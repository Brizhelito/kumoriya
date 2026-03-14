import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_matching/kumoriya_matching.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../models/source_availability.dart';

final class AnilistSourceMatcher {
  const AnilistSourceMatcher({
    SeriesFingerprintBuilder fingerprintBuilder =
        const SeriesFingerprintBuilder(),
    MatchingConfig config = const MatchingConfig(),
  }) : _fingerprintBuilder = fingerprintBuilder,
       _config = config;

  final SeriesFingerprintBuilder _fingerprintBuilder;
  final MatchingConfig _config;

  SourceMatchDecision decideMatch({
    required AnimeDetail anilistDetail,
    required List<SourceAnimeMatch> candidates,
  }) {
    if (candidates.isEmpty) {
      return const SourceMatchDecision(
        verdict: false,
        confidence: MatchConfidence.low,
        reason: 'No source candidates were returned.',
        acceptanceSignals: <String>[],
        rejectionSignals: <String>['empty_candidate_list'],
      );
    }

    final canonical = CanonicalSeries.fromAnimeDetail(anilistDetail);
    final query = _fingerprintBuilder.fromCanonical(canonical);
    final sourceFingerprints = candidates
        .map(
          (candidate) => _fingerprintBuilder.fromSource(
            SourceSeriesRecord.fromSourceAnimeMatch(
              sourceId: 'source',
              match: candidate,
            ),
          ),
        )
        .toList(growable: false);
    final resolver = SeriesEntityResolver<SourceSeriesRecord>(
      candidateIndex: SeriesCandidateIndex<SourceSeriesRecord>(
        sourceFingerprints,
      ),
      config: _config,
    );
    final resolution = resolver.resolve(query);
    final candidateByRecordId = <String, SourceAnimeMatch>{
      for (final candidate in candidates)
        'source:${candidate.sourceId}': candidate,
    };
    final bestCandidate = resolution.bestCandidate == null
        ? null
        : candidateByRecordId[resolution.bestCandidate!.recordId];

    final acceptanceSignals = resolution.reasons
        .where((reason) => !reason.isPenalty)
        .map((reason) => _signalName(reason.code))
        .toSet()
        .toList(growable: true);
    final rejectionSignals = resolution.reasons
        .where((reason) => reason.isPenalty)
        .map((reason) => _signalName(reason.code))
        .toSet()
        .toList(growable: true);

    if (acceptanceSignals.contains('grouped_season_title') &&
        !acceptanceSignals.contains('grouped-season-title')) {
      acceptanceSignals.add('grouped-season-title');
    }
    if (rejectionSignals.contains('ambiguous_runner_up') &&
        !rejectionSignals.contains('ambiguous-top-candidates')) {
      rejectionSignals.add('ambiguous-top-candidates');
    }

    return SourceMatchDecision(
      verdict: resolution.verdict == SeriesDecisionVerdict.autoMatch,
      confidence: switch (resolution.verdict) {
        SeriesDecisionVerdict.autoMatch => MatchConfidence.high,
        SeriesDecisionVerdict.reviewNeeded => MatchConfidence.medium,
        SeriesDecisionVerdict.reject => MatchConfidence.low,
      },
      reason: switch (resolution.verdict) {
        SeriesDecisionVerdict.autoMatch =>
          'Auto match accepted by hybrid scoring policy.',
        SeriesDecisionVerdict.reviewNeeded =>
          'Candidate requires manual review before linking.',
        SeriesDecisionVerdict.reject =>
          'Candidate rejected by conservative entity-resolution policy.',
      },
      acceptanceSignals: acceptanceSignals,
      rejectionSignals: rejectionSignals,
      candidate: resolution.verdict == SeriesDecisionVerdict.reject
          ? null
          : bestCandidate,
    );
  }

  String _signalName(MatchReasonCode code) {
    return code.name
        .replaceAllMapped(
          RegExp(r'(?<!^)([A-Z])'),
          (match) => '_${match.group(1)!.toLowerCase()}',
        )
        .toLowerCase();
  }
}
