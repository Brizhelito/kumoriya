import '../blocking/series_candidate_index.dart';
import '../models/canonical_series.dart';
import '../models/series_match_result.dart';
import '../models/series_record.dart';
import '../normalization/series_fingerprint_builder.dart';
import 'series_entity_resolver.dart';

final class IncrementalRecomputePlan {
  const IncrementalRecomputePlan({
    required this.impactedCanonicalIds,
    required this.blockingKeys,
    required this.fullReindexRecommended,
  });

  final Set<String> impactedCanonicalIds;
  final Set<String> blockingKeys;
  final bool fullReindexRecommended;
}

final class CanonicalMappingEngine {
  CanonicalMappingEngine({
    required List<CanonicalSeries> canonicals,
    SeriesFingerprintBuilder fingerprintBuilder =
        const SeriesFingerprintBuilder(),
  }) : _fingerprintBuilder = fingerprintBuilder,
       _canonicalFingerprints = canonicals
           .map(fingerprintBuilder.fromCanonical)
           .toList(growable: false),
       _candidateIndex = SeriesCandidateIndex<CanonicalSeries>(
         canonicals
             .map(fingerprintBuilder.fromCanonical)
             .toList(growable: false),
       );

  final SeriesFingerprintBuilder _fingerprintBuilder;
  final List<SeriesFingerprint<CanonicalSeries>> _canonicalFingerprints;
  final SeriesCandidateIndex<CanonicalSeries> _candidateIndex;

  SeriesMatchDecision<CanonicalSeries> mapSourceRecord(
    SourceSeriesRecord source,
  ) {
    final resolver = SeriesEntityResolver<CanonicalSeries>(
      candidateIndex: _candidateIndex,
    );
    return resolver.resolve(_fingerprintBuilder.fromSource(source));
  }

  IncrementalRecomputePlan planSourceUpsert(SourceSeriesRecord source) {
    final fingerprint = _fingerprintBuilder.fromSource(source);
    final impacted = _candidateIndex
        .lookup(fingerprint)
        .map((candidate) => candidate.fingerprint.payload.canonicalId)
        .toSet();
    return IncrementalRecomputePlan(
      impactedCanonicalIds: impacted,
      blockingKeys: fingerprint.blockingKeys,
      fullReindexRecommended: impacted.isEmpty,
    );
  }

  List<CanonicalSeries> get canonicals => _canonicalFingerprints
      .map((fingerprint) => fingerprint.payload)
      .toList(growable: false);
}
