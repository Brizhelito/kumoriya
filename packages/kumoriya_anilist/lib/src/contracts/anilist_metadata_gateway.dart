import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

abstract interface class AnilistMetadataGateway {
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> fetchHomeCatalog({
    int page = 1,
    int perPage = 20,
  });

  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> fetchSeasonCatalog(
    SeasonalCatalogRequest request,
  );

  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchUpcomingSeasonCatalog(SeasonalCatalogRequest request);

  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchSeasonRecommendations(SeasonalCatalogRequest request);

  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchAiringCalendar({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  });

  /// Like [fetchAiringCalendar] but returns every airing entry without
  /// deduplicating by anime ID. The same anime may appear multiple times
  /// (once per episode airing in the window).
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchAiringCalendarSlots({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  });

  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> searchAnime({
    required String query,
    int page = 1,
    int perPage = 20,
  });

  Future<Result<Map<String, dynamic>, KumoriyaError>> fetchAnimeDetail(
    int anilistId,
  );

  /// Fetches current-season, upcoming, recommended, and optionally carryover
  /// anime in a single HTTP request using the combo query.
  ///
  /// Returns a map with keys `current`, `upcoming`, `recommended`, and
  /// optionally `carryover`, each containing a list of raw media JSON maps.
  Future<Result<Map<String, List<Map<String, dynamic>>>, KumoriyaError>>
  fetchSeasonDiscovery(SeasonalCatalogRequest request);

  /// Fetches full catalog-level metadata for a batch of AniList IDs in a
  /// single request.
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchBatchAnimeByIds(List<int> ids, {int page = 1, int perPage = 50});

  /// Browses anime with advanced filters (genres, tags, format, sort, etc.).
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> browseAnime({
    String? search,
    List<String>? genres,
    List<String>? tags,
    List<String>? formats,
    String? season,
    int? seasonYear,
    List<String>? statuses,
    List<String>? sort,
    int page = 1,
    int perPage = 20,
  });

  /// Fetches all available genre names.
  Future<Result<List<String>, KumoriyaError>> fetchGenreCollection();

  /// Fetches all available media tags.
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchTagCollection();

  // ---------------------------------------------------------------------------
  // Manga
  // ---------------------------------------------------------------------------

  /// Trending + popular manga for the manga Home tab.
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchMangaHomeCatalog({int page = 1, int perPage = 20});

  /// Free-text search against the manga catalog.
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> searchManga({
    required String query,
    int page = 1,
    int perPage = 20,
  });

  /// Catalog-level metadata for a single manga (with relations).
  Future<Result<Map<String, dynamic>, KumoriyaError>> fetchMangaDetail(
    int anilistId,
  );

  /// Bulk fetch manga by AniList ids for cache warmup / library
  /// reconciliation.
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchBatchMangaByIds(List<int> ids, {int page = 1, int perPage = 50});

  /// Browse manga with advanced filters. `countryOfOrigin` accepts a
  /// single ISO 3166-1 alpha-2 code (e.g. `'JP'`, `'KR'`, `'CN'`, `'TW'`)
  /// because AniList's filter is single-valued; the application layer
  /// must merge multi-country requests itself.
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> browseManga({
    String? search,
    List<String>? genres,
    List<String>? tags,
    List<String>? formats,
    List<String>? statuses,
    String? countryOfOrigin,
    List<String>? sort,
    int page = 1,
    int perPage = 20,
  });
}
