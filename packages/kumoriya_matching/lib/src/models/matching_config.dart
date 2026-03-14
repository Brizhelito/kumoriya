final class MatchingWeights {
  const MatchingWeights({
    this.tokenSet = 0.22,
    this.tokenSort = 0.14,
    this.jaroWinkler = 0.18,
    this.trigram = 0.12,
    this.aliasOverlap = 0.14,
    this.year = 0.08,
    this.type = 0.05,
    this.season = 0.05,
    this.episodes = 0.02,
    this.exactTitleBonus = 10,
    this.aliasExactBonus = 12,
    this.rootTitleBonus = 4,
    this.sparseMetadataPenalty = 8,
  });

  final double tokenSet;
  final double tokenSort;
  final double jaroWinkler;
  final double trigram;
  final double aliasOverlap;
  final double year;
  final double type;
  final double season;
  final double episodes;
  final double exactTitleBonus;
  final double aliasExactBonus;
  final double rootTitleBonus;
  final double sparseMetadataPenalty;
}

final class MatchingThresholds {
  const MatchingThresholds({
    this.autoMatch = 84,
    this.reviewNeeded = 68,
    this.ambiguityDelta = 6,
  });

  final double autoMatch;
  final double reviewNeeded;
  final double ambiguityDelta;
}

final class MatchingConfig {
  const MatchingConfig({
    this.weights = const MatchingWeights(),
    this.thresholds = const MatchingThresholds(),
  });

  final MatchingWeights weights;
  final MatchingThresholds thresholds;
}
