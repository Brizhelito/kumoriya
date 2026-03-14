import 'match_reason.dart';

enum SeriesDecisionVerdict { autoMatch, reviewNeeded, reject }

final class SeriesScoringBreakdown {
  const SeriesScoringBreakdown({
    required this.finalScore,
    required this.tokenSetSimilarity,
    required this.tokenSortSimilarity,
    required this.jaroWinkler,
    required this.trigramSimilarity,
    required this.aliasOverlap,
    required this.yearScore,
    required this.typeScore,
    required this.seasonScore,
    required this.episodeScore,
  });

  final double finalScore;
  final double tokenSetSimilarity;
  final double tokenSortSimilarity;
  final double jaroWinkler;
  final double trigramSimilarity;
  final double aliasOverlap;
  final double yearScore;
  final double typeScore;
  final double seasonScore;
  final double episodeScore;
}

final class ScoredSeriesCandidate<T> {
  const ScoredSeriesCandidate({
    required this.candidate,
    required this.breakdown,
    required this.reasons,
    required this.blockingKeys,
  });

  final T candidate;
  final SeriesScoringBreakdown breakdown;
  final List<MatchReason> reasons;
  final Set<String> blockingKeys;

  bool get hasHardConflict => reasons.any(
    (reason) =>
        reason.code == MatchReasonCode.seasonConflict ||
        reason.code == MatchReasonCode.partConflict ||
        reason.code == MatchReasonCode.titleConflict ||
        reason.code == MatchReasonCode.typeMismatchPenalty ||
        reason.code == MatchReasonCode.yearMismatchPenalty,
  );
}

final class SeriesMatchDecision<T> {
  const SeriesMatchDecision({
    required this.verdict,
    required this.bestCandidate,
    required this.bestScore,
    required this.reasons,
    required this.topCandidates,
  });

  final SeriesDecisionVerdict verdict;
  final T? bestCandidate;
  final double bestScore;
  final List<MatchReason> reasons;
  final List<ScoredSeriesCandidate<T>> topCandidates;

  bool get isAutoMatch => verdict == SeriesDecisionVerdict.autoMatch;
}
