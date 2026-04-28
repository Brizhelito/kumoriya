import 'manga.dart';

/// Aggregate manga Home payload — four shelves returned in a single
/// repository call (and a single AniList round-trip when served by the
/// Kumoriya Go backend cache).
///
/// Any shelf whose upstream alias produced no matches is exposed as an
/// empty list rather than `null`, so the UI can iterate without guards.
final class MangaHomeSections {
  const MangaHomeSections({
    this.trending = const <Manga>[],
    this.popular = const <Manga>[],
    this.latest = const <Manga>[],
    this.topRated = const <Manga>[],
  });

  final List<Manga> trending;
  final List<Manga> popular;
  final List<Manga> latest;
  final List<Manga> topRated;

  bool get isEmpty =>
      trending.isEmpty && popular.isEmpty && latest.isEmpty && topRated.isEmpty;
}
