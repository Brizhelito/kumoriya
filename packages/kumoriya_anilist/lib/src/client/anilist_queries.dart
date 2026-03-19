const String trendingAnimeQuery = r'''
query TrendingAnime(
  $page: Int,
  $perPage: Int
) {
  Page(page: $page, perPage: $perPage) {
    media(type: ANIME, sort: [TRENDING_DESC], isAdult: false) {
      id
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
      format
      seasonYear
      episodes
      averageScore
      status
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
