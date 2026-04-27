/// The kind of media a Kumoriya entity belongs to.
///
/// Cross-cutting entities that the user perceives as a single inventory
/// (library, downloads, history, sync payloads, deep links) carry a
/// [MediaKind] to disambiguate the universe they belong to.
///
/// Universe-specific entities (e.g. `Anime`, `Manga`) do **not** carry
/// [MediaKind] — their type already implies it.
enum MediaKind {
  anime,
  manga;

  /// Stable wire identifier used for storage rows, sync payloads, and
  /// deep links. Must remain backwards-compatible across releases.
  String get wireValue => switch (this) {
    MediaKind.anime => 'anime',
    MediaKind.manga => 'manga',
  };

  /// Parses a [MediaKind] from its [wireValue]. Returns `null` when the
  /// input does not correspond to a known kind. Callers decide whether
  /// `null` should fail loudly (e.g. migration paths) or be ignored
  /// (e.g. forward-compatible reads).
  static MediaKind? tryParse(String? wireValue) {
    return switch (wireValue) {
      'anime' => MediaKind.anime,
      'manga' => MediaKind.manga,
      _ => null,
    };
  }

  /// Strict variant of [tryParse]. Throws [ArgumentError] when the input
  /// is unknown. Use in code paths where an unknown kind is a bug, not a
  /// degraded state.
  static MediaKind parse(String wireValue) {
    final parsed = tryParse(wireValue);
    if (parsed == null) {
      throw ArgumentError.value(
        wireValue,
        'wireValue',
        'Unknown MediaKind wire value',
      );
    }
    return parsed;
  }
}
