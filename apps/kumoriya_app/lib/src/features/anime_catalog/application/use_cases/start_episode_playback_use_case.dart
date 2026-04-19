import 'dart:async';
import 'dart:developer' as developer;

import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../models/episode_playback.dart';
import '../models/source_availability.dart';
import '../services/playback_preference_policy.dart';
import '../services/resolver_registry.dart';
import '../services/source_selection_policy.dart';
import 'get_source_episode_server_links_use_case.dart';
import 'resolve_source_server_link_use_case.dart';

final class StartEpisodePlaybackUseCase {
  const StartEpisodePlaybackUseCase({
    required Map<String, SourcePlugin> sourcePlugins,
    required ResolverRegistry registry,
    required ResolveSourceServerLinkUseCase resolver,
    required AnimeProgressStore progressStore,
    required SourceSelectionPolicy sourceSelectionPolicy,
    required PlaybackPreferencePolicy playbackPreferencePolicy,
  }) : _sourcePlugins = sourcePlugins,
       _registry = registry,
       _resolver = resolver,
       _progressStore = progressStore,
       _sourceSelectionPolicy = sourceSelectionPolicy,
       _playbackPreferencePolicy = playbackPreferencePolicy;

  final Map<String, SourcePlugin> _sourcePlugins;
  final ResolverRegistry _registry;
  final ResolveSourceServerLinkUseCase _resolver;
  final AnimeProgressStore _progressStore;
  final SourceSelectionPolicy _sourceSelectionPolicy;
  final PlaybackPreferencePolicy _playbackPreferencePolicy;
  static const Set<String> _autoResolveBlockedHosts = <String>{
    'animeav1.uns.bio',
  };

  /// Resolvers whose output is not suitable for live streaming and should
  /// therefore be excluded from the auto-queue race. They remain available
  /// in the manual server picker (and, separately, in the download
  /// pipeline) but must never steal a slot from a true streaming resolver.
  ///
  /// MediaFire is the canonical example: the plugin is marked as
  /// `streamResolution` for historical reasons, but the URL it returns is
  /// a download CDN link with unreliable Range support — opening it in
  /// media_kit frequently yields a non-seekable playback session.
  static const Set<String> _autoResolveBlockedResolverIds = <String>{
    'kumoriya.resolver.mediafire',
  };

  /// Upper bound on how long the whole auto-queue race is allowed to run
  /// before giving up and routing the user into the manual picker.
  ///
  /// Individual resolver timeouts already cap per-candidate latency (6–12 s
  /// depending on the host), but when *all* candidates fail, the overall
  /// resolve time is bounded by the *slowest* failing future. That created
  /// cases where the user waited 12 s for the loader only to be dumped
  /// into the picker with no intermediate feedback. This cap shortens the
  /// worst case to a predictable ceiling.
  static const Duration _autoQueueOverallTimeout = Duration(seconds: 15);

  Future<EpisodePlaybackDecision> call({
    required int anilistId,
    required double episodeNumber,
    required SourceAvailabilitySummary availabilitySummary,
    bool allowAutomaticResolution = true,
  }) async {
    // Preference and episode progress are independent DB reads — fetch
    // them in parallel to shave one round-trip off the decision path.
    final prefAndProgress = await Future.wait(<Future<Object?>>[
      _loadPreference(anilistId),
      _loadEpisodeProgress(anilistId, episodeNumber),
    ]);
    final preference = prefAndProgress[0] as PlaybackPreference?;
    final episodeProgress = prefAndProgress[1] as EpisodeProgress?;
    final sourcesWithEpisode = _episodeCandidates(
      availabilitySummary: availabilitySummary,
      episodeNumber: episodeNumber,
    );

    if (sourcesWithEpisode.isEmpty) {
      return const EpisodePlaybackDecision.unavailable();
    }

    final optionGroups = await Future.wait(
      sourcesWithEpisode.map(
        (entry) => _loadServerOptions(
          availability: entry.availability,
          episode: entry.episode,
        ),
      ),
    );

    final options = optionGroups
        .expand((group) => group)
        .toList(growable: false);
    if (options.isEmpty) {
      return const EpisodePlaybackDecision.unavailable();
    }

    final reconciliation = _playbackPreferencePolicy.reconcile(
      anilistId: anilistId,
      durablePreference: preference,
      episodeProgress: episodeProgress,
      sourceIdsWithEpisode: sourcesWithEpisode
          .map((entry) => entry.availability.manifest.id)
          .toSet(),
      options: options,
    );

    await _persistPreference(reconciliation.persistedPreferenceUpdate);

    var durablePreference = reconciliation.durablePreference;
    final ranked = _playbackPreferencePolicy.rankOptions(
      options: options,
      durablePreference: durablePreference,
      episodePreference: reconciliation.episodePreference,
      sourcePriorityIndex: _sourceSelectionPolicy.priorityIndex,
    );
    final fullAutoQueue = allowAutomaticResolution || options.length == 1
        ? _playbackPreferencePolicy.buildAutoQueue(
            rankedOptions: ranked,
            durablePreference: durablePreference,
            episodePreference: reconciliation.episodePreference,
          )
        : const <EpisodePlaybackOption>[];
    final sanitizedAutoQueue = _sanitizeAutoQueue(
      rankedOptions: ranked,
      autoQueue: fullAutoQueue,
    );
    final attemptLimit = _playbackPreferencePolicy.automaticAttemptLimit(
      durablePreference: durablePreference,
      episodePreference: reconciliation.episodePreference,
      autoQueue: sanitizedAutoQueue,
    );
    final autoQueue = sanitizedAutoQueue
        .take(attemptLimit)
        .toList(growable: false);
    final attempted = <String>{};

    // Race all auto-queue candidates in parallel. The first successful
    // resolution wins; remaining futures are left to complete (their results
    // are discarded). This converts worst-case N × timeout into 1 × timeout.
    if (autoQueue.isNotEmpty) {
      final completer = Completer<EpisodePlaybackDecision?>();
      var pending = autoQueue.length;

      for (final option in autoQueue) {
        attempted.add(option.optionKey);
        _log(
          'auto-open start source=${option.sourcePluginId} server=${option.serverLink.serverName} resolver=${option.resolverId}',
        );

        // ignore: unawaited_futures
        _resolver.call(option.serverLink).then((resolved) {
          if (completer.isCompleted) return;

          if (resolved.isSuccess) {
            final result = resolved.fold(
              onFailure: (_) => null,
              onSuccess: (value) => value,
            );
            if (result != null) {
              completer.complete(
                EpisodePlaybackDecision.direct(
                  launch: EpisodePlayerLaunch(option: option, resolved: result),
                  autoSelectionFailed: false,
                ),
              );
              return;
            }
          }

          resolved.fold(
            onFailure: (error) {
              _log(
                'auto-open failure source=${option.sourcePluginId} server=${option.serverLink.serverName} resolver=${option.resolverId} code=${error.code} message=${error.message}',
              );
              Sentry.addBreadcrumb(
                Breadcrumb(
                  message: 'Auto-open resolver failure',
                  category: 'playback',
                  data: {
                    'source_plugin_id': option.sourcePluginId,
                    'server_name': option.serverLink.serverName,
                    'resolver_id': option.resolverId,
                    'error_code': error.code,
                  },
                ),
              );
            },
            onSuccess: (_) {},
          );

          pending--;
          if (pending == 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        });
      }

      // Enforce an overall ceiling so the worst-case "all candidates fail
      // slowly" path does not make the loader feel stuck. On timeout we
      // surface the race as if all candidates had failed, which routes
      // the user into `rankRemainingOptions` / manual picker below.
      final raceResult = await completer.future.timeout(
        _autoQueueOverallTimeout,
        onTimeout: () {
          _log(
            'auto-queue overall timeout fired after '
            '${_autoQueueOverallTimeout.inSeconds}s — falling back to manual picker',
          );
          return null;
        },
      );
      if (raceResult != null) {
        return raceResult;
      }
    }

    final remaining = _playbackPreferencePolicy.rankRemainingOptions(
      options: options,
      attemptedOptionKeys: autoQueue.length == 1 ? <String>{} : attempted,
      durablePreference: durablePreference,
      episodePreference: reconciliation.episodePreference,
      sourcePriorityIndex: _sourceSelectionPolicy.priorityIndex,
    );

    if (remaining.isEmpty) {
      if (autoQueue.isNotEmpty) {
        Sentry.captureMessage(
          'All auto-queue resolvers exhausted',
          level: SentryLevel.warning,
          withScope: (scope) {
            scope.setTag('anilist_id', anilistId.toString());
            scope.setTag('episode', episodeNumber.toString());
            scope.setTag('attempted_count', attempted.length.toString());
          },
        );
      }
      return EpisodePlaybackDecision.unavailable(
        autoSelectionFailed: autoQueue.isNotEmpty,
      );
    }

    return EpisodePlaybackDecision.selection(
      options: remaining,
      autoSelectionFailed: autoQueue.isNotEmpty,
    );
  }

  Future<PlaybackPreference?> _loadPreference(int anilistId) async {
    final result = await _progressStore.getPlaybackPreference(anilistId);
    return result.fold(onFailure: (_) => null, onSuccess: (value) => value);
  }

  Future<EpisodeProgress?> _loadEpisodeProgress(
    int anilistId,
    double episodeNumber,
  ) async {
    final result = await _progressStore.getProgress(anilistId, episodeNumber);
    return result.fold(onFailure: (_) => null, onSuccess: (value) => value);
  }

  Future<void> _persistPreference(PlaybackPreference? preference) async {
    if (preference == null) {
      return;
    }
    await _progressStore.upsertPlaybackPreference(preference);
  }

  List<_EpisodeSourceCandidate> _episodeCandidates({
    required SourceAvailabilitySummary availabilitySummary,
    required double episodeNumber,
  }) {
    final ranked = _sourceSelectionPolicy.rankAvailable(
      availabilitySummary.playableSources,
    );

    return ranked
        .map((availability) {
          SourceEpisode? matchedEpisode;
          for (final episode in availability.episodes) {
            if ((episode.number - episodeNumber).abs() < 0.001) {
              matchedEpisode = episode;
              break;
            }
          }
          if (matchedEpisode == null) {
            return null;
          }
          return _EpisodeSourceCandidate(
            availability: availability,
            episode: matchedEpisode,
          );
        })
        .whereType<_EpisodeSourceCandidate>()
        .toList(growable: false);
  }

  Future<List<EpisodePlaybackOption>> _loadServerOptions({
    required SourceAvailability availability,
    required SourceEpisode episode,
  }) async {
    final plugin = _sourcePlugins[availability.manifest.id];
    if (plugin == null) {
      return const <EpisodePlaybackOption>[];
    }

    final result = await GetSourceEpisodeServerLinksUseCase(
      sourcePlugin: plugin,
      registry: _registry,
    ).call(episode);

    return result.fold(
      onFailure: (_) => const <EpisodePlaybackOption>[],
      onSuccess: (links) {
        return links
            .map((link) {
              final selection = _registry.selectFor(link.initialUrl);
              if (selection is! ResolverSelected) {
                return null;
              }
              return EpisodePlaybackOption(
                sourcePluginId: availability.manifest.id,
                sourceName: availability.manifest.displayName,
                sourceIconUrl:
                    availability.manifest.iconUrl ??
                    _fallbackIconUrl(availability.manifest),
                sourceEpisode: episode,
                serverLink: link,
                resolverId: selection.resolver.manifest.id,
                resolverName: selection.resolver.manifest.displayName,
                audioKind: sourceAudioKindFromCode(link.language),
              );
            })
            .whereType<EpisodePlaybackOption>()
            .toList(growable: false);
      },
    );
  }

  String? _fallbackIconUrl(PluginManifest manifest) {
    if (manifest.baseUrls.isNotEmpty) {
      final uri = Uri.tryParse(manifest.baseUrls.first);
      if (uri != null && uri.hasScheme) {
        return '${uri.scheme}://${uri.host}/favicon.ico';
      }
    }
    return null;
  }

  void _log(String message) {
    developer.log(message, name: 'kumoriya.start_episode_playback');
  }

  List<EpisodePlaybackOption> _sanitizeAutoQueue({
    required List<EpisodePlaybackOption> rankedOptions,
    required List<EpisodePlaybackOption> autoQueue,
  }) {
    if (autoQueue.isEmpty) {
      return autoQueue;
    }

    final sanitized = autoQueue
        .where((option) {
          final shouldSkip = _shouldSkipAutomaticResolution(
            option: option,
            rankedOptions: rankedOptions,
          );
          if (shouldSkip) {
            _log(
              'auto-open skipped source=${option.sourcePluginId} '
              'server=${option.serverLink.serverName} '
              'host=${option.serverLink.initialUrl.host} '
              'resolver=${option.resolverId}',
            );
          }
          return !shouldSkip;
        })
        .toList(growable: false);

    if (sanitized.isNotEmpty || rankedOptions.length <= 1) {
      return sanitized;
    }

    for (final option in rankedOptions) {
      if (!_shouldSkipAutomaticResolution(
        option: option,
        rankedOptions: rankedOptions,
      )) {
        return <EpisodePlaybackOption>[option];
      }
    }

    // Hard block: if every remaining option belongs to a resolver that is
    // categorically excluded from auto-resolution (e.g. MediaFire), do not
    // fall back to the original `autoQueue`. Returning an empty list routes
    // the user into the manual picker, which is the only correct outcome
    // for download-only resolvers.
    final allHardBlocked = rankedOptions.every(
      (option) => _autoResolveBlockedResolverIds.contains(option.resolverId),
    );
    if (allHardBlocked) {
      return const <EpisodePlaybackOption>[];
    }

    return autoQueue;
  }

  bool _shouldSkipAutomaticResolution({
    required EpisodePlaybackOption option,
    required List<EpisodePlaybackOption> rankedOptions,
  }) {
    final host = option.serverLink.initialUrl.host.toLowerCase();
    final resolverId = option.resolverId;
    final hostBlocked = _autoResolveBlockedHosts.contains(host);
    final resolverBlocked = _autoResolveBlockedResolverIds.contains(resolverId);
    // Download-only resolvers (e.g. MediaFire) must never enter the
    // auto-queue, even if they are the last remaining option. Forcing them
    // in yields a non-seekable "playback" that looks like a bug; the user
    // is better served by the manual picker or the download pipeline.
    if (resolverBlocked) {
      return true;
    }
    if (!hostBlocked) {
      return false;
    }

    return rankedOptions.any((candidate) {
      if (candidate.optionKey == option.optionKey) {
        return false;
      }
      final candidateHost = candidate.serverLink.initialUrl.host.toLowerCase();
      final candidateResolverBlocked = _autoResolveBlockedResolverIds.contains(
        candidate.resolverId,
      );
      if (candidateResolverBlocked) {
        return false;
      }
      return !_autoResolveBlockedHosts.contains(candidateHost);
    });
  }
}

final class _EpisodeSourceCandidate {
  const _EpisodeSourceCandidate({
    required this.availability,
    required this.episode,
  });

  final SourceAvailability availability;
  final SourceEpisode episode;
}
