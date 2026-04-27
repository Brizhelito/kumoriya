import 'manga.dart';
import 'manga_chapter.dart';
import 'manga_relation.dart';

final class MangaDetail {
  const MangaDetail({
    required this.manga,
    this.chapters = const <MangaChapter>[],
    this.relations = const <MangaRelation>[],
  });

  final Manga manga;
  final List<MangaChapter> chapters;
  final List<MangaRelation> relations;

  /// Convenience accessors delegating to [manga].
  String? get synopsis => manga.synopsis;
  List<String> get genres => manga.genres;
  String? get bannerImageUrl => manga.bannerImageUrl;
}
