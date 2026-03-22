enum MatchReasonCode {
  blockingKeyMatch,
  matchedByAlias,
  highTitleSimilarity,
  tokenSetSimilarity,
  tokenSortSimilarity,
  jaroWinklerStrong,
  trigramSimilarity,
  aliasOverlap,
  exactTitleBonus,
  groupedSeasonTitle,
  yearMatchBonus,
  yearNearBonus,
  yearMismatchPenalty,
  typeMatchBonus,
  typeMismatchPenalty,
  seasonConsistencyBonus,
  seasonConflict,
  partConsistencyBonus,
  partConflict,
  episodeCountConsistencyBonus,
  episodeCountConflict,
  sparseMetadataPenalty,
  weakPrimaryTitlePenalty,
  ambiguousRunnerUp,
  titleConflict,
  compactSimilarityBonus,
}

final class MatchReason {
  const MatchReason({
    required this.code,
    required this.impact,
    this.metadata = const <String, Object?>{},
  });

  final MatchReasonCode code;
  final double impact;
  final Map<String, Object?> metadata;

  bool get isPenalty => impact < 0;
}
