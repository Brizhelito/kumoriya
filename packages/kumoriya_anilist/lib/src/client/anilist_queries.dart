// ---------------------------------------------------------------------------
// Shared GraphQL fragment
// ---------------------------------------------------------------------------

/// Standard catalog fields shared across all media-list queries.
/// Append to any query document that uses `...MediaFields`.
const String _mediaFragment = r'''
fragment MediaFields on Media {
  id
  title {
    romaji
    english
    native
  }
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
  nextAiringEpisode {
    episode
    airingAt
  }
  coverImage {
    large
    medium
  }
}
''';

// ---------------------------------------------------------------------------
// Individual queries (kept for backward compatibility)
// ---------------------------------------------------------------------------

const String trendingAnimeQuery = r'''
query TrendingAnime(
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
      title {
        romaji
        english
        native
      }
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
      nextAiringEpisode {
        episode
        airingAt
      }
      coverImage {
        large
        medium
      }
    }
  }
}
''';

const String searchAnimeQuery = r'''
query SearchAnime(
  $query: String,
  $page: Int,
  $perPage: Int
) {
  Page(page: $page, perPage: $perPage) {
    media(type: ANIME, search: $query, sort: [SEARCH_MATCH, POPULARITY_DESC], isAdult: false) {
      id
      title {
        romaji
        english
        native
      }
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
      nextAiringEpisode {
        episode
        airingAt
      }
      coverImage {
        large
        medium
      }
    }
  }
}
''';

const String seasonalAnimeQuery = r'''
query SeasonalAnime(
  $page: Int,
  $perPage: Int,
  $season: MediaSeason,
  $seasonYear: Int,
  $status: MediaStatus
) {
  Page(page: $page, perPage: $perPage) {
    media(
      type: ANIME,
      season: $season,
      seasonYear: $seasonYear,
      status: $status,
      sort: [TRENDING_DESC],
      isAdult: false
    ) {
      id
      title {
        romaji
        english
        native
      }
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
      trending
      nextAiringEpisode {
        episode
        airingAt
      }
      coverImage {
        large
        medium
      }
    }
  }
}
''';

const String upcomingSeasonAnimeQuery = r'''
query UpcomingSeasonAnime(
  $page: Int,
  $perPage: Int,
  $season: MediaSeason,
  $seasonYear: Int
) {
  Page(page: $page, perPage: $perPage) {
    media(
      type: ANIME,
      season: $season,
      seasonYear: $seasonYear,
      status: NOT_YET_RELEASED,
      sort: [TRENDING_DESC],
      isAdult: false
    ) {
      id
      title {
        romaji
        english
        native
      }
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
      trending
      nextAiringEpisode {
        episode
        airingAt
      }
      coverImage {
        large
        medium
      }
    }
  }
}
''';

const String seasonRecommendationsQuery = r'''
query SeasonRecommendations(
  $page: Int,
  $perPage: Int,
  $season: MediaSeason,
  $seasonYear: Int
) {
  Page(page: $page, perPage: $perPage) {
    media(
      type: ANIME,
      season: $season,
      seasonYear: $seasonYear,
      sort: [SCORE_DESC, POPULARITY_DESC],
      isAdult: false
    ) {
      id
      title {
        romaji
        english
        native
      }
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
      trending
      nextAiringEpisode {
        episode
        airingAt
      }
      coverImage {
        large
        medium
      }
    }
  }
}
''';

const String airingCalendarQuery = r'''
query AiringCalendar(
  $page: Int,
  $perPage: Int,
  $airingAtGreater: Int,
  $airingAtLesser: Int
) {
  Page(page: $page, perPage: $perPage) {
    pageInfo {
      hasNextPage
    }
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
        title {
          romaji
          english
          native
        }
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
        coverImage {
          large
          medium
        }
      }
    }
  }
}
''';

const String animeDetailQuery = r'''
query AnimeDetail($id: Int) {
  Media(id: $id, type: ANIME) {
    id
    title {
      romaji
      english
      native
    }
    synonyms
    format
    seasonYear
    episodes
    averageScore
    status
    description(asHtml: false)
    genres
    bannerImage
    coverImage {
      large
      medium
    }
    nextAiringEpisode {
      episode
      airingAt
    }
    airingSchedule(page: 1, perPage: 50, notYetAired: true) {
      nodes {
        episode
        airingAt
      }
    }
    relations {
      edges {
        relationType
      }
      nodes {
        id
        type
        title {
          romaji
          english
          native
        }
        format
        seasonYear
        episodes
        averageScore
        status
        coverImage {
          large
          medium
        }
      }
    }
  }
}
''';

/// Lightweight batch query used by the background worker to check for
/// newly-aired episodes across all subscribed animes in a single request.
const String batchAiringStatusQuery = r'''
query BatchAiringStatus($ids: [Int]) {
  Page(perPage: 50) {
    media(id_in: $ids, type: ANIME) {
      id
      title {
        romaji
        english
      }
      nextAiringEpisode {
        episode
        airingAt
      }
    }
  }
}
''';

// ---------------------------------------------------------------------------
// Combo queries (request consolidation)
// ---------------------------------------------------------------------------

/// Fetches current-season, upcoming, recommended, and optionally carryover
/// anime in a **single** GraphQL request using aliased Page blocks.
///
/// Set `$includeCarryover` to `true` and supply `$prevSeason` / `$prevSeasonYear`
/// to include still-airing shows from the previous season.
const String _seasonDiscoveryBody = r'''
query SeasonDiscovery(
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
    ) {
      ...MediaFields
      trending
    }
  }
  upcoming: Page(page: $page, perPage: $perPage) {
    media(
      type: ANIME,
      season: $season,
      seasonYear: $seasonYear,
      status: NOT_YET_RELEASED,
      sort: [TRENDING_DESC],
      isAdult: false
    ) {
      ...MediaFields
      trending
    }
  }
  recommended: Page(page: $page, perPage: $perPage) {
    media(
      type: ANIME,
      season: $season,
      seasonYear: $seasonYear,
      sort: [SCORE_DESC, POPULARITY_DESC],
      isAdult: false
    ) {
      ...MediaFields
      trending
    }
  }
  carryover: Page(page: $page, perPage: $perPage) @include(if: $includeCarryover) {
    media(
      type: ANIME,
      season: $prevSeason,
      seasonYear: $prevSeasonYear,
      status: RELEASING,
      sort: [TRENDING_DESC],
      isAdult: false
    ) {
      ...MediaFields
      trending
    }
  }
}
''';

const String seasonDiscoveryQuery = _seasonDiscoveryBody + _mediaFragment;

/// Full-metadata batch query for library / favorites prefetch.
/// Uses `id_in` to fetch complete catalog-level fields for a list of AniList
/// IDs in a single request.
const String _batchAnimeByIdsBody = r'''
query BatchAnimeByIds($ids: [Int], $page: Int, $perPage: Int) {
  Page(page: $page, perPage: $perPage) {
    media(id_in: $ids, type: ANIME) {
      ...MediaFields
    }
  }
}
''';

const String batchAnimeByIdsQuery = _batchAnimeByIdsBody + _mediaFragment;

// ---------------------------------------------------------------------------
// Browse / Discover queries
// ---------------------------------------------------------------------------

/// Flexible browse query with optional filters.
/// All filter variables are nullable – AniList ignores null variables.
const String _browseAnimeBody = r'''
query BrowseAnime(
  $page: Int,
  $perPage: Int,
  $search: String,
  $genres: [String],
  $tags: [String],
  $formatIn: [MediaFormat],
  $season: MediaSeason,
  $seasonYear: Int,
  $statusIn: [MediaStatus],
  $sort: [MediaSort]
) {
  Page(page: $page, perPage: $perPage) {
    pageInfo {
      hasNextPage
    }
    media(
      type: ANIME,
      search: $search,
      genre_in: $genres,
      tag_in: $tags,
      format_in: $formatIn,
      season: $season,
      seasonYear: $seasonYear,
      status_in: $statusIn,
      sort: $sort,
      isAdult: false
    ) {
      ...MediaFields
    }
  }
}
''';

const String browseAnimeQuery = _browseAnimeBody + _mediaFragment;

/// Fetches the list of all genre names.
const String genreCollectionQuery = r'''
query GenreCollection {
  GenreCollection
}
''';

/// Fetches all media tags with category grouping.
const String tagCollectionQuery = r'''
query TagCollection {
  MediaTagCollection {
    name
    description
    category
    isAdult
  }
}
''';

// ---------------------------------------------------------------------------
// Manga queries
// ---------------------------------------------------------------------------

/// Fields shared across all manga catalog queries. Manga has no
/// `season` / `seasonYear` / `episodes` / `nextAiringEpisode`; instead it
/// carries `chapters`, `volumes`, `countryOfOrigin`, and `startDate.year`.
const String _mangaFragment = r'''
fragment MangaFields on Media {
  id
  title {
    romaji
    english
    native
  }
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
  startDate {
    year
  }
  coverImage {
    large
    medium
  }
}
''';

const String _trendingMangaBody = r'''
query TrendingManga($page: Int, $perPage: Int) {
  Page(page: $page, perPage: $perPage) {
    media(
      type: MANGA,
      sort: [TRENDING_DESC, POPULARITY_DESC, SCORE_DESC],
      isAdult: false
    ) {
      ...MangaFields
    }
  }
}
''';

const String trendingMangaQuery = _trendingMangaBody + _mangaFragment;

/// Fetches the four manga Home shelves (trending / popular / latest /
/// top-rated) in a single request via aliased Page blocks. Mirrors the
/// Kumoriya Go backend's `MangaHomeQuery` so the direct-AniList fallback
/// path produces a payload of the exact same shape the backend returns.
const String _mangaHomeBody = r'''
query MangaHome($page: Int, $perPage: Int) {
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
''';

const String mangaHomeQuery = _mangaHomeBody + _mangaFragment;

const String _searchMangaBody = r'''
query SearchManga($query: String, $page: Int, $perPage: Int) {
  Page(page: $page, perPage: $perPage) {
    media(
      type: MANGA,
      search: $query,
      sort: [SEARCH_MATCH, POPULARITY_DESC],
      isAdult: false
    ) {
      ...MangaFields
    }
  }
}
''';

const String searchMangaQuery = _searchMangaBody + _mangaFragment;

/// Manga detail. Includes relations so the UI can cross-link to anime
/// adaptations / sequels / spin-offs (relation nodes carry their own
/// `type`, so the consumer must filter to MANGA when building manga
/// relation lists and to ANIME when building cross-universe links).
const String mangaDetailQuery = r'''
query MangaDetail($id: Int) {
  Media(id: $id, type: MANGA) {
    id
    title {
      romaji
      english
      native
    }
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
    startDate {
      year
    }
    coverImage {
      large
      medium
    }
    relations {
      edges {
        relationType
      }
      nodes {
        id
        type
        title {
          romaji
          english
          native
        }
        format
        chapters
        volumes
        averageScore
        status
        countryOfOrigin
        startDate {
          year
        }
        coverImage {
          large
          medium
        }
      }
    }
  }
}
''';

/// Batch manga by AniList ids — used to warm the library cache.
const String _batchMangaByIdsBody = r'''
query BatchMangaByIds($ids: [Int], $page: Int, $perPage: Int) {
  Page(page: $page, perPage: $perPage) {
    media(id_in: $ids, type: MANGA) {
      ...MangaFields
    }
  }
}
''';

const String batchMangaByIdsQuery = _batchMangaByIdsBody + _mangaFragment;

/// Browse manga with optional filters. AniList exposes
/// `countryOfOrigin: CountryCode` as a single value (not a list); when
/// the caller passes multiple countries we use the first one and let the
/// caller decide whether to client-side merge multi-country browses.
const String _browseMangaBody = r'''
query BrowseManga(
  $page: Int,
  $perPage: Int,
  $search: String,
  $genres: [String],
  $tags: [String],
  $formatIn: [MediaFormat],
  $statusIn: [MediaStatus],
  $countryOfOrigin: CountryCode,
  $sort: [MediaSort]
) {
  Page(page: $page, perPage: $perPage) {
    pageInfo {
      hasNextPage
    }
    media(
      type: MANGA,
      search: $search,
      genre_in: $genres,
      tag_in: $tags,
      format_in: $formatIn,
      status_in: $statusIn,
      countryOfOrigin: $countryOfOrigin,
      sort: $sort,
      isAdult: false
    ) {
      ...MangaFields
    }
  }
}
''';

const String browseMangaQuery = _browseMangaBody + _mangaFragment;
