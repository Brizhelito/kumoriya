import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../anime_catalog/application/services/source_availability_cache_codec.dart';
import '../../anime_catalog/application/models/source_availability.dart';

typedef SourceEpisodeServerLinksLoader =
    Future<Result<List<SourceServerLink>, KumoriyaError>> Function({
      required SourcePlugin sourcePlugin,
      required SourceEpisode sourceEpisode,
    });

typedef EpisodeDownloadEnqueuer =
    Future<Result<void, KumoriyaError>> Function({
      required int anilistId,
      required double episodeNumber,
      required SourceServerLink serverLink,
      required String sourcePluginId,
      String? animeTitle,
      String? coverImageUrl,
      String? episodeTitle,
    });

typedef DownloadAniSkipPrefetcher =
    Future<void> Function({required int anilistId, required int episodeNumber});

final class AutoDownloadNewEpisodesReport {
  const AutoDownloadNewEpisodesReport({
    this.disabled = false,
    this.requestedEpisodes = 0,
    this.alreadyQueuedEpisodes = 0,
    this.missingSourceEpisodes = 0,
    this.enqueuedEpisodes = 0,
    this.failedEpisodes = 0,
  });

  final bool disabled;
  final int requestedEpisodes;
  final int alreadyQueuedEpisodes;
  final int missingSourceEpisodes;
  final int enqueuedEpisodes;
  final int failedEpisodes;
}

final class AutoDownloadNewEpisodesService {
  AutoDownloadNewEpisodesService({
    required LibraryStore libraryStore,
    required DownloadStore downloadStore,
    required SourceAvailabilityStore sourceAvailabilityStore,
    required SourceAvailabilityCacheCodec sourceAvailabilityCacheCodec,
    required List<SourcePlugin> sourcePlugins,
    required SourceEpisodeServerLinksLoader loadServerLinks,
    required EpisodeDownloadEnqueuer enqueueDownload,
    DownloadAniSkipPrefetcher? prefetchAniSkip,
    this.excludedSourcePluginId = 'kumoriya.source.anime_nexus',
  }) : _libraryStore = libraryStore,
       _downloadStore = downloadStore,
       _sourceAvailabilityStore = sourceAvailabilityStore,
       _sourceAvailabilityCacheCodec = sourceAvailabilityCacheCodec,
       _sourcePluginById = {
         for (final plugin in sourcePlugins) plugin.manifest.id: plugin,
       },
       _loadServerLinks = loadServerLinks,
       _enqueueDownload = enqueueDownload,
       _prefetchAniSkip = prefetchAniSkip;

  final LibraryStore _libraryStore;
  final DownloadStore _downloadStore;
  final SourceAvailabilityStore _sourceAvailabilityStore;
  final SourceAvailabilityCacheCodec _sourceAvailabilityCacheCodec;
  final Map<String, SourcePlugin> _sourcePluginById;
  final SourceEpisodeServerLinksLoader _loadServerLinks;
  final EpisodeDownloadEnqueuer _enqueueDownload;
  final DownloadAniSkipPrefetcher? _prefetchAniSkip;
  final String excludedSourcePluginId;

  Future<AutoDownloadNewEpisodesReport> enqueueEpisodes({
    required int anilistId,
    required Iterable<int> episodeNumbers,
    String? animeTitle,
    String? coverImageUrl,
  }) async {
    final requested = episodeNumbers.where((episode) => episode > 0).toSet();
    if (requested.isEmpty) {
      return const AutoDownloadNewEpisodesReport();
    }

    final autoDownloadIdsResult = await _libraryStore.getAutoDownloadAnimeIds();
    final autoDownloadIds = autoDownloadIdsResult.fold(
      onSuccess: (ids) => ids,
      onFailure: (_) => const <int>{},
    );
    if (!autoDownloadIds.contains(anilistId)) {
      return AutoDownloadNewEpisodesReport(
        disabled: true,
        requestedEpisodes: requested.length,
      );
    }

    final audioPreference =
        (await _libraryStore.getAutoDownloadAudioPreference(anilistId)) ??
        'none';
    final preferredAudioKind = switch (audioPreference) {
      'sub' => SourceAudioKind.sub,
      'dub' => SourceAudioKind.dub,
      _ => null,
    };

    final tasksResult = await _downloadStore.getTasksByAnime(anilistId);
    final existingEpisodes = tasksResult.fold(
      onSuccess: (tasks) => tasks.map((task) => task.episodeNumber).toSet(),
      onFailure: (_) => const <double>{},
    );

    final cached = await _sourceAvailabilityStore.getAvailability(anilistId);
    final snapshot = cached.fold(
      onSuccess: _sourceAvailabilityCacheCodec.decode,
      onFailure: (_) => null,
    );
    final summary = snapshot?.summary;
    if (summary == null) {
      return AutoDownloadNewEpisodesReport(
        requestedEpisodes: requested.length,
        missingSourceEpisodes: requested.length,
      );
    }

    final orderedSources =
        <SourceAvailability>[
              if (summary.recommended != null) summary.recommended!,
              ...summary.playableSources.where(
                (source) =>
                    summary.recommended == null ||
                    source.manifest.id != summary.recommended!.manifest.id,
              ),
            ]
            .where((source) => source.manifest.id != excludedSourcePluginId)
            .toList(growable: false);

    final candidates =
        <int, ({String sourcePluginId, SourceEpisode episode})>{};
    var alreadyQueuedEpisodes = 0;

    for (final episodeNumber in requested.toList()..sort()) {
      if (existingEpisodes.contains(episodeNumber.toDouble())) {
        alreadyQueuedEpisodes++;
        continue;
      }

      final preferredSources = _prioritizeSourcesByAudioPreference(
        sources: orderedSources,
        preferredAudioKind: preferredAudioKind,
      );

      for (final source in preferredSources) {
        final matched = source.episodes.where(
          (episode) => _episodeKey(episode.number) == episodeNumber,
        );
        if (matched.isEmpty) {
          continue;
        }
        candidates[episodeNumber] = (
          sourcePluginId: source.manifest.id,
          episode: matched.first,
        );
        break;
      }
    }

    var missingSourceEpisodes = 0;
    var enqueuedEpisodes = 0;
    var failedEpisodes = 0;

    for (final episodeNumber in requested.toList()..sort()) {
      if (existingEpisodes.contains(episodeNumber.toDouble())) {
        continue;
      }

      final candidate = candidates[episodeNumber];
      if (candidate == null) {
        missingSourceEpisodes++;
        continue;
      }

      final sourcePlugin = _sourcePluginById[candidate.sourcePluginId];
      if (sourcePlugin == null) {
        failedEpisodes++;
        continue;
      }

      final linksResult = await _loadServerLinks(
        sourcePlugin: sourcePlugin,
        sourceEpisode: candidate.episode,
      );
      final links = linksResult.fold(
        onSuccess: (value) => value,
        onFailure: (_) => const <SourceServerLink>[],
      );
      if (links.isEmpty) {
        failedEpisodes++;
        continue;
      }

      final preferredLinks = _prioritizeServerLinksByAudioPreference(
        links: links,
        preferredAudioKind: preferredAudioKind,
      );

      await _tryPrefetchAniSkip(
        anilistId: anilistId,
        episodeNumber: candidate.episode.number.toInt(),
      );

      final enqueueResult = await _enqueueDownload(
        anilistId: anilistId,
        episodeNumber: candidate.episode.number,
        serverLink: preferredLinks.first,
        sourcePluginId: candidate.sourcePluginId,
        animeTitle: animeTitle,
        coverImageUrl: coverImageUrl,
        episodeTitle: candidate.episode.title,
      );
      enqueueResult.fold(
        onSuccess: (_) {
          enqueuedEpisodes++;
          existingEpisodes.add(candidate.episode.number);
        },
        onFailure: (_) {
          failedEpisodes++;
        },
      );
    }

    return AutoDownloadNewEpisodesReport(
      requestedEpisodes: requested.length,
      alreadyQueuedEpisodes: alreadyQueuedEpisodes,
      missingSourceEpisodes: missingSourceEpisodes,
      enqueuedEpisodes: enqueuedEpisodes,
      failedEpisodes: failedEpisodes,
    );
  }

  int? _episodeKey(double episodeNumber) {
    final rounded = episodeNumber.round();
    if ((episodeNumber - rounded).abs() > 0.001) {
      return null;
    }
    return rounded;
  }

  List<SourceAvailability> _prioritizeSourcesByAudioPreference({
    required List<SourceAvailability> sources,
    required SourceAudioKind? preferredAudioKind,
  }) {
    if (preferredAudioKind == null) {
      return sources;
    }

    final matching = <SourceAvailability>[];
    final fallback = <SourceAvailability>[];
    for (final source in sources) {
      if (source.availableAudioKinds.contains(preferredAudioKind)) {
        matching.add(source);
      } else {
        fallback.add(source);
      }
    }
    return <SourceAvailability>[...matching, ...fallback];
  }

  List<SourceServerLink> _prioritizeServerLinksByAudioPreference({
    required List<SourceServerLink> links,
    required SourceAudioKind? preferredAudioKind,
  }) {
    if (preferredAudioKind == null) {
      return links;
    }

    final matching = <SourceServerLink>[];
    final fallback = <SourceServerLink>[];
    for (final link in links) {
      if (sourceAudioKindFromCode(link.language) == preferredAudioKind) {
        matching.add(link);
      } else {
        fallback.add(link);
      }
    }
    return <SourceServerLink>[...matching, ...fallback];
  }

  Future<void> _tryPrefetchAniSkip({
    required int anilistId,
    required int episodeNumber,
  }) async {
    if (episodeNumber <= 0 || _prefetchAniSkip == null) {
      return;
    }

    try {
      await _prefetchAniSkip(
        anilistId: anilistId,
        episodeNumber: episodeNumber,
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Soft-fail: auto-download should proceed even if AniSkip prefetch fails.
    }
  }
}
