import 'mangaupdates_series.dart' show MangaUpdatesGroupRef;

/// A single chapter release as recorded by MangaUpdates. Used for
/// the picker enrichment slice (M8) to compute "last activity per
/// scanlator on this series" without scraping.
///
/// Note: a release may legitimately have multiple groups when a
/// joint translation is published.
final class MangaUpdatesRelease {
  const MangaUpdatesRelease({
    required this.id,
    required this.seriesId,
    required this.seriesTitle,
    required this.groups,
    required this.timeAdded,
    this.chapter,
    this.volume,
    this.releaseDate,
  });

  final int id;
  final int seriesId;
  final String seriesTitle;

  /// Chapter as recorded by MU. Stored as a string because real
  /// catalogs include partial chapter markers like `"5.5"` or
  /// `"Extra"` that lose information when coerced to numeric.
  final String? chapter;

  /// Volume as recorded by MU. Same string-typed rationale as
  /// [chapter].
  final String? volume;

  /// `release_date` as `YYYY-MM-DD`. Null when the publisher did
  /// not supply a release date and the upload time is the only
  /// signal available.
  final String? releaseDate;

  /// `time_added` parsed from the rfc3339 form. This is the most
  /// reliable timestamp for "recent activity" calculations because
  /// it reflects when MU itself recorded the release, regardless
  /// of catalog backfills.
  final DateTime timeAdded;

  /// One or more groups credited with this release. May be empty
  /// when the release predates the groups attribution feature.
  final List<MangaUpdatesGroupRef> groups;
}
