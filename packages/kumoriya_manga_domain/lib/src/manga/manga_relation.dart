import 'manga.dart';

/// Type of relation between two manga entries (or between an anime and a
/// manga, surfaced from the manga side).
enum MangaRelationType {
  prequel,
  sequel,
  sideStory,
  adaptation,
  spinOff,
  other,
}

/// A relation edge starting from a manga, pointing to another manga.
/// Anime↔manga adaptations cross the universe boundary and are surfaced
/// at the application layer using `kumoriya_matching` rather than here.
final class MangaRelation {
  const MangaRelation({required this.type, required this.manga});

  final MangaRelationType type;
  final Manga manga;
}
