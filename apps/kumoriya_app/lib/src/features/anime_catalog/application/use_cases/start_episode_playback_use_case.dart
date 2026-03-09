import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../models/episode_playback.dart';
import '../models/source_availability.dart';
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
  }) : _sourcePlugins = sourcePlugins,
       _registry = registry,
       _resolver = resolver,
       _progressStore = progressStore,
       _sourceSelectionPolicy = sourceSelectionPolicy;

  final Map<String, SourcePlugin> _sourcePlugins;
  final ResolverRegistry _registry;
  final ResolveSourceServerLinkUseCase _resolver;
  final AnimeProgressStore _progressStore;
  final SourceSelectionPolicy _sourceSelectionPolicy;

  Future<EpisodePlaybackDecision> call({
    required int anilistId,
    required double episodeNumber,
    required SourceAvailabilitySummary availabilitySummary,
  }) async {
    final preference = await _loadPreference(anilistId);
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

    final ranked = _rankOptions(options, preference);
    final autoQueue = _buildAutoQueue(ranked, preference);
    final attempted = <String>{};

    for (final option in autoQueue) {
      attempted.add(option.optionKey);
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
    }

    final remaining = ranked
        .where((option) => !attempted.contains(option.optionKey))
        .toList(growable: false);

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

  List<EpisodePlaybackOption> _rankOptions(
    List<EpisodePlaybackOption> options,
    PlaybackPreference? preference,
  ) {
    final ranked = [...options];
    ranked.sort(
      (left, right) => _scoreOption(
        right,
        preference,
      ).compareTo(_scoreOption(left, preference)),
    );

    if (ranked.isEmpty) {
      return ranked;
    }

    final preferredKey = ranked.first.optionKey;
    return ranked
        .map(
          (option) => option.copyWith(
            isPreferred: _matchesExactPreference(option, preference),
            isRecommended: option.optionKey == preferredKey,
          ),
        )
        .toList(growable: false);
  }

  int _scoreOption(
    EpisodePlaybackOption option,
    PlaybackPreference? preference,
  ) {
    var score =
        1000 -
        _sourceSelectionPolicy.priorityIndex(option.sourcePluginId) * 100;

    if (preference == null) {
      return score;
    }

    if (option.sourcePluginId == preference.preferredSourcePluginId) {
      score += 240;
    }
    if (option.serverLink.serverName == preference.preferredServerName) {
      score += 360;
    }
    if (option.resolverId == preference.preferredResolverPluginId) {
      score += 140;
    }
    if (option.audioKind != null &&
        preference.preferredAudioPreference != null &&
        option.audioKind!.name == preference.preferredAudioPreference!.name) {
      score += 90;
    }

    return score;
  }

  List<EpisodePlaybackOption> _buildAutoQueue(
    List<EpisodePlaybackOption> ranked,
    PlaybackPreference? preference,
  ) {
    if (ranked.isEmpty) {
      return const <EpisodePlaybackOption>[];
    }

    final queue = <EpisodePlaybackOption>[];
    final seenKeys = <String>{};

    void add(EpisodePlaybackOption? option) {
      if (option == null || !seenKeys.add(option.optionKey)) {
        return;
      }
      queue.add(option);
    }

    add(
      ranked.cast<EpisodePlaybackOption?>().firstWhere(
        (option) =>
            option != null && _matchesExactPreference(option, preference),
        orElse: () => null,
      ),
    );

    if (preference?.preferredSourcePluginId != null) {
      final sourceMatches = ranked
          .where(
            (option) =>
                option.sourcePluginId == preference!.preferredSourcePluginId,
          )
          .toList(growable: false);
      if (sourceMatches.length == 1) {
        add(sourceMatches.first);
      }
    }

    final topSourceId = ranked.first.sourcePluginId;
    final topSourceOptions = ranked
        .where((option) => option.sourcePluginId == topSourceId)
        .toList(growable: false);

    if (topSourceOptions.length == 1) {
      add(topSourceOptions.first);
    }

    if (ranked.length == 1) {
      add(ranked.first);
    }

    return queue;
  }

  bool _matchesExactPreference(
    EpisodePlaybackOption option,
    PlaybackPreference? preference,
  ) {
    if (preference == null) {
      return false;
    }

    if (preference.preferredSourcePluginId != null &&
        option.sourcePluginId != preference.preferredSourcePluginId) {
      return false;
    }
    if (preference.preferredServerName != null &&
        option.serverLink.serverName != preference.preferredServerName) {
      return false;
    }
    if (preference.preferredResolverPluginId != null &&
        option.resolverId != preference.preferredResolverPluginId) {
      return false;
    }
    if (preference.preferredAudioPreference != null &&
        option.audioKind?.name != preference.preferredAudioPreference!.name) {
      return false;
    }

    return preference.preferredSourcePluginId != null ||
        preference.preferredServerName != null ||
        preference.preferredResolverPluginId != null ||
        preference.preferredAudioPreference != null;
  }

  String? _fallbackIconUrl(PluginManifest manifest) {
    if (manifest.baseUrls.isEmpty) {
      return null;
    }

    final base = Uri.tryParse(manifest.baseUrls.first);
    if (base == null || !base.hasScheme) {
      return null;
    }

    return base.resolve('/favicon.ico').toString();
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
