/// Localized title bundle for a manga.
///
/// Mirrors `AnimeTitle` so unified components can render either universe
/// with the same logic.
final class MangaTitle {
  const MangaTitle({
    required this.romaji,
    this.english,
    this.native,
    this.synonyms = const <String>[],
  });

  final String romaji;
  final String? english;
  final String? native;
  final List<String> synonyms;
}
