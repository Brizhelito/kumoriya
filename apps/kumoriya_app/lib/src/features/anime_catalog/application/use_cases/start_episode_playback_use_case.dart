import 'dart:developer' as developer;

import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

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

  Future<EpisodePlaybackDecision> call({
    required int anilistId,
    required double episodeNumber,
    required SourceAvailabilitySummary availabilitySummary,
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
    final autoQueue = _playbackPreferencePolicy
        .buildAutoQueue(
          rankedOptions: ranked,
          durablePreference: durablePreference,
          episodePreference: reconciliation.episodePreference,
        )
        .take(
          _playbackPreferencePolicy.automaticAttemptLimit(
            durablePreference: durablePreference,
            episodePreference: reconciliation.episodePreference,
          ),
        )
        .toList(growable: false);
    final attempted = <String>{};

    for (final option in autoQueue) {
      attempted.add(option.optionKey);
      _log(
        'auto-open start source=${option.sourcePluginId} server=${option.serverLink.serverName} resolver=${option.resolverId}',
      );
      final resolved = await _resolver.call(option.serverLink);
      if (resolved.isSuccess) {
        final result = resolved.fold(
          onFailure: (_) => null,
          onSuccess: (value) => value,
        );
        if (result != null) {
          return EpisodePlaybackDecision.direct(
            launch: EpisodePlayerLaunch(option: option, resolved: result),
            autoSelectionFailed: attempted.length > 1,
          );
        }
      }
      resolved.fold(
        onFailure: (error) {
          _log(
            'auto-open failure source=${option.sourcePluginId} server=${option.serverLink.serverName} resolver=${option.resolverId} code=${error.code} message=${error.message}',
          );
        },
        onSuccess: (_) {},
      );

      final invalidated = _playbackPreferencePolicy.invalidateAfterAutoFailure(
        durablePreference: durablePreference,
        failedOption: option,
        rankedOptions: _playbackPreferencePolicy.remainingOptions(
          options: ranked,
          attemptedOptionKeys: attempted,
        ),
      );
      if (invalidated != null) {
        durablePreference = invalidated;
        await _persistPreference(invalidated);
      }
    }

    final remaining = _playbackPreferencePolicy.rankRemainingOptions(
      options: options,
      attemptedOptionKeys: attempted,
      durablePreference: durablePreference,
      episodePreference: reconciliation.episodePreference,
      sourcePriorityIndex: _sourceSelectionPolicy.priorityIndex,
    );

    if (remaining.isEmpty) {
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
    return null;
  }

  void _log(String message) {
    developer.log(message, name: 'kumoriya.start_episode_playback');
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
