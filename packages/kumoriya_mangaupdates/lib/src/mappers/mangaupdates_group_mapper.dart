import '../models/mangaupdates_group.dart';

/// Maps raw MangaUpdates `/v1/groups/{id}` payloads into
/// [MangaUpdatesGroup].
final class MangaUpdatesGroupMapper {
  const MangaUpdatesGroupMapper._();

  /// Throws [FormatException] when the payload is missing
  /// `group_id` or `name`.
  static MangaUpdatesGroup map(Map<String, dynamic> data) {
    final id = data['group_id'];
    if (id is! int) {
      throw const FormatException(
        'MangaUpdates group payload is missing a numeric group_id.',
      );
    }
    final name = (data['name'] as String?)?.trim();
    if (name == null || name.isEmpty) {
      throw const FormatException(
        'MangaUpdates group payload is missing a name.',
      );
    }

    final social = data['social'];
    String? socialUrl(String key) {
      if (social is! Map<String, dynamic>) return null;
      final value = social[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      return null;
    }

    return MangaUpdatesGroup(
      id: id,
      name: name,
      active: data['active'] is bool ? data['active'] as bool : false,
      url: _trimOrNull(data['url']),
      notes: _trimOrNull(data['notes']),
      siteUrl: socialUrl('site'),
      discordUrl: socialUrl('discord'),
      facebookUrl: socialUrl('facebook'),
      twitterUrl: socialUrl('twitter'),
      associatedNames: _stringList(data['associated']),
    );
  }

  static String? _trimOrNull(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    final seen = <String>{};
    final out = <String>[];
    for (final entry in value) {
      String? name;
      if (entry is String) {
        name = entry;
      } else if (entry is Map<String, dynamic>) {
        final n = entry['name'] ?? entry['title'];
        if (n is String) name = n;
      }
      if (name == null) continue;
      final trimmed = name.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(trimmed.toLowerCase())) {
        out.add(trimmed);
      }
    }
    return List<String>.unmodifiable(out);
  }
}
