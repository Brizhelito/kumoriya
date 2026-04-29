import '../models/mangabaka_series.dart';

/// Maps raw MangaBaka JSON `data` payloads into [MangaBakaSeries].
///
/// All parsing is defensive: missing optional fields fall back to
/// safe defaults; the only field that is hard-required is `id`,
/// since a series without one cannot be referenced.
final class MangaBakaSeriesMapper {
  const MangaBakaSeriesMapper._();

  /// Parses a single MangaBaka `data` map. Throws [FormatException]
  /// when the payload is fundamentally invalid (missing/non-int id or
  /// missing/empty title), so the gateway can lift it into a
  /// [MangaBakaMappingError]. All other anomalies (unknown enum
  /// values, missing relationships, partial source maps) are tolerated.
  static MangaBakaSeries map(Map<String, dynamic> data) {
    final id = data['id'];
    if (id is! int) {
      throw const FormatException(
        'MangaBaka series payload is missing a numeric id.',
      );
    }

    final title = (data['title'] as String?)?.trim();
    if (title == null || title.isEmpty) {
      throw const FormatException(
        'MangaBaka series payload is missing a title.',
      );
    }

    return MangaBakaSeries(
      id: id,
      state: _mapState(data['state'] as String?),
      mergedWith: data['merged_with'] is int
          ? data['merged_with'] as int
          : null,
      title: title,
      nativeTitle: _trimOrNull(data['native_title']),
      romanizedTitle: _trimOrNull(data['romanized_title']),
      secondaryTitles: _flattenSecondaryTitles(data['secondary_titles']),
      type: _mapType(data['type'] as String?),
      status: _mapStatus(data['status'] as String?),
      year: data['year'] is int ? data['year'] as int : null,
      description: _trimOrNull(data['description']),
      coverUrl: _extractCoverUrl(data['cover']),
      authors: _stringList(data['authors']),
      artists: _stringList(data['artists']),
      genres: _stringList(data['genres']),
      crossIds: _mapCrossIds(data['source']),
    );
  }

  static MangaBakaSeriesState _mapState(String? raw) {
    switch (raw) {
      case 'active':
        return MangaBakaSeriesState.active;
      case 'merged':
        return MangaBakaSeriesState.merged;
      case 'deleted':
        return MangaBakaSeriesState.deleted;
      default:
        return MangaBakaSeriesState.unknown;
    }
  }

  static MangaBakaSeriesType _mapType(String? raw) {
    switch (raw) {
      case 'manga':
        return MangaBakaSeriesType.manga;
      case 'manhwa':
        return MangaBakaSeriesType.manhwa;
      case 'manhua':
        return MangaBakaSeriesType.manhua;
      case 'novel':
        return MangaBakaSeriesType.novel;
      case 'oel':
        return MangaBakaSeriesType.oel;
      case 'other':
        return MangaBakaSeriesType.other;
      default:
        return MangaBakaSeriesType.unknown;
    }
  }

  static MangaBakaSeriesStatus _mapStatus(String? raw) {
    switch (raw) {
      case 'releasing':
        return MangaBakaSeriesStatus.releasing;
      case 'completed':
        return MangaBakaSeriesStatus.completed;
      case 'hiatus':
        return MangaBakaSeriesStatus.hiatus;
      case 'cancelled':
        return MangaBakaSeriesStatus.cancelled;
      case 'upcoming':
        return MangaBakaSeriesStatus.upcoming;
      default:
        return MangaBakaSeriesStatus.unknown;
    }
  }

  static String? _trimOrNull(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  /// Flattens the `secondary_titles` map (`{lang: [{title}, ...]}`)
  /// into a single deduplicated list, preserving original order.
  /// Case-insensitive dedup.
  static List<String> _flattenSecondaryTitles(dynamic raw) {
    if (raw is! Map) return const <String>[];
    final seen = <String>{};
    final result = <String>[];
    for (final entry in raw.values) {
      if (entry is! List) continue;
      for (final item in entry) {
        if (item is! Map) continue;
        final title = item['title'];
        if (title is! String) continue;
        final trimmed = title.trim();
        if (trimmed.isEmpty) continue;
        if (seen.add(trimmed.toLowerCase())) {
          result.add(trimmed);
        }
      }
    }
    return List<String>.unmodifiable(result);
  }

  static String? _extractCoverUrl(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    // Prefer the largest-quality variant available.
    for (final key in const ['raw', 'x350', 'x250', 'x150']) {
      final entry = raw[key];
      if (entry is Map<String, dynamic>) {
        final url = entry['url'];
        if (url is String && url.trim().isNotEmpty) {
          return url.trim();
        }
        // The `raw` block sometimes contains the URL directly under
        // alternate keys; search shallowly for any string-valued URL.
        for (final value in entry.values) {
          if (value is String && value.startsWith('http')) {
            return value;
          }
        }
      } else if (entry is String && entry.startsWith('http')) {
        return entry;
      }
    }
    return null;
  }

  static MangaBakaCrossIds _mapCrossIds(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return const MangaBakaCrossIds();
    }
    return MangaBakaCrossIds(
      anilistId: _intIdAt(raw, 'anilist'),
      myAnimeListId: _intIdAt(raw, 'my_anime_list'),
      kitsuId: _intIdAt(raw, 'kitsu'),
      mangaUpdatesId: _stringIdAt(raw, 'manga_updates'),
      animePlanetId: _stringIdAt(raw, 'anime_planet'),
      animeNewsNetworkId: _intIdAt(raw, 'anime_news_network'),
      shikimoriId: _intIdAt(raw, 'shikimori'),
    );
  }

  static int? _intIdAt(Map<String, dynamic> source, String key) {
    final entry = source[key];
    if (entry is! Map<String, dynamic>) return null;
    final id = entry['id'];
    if (id is int) return id;
    // MangaBaka occasionally returns numeric ids encoded as strings.
    if (id is String) return int.tryParse(id);
    return null;
  }

  static String? _stringIdAt(Map<String, dynamic> source, String key) {
    final entry = source[key];
    if (entry is! Map<String, dynamic>) return null;
    final id = entry['id'];
    if (id is String) {
      final trimmed = id.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (id is int) return id.toString();
    return null;
  }
}
