import 'dart:convert';
import 'dart:io';

import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_matching/kumoriya_matching.dart';

enum ManualSeedLabel { match, reviewNeeded, reject }

final class ManualSeedRow {
  const ManualSeedRow({
    required this.caseId,
    required this.canonicalTitle,
    required this.canonicalAliases,
    required this.canonicalYear,
    required this.canonicalFormat,
    required this.source,
    required this.searchQuery,
    required this.candidateRank,
    required this.candidateTitle,
    required this.candidateUrl,
    required this.observedFormat,
    required this.observedYear,
    required this.label,
    required this.decisionBucket,
    required this.reasons,
  });

  factory ManualSeedRow.fromJson(Map<String, Object?> json) {
    return ManualSeedRow(
      caseId: json['case_id']! as String,
      canonicalTitle: json['canonical_title']! as String,
      canonicalAliases: (json['canonical_aliases']! as List<Object?>)
          .whereType<String>()
          .toList(growable: false),
      canonicalYear: _readOptionalInt(json['canonical_year']),
      canonicalFormat: _parseFormat(json['canonical_format']),
      source: json['source']! as String,
      searchQuery: json['search_query']! as String,
      candidateRank: _readOptionalInt(json['candidate_rank']),
      candidateTitle: json['candidate_title'] as String?,
      candidateUrl: json['candidate_url'] as String?,
      observedFormat: _parseFormat(json['observed_format']),
      observedYear: _extractYear(json['observed_year']),
      label: _parseLabel(json['label']! as String),
      decisionBucket: _parseVerdict(json['decision_bucket']! as String),
      reasons: (json['reasons']! as List<Object?>).whereType<String>().toList(
        growable: false,
      ),
    );
  }

  final String caseId;
  final String canonicalTitle;
  final List<String> canonicalAliases;
  final int? canonicalYear;
  final AnimeFormat canonicalFormat;
  final String source;
  final String searchQuery;
  final int? candidateRank;
  final String? candidateTitle;
  final String? candidateUrl;
  final AnimeFormat observedFormat;
  final int? observedYear;
  final ManualSeedLabel label;
  final SeriesDecisionVerdict decisionBucket;
  final List<String> reasons;

  bool get hasCandidate =>
      candidateTitle != null && candidateTitle!.trim().isNotEmpty;

  CanonicalSeries toCanonicalSeries() {
    return CanonicalSeries(
      canonicalId: _canonicalSeriesId,
      anilistId: _stablePositiveInt(_canonicalSeriesId),
      primaryTitle: canonicalTitle,
      aliases: canonicalAliases,
      format: canonicalFormat,
      releaseYear: canonicalYear,
      seasonInfo: inferSeasonInfoFromTitles(<String>[
        canonicalTitle,
        ...canonicalAliases,
      ]),
    );
  }

  SourceSeriesRecord? toSourceSeriesRecord() {
    if (!hasCandidate) {
      return null;
    }
    return SourceSeriesRecord(
      recordId: '$source:${_sourceSeriesId}',
      sourceId: source,
      sourceSeriesId: _sourceSeriesId,
      primaryTitle: candidateTitle!,
      format: observedFormat,
      releaseYear: observedYear,
      seasonInfo: inferSeasonInfoFromTitles(<String>[candidateTitle!]),
    );
  }

  String get queryKey => [
    source.trim().toLowerCase(),
    searchQuery.trim().toLowerCase(),
    canonicalTitle.trim().toLowerCase(),
    canonicalYear?.toString() ?? 'na',
    canonicalFormat.name,
  ].join('|');

  String get _sourceSeriesId {
    final url = candidateUrl;
    if (url == null || url.isEmpty) {
      return caseId;
    }
    final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    for (final segment in segments.reversed) {
      if (segment.isNotEmpty) {
        return segment;
      }
    }
    return caseId;
  }

  String get _canonicalSeriesId {
    final normalized = canonicalTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return 'manual:$normalized:${canonicalYear ?? 'na'}';
  }
}

final class ManualSeedQueryScenario {
  const ManualSeedQueryScenario({
    required this.key,
    required this.canonical,
    required this.rows,
    required this.expectedVerdict,
    required this.expectedBestCaseId,
  });

  final String key;
  final CanonicalSeries canonical;
  final List<ManualSeedRow> rows;
  final SeriesDecisionVerdict expectedVerdict;
  final String? expectedBestCaseId;

  List<SourceSeriesRecord> get candidates => rows
      .map((row) => row.toSourceSeriesRecord())
      .whereType<SourceSeriesRecord>()
      .toList(growable: false);
}

final class ManualSeedRowEvaluation {
  const ManualSeedRowEvaluation({
    required this.row,
    required this.expectedVerdict,
    required this.actualVerdict,
    required this.bestScore,
    required this.predictedBestTitle,
    required this.reasonCodes,
  });

  final ManualSeedRow row;
  final SeriesDecisionVerdict expectedVerdict;
  final SeriesDecisionVerdict actualVerdict;
  final double bestScore;
  final String? predictedBestTitle;
  final List<MatchReasonCode> reasonCodes;

  bool get isUnsafeAutoMatch =>
      actualVerdict == SeriesDecisionVerdict.autoMatch &&
      expectedVerdict != SeriesDecisionVerdict.autoMatch;

  bool get isExactVerdictMatch => actualVerdict == expectedVerdict;
}

final class ManualSeedQueryEvaluation {
  const ManualSeedQueryEvaluation({
    required this.scenario,
    required this.expectedVerdict,
    required this.actualVerdict,
    required this.bestScore,
    required this.predictedBestTitle,
    required this.predictedBestCaseId,
    required this.reasonCodes,
  });

  final ManualSeedQueryScenario scenario;
  final SeriesDecisionVerdict expectedVerdict;
  final SeriesDecisionVerdict actualVerdict;
  final double bestScore;
  final String? predictedBestTitle;
  final String? predictedBestCaseId;
  final List<MatchReasonCode> reasonCodes;

  bool get isUnsafeAutoMatch =>
      actualVerdict == SeriesDecisionVerdict.autoMatch &&
      expectedVerdict != SeriesDecisionVerdict.autoMatch;

  bool get isExactVerdictMatch => actualVerdict == expectedVerdict;

  bool get isExpectedBestCandidateMatch =>
      scenario.expectedBestCaseId == null ||
      predictedBestCaseId == scenario.expectedBestCaseId;
}

final class ManualSeedCalibrationReport {
  const ManualSeedCalibrationReport({
    required this.datasetPath,
    required this.rowEvaluations,
    required this.queryEvaluations,
  });

  final String datasetPath;
  final List<ManualSeedRowEvaluation> rowEvaluations;
  final List<ManualSeedQueryEvaluation> queryEvaluations;

  int get totalRows => rowEvaluations.length;
  int get totalQueries => queryEvaluations.length;

  int get rowUnsafeAutoMatches =>
      rowEvaluations.where((evaluation) => evaluation.isUnsafeAutoMatch).length;

  int get queryUnsafeAutoMatches => queryEvaluations
      .where((evaluation) => evaluation.isUnsafeAutoMatch)
      .length;

  double get rowExactAccuracy => _ratio(
    rowEvaluations.where((evaluation) => evaluation.isExactVerdictMatch).length,
    totalRows,
  );

  double get queryExactAccuracy => _ratio(
    queryEvaluations
        .where((evaluation) => evaluation.isExactVerdictMatch)
        .length,
    totalQueries,
  );

  double get rowSafeAccuracy => _ratio(
    rowEvaluations.where((evaluation) {
      if (evaluation.expectedVerdict == SeriesDecisionVerdict.autoMatch) {
        return evaluation.actualVerdict == SeriesDecisionVerdict.autoMatch;
      }
      return evaluation.actualVerdict != SeriesDecisionVerdict.autoMatch;
    }).length,
    totalRows,
  );

  double get querySafeAccuracy => _ratio(
    queryEvaluations.where((evaluation) {
      if (evaluation.expectedVerdict == SeriesDecisionVerdict.autoMatch) {
        return evaluation.actualVerdict == SeriesDecisionVerdict.autoMatch;
      }
      return evaluation.actualVerdict != SeriesDecisionVerdict.autoMatch;
    }).length,
    totalQueries,
  );

  double get rowMatchRecall {
    final positives = rowEvaluations
        .where(
          (evaluation) =>
              evaluation.expectedVerdict == SeriesDecisionVerdict.autoMatch,
        )
        .length;
    return _ratio(
      rowEvaluations.where((evaluation) {
        return evaluation.expectedVerdict == SeriesDecisionVerdict.autoMatch &&
            evaluation.actualVerdict == SeriesDecisionVerdict.autoMatch;
      }).length,
      positives,
    );
  }

  double get queryMatchRecall {
    final positives = queryEvaluations
        .where(
          (evaluation) =>
              evaluation.expectedVerdict == SeriesDecisionVerdict.autoMatch,
        )
        .length;
    return _ratio(
      queryEvaluations.where((evaluation) {
        return evaluation.expectedVerdict == SeriesDecisionVerdict.autoMatch &&
            evaluation.actualVerdict == SeriesDecisionVerdict.autoMatch;
      }).length,
      positives,
    );
  }

  double get queryBestCandidateAccuracy {
    final queriesWithExpectedCandidate = queryEvaluations.where((evaluation) {
      return evaluation.scenario.expectedBestCaseId != null;
    }).length;
    return _ratio(
      queryEvaluations.where((evaluation) {
        return evaluation.scenario.expectedBestCaseId != null &&
            evaluation.isExpectedBestCandidateMatch;
      }).length,
      queriesWithExpectedCandidate,
    );
  }

  List<ManualSeedRowEvaluation> get rowMismatches => rowEvaluations
      .where((evaluation) => !evaluation.isExactVerdictMatch)
      .toList(growable: false);

  List<ManualSeedQueryEvaluation> get queryMismatches => queryEvaluations
      .where((evaluation) => !evaluation.isExactVerdictMatch)
      .toList(growable: false);
}

ManualSeedCalibrationReport evaluateManualSeedDataset({
  String? datasetPath,
  MatchingConfig config = const MatchingConfig(),
}) {
  final resolvedDatasetPath = datasetPath ?? findManualSeedDatasetPath().path;
  final rows = loadManualSeedRows(resolvedDatasetPath);
  final rowEvaluations = rows
      .map((row) => _evaluateRow(row, config: config))
      .toList(growable: false);
  final queryEvaluations = buildManualSeedQueryScenarios(rows)
      .map((scenario) => _evaluateQueryScenario(scenario, config: config))
      .toList(growable: false);
  return ManualSeedCalibrationReport(
    datasetPath: resolvedDatasetPath,
    rowEvaluations: rowEvaluations,
    queryEvaluations: queryEvaluations,
  );
}

List<ManualSeedRow> loadManualSeedRows(String datasetPath) {
  final content = File(datasetPath).readAsStringSync();
  final jsonMap = jsonDecode(content) as Map<String, Object?>;
  return (jsonMap['rows']! as List<Object?>)
      .whereType<Map<String, Object?>>()
      .map(ManualSeedRow.fromJson)
      .toList(growable: false);
}

List<ManualSeedQueryScenario> buildManualSeedQueryScenarios(
  List<ManualSeedRow> rows,
) {
  final grouped = <String, List<ManualSeedRow>>{};
  for (final row in rows) {
    grouped.putIfAbsent(row.queryKey, () => <ManualSeedRow>[]).add(row);
  }

  return grouped.entries
      .map((entry) {
        final sortedRows = [...entry.value]
          ..sort((left, right) {
            final leftRank = left.candidateRank ?? 1 << 20;
            final rightRank = right.candidateRank ?? 1 << 20;
            return leftRank.compareTo(rightRank);
          });
        final expectedVerdict = _inferExpectedScenarioVerdict(sortedRows);
        final expectedBestCaseId = _inferExpectedBestCaseId(
          sortedRows,
          expectedVerdict,
        );
        return ManualSeedQueryScenario(
          key: entry.key,
          canonical: sortedRows.first.toCanonicalSeries(),
          rows: sortedRows,
          expectedVerdict: expectedVerdict,
          expectedBestCaseId: expectedBestCaseId,
        );
      })
      .toList(growable: false);
}

File findManualSeedDatasetPath() {
  final relativeSegments = <String>[
    'docs',
    'audits',
    'matching',
    'manual_search_seed_dataset_2026-03-12.json',
  ];

  var current = Directory.current.absolute;
  for (var attempt = 0; attempt < 8; attempt++) {
    final candidate = File(
      _joinPath(<String>[current.path, ...relativeSegments]),
    );
    if (candidate.existsSync()) {
      return candidate;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      break;
    }
    current = parent;
  }

  throw FileSystemException(
    'Manual seed dataset not found from ${Directory.current.path}',
  );
}

String formatCalibrationReport(ManualSeedCalibrationReport report) {
  final buffer = StringBuffer()
    ..writeln('Manual seed dataset: ${report.datasetPath}')
    ..writeln('Rows: ${report.totalRows}')
    ..writeln('Queries: ${report.totalQueries}')
    ..writeln(
      'Row metrics: exact=${_formatPercent(report.rowExactAccuracy)}, '
      'safe=${_formatPercent(report.rowSafeAccuracy)}, '
      'match_recall=${_formatPercent(report.rowMatchRecall)}, '
      'unsafe_auto=${report.rowUnsafeAutoMatches}',
    )
    ..writeln(
      'Query metrics: exact=${_formatPercent(report.queryExactAccuracy)}, '
      'safe=${_formatPercent(report.querySafeAccuracy)}, '
      'match_recall=${_formatPercent(report.queryMatchRecall)}, '
      'best_candidate=${_formatPercent(report.queryBestCandidateAccuracy)}, '
      'unsafe_auto=${report.queryUnsafeAutoMatches}',
    );

  if (report.queryMismatches.isNotEmpty) {
    buffer.writeln('Query mismatches:');
    for (final mismatch in report.queryMismatches) {
      buffer.writeln(
        '- ${mismatch.scenario.key}: expected=${mismatch.expectedVerdict.name} '
        'actual=${mismatch.actualVerdict.name} '
        'best=${mismatch.predictedBestTitle ?? 'none'} '
        'score=${mismatch.bestScore.toStringAsFixed(1)} '
        'reasons=${mismatch.reasonCodes.map((code) => code.name).join(",")}',
      );
    }
  }

  if (report.rowMismatches.isNotEmpty) {
    buffer.writeln('Row mismatches:');
    for (final mismatch in report.rowMismatches) {
      buffer.writeln(
        '- ${mismatch.row.caseId}: expected=${mismatch.expectedVerdict.name} '
        'actual=${mismatch.actualVerdict.name} '
        'best=${mismatch.predictedBestTitle ?? 'none'} '
        'score=${mismatch.bestScore.toStringAsFixed(1)} '
        'reasons=${mismatch.reasonCodes.map((code) => code.name).join(",")}',
      );
    }
  }

  return buffer.toString().trimRight();
}

ManualSeedRowEvaluation _evaluateRow(
  ManualSeedRow row, {
  required MatchingConfig config,
}) {
  final decision = _resolveAgainstCandidates(
    canonical: row.toCanonicalSeries(),
    candidates: [
      if (row.toSourceSeriesRecord() case final candidate?) candidate,
    ],
    config: config,
  );

  return ManualSeedRowEvaluation(
    row: row,
    expectedVerdict: row.decisionBucket,
    actualVerdict: decision.verdict,
    bestScore: decision.bestScore,
    predictedBestTitle: decision.bestCandidate?.primaryTitle,
    reasonCodes: decision.reasons
        .map((reason) => reason.code)
        .toList(growable: false),
  );
}

ManualSeedQueryEvaluation _evaluateQueryScenario(
  ManualSeedQueryScenario scenario, {
  required MatchingConfig config,
}) {
  final decision = _resolveAgainstCandidates(
    canonical: scenario.canonical,
    candidates: scenario.candidates,
    config: config,
  );

  final predictedBestCaseId = scenario.rows
      .firstWhere(
        (row) =>
            row.toSourceSeriesRecord()?.sourceSeriesId ==
            decision.bestCandidate?.sourceSeriesId,
        orElse: () => const ManualSeedRow(
          caseId: '',
          canonicalTitle: '',
          canonicalAliases: <String>[],
          canonicalYear: null,
          canonicalFormat: AnimeFormat.unknown,
          source: '',
          searchQuery: '',
          candidateRank: null,
          candidateTitle: null,
          candidateUrl: null,
          observedFormat: AnimeFormat.unknown,
          observedYear: null,
          label: ManualSeedLabel.reject,
          decisionBucket: SeriesDecisionVerdict.reject,
          reasons: <String>[],
        ),
      )
      .caseId;

  return ManualSeedQueryEvaluation(
    scenario: scenario,
    expectedVerdict: scenario.expectedVerdict,
    actualVerdict: decision.verdict,
    bestScore: decision.bestScore,
    predictedBestTitle: decision.bestCandidate?.primaryTitle,
    predictedBestCaseId: predictedBestCaseId.isEmpty
        ? null
        : predictedBestCaseId,
    reasonCodes: decision.reasons
        .map((reason) => reason.code)
        .toList(growable: false),
  );
}

SeriesMatchDecision<SourceSeriesRecord> _resolveAgainstCandidates({
  required CanonicalSeries canonical,
  required List<SourceSeriesRecord> candidates,
  required MatchingConfig config,
}) {
  final fingerprintBuilder = const SeriesFingerprintBuilder();
  final candidateIndex = SeriesCandidateIndex<SourceSeriesRecord>(
    candidates.map(fingerprintBuilder.fromSource),
  );
  final resolver = SeriesEntityResolver<SourceSeriesRecord>(
    candidateIndex: candidateIndex,
    config: config,
  );
  return resolver.resolve(fingerprintBuilder.fromCanonical(canonical));
}

SeriesDecisionVerdict _inferExpectedScenarioVerdict(List<ManualSeedRow> rows) {
  if (rows.any(
    (row) => row.decisionBucket == SeriesDecisionVerdict.autoMatch,
  )) {
    return SeriesDecisionVerdict.autoMatch;
  }
  if (rows.any(
    (row) => row.decisionBucket == SeriesDecisionVerdict.reviewNeeded,
  )) {
    return SeriesDecisionVerdict.reviewNeeded;
  }
  return SeriesDecisionVerdict.reject;
}

String? _inferExpectedBestCaseId(
  List<ManualSeedRow> rows,
  SeriesDecisionVerdict expectedVerdict,
) {
  final matchingRow = rows
      .where((row) => row.decisionBucket == expectedVerdict && row.hasCandidate)
      .fold<ManualSeedRow?>(null, (best, row) {
        if (best == null) {
          return row;
        }
        final bestRank = best.candidateRank ?? 1 << 20;
        final rowRank = row.candidateRank ?? 1 << 20;
        return rowRank < bestRank ? row : best;
      });
  return matchingRow?.caseId;
}

SeriesDecisionVerdict _parseVerdict(String value) {
  switch (value.trim().toLowerCase()) {
    case 'auto_match':
      return SeriesDecisionVerdict.autoMatch;
    case 'review_needed':
      return SeriesDecisionVerdict.reviewNeeded;
    case 'reject':
      return SeriesDecisionVerdict.reject;
  }
  throw ArgumentError.value(value, 'value', 'Unsupported decision bucket');
}

ManualSeedLabel _parseLabel(String value) {
  switch (value.trim().toLowerCase()) {
    case 'match':
      return ManualSeedLabel.match;
    case 'review_needed':
      return ManualSeedLabel.reviewNeeded;
    case 'reject':
      return ManualSeedLabel.reject;
  }
  throw ArgumentError.value(value, 'value', 'Unsupported label');
}

AnimeFormat _parseFormat(Object? raw) {
  final normalized = raw?.toString().trim().toLowerCase();
  switch (normalized) {
    case 'tv':
    case 'serie':
    case 'series':
      return AnimeFormat.tv;
    case 'movie':
    case 'pelicula':
    case 'película':
      return AnimeFormat.movie;
    case 'ova':
      return AnimeFormat.ova;
    case 'ona':
      return AnimeFormat.ona;
    case 'special':
      return AnimeFormat.special;
    case null:
    case '':
      return AnimeFormat.unknown;
  }
  return AnimeFormat.unknown;
}

int? _extractYear(Object? raw) {
  final value = raw?.toString().trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  final match = RegExp(r'(\d{4})').firstMatch(value);
  return match == null ? null : int.tryParse(match.group(1)!);
}

int? _readOptionalInt(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is int) {
    return raw;
  }
  return int.tryParse(raw.toString());
}

int _stablePositiveInt(String value) {
  var hash = 17;
  for (final codeUnit in value.codeUnits) {
    hash = 37 * hash + codeUnit;
  }
  return hash.abs();
}

double _ratio(int numerator, int denominator) {
  if (denominator == 0) {
    return 0;
  }
  return numerator / denominator;
}

String _formatPercent(double value) => '${(value * 100).toStringAsFixed(1)}%';

String _joinPath(List<String> segments) {
  final cleaned = <String>[];
  for (final segment in segments) {
    if (segment.isEmpty) {
      continue;
    }
    if (cleaned.isEmpty) {
      cleaned.add(segment.replaceAll(RegExp(r'[\\/]+$'), ''));
      continue;
    }
    cleaned.add(segment.replaceAll(RegExp(r'^[\\/]+|[\\/]+$'), ''));
  }
  return cleaned.join(Platform.pathSeparator);
}
