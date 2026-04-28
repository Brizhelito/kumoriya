import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';

import 'reader_mode.dart';

/// Everything the reader needs to render one chapter, fully resolved.
///
/// The reader does **not** know how the pages were obtained
/// (network from a `MangaSourcePlugin`, disk from a downloaded CBZ,
/// or test fixtures). The slice that wires these sources lives in the
/// app, never inside `kumoriya_reader`.
final class ChapterSession {
  const ChapterSession({
    required this.mangaAnilistId,
    required this.sourceId,
    required this.chapter,
    required this.pages,
    required this.mode,
    this.initialPageIndex = 0,
    this.initialScrollOffsetPx,
    this.title,
  }) : assert(initialPageIndex >= 0, 'initialPageIndex must be >= 0');

  /// AniList id of the parent manga. Used for progress persistence.
  final int mangaAnilistId;

  /// Plugin id that produced the pages (e.g. `mangadex`). Same key the
  /// progress store uses.
  final String sourceId;

  /// Chapter metadata (number, title, language, scanlator, etc.).
  final MangaChapter chapter;

  /// Already-resolved page list, ordered by `MangaPage.index` ascending.
  /// Empty list is treated as a degraded state by the UI; the resolver
  /// upstream should refuse to construct an empty session.
  final List<MangaPage> pages;

  /// Layout strategy the reader will use.
  final ReaderMode mode;

  /// Starting page (paginated mode) — the first page visible when the
  /// reader opens. Vertical mode uses `initialScrollOffsetPx` instead;
  /// `initialPageIndex` becomes a fallback (we scroll to the top of
  /// that page) when the offset is unknown.
  final int initialPageIndex;

  /// Starting scroll position (vertical mode), in logical pixels from
  /// the top of the chapter list. Null = scroll to `initialPageIndex`.
  final double? initialScrollOffsetPx;

  /// Optional human-readable title shown in the reader app bar.
  /// Defaults to `Chapter <number>` when null.
  final String? title;
}
