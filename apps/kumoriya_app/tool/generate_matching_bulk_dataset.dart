import 'dart:convert';
import 'dart:io';

import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_matching/kumoriya_matching.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_anime_nexus/kumoriya_source_anime_nexus.dart';
import 'package:kumoriya_source_animeav1/kumoriya_source_animeav1.dart';
import 'package:kumoriya_source_animeflv/kumoriya_source_animeflv.dart';
import 'package:kumoriya_source_jkanime/kumoriya_source_jkanime.dart';

const int _defaultTargetCanonicalCount = 200;
const int _searchLimitPerSource = 5;
const String _captureDate = '2026-03-12';

Future<void> main(List<String> args) async {
  final targetCanonicalCount = _parseTargetCanonicalCount(args);
  final repoRoot = _findRepoRoot();
  final outputDir = Directory(
    '${repoRoot.path}${Platform.pathSeparator}docs${Platform.pathSeparator}audits${Platform.pathSeparator}matching',
  );
  outputDir.createSync(recursive: true);

  final canonicals = await _loadCanonicals(targetCanonicalCount);
  final sources = <_SourceHarness>[
    _SourceHarness(id: 'jkanime', plugin: JkAnimeSourcePlugin()),
    _SourceHarness(id: 'anime_nexus', plugin: AnimeNexusSourcePlugin()),
    _SourceHarness(id: 'animeflv', plugin: AnimeFlvSourcePlugin()),
    _SourceHarness(id: 'animeav1', plugin: AnimeAv1SourcePlugin()),
  ];

  final observations = <Map<String, Object?>>[];
  final statsBySource = <String, _SourceStats>{};
  for (final source in sources) {
    statsBySource[source.id] = _SourceStats();
  }

  for (final canonical in canonicals) {
    for (final source in sources) {
      final stats = statsBySource[source.id]!;
      stats.totalQueries++;

      final searchResult = await _searchAcrossQueries(
        source: source,
        canonical: canonical,
      );
      final observation = await searchResult.result
          .fold<Future<Map<String, Object?>>>(
            onSuccess: (matches) async {
              final enriched = await _buildObservation(
                source: source,
                canonical: canonical,
                query: searchResult.usedQuery,
                attemptedQueries: searchResult.attemptedQueries,
                matches: matches,
              );
              stats.totalCandidates += matches.length;
              if (matches.isEmpty) {
                stats.emptyResults++;
              }
              stats.addVerdict(enriched['decision_verdict'] as String);
              return enriched;
            },
            onFailure: (error) async {
              stats.failures++;
              return <String, Object?>{
                'canonical': _canonicalToJson(canonical),
                'source': source.id,
                'search_query': searchResult.usedQuery,
                'search_queries_attempted': searchResult.attemptedQueries,
                'search_status': 'error',
                'error': <String, Object?>{
                  'code': error.code,
                  'kind': error.kind.name,
                  'message': error.message,
                },
                'candidate_count': 0,
              };
            },
          );
      observations.add(observation);
      stdout.writeln(
        '[${source.id}] ${canonical.primaryTitle} -> ${observation['search_status']}',
      );
    }
  }

  final dataset = <String, Object?>{
    'captured_at': _captureDate,
    'generator': 'apps/kumoriya_app/tool/generate_matching_bulk_dataset.dart',
    'target_canonical_count': targetCanonicalCount,
    'sources': sources.map((source) => source.id).toList(growable: false),
    'summary': <String, Object?>{
      for (final entry in statsBySource.entries)
        entry.key: entry.value.toJson(),
    },
    'observations': observations,
  };

  final datasetPath =
      '${outputDir.path}${Platform.pathSeparator}bulk_matching_observation_dataset_$_captureDate.json';
  final reportPath =
      '${outputDir.path}${Platform.pathSeparator}bulk_matching_observation_report_$_captureDate.md';

  File(
    datasetPath,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(dataset));
  File(reportPath).writeAsStringSync(
    _buildMarkdownReport(
      datasetPath: datasetPath,
      targetCanonicalCount: targetCanonicalCount,
      canonicals: canonicals,
      statsBySource: statsBySource,
      observations: observations,
    ),
  );

  stdout.writeln('Dataset written to $datasetPath');
  stdout.writeln('Report written to $reportPath');
}

int _parseTargetCanonicalCount(List<String> args) {
  for (final argument in args) {
    if (!argument.startsWith('--count=')) {
      continue;
    }

    final parsed = int.tryParse(argument.substring('--count='.length));
    if (parsed != null && parsed > 0) {
      return parsed;
    }
  }

  return _defaultTargetCanonicalCount;
}

Future<List<CanonicalSeries>> _loadCanonicals(int targetCanonicalCount) async {
  final repository = AnilistAnimeCatalogRepository(
    gateway: GraphqlAnilistMetadataGateway(client: HttpAnilistGraphqlClient()),
  );

  final collected = <Anime>[];
  final seenIds = <int>{};
  final maxPages = ((targetCanonicalCount / 20).ceil() + 10).clamp(10, 30);
  for (var page = 1; page <= maxPages; page++) {
    final result = await repository.fetchHomeCatalog(page: page, perPage: 20);
    result.fold(
      onSuccess: (animeList) {
        for (final anime in animeList) {
          if (seenIds.add(anime.anilistId)) {
            collected.add(anime);
          }
        }
      },
      onFailure: (error) {
        throw StateError(
          'AniList trending fetch failed on page $page: ${error.message}',
        );
      },
    );
    if (collected.length >= targetCanonicalCount) {
      break;
    }
  }

  return collected
      .take(targetCanonicalCount)
      .map(_canonicalFromAnime)
      .toList(growable: false);
}

CanonicalSeries _canonicalFromAnime(Anime anime) {
  final aliases = <String>[
    if (anime.title.english != null) anime.title.english!,
    if (anime.title.native != null) anime.title.native!,
    ...anime.title.synonyms,
  ];
  return CanonicalSeries(
    canonicalId: 'anilist:${anime.anilistId}',
    anilistId: anime.anilistId,
    primaryTitle: anime.title.romaji,
    aliases: aliases,
    format: anime.format,
    releaseYear: anime.releaseYear,
    episodeCount: anime.totalEpisodes,
    seasonInfo: inferSeasonInfoFromTitles(<String>[
      anime.title.romaji,
      ...aliases,
    ]),
  );
}

Future<_SearchOutcome> _searchAcrossQueries({
  required _SourceHarness source,
  required CanonicalSeries canonical,
}) async {
  final queries = _buildSearchQueries(canonical);
  final attempted = <String>[];
  final seenIds = <String>{};
  final collected = <SourceAnimeMatch>[];
  String? successfulQuery;
  KumoriyaError? lastError;

  for (final query in queries) {
    attempted.add(query);
    final result = await source.plugin.search(
      SourceSearchQuery(query: query, limit: _searchLimitPerSource),
    );

    result.fold(
      onFailure: (error) => lastError = error,
      onSuccess: (matches) {
        if (matches.isNotEmpty) {
          successfulQuery ??= query;
        }
        for (final match in matches) {
          if (seenIds.add(match.sourceId)) {
            collected.add(match);
          }
        }
      },
    );

    if (collected.length >= _searchLimitPerSource) {
      break;
    }
  }

  if (collected.isNotEmpty) {
    return _SearchOutcome(
      usedQuery: successfulQuery ?? attempted.first,
      attemptedQueries: attempted,
      result: Success(
        collected.take(_searchLimitPerSource).toList(growable: false),
      ),
    );
  }

  final usedQuery = attempted.isEmpty
      ? canonical.primaryTitle.trim()
      : attempted.firstWhere(
          (query) => _isPreferredLatinQuery(query),
          orElse: () => attempted.first,
        );
  if (lastError != null) {
    return _SearchOutcome(
      usedQuery: usedQuery,
      attemptedQueries: attempted,
      result: Failure(lastError!),
    );
  }

  return _SearchOutcome(
    usedQuery: usedQuery,
    attemptedQueries: attempted,
    result: const Success(<SourceAnimeMatch>[]),
  );
}

List<String> _buildSearchQueries(CanonicalSeries canonical) {
  final rawTitles = <String>{
    canonical.primaryTitle,
    ...canonical.aliases.where((alias) => alias.trim().isNotEmpty),
  };
  final ordered = <String>[];
  final seen = <String>{};

  void addQuery(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final normalizedKey = trimmed.toLowerCase();
    if (seen.add(normalizedKey)) {
      ordered.add(trimmed);
    }
  }

  final prioritizedTitles = rawTitles.toList(growable: false)
    ..sort((left, right) {
      return _titleQueryPriority(left).compareTo(_titleQueryPriority(right));
    });

  for (final title in prioritizedTitles) {
    for (final variant in _expandQueryVariants(title)) {
      addQuery(variant);
    }
  }

  return ordered.isEmpty ? <String>[canonical.primaryTitle.trim()] : ordered;
}

bool _isPreferredLatinQuery(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  if (trimmed.contains('Ã') ||
      trimmed.contains('â') ||
      trimmed.contains('å') ||
      trimmed.contains('ð')) {
    return false;
  }
  return !RegExp(
    r'[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]',
    unicode: true,
  ).hasMatch(trimmed);
}

Iterable<String> _expandQueryVariants(String title) sync* {
  final trimmed = title.trim();
  if (trimmed.isEmpty) {
    return;
  }

  yield trimmed;

  final withoutSeason = _stripSeasonDescriptor(trimmed);
  if (withoutSeason != trimmed) {
    yield withoutSeason;
  }

  final withoutParenthetical = _stripTrailingParenthetical(withoutSeason);
  if (withoutParenthetical != withoutSeason) {
    yield withoutParenthetical;
  }

  final root = _extractRootTitle(withoutParenthetical);
  if (root != withoutParenthetical) {
    yield root;
  }

  final rootPlusSuffix = _extractRootPlusSuffixTitle(trimmed);
  if (rootPlusSuffix != trimmed) {
    yield rootPlusSuffix;
  }

  final swappedSeason = _swapSeasonNotation(trimmed);
  if (swappedSeason != trimmed) {
    yield swappedSeason;
  }
}

String _stripSeasonDescriptor(String value) {
  var result = value.trim();
  const patterns = <String>[
    r'\s*[-:]?\s*\b\d+(?:st|nd|rd|th)?\s+season\b$',
    r'\s*[-:]?\s*\bseason\s+\d+\b$',
    r'\s*[-:]?\s*\bpart\s+\d+\b$',
    r'\s*[-:]?\s*\bcour\s+\d+\b$',
    r'\s*[-:]?\s*\b(?:ii|iii|iv|v)\b$',
  ];

  for (final pattern in patterns) {
    result = result.replaceFirst(RegExp(pattern, caseSensitive: false), '');
  }

  return result.trim();
}

String _extractRootTitle(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }

  final colonIndex = trimmed.indexOf(':');
  final dashIndex = trimmed.indexOf(' - ');
  final splitIndex = <int>[colonIndex, dashIndex]
      .where((index) => index > 0)
      .fold<int?>(null, (current, index) {
        if (current == null || index < current) {
          return index;
        }
        return current;
      });

  if (splitIndex == null) {
    return trimmed;
  }

  final root = trimmed.substring(0, splitIndex).trim();
  if (root.split(' ').length < 2 || root.length < 6) {
    return trimmed;
  }
  return root;
}

String _extractRootPlusSuffixTitle(String value) {
  final trimmed = value.trim();
  final colonIndex = trimmed.indexOf(':');
  final dashIndex = trimmed.lastIndexOf(' - ');
  if (colonIndex <= 0 || dashIndex <= colonIndex) {
    return trimmed;
  }

  final root = trimmed.substring(0, colonIndex).trim();
  final suffix = trimmed.substring(dashIndex + 3).trim();
  if (root.isEmpty || suffix.isEmpty) {
    return trimmed;
  }

  return '$root: $suffix';
}

String _stripTrailingParenthetical(String value) {
  return value.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
}

String _swapSeasonNotation(String value) {
  final seasonFirst = RegExp(
    r'\bseason\s+(\d+)\b',
    caseSensitive: false,
  ).firstMatch(value);
  if (seasonFirst != null) {
    final number = int.tryParse(seasonFirst.group(1) ?? '');
    if (number != null) {
      return value.replaceFirst(
        seasonFirst.group(0)!,
        '${_ordinal(number)} Season',
      );
    }
  }

  final ordinalFirst = RegExp(
    r'\b(\d+)(st|nd|rd|th)\s+season\b',
    caseSensitive: false,
  ).firstMatch(value);
  if (ordinalFirst != null) {
    final number = int.tryParse(ordinalFirst.group(1) ?? '');
    if (number != null) {
      return value.replaceFirst(ordinalFirst.group(0)!, 'Season $number');
    }
  }

  return value;
}

int _titleQueryPriority(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 3;
  }
  if (_containsMojibake(trimmed)) {
    return 2;
  }
  if (_containsCjk(trimmed)) {
    return 1;
  }
  return 0;
}

bool _containsCjk(String value) {
  return RegExp(
    r'[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]',
    unicode: true,
  ).hasMatch(value);
}

bool _containsMojibake(String value) {
  return value.contains('Ãƒ') ||
      value.contains('Ã¢') ||
      value.contains('Ã¥') ||
      value.contains('Ã°');
}

String _ordinal(int value) {
  final remainder100 = value % 100;
  if (remainder100 >= 11 && remainder100 <= 13) {
    return '${value}th';
  }

  switch (value % 10) {
    case 1:
      return '${value}st';
    case 2:
      return '${value}nd';
    case 3:
      return '${value}rd';
    default:
      return '${value}th';
  }
}

Future<Map<String, Object?>> _buildObservation({
  required _SourceHarness source,
  required CanonicalSeries canonical,
  required String query,
  required List<String> attemptedQueries,
  required List<SourceAnimeMatch> matches,
}) async {
  final fingerprintBuilder = const SeriesFingerprintBuilder();
  final scorer = const HybridSeriesScorer();
  final queryFingerprint = fingerprintBuilder.fromCanonical(canonical);
  final sourceRecords = matches
      .map(
        (match) => SourceSeriesRecord.fromSourceAnimeMatch(
          sourceId: source.id,
          match: match,
        ),
      )
      .toList(growable: false);
  final candidateFingerprints = sourceRecords
      .map(fingerprintBuilder.fromSource)
      .toList(growable: false);
  final candidateIndex = SeriesCandidateIndex<SourceSeriesRecord>(
    candidateFingerprints,
  );
  final resolver = SeriesEntityResolver<SourceSeriesRecord>(
    candidateIndex: candidateIndex,
  );
  final decision = resolver.resolve(queryFingerprint);
  final scoredCandidates =
      candidateIndex
          .lookup(queryFingerprint)
          .map(
            (candidate) => scorer.score(
              query: queryFingerprint,
              candidate: candidate.fingerprint,
              blockingKeys: candidate.matchedKeys,
            ),
          )
          .toList(growable: false)
        ..sort(
          (left, right) =>
              right.breakdown.finalScore.compareTo(left.breakdown.finalScore),
        );

  final scoredByRecordId = <String, ScoredSeriesCandidate<SourceSeriesRecord>>{
    for (final scored in scoredCandidates) scored.candidate.recordId: scored,
  };

  Map<String, Object?>? bestDetail;
  if (decision.bestCandidate case final best?) {
    final detailResult = await source.plugin.getAnimeDetail(
      best.sourceSeriesId,
    );
    bestDetail = detailResult.fold(
      onSuccess: (detail) => <String, Object?>{
        'title': detail.title,
        'release_year': detail.releaseYear,
        'format': detail.format.name,
        'aliases': detail.aliases,
        'season_number': detail.seasonNumber,
        'part_number': detail.partNumber,
      },
      onFailure: (error) => <String, Object?>{
        'error_code': error.code,
        'error_kind': error.kind.name,
        'error_message': error.message,
      },
    );
  }

  return <String, Object?>{
    'canonical': _canonicalToJson(canonical),
    'source': source.id,
    'search_query': query,
    'search_queries_attempted': attemptedQueries,
    'search_status': 'ok',
    'candidate_count': matches.length,
    'decision_verdict': decision.verdict.name,
    'decision_best_score': decision.bestScore,
    'decision_reasons': decision.reasons
        .map((reason) => reason.code.name)
        .toList(growable: false),
    'decision_best_candidate': decision.bestCandidate == null
        ? null
        : <String, Object?>{
            'source_series_id': decision.bestCandidate!.sourceSeriesId,
            'title': decision.bestCandidate!.primaryTitle,
            'release_year': decision.bestCandidate!.releaseYear,
            'format': decision.bestCandidate!.format.name,
          },
    'best_candidate_detail': bestDetail,
    'candidates': [
      for (var index = 0; index < matches.length; index++)
        _candidateToJson(
          rank: index + 1,
          match: matches[index],
          record: sourceRecords[index],
          scored: scoredByRecordId[sourceRecords[index].recordId],
          isBest:
              decision.bestCandidate?.recordId == sourceRecords[index].recordId,
        ),
    ],
  };
}

Map<String, Object?> _canonicalToJson(CanonicalSeries canonical) {
  return <String, Object?>{
    'canonical_id': canonical.canonicalId,
    'anilist_id': canonical.anilistId,
    'primary_title': canonical.primaryTitle,
    'aliases': canonical.aliases,
    'release_year': canonical.releaseYear,
    'format': canonical.format.name,
    'episode_count': canonical.episodeCount,
    'season_number': canonical.seasonInfo.seasonNumber,
    'part_number': canonical.seasonInfo.partNumber,
  };
}

Map<String, Object?> _candidateToJson({
  required int rank,
  required SourceAnimeMatch match,
  required SourceSeriesRecord record,
  required ScoredSeriesCandidate<SourceSeriesRecord>? scored,
  required bool isBest,
}) {
  return <String, Object?>{
    'rank': rank,
    'source_id': match.sourceId,
    'title': match.title,
    'release_year': match.releaseYear,
    'format': match.format.name,
    'aliases': match.aliases,
    'total_episodes': match.totalEpisodes,
    'season_number': match.seasonNumber,
    'part_number': match.partNumber,
    'is_best_candidate': isBest,
    'scored': scored == null
        ? null
        : <String, Object?>{
            'score': scored.breakdown.finalScore,
            'blocking_keys': scored.blockingKeys.toList(growable: false),
            'reasons': scored.reasons
                .map((reason) => reason.code.name)
                .toList(growable: false),
            'token_set_similarity': scored.breakdown.tokenSetSimilarity,
            'token_sort_similarity': scored.breakdown.tokenSortSimilarity,
            'jaro_winkler': scored.breakdown.jaroWinkler,
            'trigram_similarity': scored.breakdown.trigramSimilarity,
            'alias_overlap': scored.breakdown.aliasOverlap,
            'year_score': scored.breakdown.yearScore,
            'type_score': scored.breakdown.typeScore,
            'season_score': scored.breakdown.seasonScore,
            'episode_score': scored.breakdown.episodeScore,
          },
    'normalized_record': <String, Object?>{
      'record_id': record.recordId,
      'source_series_id': record.sourceSeriesId,
      'primary_title': record.primaryTitle,
      'release_year': record.releaseYear,
      'format': record.format.name,
      'season_number': record.seasonInfo.seasonNumber,
      'part_number': record.seasonInfo.partNumber,
    },
  };
}

String _buildMarkdownReport({
  required String datasetPath,
  required int targetCanonicalCount,
  required List<CanonicalSeries> canonicals,
  required Map<String, _SourceStats> statsBySource,
  required List<Map<String, Object?>> observations,
}) {
  final topReviews = observations
      .where((item) => item['decision_verdict'] == 'reviewNeeded')
      .take(12)
      .toList(growable: false);
  final errors = observations
      .where((item) => item['search_status'] == 'error')
      .take(12)
      .toList(growable: false);

  final buffer = StringBuffer()
    ..writeln('# Bulk Matching Observation Report ($_captureDate)')
    ..writeln()
    ..writeln('- Dataset: `$datasetPath`')
    ..writeln(
      '- Canonicals sampled from AniList trending: ${canonicals.length}',
    )
    ..writeln('- Target canonical count: $targetCanonicalCount')
    ..writeln('- Sources audited: ${statsBySource.keys.join(', ')}')
    ..writeln()
    ..writeln('## Source Summary')
    ..writeln();

  for (final entry in statsBySource.entries) {
    final stats = entry.value;
    buffer
      ..writeln('- `${entry.key}`')
      ..writeln('  - queries: ${stats.totalQueries}')
      ..writeln('  - failures: ${stats.failures}')
      ..writeln('  - empty_results: ${stats.emptyResults}')
      ..writeln('  - total_candidates: ${stats.totalCandidates}')
      ..writeln('  - auto_match: ${stats.autoMatch}')
      ..writeln('  - review_needed: ${stats.reviewNeeded}')
      ..writeln('  - reject: ${stats.reject}');
  }

  if (topReviews.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('## Review Needed Sample')
      ..writeln();
    for (final item in topReviews) {
      final canonical = item['canonical']! as Map<String, Object?>;
      final bestCandidate =
          item['decision_best_candidate'] as Map<String, Object?>?;
      buffer.writeln(
        '- `${item['source']}` | `${canonical['primary_title']}` -> `${bestCandidate?['title'] ?? 'none'}` (${item['decision_best_score']})',
      );
    }
  }

  if (errors.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('## Search Errors')
      ..writeln();
    for (final item in errors) {
      final canonical = item['canonical']! as Map<String, Object?>;
      final error = item['error']! as Map<String, Object?>;
      buffer.writeln(
        '- `${item['source']}` | `${canonical['primary_title']}` -> `${error['code']}`: ${error['message']}',
      );
    }
  }

  return buffer.toString().trimRight();
}

Directory _findRepoRoot() {
  var current = Directory.current.absolute;
  for (var attempt = 0; attempt < 8; attempt++) {
    final pubspec = File(
      '${current.path}${Platform.pathSeparator}pubspec.yaml',
    );
    final docsDir = Directory(
      '${current.path}${Platform.pathSeparator}docs${Platform.pathSeparator}audits${Platform.pathSeparator}matching',
    );
    if (pubspec.existsSync() && docsDir.existsSync()) {
      return current;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      break;
    }
    current = parent;
  }
  throw StateError(
    'Repo root could not be located from ${Directory.current.path}',
  );
}

final class _SourceHarness {
  const _SourceHarness({required this.id, required this.plugin});

  final String id;
  final SourcePlugin plugin;
}

final class _SearchOutcome {
  const _SearchOutcome({
    required this.usedQuery,
    required this.attemptedQueries,
    required this.result,
  });

  final String usedQuery;
  final List<String> attemptedQueries;
  final Result<List<SourceAnimeMatch>, KumoriyaError> result;
}

final class _SourceStats {
  int totalQueries = 0;
  int failures = 0;
  int emptyResults = 0;
  int totalCandidates = 0;
  int autoMatch = 0;
  int reviewNeeded = 0;
  int reject = 0;

  void addVerdict(String verdict) {
    switch (verdict) {
      case 'autoMatch':
        autoMatch++;
      case 'reviewNeeded':
        reviewNeeded++;
      case 'reject':
        reject++;
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'total_queries': totalQueries,
    'failures': failures,
    'empty_results': emptyResults,
    'total_candidates': totalCandidates,
    'auto_match': autoMatch,
    'review_needed': reviewNeeded,
    'reject': reject,
  };
}
