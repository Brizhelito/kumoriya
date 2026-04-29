/// High-level work type as classified by MangaUpdates. The API uses
/// title-case strings (`Manga`, `Manhwa`, `Manhua`, `Doujinshi`,
/// `Novel`, `OEL`); we collapse into the same enum shape used by
/// the MangaBaka adapter for cross-gateway pattern matching.
enum MangaUpdatesSeriesType {
  manga,
  manhwa,
  manhua,
  doujinshi,
  novel,
  oel,
  artbook,
  other,
  unknown,
}

/// A reference to a scanlator group as it appears inside a release.
/// MangaUpdates exposes the canonical group surface via
/// `/v1/groups/{id}` (modeled by [MangaUpdatesGroup]); this is the
/// minimal subset embedded in release records.
final class MangaUpdatesGroupRef {
  const MangaUpdatesGroupRef({required this.id, required this.name, this.url});

  final int id;
  final String name;
  final String? url;
}

/// A MangaUpdates series record. Used for both search hits and
/// detail responses; fields exclusive to the detail endpoint stay
/// nullable so the same model serves both paths.
///
/// **64-bit ids:** MangaUpdates `series_id` values exceed the 32-bit
/// range (e.g. `15_180_124_327`). Dart `int` handles this on native
/// platforms; consumers compiled to JS must avoid storing the id in
/// a JSON payload that goes through `int.parse` from a JS number.
final class MangaUpdatesSeries {
  const MangaUpdatesSeries({
    required this.id,
    required this.title,
    required this.url,
    this.type = MangaUpdatesSeriesType.unknown,
    this.year,
    this.description,
    this.coverUrl,
    this.bayesianRating,
    this.ratingVotes,
    this.genres = const <String>[],
    this.associatedTitles = const <String>[],
    this.latestChapter,
    this.completed,
    this.licensed,
    this.statusNote,
    this.lastUpdated,
  });

  final int id;
  final String title;
  final String url;
  final MangaUpdatesSeriesType type;
  final String? year;
  final String? description;
  final String? coverUrl;
  final double? bayesianRating;
  final int? ratingVotes;
  final List<String> genres;

  /// Alternate titles ("associated"). Only populated by the detail
  /// endpoint; search hits expose them via `hit_associated` which
  /// callers can ignore for matching purposes.
  final List<String> associatedTitles;

  final int? latestChapter;
  final bool? completed;
  final bool? licensed;

  /// Free-form status note (e.g. "Complete (200 chapters)"). Detail
  /// endpoint only.
  final String? statusNote;

  final DateTime? lastUpdated;

  /// Every known title for this series: the canonical title plus
  /// every associated translation, deduped case-insensitively while
  /// preserving order. Mirrors `MangaBakaSeries.titleCorpus` so the
  /// matching pipeline can consume both gateways uniformly.
  Iterable<String> get titleCorpus sync* {
    final seen = <String>{};
    final candidates = <String?>[title, ...associatedTitles];
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
