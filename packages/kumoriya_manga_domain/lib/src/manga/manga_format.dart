/// Format of a manga-universe title.
///
/// Used by the reader to pick a sensible default layout (vertical webtoon
/// for manhwa/manhua, paginated for manga / one-shot) and by the UI to
/// label the format. The user can override the reader layout per title.
///
/// Light novels are intentionally absent from this enum: they are out of
/// scope for the manga phase.
enum MangaFormat { manga, manhwa, manhua, oneShot, doujinshi, unknown }
