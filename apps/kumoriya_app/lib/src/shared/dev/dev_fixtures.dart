import 'package:kumoriya_storage/kumoriya_storage.dart';

/// Dev-only seed data so the app boots into a usable state when the
/// caches are empty AND AniList is unreachable (typical on a fresh
/// `flutter run` during an upstream incident).
///
/// These are *minimal* entries — only the fields the home/search/detail
/// pages need to render a card and a placeholder detail screen. Cover
/// images are deliberately left null so we don't ship broken URLs;
/// `KumoriyaCachedImage` falls back to a placeholder.
///
/// IDs are real AniList ids so that when the network comes back the
/// regular AniList path will refine these entries with full metadata
/// transparently (cache write-through replaces the seed values).
class DevFixtures {
  const DevFixtures._();

  static List<AnilistCacheEntry> animeSeed(DateTime now) {
    return <AnilistCacheEntry>[
      _anime(
        id: 16498,
        romaji: 'Shingeki no Kyojin',
        english: 'Attack on Titan',
        year: 2013,
        score: 84,
        episodes: 25,
        genres: const ['Action', 'Drama', 'Fantasy'],
        now: now,
      ),
      _anime(
        id: 21,
        romaji: 'One Piece',
        english: 'One Piece',
        year: 1999,
        score: 88,
        genres: const ['Action', 'Adventure', 'Comedy', 'Fantasy'],
        now: now,
      ),
      _anime(
        id: 101922,
        romaji: 'Kimetsu no Yaiba',
        english: 'Demon Slayer',
        year: 2019,
        score: 84,
        episodes: 26,
        genres: const ['Action', 'Supernatural'],
        now: now,
      ),
      _anime(
        id: 113415,
        romaji: 'Jujutsu Kaisen',
        english: 'Jujutsu Kaisen',
        year: 2020,
        score: 86,
        episodes: 24,
        genres: const ['Action', 'Supernatural'],
        now: now,
      ),
      _anime(
        id: 154587,
        romaji: 'Sousou no Frieren',
        english: 'Frieren: Beyond Journey\'s End',
        year: 2023,
        score: 92,
        episodes: 28,
        genres: const ['Adventure', 'Drama', 'Fantasy'],
        now: now,
      ),
      _anime(
        id: 127230,
        romaji: 'Chainsaw Man',
        english: 'Chainsaw Man',
        year: 2022,
        score: 84,
        episodes: 12,
        genres: const ['Action', 'Supernatural'],
        now: now,
      ),
      _anime(
        id: 101348,
        romaji: 'Vinland Saga',
        english: 'Vinland Saga',
        year: 2019,
        score: 87,
        episodes: 24,
        genres: const ['Action', 'Adventure', 'Drama', 'Historical'],
        now: now,
      ),
      _anime(
        id: 97986,
        romaji: 'Made in Abyss',
        english: 'Made in Abyss',
        year: 2017,
        score: 84,
        episodes: 13,
        genres: const ['Adventure', 'Drama', 'Fantasy', 'Mystery'],
        now: now,
      ),
    ];
  }

  static List<MangaCacheEntry> mangaSeed(DateTime now) {
    return <MangaCacheEntry>[
      _manga(
        id: 30002,
        romaji: 'Berserk',
        english: 'Berserk',
        year: 1989,
        score: 94,
        chapters: 374,
        genres: const ['Action', 'Adventure', 'Drama', 'Fantasy', 'Horror'],
        now: now,
      ),
      _manga(
        id: 30013,
        romaji: 'One Piece',
        english: 'One Piece',
        year: 1997,
        score: 92,
        chapters: 1100,
        genres: const ['Action', 'Adventure', 'Comedy', 'Fantasy'],
        now: now,
      ),
      _manga(
        id: 30049,
        romaji: 'Vagabond',
        english: 'Vagabond',
        year: 1998,
        score: 91,
        chapters: 327,
        volumes: 37,
        genres: const ['Action', 'Adventure', 'Drama', 'Historical'],
        now: now,
      ),
      _manga(
        id: 30642,
        romaji: 'Vinland Saga',
        english: 'Vinland Saga',
        year: 2005,
        score: 91,
        chapters: 200,
        genres: const ['Action', 'Adventure', 'Drama', 'Historical'],
        now: now,
      ),
      _manga(
        id: 30607,
        romaji: 'Monster',
        english: 'Monster',
        year: 1994,
        score: 91,
        chapters: 162,
        volumes: 18,
        status: 'FINISHED',
        genres: const ['Drama', 'Mystery', 'Psychological', 'Thriller'],
        now: now,
      ),
      _manga(
        id: 30649,
        romaji: '20th Century Boys',
        english: '20th Century Boys',
        year: 1999,
        score: 91,
        chapters: 249,
        volumes: 22,
        status: 'FINISHED',
        genres: const ['Drama', 'Mystery', 'Sci-Fi', 'Thriller'],
        now: now,
      ),
      _manga(
        id: 30019,
        romaji: 'Slam Dunk',
        english: 'Slam Dunk',
        year: 1990,
        score: 90,
        chapters: 276,
        volumes: 31,
        status: 'FINISHED',
        genres: const ['Comedy', 'Drama', 'Sports'],
        now: now,
      ),
      _manga(
        id: 30327,
        romaji: 'Steel Ball Run',
        english: 'JoJo\'s Bizarre Adventure Part 7: Steel Ball Run',
        year: 2004,
        score: 92,
        chapters: 96,
        volumes: 24,
        status: 'FINISHED',
        genres: const ['Action', 'Adventure', 'Mystery', 'Supernatural'],
        now: now,
      ),
    ];
  }

  static AnilistCacheEntry _anime({
    required int id,
    required String romaji,
    required String english,
    required int year,
    required int score,
    int? episodes,
    required List<String> genres,
    required DateTime now,
  }) {
    return AnilistCacheEntry(
      anilistId: id,
      titleRomaji: romaji,
      titleEnglish: english,
      status: 'FINISHED',
      format: 'TV',
      releaseYear: year,
      averageScore: score,
      totalEpisodes: episodes,
      genres: genres,
      synopsis: 'Dev seed entry — full synopsis loads when AniList recovers.',
      updatedAt: now,
    );
  }

  static MangaCacheEntry _manga({
    required int id,
    required String romaji,
    required String english,
    required int year,
    required int score,
    int? chapters,
    int? volumes,
    String status = 'RELEASING',
    required List<String> genres,
    required DateTime now,
  }) {
    return MangaCacheEntry(
      anilistId: id,
      titleRomaji: romaji,
      titleEnglish: english,
      status: status,
      format: 'MANGA',
      countryOfOrigin: 'JP',
      releaseYear: year,
      totalChapters: chapters,
      totalVolumes: volumes,
      averageScore: score,
      genres: genres,
      synopsis: 'Dev seed entry — full synopsis loads when AniList recovers.',
      updatedAt: now,
    );
  }
}
