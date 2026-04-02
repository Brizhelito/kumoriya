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
