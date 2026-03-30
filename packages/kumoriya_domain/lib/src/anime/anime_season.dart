enum AnimeSeason { winter, spring, summer, fall }

final class SeasonalCatalogRequest {
  const SeasonalCatalogRequest({
    required this.season,
    required this.year,
    this.page = 1,
    this.perPage = 30,
    this.includeCarryovers = true,
  });

  final AnimeSeason season;
  final int year;
  final int page;
  final int perPage;
  final bool includeCarryovers;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SeasonalCatalogRequest &&
            other.season == season &&
            other.year == year &&
            other.page == page &&
            other.perPage == perPage &&
            other.includeCarryovers == includeCarryovers;
  }

  @override
  int get hashCode =>
      Object.hash(season, year, page, perPage, includeCarryovers);
}
