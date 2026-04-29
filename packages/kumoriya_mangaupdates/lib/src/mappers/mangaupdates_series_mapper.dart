import '../models/mangaupdates_series.dart';

/// Maps raw MangaUpdates JSON `record` payloads (search hit or
/// detail response) into [MangaUpdatesSeries]. Detail-only fields
/// fall through to null when absent.
final class MangaUpdatesSeriesMapper {
  const MangaUpdatesSeriesMapper._();

  /// Parses a single MangaUpdates series record. Throws
  /// [FormatException] when the payload is fundamentally invalid
  /// (missing/non-int `series_id` or missing/empty `title`), so the
  /// gateway can lift it into a `MangaUpdatesMappingError`.
  static MangaUpdatesSeries map(Map<String, dynamic> record) {
    final id = record['series_id'];
    if (id is! int) {
      throw const FormatException(
        'MangaUpdates series payload is missing a numeric series_id.',
      );
    }

    final title = (record['title'] as String?)?.trim();
    if (title == null || title.isEmpty) {
      throw const FormatException(
        'MangaUpdates series payload is missing a title.',
      );
    }

    return MangaUpdatesSeries(
      id: id,
      title: title,
      url: (record['url'] as String?)?.trim() ?? '',
      type: _mapType(record['type'] as String?),
      year: _trimOrNull(record['year']),
      description: _trimOrNull(record['description']),
      coverUrl: _extractCoverUrl(record['image']),
      bayesianRating: _asDouble(record['bayesian_rating']),
      ratingVotes: record['rating_votes'] is int
          ? record['rating_votes'] as int
          : null,
      genres: _genreList(record['genres']),
      associatedTitles: _associatedTitles(record['associated']),
      latestChapter: record['latest_chapter'] is int
          ? record['latest_chapter'] as int
          : null,
      completed: record['completed'] is bool
          ? record['completed'] as bool
          : null,
      licensed: record['licensed'] is bool ? record['licensed'] as bool : null,
      statusNote: _trimOrNull(record['status']),
      lastUpdated: _parseLastUpdated(record['last_updated']),
    );
  }

  static MangaUpdatesSeriesType _mapType(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'manga':
        return MangaUpdatesSeriesType.manga;
      case 'manhwa':
        return MangaUpdatesSeriesType.manhwa;
      case 'manhua':
        return MangaUpdatesSeriesType.manhua;
      case 'doujinshi':
        return MangaUpdatesSeriesType.doujinshi;
      case 'novel':
        return MangaUpdatesSeriesType.novel;
      case 'oel':
        return MangaUpdatesSeriesType.oel;
      case 'artbook':
        return MangaUpdatesSeriesType.artbook;
      case 'other':
        return MangaUpdatesSeriesType.other;
      case null:
        return MangaUpdatesSeriesType.unknown;
      default:
        return MangaUpdatesSeriesType.other;
    }
  }

  static String? _trimOrNull(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// MangaUpdates `genres` is a list of `{genre: name}` objects, not
  /// a flat string list. Defensively handles either shape.
  static List<String> _genreList(dynamic value) {
    if (value is! List) return const <String>[];
    final out = <String>[];
    for (final entry in value) {
      if (entry is String) {
        final trimmed = entry.trim();
        if (trimmed.isNotEmpty) out.add(trimmed);
      } else if (entry is Map<String, dynamic>) {
        final name = entry['genre'];
        if (name is String && name.trim().isNotEmpty) {
          out.add(name.trim());
        }
      }
    }
    return List<String>.unmodifiable(out);
  }

  /// `associated` is a list of `{title: ...}` entries on the detail
  /// endpoint. Search hits use a flat `hit_associated` list which
  /// callers can map directly to a string list.
  static List<String> _associatedTitles(dynamic value) {
    if (value is! List) return const <String>[];
    final seen = <String>{};
    final out = <String>[];
    for (final entry in value) {
      String? title;
      if (entry is String) {
        title = entry;
      } else if (entry is Map<String, dynamic>) {
        final t = entry['title'];
        if (t is String) title = t;
      }
      if (title == null) continue;
      final trimmed = title.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(trimmed.toLowerCase())) {
        out.add(trimmed);
      }
    }
    return List<String>.unmodifiable(out);
  }

  static String? _extractCoverUrl(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final url = raw['url'];
    if (url is String && url.trim().isNotEmpty) {
      return url.trim();
    }
    return null;
  }

  static DateTime? _parseLastUpdated(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final rfc = raw['as_rfc3339'];
    if (rfc is String) {
      final parsed = DateTime.tryParse(rfc);
      if (parsed != null) return parsed;
    }
    final ts = raw['timestamp'];
    if (ts is int) {
      return DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true);
    }
    return null;
  }
}
