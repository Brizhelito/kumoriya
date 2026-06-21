import 'dart:ui';

/// Per-universe accent colors.
///
/// Anime gets a blue/sky tint; manga gets a warm sepia tint.
/// These flow through `Theme.of(context).colorScheme.primary` as before.
class UniverseAccent {
  const UniverseAccent({
    required this.primary,
    required this.primarySoft,
    required this.name,
  });

  final Color primary;
  final Color primarySoft;
  final String name;

  /// Anime universe — sky blue accent.
  static const UniverseAccent anime = UniverseAccent(
    primary: Color(0xFF5B7BB5),
    primarySoft: Color(0xFFA8B8D4),
    name: 'anime',
  );

  /// Manga universe — warm sepia accent.
  static const UniverseAccent manga = UniverseAccent(
    primary: Color(0xFFC9A855),
    primarySoft: Color(0xFFE8DFCB),
    name: 'manga',
  );
}
