import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/matching/anilist_source_matcher.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/source_availability.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/check_source_availability_use_case.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_anime_nexus/kumoriya_source_anime_nexus.dart';
import 'package:kumoriya_source_animeav1/kumoriya_source_animeav1.dart';
import 'package:kumoriya_source_animeflv/kumoriya_source_animeflv.dart';
import 'package:kumoriya_source_jkanime/kumoriya_source_jkanime.dart';

void main() {
  test(
    'probe live AniList current-week airing titles across all source plugins',
    () async {
      final output = await _runProbe();

      final outputFile = File(
        r'c:\Users\Reny\Documents\Kumoriya\build\test_cache\current_airing_availability_probe_2026-03-18.json',
      );
      outputFile.parent.createSync(recursive: true);
      outputFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(output),
      );

      expect(output['summary'], isNotNull);
    },
    timeout: const Timeout(Duration(minutes: 30)),
    skip:
        'Expensive live network probe. Run manually when current-airing audit is needed.',
  );
}

Future<Map<String, Object?>> _runProbe() async {
  final titles = await _fetchCurrentWeekAiringAnimeDetails();
  const matcher = AnilistSourceMatcher();
  final plugins = <String, _RecordingSourcePlugin>{
    'jkanime': _RecordingSourcePlugin(JkAnimeSourcePlugin()),
    'animeflv': _RecordingSourcePlugin(AnimeFlvSourcePlugin()),
    'animeav1': _RecordingSourcePlugin(AnimeAv1SourcePlugin()),
    'anime_nexus': _RecordingSourcePlugin(AnimeNexusSourcePlugin()),
  };
  final useCases = <String, CheckSourceAvailabilityUseCase>{
    for (final entry in plugins.entries)
      entry.key: CheckSourceAvailabilityUseCase(
        sourcePlugin: entry.value,
        matcher: matcher,
      ),
  };

  final perSourceAvailable = <String, int>{
    for (final sourceId in plugins.keys) sourceId: 0,
  };
  final uncoveredTitles = <Map<String, Object?>>[];
  final excludedUncoveredTitles = <Map<String, Object?>>[];
  final spotlightTitles = <Map<String, Object?>>[];
  var withAnySource = 0;
  var withoutAnySource = 0;
  var actionableWithoutAnySource = 0;
  var nonActionableWithoutAnySource = 0;
  var pokemonWithoutAnySource = 0;

  for (final detail in titles) {
    final sourceResults = <Map<String, Object?>>[];
    final availableSources = <String>[];
    final availabilityResults = await Future.wait(
      plugins.entries.map((entry) async {
        entry.value.reset();
        final availability = await useCases[entry.key]!.call(detail);
        return (entry: entry, availability: availability);
      }),
    );

    for (final result in availabilityResults) {
      final entry = result.entry;
      final availability = result.availability;
      if (availability.status == SourceAvailabilityStatus.available) {
        perSourceAvailable[entry.key] = perSourceAvailable[entry.key]! + 1;
        availableSources.add(entry.key);
      }

      sourceResults.add(<String, Object?>{
        'source': entry.key,
        'status': availability.status.name,
        'matched_source_id': availability.matchedAnime?.sourceId,
        'matched_title': availability.matchedAnime?.title,
        'decision_reason': availability.decision.reason,
        'unavailable_reason': availability.unavailableReason?.name,
        'error_message': availability.errorMessage,
        'queries_attempted': entry.value.queriesAttempted.toList(
          growable: false,
        ),
        'detail_probes_attempted': entry.value.detailProbesAttempted.toList(
          growable: false,
        ),
      });
    }

    final isPokemon = _isPokemonTitle(detail.anime);
    final gapClassification = _classifyCoverageGap(detail.anime);
    final titleRow = <String, Object?>{
      'anilist_id': detail.anime.anilistId,
      'title': detail.anime.title.romaji,
      'format': detail.anime.format.name,
      'season_year': detail.anime.releaseYear,
      'next_airing_at': detail.anime.nextAiringAt?.toIso8601String(),
      'available_sources': availableSources,
      'is_pokemon': isPokemon,
      'coverage_gap_status': gapClassification.status,
      'coverage_gap_reason': gapClassification.reason,
      'source_results': sourceResults,
    };

    if (availableSources.isEmpty) {
      withoutAnySource += 1;
      if (isPokemon) {
        pokemonWithoutAnySource += 1;
      }
      if (gapClassification.isActionable) {
        actionableWithoutAnySource += 1;
        uncoveredTitles.add(titleRow);
      } else {
        nonActionableWithoutAnySource += 1;
        excludedUncoveredTitles.add(titleRow);
      }
    } else {
      withAnySource += 1;
    }

    if (detail.anime.anilistId == 191205) {
      spotlightTitles.add(titleRow);
    }
  }

  uncoveredTitles.sort((left, right) {
    final leftTitle = left['title']?.toString() ?? '';
    final rightTitle = right['title']?.toString() ?? '';
    return leftTitle.compareTo(rightTitle);
  });
  excludedUncoveredTitles.sort((left, right) {
    final leftTitle = left['title']?.toString() ?? '';
    final rightTitle = right['title']?.toString() ?? '';
    return leftTitle.compareTo(rightTitle);
  });

  return <String, Object?>{
    'summary': <String, Object?>{
      'generated_at': DateTime.now().toIso8601String(),
      'total_titles': titles.length,
      'titles_with_any_source': withAnySource,
      'titles_without_any_source': actionableWithoutAnySource,
      'titles_without_any_source_raw': withoutAnySource,
      'titles_without_any_source_non_actionable': nonActionableWithoutAnySource,
      'titles_without_any_source_excluding_pokemon_raw':
          withoutAnySource - pokemonWithoutAnySource,
      'per_source_available': perSourceAvailable,
    },
    'spotlight_titles': spotlightTitles,
    'uncovered_titles': uncoveredTitles,
    'excluded_uncovered_titles': excludedUncoveredTitles,
  };
}

Future<List<AnimeDetail>> _fetchCurrentWeekAiringAnimeDetails() async {
  final repository = AnilistAnimeCatalogRepository(
    gateway: GraphqlAnilistMetadataGateway(client: HttpAnilistGraphqlClient()),
  );
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day);
  final calendarResult = await repository.fetchAiringCalendar(
    from: from,
    to: from.add(const Duration(days: 7)),
    perPage: 100,
  );

  final animeList = calendarResult.fold(
    onFailure: (error) => throw StateError(
      'AniList airing calendar query failed: ${error.code} ${error.message}',
    ),
    onSuccess: (value) => value,
  );

  final details = <AnimeDetail>[];
  for (final anime in animeList) {
    final detailResult = await repository.fetchAnimeDetail(anime.anilistId);
    final detail = detailResult.fold(
      onFailure: (_) => AnimeDetail(anime: anime),
      onSuccess: (value) => value,
    );
    details.add(detail);
  }

  return details;
}

bool _isPokemonTitle(Anime anime) {
  final titles = <String?>[
    anime.title.romaji,
    anime.title.english,
    anime.title.native,
    ...anime.title.synonyms,
  ];

  for (final value in titles) {
    final normalized = value?.toLowerCase();
    if (normalized == null) {
      continue;
    }
    if (normalized.contains('pokemon') || normalized.contains('pokémon')) {
      return true;
    }
  }

  return false;
}

const Map<int, _CoverageGapClassification>
_manualCoverageGapAudit = <int, _CoverageGapClassification>{
  200930: _CoverageGapClassification.nonActionable('adult-out-of-scope'),
  198373: _CoverageGapClassification.nonActionable(
    'manual-audit-non-actionable',
  ),
  203146: _CoverageGapClassification.nonActionable(
    'manual-audit-non-actionable',
  ),
  165159: _CoverageGapClassification.nonActionable(
    'manual-audit-non-actionable',
  ),
  205676: _CoverageGapClassification.nonActionable(
    'manual-audit-non-actionable',
  ),
  140842: _CoverageGapClassification.nonActionable(
    'manual-audit-non-actionable',
  ),
  966: _CoverageGapClassification.nonActionable('manual-audit-non-actionable'),
  8687: _CoverageGapClassification.nonActionable('manual-audit-non-actionable'),
  137683: _CoverageGapClassification.nonActionable(
    'manual-audit-non-actionable',
  ),
  8336: _CoverageGapClassification.nonActionable('manual-audit-non-actionable'),
  203148: _CoverageGapClassification.nonActionable(
    'manual-audit-non-actionable',
  ),
  190327: _CoverageGapClassification.nonActionable(
    'manual-audit-non-actionable',
  ),
  184289: _CoverageGapClassification.nonActionable(
    'manual-audit-non-actionable',
  ),
  194389: _CoverageGapClassification.nonActionable(
    'manual-audit-non-actionable',
  ),
  142274: _CoverageGapClassification.nonActionable(
    'manual-audit-non-actionable',
  ),
  206857: _CoverageGapClassification.nonActionable(
    'manual-audit-non-actionable',
  ),
  199635: _CoverageGapClassification.nonActionable(
    'manual-audit-non-actionable',
  ),
  158871: _CoverageGapClassification.nonActionable(
    'manual-audit-non-actionable',
  ),
  199446: _CoverageGapClassification.nonActionable(
    'manual-audit-non-actionable',
  ),
  188529: _CoverageGapClassification.nonActionable(
    'manual-audit-non-actionable',
  ),
  187166: _CoverageGapClassification.actionable(
    'manual-audit-confirmed-source-miss',
  ),
  235: _CoverageGapClassification.actionable(
    'manual-audit-confirmed-source-miss',
  ),
};

_CoverageGapClassification _classifyCoverageGap(Anime anime) {
  return _manualCoverageGapAudit[anime.anilistId] ??
      const _CoverageGapClassification.actionable('unreviewed');
}

final class _CoverageGapClassification {
  const _CoverageGapClassification(this.isActionable, this.reason);

  const _CoverageGapClassification.actionable(String reason)
    : this(true, reason);

  const _CoverageGapClassification.nonActionable(String reason)
    : this(false, reason);

  final bool isActionable;
  final String reason;

  String get status => isActionable ? 'actionable' : 'non_actionable';
}

final class _RecordingSourcePlugin implements SourcePlugin {
  _RecordingSourcePlugin(this._delegate);

  final SourcePlugin _delegate;
  final List<String> queriesAttempted = <String>[];
  final List<String> detailProbesAttempted = <String>[];

  void reset() {
    queriesAttempted.clear();
    detailProbesAttempted.clear();
  }

  @override
  PluginManifest get manifest => _delegate.manifest;

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) {
    detailProbesAttempted.add(sourceId);
    return _delegate.getAnimeDetail(sourceId);
  }

  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String animeId,
  ) {
    return _delegate.getEpisodes(animeId);
  }

  @override
  Future<Result<List<SourceServerLink>, KumoriyaError>> getEpisodeServerLinks(
    SourceEpisode episode,
  ) {
    return _delegate.getEpisodeServerLinks(episode);
  }

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) {
    queriesAttempted.add(query.query);
    return _delegate.search(query);
  }
}
