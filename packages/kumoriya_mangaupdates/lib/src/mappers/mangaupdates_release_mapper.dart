import '../models/mangaupdates_release.dart';
import '../models/mangaupdates_series.dart' show MangaUpdatesGroupRef;

/// Maps raw MangaUpdates `/v1/releases/search` records into
/// [MangaUpdatesRelease]. Each search result has shape
/// `{record: {...}, hit_title: ...}`; this mapper accepts the
/// `record` map directly.
final class MangaUpdatesReleaseMapper {
  const MangaUpdatesReleaseMapper._();

  /// Throws [FormatException] when the payload is missing required
  /// fields (`id`, `time_added`).
  static MangaUpdatesRelease map(Map<String, dynamic> record) {
    final id = record['id'];
    if (id is! int) {
      throw const FormatException(
        'MangaUpdates release payload is missing a numeric id.',
      );
    }

    final timeAdded = _parseTimeAdded(record['time_added']);
    if (timeAdded == null) {
      throw const FormatException(
        'MangaUpdates release payload is missing a parseable time_added.',
      );
    }

    return MangaUpdatesRelease(
      id: id,
      seriesId: record['series_id'] is int ? record['series_id'] as int : 0,
      seriesTitle: (record['title'] as String?)?.trim() ?? '',
      chapter: _trimOrNull(record['chapter']),
      volume: _trimOrNull(record['volume']),
      releaseDate: _trimOrNull(record['release_date']),
      timeAdded: timeAdded,
      groups: _mapGroups(record['groups']),
    );
  }

  static List<MangaUpdatesGroupRef> _mapGroups(dynamic raw) {
    if (raw is! List) return const <MangaUpdatesGroupRef>[];
    final out = <MangaUpdatesGroupRef>[];
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      final id = entry['group_id'];
      final name = entry['name'];
      if (id is! int) continue;
      if (name is! String || name.trim().isEmpty) continue;
      out.add(
        MangaUpdatesGroupRef(
          id: id,
          name: name.trim(),
          url: _trimOrNull(entry['url']),
        ),
      );
    }
    return List<MangaUpdatesGroupRef>.unmodifiable(out);
  }

  static DateTime? _parseTimeAdded(dynamic raw) {
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

  static String? _trimOrNull(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
