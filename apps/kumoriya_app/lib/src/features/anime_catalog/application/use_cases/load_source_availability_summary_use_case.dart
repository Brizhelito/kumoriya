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
  }) : _store = store,
       _computeUseCase = computeUseCase,
       _sourcePluginIds = sourcePlugins
           .map((plugin) => plugin.manifest.id)
           .toSet(),
       _cacheCodec = cacheCodec,
       _freshTtl = freshTtl ?? const Duration(hours: 6),
       _maxStaleAge = maxStaleAge ?? const Duration(days: 3);

  final SourceAvailabilityStore _store;
  final GetSourceAvailabilitySummaryUseCase _computeUseCase;
  final Set<String> _sourcePluginIds;
  final SourceAvailabilityCacheCodec _cacheCodec;
  final Duration _freshTtl;
  final Duration _maxStaleAge;

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

      if (age <= _maxStaleAge) {
        return Success(
          LoadedSourceAvailabilitySummary(
            summary: cached.summary,
            updatedAt: cached.updatedAt,
            fromCache: true,
            shouldRefreshInBackground: age > _freshTtl || missingCoverage,
          ),
        );
      }
    }

    return _refresh(anilistDetail, now);
  }

  Future<Result<SourceAvailabilitySummary, KumoriyaError>> refresh(
    AnimeDetail anilistDetail,
  ) async {
    final refreshed = await _refresh(anilistDetail, DateTime.now());
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
    DateTime now,
  ) async {
    final summary = await _computeUseCase.call(anilistDetail);
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
          shouldRefreshInBackground: false,
        ),
      ),
      onSuccess: (_) => Success(
        LoadedSourceAvailabilitySummary(
          summary: summary,
          updatedAt: now,
          fromCache: false,
          shouldRefreshInBackground: false,
        ),
      ),
    );
  }
}
