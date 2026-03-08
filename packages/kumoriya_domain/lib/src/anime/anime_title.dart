final class AnimeTitle {
  const AnimeTitle({
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
