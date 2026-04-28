import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';

/// Layout strategy the reader uses to display a chapter.
///
/// `vertical` is the default for manhwa / manhua / webtoon — a single
/// continuous scroll with no per-page UI affordances.
///
/// `paginated` is the default for traditional manga / one-shots — one
/// page at a time, swipe horizontally, with `PhotoView` zoom.
enum ReaderMode { vertical, paginated }

/// Picks a default `ReaderMode` for a given source format.
///
/// Korean / Chinese formats default to vertical; everything else
/// (including unknown) defaults to paginated. The user can override
/// per-title — that override lives outside this package.
ReaderMode defaultReaderModeForFormat(MangaFormat format) {
  return switch (format) {
    MangaFormat.manhwa || MangaFormat.manhua => ReaderMode.vertical,
    MangaFormat.manga ||
    MangaFormat.oneShot ||
    MangaFormat.doujinshi ||
    MangaFormat.unknown => ReaderMode.paginated,
  };
}
