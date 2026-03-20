import 'dart:async';
import 'dart:developer' as developer;

import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../models/source_availability.dart';
import '../use_cases/load_source_availability_summary_use_case.dart';

final class BackgroundSourceAvailabilityWarmupService {
  BackgroundSourceAvailabilityWarmupService({
    required Future<Result<AnimeDetail, KumoriyaError>> Function(int anilistId)
    loadAnimeDetail,
    required LoadSourceAvailabilitySummaryUseCase loadSourceAvailability,
    int maxConcurrent = 2,
  }) : _loadAnimeDetail = loadAnimeDetail,
       _loadSourceAvailability = loadSourceAvailability,
       _maxConcurrent = maxConcurrent.clamp(1, 4);

  final Future<Result<AnimeDetail, KumoriyaError>> Function(int anilistId)
  _loadAnimeDetail;
  final LoadSourceAvailabilitySummaryUseCase _loadSourceAvailability;
  final int _maxConcurrent;

  Future<void> warmUp(Iterable<int> anilistIds) async {
    final uniqueIds = anilistIds.toSet().toList(growable: false);
    if (uniqueIds.isEmpty) {
      return;
    }

    for (var index = 0; index < uniqueIds.length; index += _maxConcurrent) {
      final end = (index + _maxConcurrent < uniqueIds.length)
          ? index + _maxConcurrent
          : uniqueIds.length;
      final batch = uniqueIds.sublist(index, end);
      await Future.wait(batch.map(_warmSingle));
    }
  }

  Future<void> _warmSingle(int anilistId) async {
    final detailResult = await _loadAnimeDetail(anilistId);
    if (detailResult case Failure<AnimeDetail, KumoriyaError> failure) {
      developer.log(
        'Skipping warmup for anime $anilistId: ${failure.error.message}',
        name: 'BackgroundSourceAvailabilityWarmupService',
      );
      return;
    }

    final detail = (detailResult as Success<AnimeDetail, KumoriyaError>).value;
    final refreshResult = await _loadSourceAvailability.refresh(detail);
    if (refreshResult
        case Failure<SourceAvailabilitySummary, KumoriyaError> failure) {
      developer.log(
        'Availability warmup failed for anime $anilistId: ${failure.error.message}',
        name: 'BackgroundSourceAvailabilityWarmupService',
      );
    }
  }
}
