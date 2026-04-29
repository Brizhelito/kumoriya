/// State of a MangaBaka series record.
///
/// MangaBaka periodically merges duplicates and tombstones invalid
/// entries. Consumers must treat `merged` rows as redirects: the
/// canonical id lives in [MangaBakaSeries.mergedWith].
enum MangaBakaSeriesState { active, merged, deleted, unknown }

/// High-level work type as classified by MangaBaka. Used by the
/// matching pipeline to decide whether a row is a candidate for the
/// manga catalog (we exclude `novel` and `other` upstream).
enum MangaBakaSeriesType { manga, manhwa, manhua, novel, oel, other, unknown }

/// Publication status. Mirrors AniList's MangaStatus shape but stays
/// in this package so we don't leak domain types into the adapter.
enum MangaBakaSeriesStatus {
  releasing,
  completed,
  hiatus,
  cancelled,
  upcoming,
  unknown,
}

/// Cross-tracker identifiers for a series. Every field is nullable
/// because MangaBaka entries vary in coverage. The `mangaUpdates` and
/// `animePlanet` ids are strings (slugs/hashes), the rest are ints.
final class MangaBakaCrossIds {
  const MangaBakaCrossIds({
    this.anilistId,
    this.myAnimeListId,
    this.kitsuId,
    this.mangaUpdatesId,
    this.animePlanetId,
    this.animeNewsNetworkId,
    this.shikimoriId,
  });

  final int? anilistId;
  final int? myAnimeListId;
  final int? kitsuId;
  final String? mangaUpdatesId;
  final String? animePlanetId;
  final int? animeNewsNetworkId;
  final int? shikimoriId;

  /// Convenience: true when at least one tracker id is populated. Used
  /// by the matching pipeline to skip series that contribute no
  /// resolution value.
  bool get hasAny =>
      anilistId != null ||
      myAnimeListId != null ||
      kitsuId != null ||
      mangaUpdatesId != null ||
      animePlanetId != null ||
      animeNewsNetworkId != null ||
      shikimoriId != null;
}

/// Parsed MangaBaka series record. The shape is intentionally minimal:
/// only the fields the matching pipeline needs. Adding new fields here
/// is free, but every field must be defensively parsed in the mapper.
final class MangaBakaSeries {
  const MangaBakaSeries({
    required this.id,
    required this.state,
    required this.title,
    required this.type,
    required this.status,
    required this.crossIds,
    this.mergedWith,
    this.nativeTitle,
    this.romanizedTitle,
    this.secondaryTitles = const <String>[],
    this.year,
    this.description,
    this.coverUrl,
    this.authors = const <String>[],
    this.artists = const <String>[],
    this.genres = const <String>[],
  });

  final int id;
  final MangaBakaSeriesState state;

  /// When [state] is [MangaBakaSeriesState.merged], this points to the
  /// canonical surviving id. Null in every other state.
  final int? mergedWith;

  final String title;
  final String? nativeTitle;
  final String? romanizedTitle;

  /// Flattened, deduplicated list of secondary titles across all
  /// languages. The mapper trims whitespace and drops empties; order
  /// follows the original API response.
  final List<String> secondaryTitles;

  final MangaBakaSeriesType type;
  final MangaBakaSeriesStatus status;
  final int? year;
  final String? description;
  final String? coverUrl;
  final List<String> authors;
  final List<String> artists;
  final List<String> genres;
  final MangaBakaCrossIds crossIds;

  /// Every known title for this series, in priority order:
  /// `title`, `romanizedTitle`, `nativeTitle`, then secondary titles.
  /// Used by the matching pipeline to expand fuzzy-match candidates
  /// against scanlator sources that don't expose AniList ids.
  ///
  /// Whitespace is trimmed and case-insensitive duplicates are
  /// dropped (the first occurrence wins, preserving priority order).
  /// Returned as an `Iterable` so consumers can short-circuit
  /// iteration once a satisfactory match is found.
  Iterable<String> get titleCorpus sync* {
    final seen = <String>{};
    final candidates = <String?>[
      title,
      romanizedTitle,
      nativeTitle,
      ...secondaryTitles,
    ];
    for (final raw in candidates) {
      if (raw == null) continue;
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(trimmed.toLowerCase())) {
        yield trimmed;
      }
    }
  }
}
