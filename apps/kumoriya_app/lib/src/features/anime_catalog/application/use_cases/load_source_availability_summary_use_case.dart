import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../models/source_availability.dart';
import '../services/source_availability_cache_codec.dart';
import 'get_source_availability_summary_use_case.dart';

final class LoadedSourceAvailabilitySummary {
  const LoadedSourceAvailabilitySummary({
    required this.summary,
    required this.updatedAt,
    required this.fromCache,
    required this.shouldRefreshInBackground,
  });

  final SourceAvailabilitySummary summary;
  final DateTime updatedAt;
  final bool fromCache;
  final bool shouldRefreshInBackground;
}

final class LoadSourceAvailabilitySummaryUseCase {
  LoadSourceAvailabilitySummaryUseCase({
    required SourceAvailabilityStore store,
    required GetSourceAvailabilitySummaryUseCase computeUseCase,
    required List<SourcePlugin> sourcePlugins,
    required SourceAvailabilityCacheCodec cacheCodec,
    Duration? freshTtl,
    Duration? maxStaleAge,
    Duration? unavailableFreshTtl,
    Duration? airingEpisodeFreshTtl,
  }) : _store = store,
       _computeUseCase = computeUseCase,
       _sourcePluginIds = sourcePlugins
           .map((plugin) => plugin.manifest.id)
           .toSet(),
       _cacheCodec = cacheCodec,
       _freshTtl = freshTtl ?? const Duration(hours: 4),
       _maxStaleAge = maxStaleAge ?? const Duration(hours: 12),
       _unavailableFreshTtl =
           unavailableFreshTtl ?? const Duration(minutes: 10),
       _airingEpisodeFreshTtl =
           airingEpisodeFreshTtl ?? const Duration(minutes: 2);

  final SourceAvailabilityStore _store;
  final GetSourceAvailabilitySummaryUseCase _computeUseCase;
  final Set<String> _sourcePluginIds;
  final SourceAvailabilityCacheCodec _cacheCodec;
  final Duration _freshTtl;
  final Duration _maxStaleAge;
  final Duration _unavailableFreshTtl;
  final Duration _airingEpisodeFreshTtl;

  Future<Result<LoadedSourceAvailabilitySummary, KumoriyaError>> call(
    AnimeDetail anilistDetail,
  ) async {
    final now = DateTime.now();
    final cached = await _readCached(anilistDetail.anime.anilistId);
    if (cached != null) {
      final age = now.difference(cached.updatedAt);
      final missingCoverage = _sourcePluginIds
          .difference(cached.coveredSourcePluginIds)
          .isNotEmpty;
      final hasPlayableSources = cached.summary.playableSources.isNotEmpty;
      final missingAiredEpisode = _hasMissingAiredSourceEpisode(
        anilistDetail,
        cached.summary,
      );

      if (age <= _maxStaleAge) {
        if (missingAiredEpisode && age > _airingEpisodeFreshTtl) {
          return _refresh(anilistDetail, now);
        }

        return Success(
          LoadedSourceAvailabilitySummary(
            summary: cached.summary,
            updatedAt: cached.updatedAt,
            fromCache: true,
            shouldRefreshInBackground:
                age > (hasPlayableSources ? _freshTtl : _unavailableFreshTtl) ||
                missingCoverage ||
                !hasPlayableSources ||
                missingAiredEpisode,
          ),
        );
      }
    }

    return _refresh(anilistDetail, now);
  }

  bool _hasMissingAiredSourceEpisode(
    AnimeDetail anilistDetail,
    SourceAvailabilitySummary summary,
  ) {
    if (anilistDetail.anime.status != AnimeStatus.releasing) {
      return false;
    }

    final airedEpisodeNumbers = anilistDetail.episodes
        .where((episode) => episode.isAired)
        .map((episode) => episode.number)
        .toSet();
    if (airedEpisodeNumbers.isEmpty || summary.playableSources.isEmpty) {
      return false;
    }

    final sourceEpisodeNumbers = <double>{
      for (final source in summary.playableSources)
        for (final episode in source.episodes) episode.number,
    };

    return airedEpisodeNumbers.any(
      (episodeNumber) => !sourceEpisodeNumbers.contains(episodeNumber),
    );
  }

  Future<Result<SourceAvailabilitySummary, KumoriyaError>> refresh(
    AnimeDetail anilistDetail,
  ) async {
    final refreshed = await _refresh(
      anilistDetail,
      DateTime.now(),
      enforceSourceTimeout: false,
    );
    return refreshed.fold(
      onFailure: Failure.new,
      onSuccess: (value) => Success(value.summary),
    );
  }

  Future<CachedSourceAvailabilitySnapshot?> _readCached(int anilistId) async {
    final cachedResult = await _store.getAvailability(anilistId);
    return cachedResult.fold(
      onFailure: (_) => null,
      onSuccess: _cacheCodec.decode,
    );
  }

  Future<Result<LoadedSourceAvailabilitySummary, KumoriyaError>> _refresh(
    AnimeDetail anilistDetail,
    DateTime now, {
    bool enforceSourceTimeout = true,
  }) async {
    var summary = await _computeUseCase.call(
      anilistDetail,
      enforceSourceTimeout: enforceSourceTimeout,
    );
    if (enforceSourceTimeout &&
        summary.playableSources.isEmpty &&
        _hasTimedOutSources(summary)) {
      summary = await _computeUseCase.call(
        anilistDetail,
        enforceSourceTimeout: false,
      );
    }
    final shouldRefreshInBackground =
        enforceSourceTimeout && _hasTimedOutSources(summary);
    final persistResult = await _store.replaceAvailability(
      anilistDetail.anime.anilistId,
      _cacheCodec.encode(
        anilistId: anilistDetail.anime.anilistId,
        summary: summary,
        updatedAt: now,
      ),
    );

    return persistResult.fold(
      onFailure: (_) => Success(
        LoadedSourceAvailabilitySummary(
          summary: summary,
          updatedAt: now,
          fromCache: false,
          shouldRefreshInBackground: shouldRefreshInBackground,
        ),
      ),
      onSuccess: (_) => Success(
        LoadedSourceAvailabilitySummary(
          summary: summary,
          updatedAt: now,
          fromCache: false,
          shouldRefreshInBackground: shouldRefreshInBackground,
        ),
      ),
    );
  }

  bool _hasTimedOutSources(SourceAvailabilitySummary summary) {
    return summary.sources.any(
      (source) => source.decision.rejectionSignals.contains(
        'source-availability-timeout',
      ),
    );
  }
}
