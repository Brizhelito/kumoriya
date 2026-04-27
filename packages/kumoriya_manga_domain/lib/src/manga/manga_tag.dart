/// AniList-style tag for manga browsing.
final class MangaTag {
  const MangaTag({
    required this.name,
    this.description,
    this.category,
    this.isAdult = false,
  });

  final String name;
  final String? description;
  final String? category;
  final bool isAdult;

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is MangaTag && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'MangaTag($name)';
}
