/// Publication status of a manga / manhwa / manhua title.
///
/// Mirrors `AnimeStatus` shape so unified UI components can treat both
/// universes uniformly. Wire mapping is the responsibility of the AniList
/// gateway, not this enum.
enum MangaStatus {
  finished,
  releasing,
  notYetReleased,
  cancelled,
  hiatus,
  unknown,
}
