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
    airingSchedules(
      notYetAired: true,
      sort: [TIME],
      airingAt_greater: $airingAtGreater,
      airingAt_lesser: $airingAtLesser
    ) {
      episode
      airingAt
      media {
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
