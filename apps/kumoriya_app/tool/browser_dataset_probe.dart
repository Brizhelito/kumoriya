import 'dart:convert';
import 'dart:io';

import 'package:kumoriya_app/src/features/anime_catalog/application/matching/anilist_source_matcher.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/source_availability.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/check_source_availability_use_case.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_animeav1/kumoriya_source_animeav1.dart';
import 'package:kumoriya_source_animeflv/kumoriya_source_animeflv.dart';

Future<void> main() async {
  final output = await _runProbe();

  final outputFile = File(
    r'c:\Users\Reny\Documents\Kumoriya\build\test_cache\browser_dataset_probe_2026-03-18.json',
  );
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(output),
  );

  stdout.writeln(outputFile.path);
}

Future<Map<String, Object?>> _runProbe() async {
  const matcher = AnilistSourceMatcher();
  final datasetFile = File(
    r'c:\Users\Reny\Documents\Kumoriya\docs\audits\matching\browser_validated_matching_dataset_2026-03-17.json',
  );
  final dataset =
      jsonDecode(await datasetFile.readAsString()) as Map<String, Object?>;
  final rows =
      <Map<String, Object?>>[
            ...((dataset['manual_seed_rows'] as List<Object?>)
                .cast<Map<String, Object?>>()),
            ...((dataset['browser_rows'] as List<Object?>)
                .cast<Map<String, Object?>>()),
          ]
          .where((row) {
            final source = row['source']?.toString();
            return source == 'animeflv' || source == 'animeav1';
          })
          .toList(growable: false);

  final plugins = <String, _RecordingSourcePlugin>{
    'animeflv': _RecordingSourcePlugin(AnimeFlvSourcePlugin()),
    'animeav1': _RecordingSourcePlugin(AnimeAv1SourcePlugin()),
  };
  final useCases = <String, CheckSourceAvailabilityUseCase>{
    for (final entry in plugins.entries)
      entry.key: CheckSourceAvailabilityUseCase(
        sourcePlugin: entry.value,
        matcher: matcher,
      ),
  };

  final summary = <String, Map<String, Object>>{};
  final queryRecoveries = <Map<String, Object?>>[];
  final missedMatches = <Map<String, Object?>>[];

  for (final source in plugins.keys) {
    summary[source] = <String, Object>{
      'total_rows': 0,
      'available_rows': 0,
      'unavailable_rows': 0,
      'error_rows': 0,
      'match_rows_with_expected_slug': 0,
      'match_rows_expected_matched': 0,
      'query_strategy_failures': 0,
      'query_strategy_failures_now_available': 0,
    };
  }

  for (final row in rows) {
    final source = row['source']!.toString();
    final plugin = plugins[source]!;
    final useCase = useCases[source]!;
    final query = row['search_query']?.toString() ?? '';
    final label = row['label']?.toString() ?? '';
    final candidateUrl = row['candidate_url']?.toString();
    final expectedSlug = _extractExpectedSlug(source, candidateUrl);
    final stats = summary[source]!;
    stats['total_rows'] = (stats['total_rows'] as int) + 1;
    if (label == 'search_failed_query_strategy') {
      stats['query_strategy_failures'] =
          (stats['query_strategy_failures'] as int) + 1;
    }

    plugin.reset();

    SourceAvailability? availability;
    var status = 'error';
    String? matchedSlug;

    try {
      availability = await useCase.call(_buildAnimeDetail(row));
      status = availability.status.name;
      matchedSlug = availability.matchedAnime?.sourceId;
      switch (availability.status) {
        case SourceAvailabilityStatus.available:
          stats['available_rows'] = (stats['available_rows'] as int) + 1;
        case SourceAvailabilityStatus.unavailable:
          stats['unavailable_rows'] = (stats['unavailable_rows'] as int) + 1;
        case SourceAvailabilityStatus.error:
          stats['error_rows'] = (stats['error_rows'] as int) + 1;
      }
    } catch (_) {
      stats['error_rows'] = (stats['error_rows'] as int) + 1;
    }

    final queriesAttempted = plugin.queriesAttempted.toList(growable: false);
    final detailProbesAttempted = plugin.detailProbesAttempted.toList(
      growable: false,
    );

    if (label == 'match' && expectedSlug != null) {
      stats['match_rows_with_expected_slug'] =
          (stats['match_rows_with_expected_slug'] as int) + 1;
      if (availability?.status == SourceAvailabilityStatus.available &&
          matchedSlug == expectedSlug) {
        stats['match_rows_expected_matched'] =
            (stats['match_rows_expected_matched'] as int) + 1;
      } else {
        missedMatches.add(<String, Object?>{
          'source': source,
          'query': query,
          'canonical_title': row['canonical_title'],
          'expected_slug': expectedSlug,
          'matched_slug': matchedSlug,
          'status': status,
          'queries_attempted': queriesAttempted,
          'detail_probes_attempted': detailProbesAttempted,
        });
      }
    }

    if (label == 'search_failed_query_strategy' &&
        availability?.status == SourceAvailabilityStatus.available) {
      stats['query_strategy_failures_now_available'] =
          (stats['query_strategy_failures_now_available'] as int) + 1;
      queryRecoveries.add(<String, Object?>{
        'source': source,
        'query': query,
        'canonical_title': row['canonical_title'],
        'matched_slug': matchedSlug,
        'queries_attempted': queriesAttempted,
        'detail_probes_attempted': detailProbesAttempted,
      });
    }
  }

  return <String, Object?>{
    'summary': summary,
    'query_strategy_recoveries': queryRecoveries,
    'missed_expected_match_rows': missedMatches,
  };
}

String? _extractExpectedSlug(String source, String? candidateUrl) {
  if (candidateUrl == null || candidateUrl.trim().isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(candidateUrl.trim());
  if (uri == null) {
    return null;
  }
  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  if (source == 'animeflv') {
    final animeIndex = segments.indexOf('anime');
    if (animeIndex >= 0 && animeIndex + 1 < segments.length) {
      return segments[animeIndex + 1];
    }
  }
  if (source == 'animeav1') {
    final mediaIndex = segments.indexOf('media');
    if (mediaIndex >= 0 && mediaIndex + 1 < segments.length) {
      return segments[mediaIndex + 1];
    }
  }
  return segments.isEmpty ? null : segments.last;
}

AnimeDetail _buildAnimeDetail(Map<String, Object?> row) {
  final canonicalTitle = row['canonical_title']?.toString().trim() ?? '';
  final aliases =
      (row['canonical_aliases'] as List<Object?>? ?? const <Object?>[])
          .whereType<String>()
          .map((alias) => alias.trim())
          .where((alias) => alias.isNotEmpty)
          .toList(growable: false);
  final firstAlias = aliases.isEmpty ? null : aliases.first;
  final english = firstAlias != null && firstAlias != canonicalTitle
      ? firstAlias
      : null;

  return AnimeDetail(
    anime: Anime(
      anilistId: 1,
      title: AnimeTitle(
        romaji: canonicalTitle,
        english: english,
        synonyms: aliases.skip(1).toList(growable: false),
      ),
      format: _parseAnimeFormat(row['canonical_format']?.toString()),
      releaseYear: row['canonical_year'] is int
          ? row['canonical_year'] as int
          : null,
    ),
  );
}

AnimeFormat _parseAnimeFormat(String? value) {
  switch (value?.toUpperCase()) {
    case 'TV':
      return AnimeFormat.tv;
    case 'MOVIE':
      return AnimeFormat.movie;
    case 'OVA':
      return AnimeFormat.ova;
    case 'ONA':
      return AnimeFormat.ona;
    case 'SPECIAL':
      return AnimeFormat.special;
    default:
      return AnimeFormat.unknown;
  }
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
    String sourceId,
  ) {
    return _delegate.getEpisodes(sourceId);
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
