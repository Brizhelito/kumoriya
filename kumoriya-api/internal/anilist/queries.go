// Package anilist groups the AniList edge-cache subsystem.
//
// The subsystem centralises fetches for *shared* Home surfaces (trending,
// seasonal, airing calendar) so that thousands of users can be served from
// an in-memory SWR cache instead of each hitting graphql.anilist.co directly.
//
// Non-shared surfaces (per-media detail, search, per-user lists) are **not**
// cached here: clients continue to fetch those directly from AniList so the
// global rate limit stays distributed across user IPs rather than bottle-
// necking on a single server IP.
package anilist

// The queries below are copied verbatim from
// packages/kumoriya_anilist/lib/src/client/anilist_queries.dart.
//
// IMPORTANT: keep them in sync with the Dart client. The server acts as a
// pass-through cache: it returns the raw `data` object from AniList so the
// existing Flutter mappers work without modification.

// TrendingQuery fetches the combined trending/current-season Home catalog.
const TrendingQuery = `query TrendingAnime(
  $page: Int,
  $perPage: Int,
  $season: MediaSeason,
  $seasonYear: Int,
  $statusIn: [MediaStatus]
) {
  Page(page: $page, perPage: $perPage) {
    media(
      type: ANIME,
      season: $season,
      seasonYear: $seasonYear,
      status_in: $statusIn,
      sort: [SCORE_DESC, POPULARITY_DESC, TRENDING_DESC],
      isAdult: false
    ) {
      id
      title { romaji english native }
      synonyms
      format
      season
      seasonYear
      episodes
      averageScore
      popularity
      status
      description(asHtml: false)
      genres
      bannerImage
      nextAiringEpisode { episode airingAt }
      coverImage { large medium }
    }
  }
}`

// SeasonDiscoveryQuery fetches current, upcoming, recommended, and
// (optionally) carryover season anime in a single request using aliased
// Page blocks.
const SeasonDiscoveryQuery = `query SeasonDiscovery(
  $page: Int,
  $perPage: Int,
  $season: MediaSeason,
  $seasonYear: Int,
  $prevSeason: MediaSeason,
  $prevSeasonYear: Int,
  $includeCarryover: Boolean!
) {
  current: Page(page: $page, perPage: $perPage) {
    media(
      type: ANIME,
      season: $season,
      seasonYear: $seasonYear,
      status: RELEASING,
      sort: [TRENDING_DESC],
      isAdult: false
    ) { ...MediaFields trending }
  }
  upcoming: Page(page: $page, perPage: $perPage) {
    media(
      type: ANIME,
      season: $season,
      seasonYear: $seasonYear,
      status: NOT_YET_RELEASED,
      sort: [TRENDING_DESC],
      isAdult: false
    ) { ...MediaFields trending }
  }
  recommended: Page(page: $page, perPage: $perPage) {
    media(
      type: ANIME,
      season: $season,
      seasonYear: $seasonYear,
      sort: [SCORE_DESC, POPULARITY_DESC],
      isAdult: false
    ) { ...MediaFields trending }
  }
  carryover: Page(page: $page, perPage: $perPage) @include(if: $includeCarryover) {
    media(
      type: ANIME,
      season: $prevSeason,
      seasonYear: $prevSeasonYear,
      status: RELEASING,
      sort: [TRENDING_DESC],
      isAdult: false
    ) { ...MediaFields trending }
  }
}

fragment MediaFields on Media {
  id
  title { romaji english native }
  synonyms
  format
  season
  seasonYear
  episodes
  averageScore
  popularity
  status
  description(asHtml: false)
  genres
  bannerImage
  nextAiringEpisode { episode airingAt }
  coverImage { large medium }
}`

// MangaHomeQuery fetches the four manga Home shelves
// (trending / popular / latest / top-rated) in a single request via
// aliased Page blocks. Mirrors the Dart-side fields verbatim so the
// existing manga mapper consumes the payload unchanged.
//
// `latest` filters out NOT_YET_RELEASED so the row is not dominated by
// announcements with no chapters. `topRated` requires popularity ≥ 5000
// so freshly-rated one-shots with 9.0+ scores from a handful of users
// don't outrank the actual cult classics.
const MangaHomeQuery = `query MangaHome($page: Int, $perPage: Int) {
  trending: Page(page: $page, perPage: $perPage) {
    media(
      type: MANGA,
      sort: [TRENDING_DESC, POPULARITY_DESC],
      isAdult: false
    ) { ...MangaFields }
  }
  popular: Page(page: $page, perPage: $perPage) {
    media(
      type: MANGA,
      sort: [POPULARITY_DESC],
      isAdult: false
    ) { ...MangaFields }
  }
  latest: Page(page: $page, perPage: $perPage) {
    media(
      type: MANGA,
      status_in: [RELEASING, FINISHED],
      sort: [START_DATE_DESC],
      isAdult: false
    ) { ...MangaFields }
  }
  topRated: Page(page: $page, perPage: $perPage) {
    media(
      type: MANGA,
      sort: [SCORE_DESC],
      popularity_greater: 5000,
      isAdult: false
    ) { ...MangaFields }
  }
}

fragment MangaFields on Media {
  id
  title { romaji english native }
  synonyms
  format
  chapters
  volumes
  averageScore
  popularity
  status
  description(asHtml: false)
  genres
  bannerImage
  countryOfOrigin
  startDate { year }
  coverImage { large medium }
}`

// AiringCalendarQuery fetches airing schedules within a timestamp window.
// Paginated by the caller.
const AiringCalendarQuery = `query AiringCalendar(
  $page: Int,
  $perPage: Int,
  $airingAtGreater: Int,
  $airingAtLesser: Int
) {
  Page(page: $page, perPage: $perPage) {
    pageInfo { hasNextPage }
    airingSchedules(
      sort: [TIME],
      airingAt_greater: $airingAtGreater,
      airingAt_lesser: $airingAtLesser
    ) {
      episode
      airingAt
      media {
        id
        isAdult
        title { romaji english native }
        synonyms
        format
        season
        seasonYear
        episodes
        averageScore
        popularity
        status
        description(asHtml: false)
        genres
        bannerImage
        coverImage { large medium }
      }
    }
  }
}`
