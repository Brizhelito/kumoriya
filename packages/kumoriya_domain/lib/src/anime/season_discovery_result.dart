import 'anime.dart';

/// Result of a consolidated season discovery fetch combining current-season,
/// upcoming, and recommended anime lists in a single operation.
final class SeasonDiscoveryResult {
  const SeasonDiscoveryResult({
    required this.inSeason,
    required this.upcoming,
    required this.recommended,
  });

  /// Currently-airing anime for the requested season (including carryovers
  /// from the previous season when requested).
  final List<Anime> inSeason;

  /// Not-yet-released anime for the requested season.
  final List<Anime> upcoming;

  /// Top-rated anime for the requested season.
  final List<Anime> recommended;
}
