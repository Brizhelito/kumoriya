import 'dart:math' as math;

import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../models/match_reason.dart';
import '../models/matching_config.dart';
import '../models/series_match_result.dart';
import '../normalization/series_fingerprint_builder.dart';

final class HybridSeriesScorer {
  const HybridSeriesScorer({this.config = const MatchingConfig()});

  final MatchingConfig config;

  ScoredSeriesCandidate<T> score<T>({
    required SeriesFingerprint<dynamic> query,
    required SeriesFingerprint<T> candidate,
    required Set<String> blockingKeys,
  }) {
    final titleMetrics = _bestTitleMetrics(query.titles, candidate.titles);
    final primaryTitleMetrics = _scoreTitlePair(
      query.primaryTitle,
      candidate.primaryTitle,
    );
    final aliasIntersection = query.aliases.intersection(candidate.aliases);
    final aliasOverlap = _ratio(
      aliasIntersection.length.toDouble(),
      query.aliases.union(candidate.aliases).length.toDouble(),
    );
    final yearScore = _yearScore(query.releaseYear, candidate.releaseYear);
    final typeScore = _typeScore(query.format, candidate.format);
    final seasonScore = _seasonScore(query, candidate);
    final episodeScore = _episodeScore(
      query.episodeCount,
      candidate.episodeCount,
    );

    var finalScore =
        (titleMetrics.tokenSetSimilarity * config.weights.tokenSet * 100) +
        (titleMetrics.tokenSortSimilarity * config.weights.tokenSort * 100) +
        (titleMetrics.jaroWinkler * config.weights.jaroWinkler * 100) +
        (titleMetrics.trigramSimilarity * config.weights.trigram * 100) +
        (aliasOverlap * config.weights.aliasOverlap * 100) +
        (math.max(yearScore, 0) * config.weights.year * 100) +
        (math.max(typeScore, 0) * config.weights.type * 100) +
        (math.max(seasonScore, 0) * config.weights.season * 100) +
        (math.max(episodeScore, 0) * config.weights.episodes * 100);

    final reasons = <MatchReason>[
      MatchReason(
        code: MatchReasonCode.blockingKeyMatch,
        impact: blockingKeys.isEmpty ? 0 : 1,
        metadata: <String, Object?>{
          'keys': blockingKeys.toList(growable: false),
        },
      ),
    ];

    if (titleMetrics.aliasExact) {
      finalScore += config.weights.aliasExactBonus;
      reasons.add(
        MatchReason(
          code: MatchReasonCode.matchedByAlias,
          impact: config.weights.aliasExactBonus,
        ),
      );
    }
    if (titleMetrics.exactTitle) {
      finalScore += config.weights.exactTitleBonus;
      reasons.add(
        MatchReason(
          code: MatchReasonCode.exactTitleBonus,
          impact: config.weights.exactTitleBonus,
        ),
      );
    }
    if (titleMetrics.sharedRootTitle) {
      finalScore += config.weights.rootTitleBonus;
      reasons.add(
        MatchReason(
          code: MatchReasonCode.highTitleSimilarity,
          impact: config.weights.rootTitleBonus,
          metadata: <String, Object?>{
            'root_title': candidate.primaryTitle.rootTitle,
          },
        ),
      );
    }
    if (query.isSparse || candidate.isSparse) {
      finalScore -= config.weights.sparseMetadataPenalty;
      reasons.add(
        MatchReason(
          code: MatchReasonCode.sparseMetadataPenalty,
          impact: -config.weights.sparseMetadataPenalty,
        ),
      );
    }
    if (titleMetrics.tokenSetSimilarity >= 0.85) {
      reasons.add(
        MatchReason(
          code: MatchReasonCode.tokenSetSimilarity,
          impact:
              titleMetrics.tokenSetSimilarity * config.weights.tokenSet * 100,
        ),
      );
    }
    if (titleMetrics.tokenSortSimilarity >= 0.9) {
      reasons.add(
        MatchReason(
          code: MatchReasonCode.tokenSortSimilarity,
          impact:
              titleMetrics.tokenSortSimilarity * config.weights.tokenSort * 100,
        ),
      );
    }
    if (titleMetrics.jaroWinkler >= 0.93) {
      reasons.add(
        MatchReason(
          code: MatchReasonCode.jaroWinklerStrong,
          impact: titleMetrics.jaroWinkler * config.weights.jaroWinkler * 100,
        ),
      );
    }
    if (titleMetrics.trigramSimilarity >= 0.85) {
      reasons.add(
        MatchReason(
          code: MatchReasonCode.trigramSimilarity,
          impact: titleMetrics.trigramSimilarity * config.weights.trigram * 100,
        ),
      );
    }
    if (aliasOverlap > 0) {
      reasons.add(
        MatchReason(
          code: MatchReasonCode.aliasOverlap,
          impact: aliasOverlap * config.weights.aliasOverlap * 100,
          metadata: <String, Object?>{
            'overlap': aliasOverlap,
            'shared_aliases': aliasIntersection.toList(growable: false),
          },
        ),
      );
    }

    _pushContextReason(
      reasons: reasons,
      score: yearScore,
      positive: MatchReasonCode.yearMatchBonus,
      nearPositive: MatchReasonCode.yearNearBonus,
      negative: MatchReasonCode.yearMismatchPenalty,
      weight: config.weights.year,
      metadata: <String, Object?>{
        'query_year': query.releaseYear,
        'candidate_year': candidate.releaseYear,
      },
    );
    _pushContextReason(
      reasons: reasons,
      score: typeScore,
      positive: MatchReasonCode.typeMatchBonus,
      nearPositive: MatchReasonCode.typeMatchBonus,
      negative: MatchReasonCode.typeMismatchPenalty,
      weight: config.weights.type,
      metadata: <String, Object?>{
        'query_type': query.format.name,
        'candidate_type': candidate.format.name,
      },
    );
    _pushSeasonReason(
      reasons: reasons,
      score: seasonScore,
      query: query,
      candidate: candidate,
      weight: config.weights.season,
    );
    _pushEpisodeReason(
      reasons: reasons,
      score: episodeScore,
      queryEpisodes: query.episodeCount,
      candidateEpisodes: candidate.episodeCount,
      weight: config.weights.episodes,
    );

    if (titleMetrics.groupedSeasonTitle) {
      reasons.add(
        const MatchReason(code: MatchReasonCode.groupedSeasonTitle, impact: 6),
      );
      finalScore += 6;
    }
    if (titleMetrics.compactSimilarity >= 0.92 &&
        titleMetrics.tokenSetSimilarity < 0.8) {
      final compactBonus =
          (titleMetrics.compactSimilarity - titleMetrics.tokenSetSimilarity) *
          config.weights.tokenSet *
          100 *
          0.75;
      finalScore += compactBonus;
      reasons.add(
        MatchReason(
          code: MatchReasonCode.compactSimilarityBonus,
          impact: compactBonus,
          metadata: <String, Object?>{
            'compact_similarity': titleMetrics.compactSimilarity,
            'token_set_similarity': titleMetrics.tokenSetSimilarity,
          },
        ),
      );
    }
    final weakPrimaryAliasPenalty = _weakPrimaryAliasPenalty(
      query: query,
      candidate: candidate,
      titleMetrics: titleMetrics,
      primaryTitleMetrics: primaryTitleMetrics,
      yearScore: yearScore,
      typeScore: typeScore,
    );
    if (weakPrimaryAliasPenalty > 0) {
      reasons.add(
        MatchReason(
          code: MatchReasonCode.weakPrimaryTitlePenalty,
          impact: -weakPrimaryAliasPenalty,
          metadata: <String, Object?>{
            'primary_token_set_similarity':
                primaryTitleMetrics.tokenSetSimilarity,
            'primary_jaro_winkler': primaryTitleMetrics.jaroWinkler,
            'primary_shared_root': primaryTitleMetrics.sharedRootTitle,
            'year_score': yearScore,
          },
        ),
      );
      finalScore -= weakPrimaryAliasPenalty;
    }
    if (titleMetrics.titleConflict) {
      reasons.add(
        const MatchReason(code: MatchReasonCode.titleConflict, impact: -20),
      );
      finalScore -= 20;
    }

    return ScoredSeriesCandidate<T>(
      candidate: candidate.payload,
      blockingKeys: blockingKeys,
      breakdown: SeriesScoringBreakdown(
        finalScore: finalScore.clamp(0, 100).toDouble(),
        tokenSetSimilarity: titleMetrics.tokenSetSimilarity,
        tokenSortSimilarity: titleMetrics.tokenSortSimilarity,
        jaroWinkler: titleMetrics.jaroWinkler,
        trigramSimilarity: titleMetrics.trigramSimilarity,
        aliasOverlap: aliasOverlap,
        yearScore: yearScore,
        typeScore: typeScore,
        seasonScore: seasonScore,
        episodeScore: episodeScore,
      ),
      reasons: reasons,
    );
  }

  _TitleMetrics _bestTitleMetrics(
    List<NormalizedSeriesTitle> queryTitles,
    List<NormalizedSeriesTitle> candidateTitles,
  ) {
    _TitleMetrics best = const _TitleMetrics.empty();
    for (final queryTitle in queryTitles) {
      for (final candidateTitle in candidateTitles) {
        final metrics = _scoreTitlePair(queryTitle, candidateTitle);
        if (metrics.blended > best.blended) {
          best = metrics;
        }
      }
    }
    return best;
  }

  _TitleMetrics _scoreTitlePair(
    NormalizedSeriesTitle queryTitle,
    NormalizedSeriesTitle candidateTitle,
  ) {
    final tokenSetSimilarity = _jaccard(
      queryTitle.significantTokens,
      candidateTitle.significantTokens,
    );
    final tokenSortSimilarity = _jaroWinkler(
      queryTitle.sortedTokens.join(' '),
      candidateTitle.sortedTokens.join(' '),
    );
    final jaroWinkler = _jaroWinkler(
      queryTitle.normalized,
      candidateTitle.normalized,
    );
    final trigramSimilarity = _dice(
      queryTitle.trigrams,
      candidateTitle.trigrams,
    );
    final compactSimilarity =
        queryTitle.compact.isNotEmpty && candidateTitle.compact.isNotEmpty
        ? _jaroWinkler(queryTitle.compact, candidateTitle.compact)
        : 0.0;
    final exactTitle =
        queryTitle.compact.isNotEmpty &&
        queryTitle.compact == candidateTitle.compact;
    final aliasExact = queryTitle.normalized == candidateTitle.normalized;
    final sharedRootTitle = _sharesRootTitle(queryTitle, candidateTitle);
    final groupedSeasonTitle =
        sharedRootTitle &&
        queryTitle.baseTitle.isNotEmpty &&
        queryTitle.baseTitle == candidateTitle.baseTitle &&
        queryTitle.tokens.length > candidateTitle.tokens.length;
    final titleConflict =
        sharedRootTitle && tokenSetSimilarity < 0.55 && trigramSimilarity < 0.6;
    final blended =
        (tokenSetSimilarity * 0.3) +
        (tokenSortSimilarity * 0.2) +
        (jaroWinkler * 0.3) +
        (trigramSimilarity * 0.2);
    return _TitleMetrics(
      blended: blended,
      tokenSetSimilarity: tokenSetSimilarity,
      tokenSortSimilarity: tokenSortSimilarity,
      jaroWinkler: jaroWinkler,
      trigramSimilarity: trigramSimilarity,
      compactSimilarity: compactSimilarity,
      exactTitle: exactTitle,
      aliasExact: aliasExact,
      sharedRootTitle: sharedRootTitle,
      groupedSeasonTitle: groupedSeasonTitle,
      titleConflict: titleConflict,
    );
  }

  bool _sharesRootTitle(
    NormalizedSeriesTitle queryTitle,
    NormalizedSeriesTitle candidateTitle,
  ) {
    final queryRoot = queryTitle.rootTitle.trim();
    final candidateRoot = candidateTitle.rootTitle.trim();
    if (queryRoot.isNotEmpty && queryRoot == candidateRoot) {
      return true;
    }

    bool isStrongRoot(String value) {
      final tokenCount = value
          .split(' ')
          .where((token) => token.isNotEmpty)
          .length;
      return tokenCount >= 2 && value.length >= 6;
    }

    if (isStrongRoot(queryRoot) &&
        candidateTitle.baseTitle.length > queryRoot.length &&
        candidateTitle.baseTitle.startsWith('$queryRoot ')) {
      return true;
    }
    if (isStrongRoot(candidateRoot) &&
        queryTitle.baseTitle.length > candidateRoot.length &&
        queryTitle.baseTitle.startsWith('$candidateRoot ')) {
      return true;
    }

    return false;
  }

  double _weakPrimaryAliasPenalty({
    required SeriesFingerprint<dynamic> query,
    required SeriesFingerprint<dynamic> candidate,
    required _TitleMetrics titleMetrics,
    required _TitleMetrics primaryTitleMetrics,
    required double yearScore,
    required double typeScore,
  }) {
    if (!titleMetrics.aliasExact) {
      return 0;
    }
    final primaryMismatch =
        primaryTitleMetrics.tokenSetSimilarity < 0.35 &&
        primaryTitleMetrics.jaroWinkler < 0.72 &&
        !primaryTitleMetrics.sharedRootTitle;
    if (!primaryMismatch) {
      return 0;
    }
    final missingPrimaryDisambiguator = _isMissingPrimaryDisambiguator(
      query.primaryTitle,
      candidate.primaryTitle,
    );
    final trustedExactAlias =
        titleMetrics.exactTitle &&
        titleMetrics.tokenSetSimilarity >= 0.99 &&
        titleMetrics.jaroWinkler >= 0.99 &&
        typeScore >= 0;
    if (trustedExactAlias && !missingPrimaryDisambiguator) {
      return 0;
    }
    if (yearScore > 0) {
      return 0;
    }
    return 18;
  }

  bool _isMissingPrimaryDisambiguator(
    NormalizedSeriesTitle queryTitle,
    NormalizedSeriesTitle candidateTitle,
  ) {
    final numericTokens = queryTitle.significantTokens.where((token) {
      final value = int.tryParse(token);
      return value != null && value >= 1900 && value <= 2100;
    });
    for (final token in numericTokens) {
      if (!candidateTitle.significantTokens.contains(token)) {
        return true;
      }
    }
    final explicitMarkers = queryTitle.tokens.any(
      (token) => token == 'season' || token == 'part',
    );
    if (explicitMarkers &&
        !candidateTitle.tokens.any(
          (token) => token == 'season' || token == 'part',
        )) {
      return true;
    }
    return false;
  }

  void _pushContextReason({
    required List<MatchReason> reasons,
    required double score,
    required MatchReasonCode positive,
    required MatchReasonCode nearPositive,
    required MatchReasonCode negative,
    required double weight,
    required Map<String, Object?> metadata,
  }) {
    if (score > 0.95) {
      reasons.add(
        MatchReason(
          code: positive,
          impact: score * weight * 100,
          metadata: metadata,
        ),
      );
    } else if (score > 0) {
      reasons.add(
        MatchReason(
          code: nearPositive,
          impact: score * weight * 100,
          metadata: metadata,
        ),
      );
    } else if (score < 0) {
      reasons.add(
        MatchReason(
          code: negative,
          impact: score * weight * 100,
          metadata: metadata,
        ),
      );
    }
  }

  void _pushSeasonReason({
    required List<MatchReason> reasons,
    required double score,
    required SeriesFingerprint<dynamic> query,
    required SeriesFingerprint<dynamic> candidate,
    required double weight,
  }) {
    if (score > 0) {
      reasons.add(
        MatchReason(
          code: MatchReasonCode.seasonConsistencyBonus,
          impact: score * weight * 100,
          metadata: <String, Object?>{
            'query_season': query.seasonInfo.seasonNumber,
            'candidate_season': candidate.seasonInfo.seasonNumber,
            'query_part': query.seasonInfo.partNumber,
            'candidate_part': candidate.seasonInfo.partNumber,
          },
        ),
      );
      if (query.seasonInfo.partNumber != null &&
          query.seasonInfo.partNumber == candidate.seasonInfo.partNumber) {
        reasons.add(
          MatchReason(
            code: MatchReasonCode.partConsistencyBonus,
            impact: score * weight * 80,
          ),
        );
      }
    } else if (score < 0) {
      final partConflict =
          query.seasonInfo.partNumber != null &&
          candidate.seasonInfo.partNumber != null &&
          query.seasonInfo.partNumber != candidate.seasonInfo.partNumber;
      reasons.add(
        MatchReason(
          code: partConflict
              ? MatchReasonCode.partConflict
              : MatchReasonCode.seasonConflict,
          impact: score * weight * 100,
          metadata: <String, Object?>{
            'query_season': query.seasonInfo.seasonNumber,
            'candidate_season': candidate.seasonInfo.seasonNumber,
            'query_part': query.seasonInfo.partNumber,
            'candidate_part': candidate.seasonInfo.partNumber,
          },
        ),
      );
    }
  }

  void _pushEpisodeReason({
    required List<MatchReason> reasons,
    required double score,
    required int? queryEpisodes,
    required int? candidateEpisodes,
    required double weight,
  }) {
    if (score > 0) {
      reasons.add(
        MatchReason(
          code: MatchReasonCode.episodeCountConsistencyBonus,
          impact: score * weight * 100,
          metadata: <String, Object?>{
            'query_episodes': queryEpisodes,
            'candidate_episodes': candidateEpisodes,
          },
        ),
      );
    } else if (score < 0) {
      reasons.add(
        MatchReason(
          code: MatchReasonCode.episodeCountConflict,
          impact: score * weight * 100,
          metadata: <String, Object?>{
            'query_episodes': queryEpisodes,
            'candidate_episodes': candidateEpisodes,
          },
        ),
      );
    }
  }

  double _yearScore(int? queryYear, int? candidateYear) {
    if (queryYear == null || candidateYear == null) {
      return 0;
    }
    final delta = (queryYear - candidateYear).abs();
    if (delta == 0) {
      return 1;
    }
    if (delta == 1) {
      return 0.7;
    }
    if (delta == 2) {
      return 0.35;
    }
    if (delta <= 4) {
      return -0.4;
    }
    return -1;
  }

  double _typeScore(AnimeFormat queryType, AnimeFormat candidateType) {
    if (queryType == AnimeFormat.unknown ||
        candidateType == AnimeFormat.unknown) {
      return 0;
    }
    return queryType == candidateType ? 1 : -1;
  }

  double _seasonScore(
    SeriesFingerprint<dynamic> query,
    SeriesFingerprint<dynamic> candidate,
  ) {
    final querySeason = query.seasonInfo.seasonNumber;
    final candidateSeason = candidate.seasonInfo.seasonNumber;
    final queryPart = query.seasonInfo.partNumber;
    final candidatePart = candidate.seasonInfo.partNumber;
    if (querySeason != null && candidateSeason != null) {
      if (querySeason == candidateSeason) {
        return queryPart != null &&
                candidatePart != null &&
                queryPart != candidatePart
            ? -0.8
            : 1;
      }
      return -1;
    }
    if (queryPart != null && candidatePart != null) {
      return queryPart == candidatePart ? 0.8 : -0.8;
    }
    if ((querySeason != null && candidateSeason == null) ||
        (querySeason == null && candidateSeason != null)) {
      return query.primaryTitle.baseTitle == candidate.primaryTitle.baseTitle
          ? 0.4
          : 0;
    }
    return 0;
  }

  double _episodeScore(int? queryEpisodes, int? candidateEpisodes) {
    if (queryEpisodes == null || candidateEpisodes == null) {
      return 0;
    }
    final delta = (queryEpisodes - candidateEpisodes).abs();
    if (delta == 0) {
      return 1;
    }
    if (delta <= 2) {
      return 0.6;
    }
    if (delta <= 4) {
      return 0.2;
    }
    return -0.9;
  }

  double _jaccard(Set<String> left, Set<String> right) {
    if (left.isEmpty || right.isEmpty) {
      return 0;
    }
    var intersectionCount = 0;
    for (final item in left) {
      if (right.contains(item)) intersectionCount++;
    }
    final unionCount = left.length + right.length - intersectionCount;
    return _ratio(intersectionCount.toDouble(), unionCount.toDouble());
  }

  double _dice(Set<String> left, Set<String> right) {
    if (left.isEmpty || right.isEmpty) {
      return 0;
    }
    var intersectionCount = 0;
    for (final item in left) {
      if (right.contains(item)) intersectionCount++;
    }
    return _ratio(
      (2 * intersectionCount).toDouble(),
      (left.length + right.length).toDouble(),
    );
  }

  double _ratio(double numerator, double denominator) {
    if (denominator == 0) {
      return 0;
    }
    return numerator / denominator;
  }

  double _jaroWinkler(String left, String right) {
    if (left == right) {
      return 1;
    }
    if (left.isEmpty || right.isEmpty) {
      return 0;
    }

    final matchDistance = (math.max(left.length, right.length) ~/ 2) - 1;
    final leftMatches = List<bool>.filled(left.length, false);
    final rightMatches = List<bool>.filled(right.length, false);

    var matches = 0;
    for (var leftIndex = 0; leftIndex < left.length; leftIndex++) {
      final start = math.max(0, leftIndex - matchDistance);
      final end = math.min(leftIndex + matchDistance + 1, right.length);
      for (var rightIndex = start; rightIndex < end; rightIndex++) {
        if (rightMatches[rightIndex] || left[leftIndex] != right[rightIndex]) {
          continue;
        }
        leftMatches[leftIndex] = true;
        rightMatches[rightIndex] = true;
        matches++;
        break;
      }
    }
    if (matches == 0) {
      return 0;
    }

    var transpositions = 0;
    var rightCursor = 0;
    for (var leftIndex = 0; leftIndex < left.length; leftIndex++) {
      if (!leftMatches[leftIndex]) {
        continue;
      }
      while (!rightMatches[rightCursor]) {
        rightCursor++;
      }
      if (left[leftIndex] != right[rightCursor]) {
        transpositions++;
      }
      rightCursor++;
    }

    final m = matches.toDouble();
    final jaro =
        ((m / left.length) +
            (m / right.length) +
            ((m - transpositions / 2) / m)) /
        3;
    var prefix = 0;
    for (
      var index = 0;
      index < math.min(4, math.min(left.length, right.length));
      index++
    ) {
      if (left[index] != right[index]) {
        break;
      }
      prefix++;
    }
    return jaro + (prefix * 0.1 * (1 - jaro));
  }
}

final class _TitleMetrics {
  const _TitleMetrics({
    required this.blended,
    required this.tokenSetSimilarity,
    required this.tokenSortSimilarity,
    required this.jaroWinkler,
    required this.trigramSimilarity,
    required this.compactSimilarity,
    required this.exactTitle,
    required this.aliasExact,
    required this.sharedRootTitle,
    required this.groupedSeasonTitle,
    required this.titleConflict,
  });

  const _TitleMetrics.empty()
    : this(
        blended: 0,
        tokenSetSimilarity: 0,
        tokenSortSimilarity: 0,
        jaroWinkler: 0,
        trigramSimilarity: 0,
        compactSimilarity: 0,
        exactTitle: false,
        aliasExact: false,
        sharedRootTitle: false,
        groupedSeasonTitle: false,
        titleConflict: false,
      );

  final double blended;
  final double tokenSetSimilarity;
  final double tokenSortSimilarity;
  final double jaroWinkler;
  final double trigramSimilarity;
  final double compactSimilarity;
  final bool exactTitle;
  final bool aliasExact;
  final bool sharedRootTitle;
  final bool groupedSeasonTitle;
  final bool titleConflict;
}
