/// Sort modes supported when browsing the manga catalog.
///
/// `chaptersDesc` is manga-specific and has no anime equivalent; it's
/// useful for surfacing long-running titles ahead of one-shots.
enum MangaSortType {
  trending,
  score,
  popularity,
  favourites,
  startDate,
  titleRomaji,
  chaptersDesc,
}
