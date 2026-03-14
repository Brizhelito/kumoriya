import '../blocking/series_candidate_index.dart';
import '../models/match_reason.dart';
import '../models/matching_config.dart';
import '../models/series_match_result.dart';
import '../normalization/series_fingerprint_builder.dart';
import '../scoring/hybrid_series_scorer.dart';

final class SeriesEntityResolver<T> {
  SeriesEntityResolver({
    required SeriesCandidateIndex<T> candidateIndex,
    HybridSeriesScorer? scorer,
    MatchingConfig config = const MatchingConfig(),
  }) : _candidateIndex = candidateIndex,
       _scorer = scorer ?? HybridSeriesScorer(config: config),
       _config = config;

  final SeriesCandidateIndex<T> _candidateIndex;
  final HybridSeriesScorer _scorer;
  final MatchingConfig _config;

  SeriesMatchDecision<T> resolve(SeriesFingerprint<dynamic> query) {
    final candidates = _candidateIndex.lookup(query);
    if (candidates.isEmpty) {
      return SeriesMatchDecision<T>(
        verdict: SeriesDecisionVerdict.reject,
        bestCandidate: null,
        bestScore: 0,
        reasons: const <MatchReason>[],
        topCandidates: <ScoredSeriesCandidate<T>>[],
      );
    }

    final scored =
        candidates
            .map(
              (candidate) => _scorer.score(
                query: query,
                candidate: candidate.fingerprint,
                blockingKeys: candidate.matchedKeys,
              ),
            )
            .toList(growable: false)
          ..sort(
            (left, right) =>
                right.breakdown.finalScore.compareTo(left.breakdown.finalScore),
          );

    final best = scored.first;
    final runnerUpScore = scored.length > 1
        ? scored[1].breakdown.finalScore
        : double.negativeInfinity;
    final scoreDelta = best.breakdown.finalScore - runnerUpScore;
    final isAmbiguous =
        scored.length > 1 && scoreDelta < _config.thresholds.ambiguityDelta;
    final reasons = List<MatchReason>.from(best.reasons);
    if (isAmbiguous) {
      reasons.add(
        MatchReason(
          code: MatchReasonCode.ambiguousRunnerUp,
          impact: -5,
          metadata: <String, Object?>{'score_delta': scoreDelta},
        ),
      );
    }

    final strongLexical =
        best.breakdown.tokenSetSimilarity >= 0.8 ||
        best.breakdown.jaroWinkler >= 0.92 ||
        best.reasons.any(
          (reason) =>
              reason.code == MatchReasonCode.matchedByAlias ||
              reason.code == MatchReasonCode.groupedSeasonTitle ||
              reason.code == MatchReasonCode.highTitleSimilarity,
        );
    final verdict = _decide(
      score: best.breakdown.finalScore,
      strongLexical: strongLexical,
      hasHardConflict: best.hasHardConflict,
      isAmbiguous: isAmbiguous,
    );

    return SeriesMatchDecision<T>(
      verdict: verdict,
      bestCandidate: best.candidate,
      bestScore: best.breakdown.finalScore,
      reasons: reasons,
      topCandidates: scored.take(3).toList(growable: false),
    );
  }

  SeriesDecisionVerdict _decide({
    required double score,
    required bool strongLexical,
    required bool hasHardConflict,
    required bool isAmbiguous,
  }) {
    if (!strongLexical) {
      return SeriesDecisionVerdict.reject;
    }
    if (hasHardConflict) {
      return SeriesDecisionVerdict.reject;
    }
    if (!hasHardConflict &&
        !isAmbiguous &&
        score >= _config.thresholds.autoMatch) {
      return SeriesDecisionVerdict.autoMatch;
    }
    if (score >= _config.thresholds.reviewNeeded) {
      return SeriesDecisionVerdict.reviewNeeded;
    }
    return SeriesDecisionVerdict.reject;
  }
}
