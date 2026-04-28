import 'package:kumoriya_core/kumoriya_core.dart';

import '../manga/manga.dart';
import '../manga/manga_browse_request.dart';
import '../manga/manga_chapter.dart';
import '../manga/manga_detail.dart';
import '../manga/manga_home_sections.dart';
import '../manga/manga_tag.dart';

final class MangaSearchRequest {
  const MangaSearchRequest({
    required this.query,
    this.page = 1,
    this.perPage = 20,
  });

  final String query;
  final int page;
  final int perPage;
}

/// Use-case-facing repository for the manga catalog. The implementation
/// composes AniList (canonical metadata), `kumoriya_matching` (canonical
/// series identity), and a `MangaSourcePlugin` (chapter list). Callers
/// in the UI layer must depend on this contract, never on concrete
/// gateways or plugins.
abstract interface class MangaCatalogRepository {
  /// Trending + popular mix for the manga Home tab.
  Future<Result<List<Manga>, KumoriyaError>> fetchHomeCatalog({
    int page = 1,
    int perPage = 20,
  });

  /// Aggregate manga Home: four shelves (trending / popular / latest /
  /// top-rated) in a single call. Backed by an aliased AniList query
  /// served from the Kumoriya Go backend cache when available, with
  /// fallback to direct AniList.
  Future<Result<MangaHomeSections, KumoriyaError>> fetchHomeSections({
    int page = 1,
    int perPage = 20,
  });

  /// Free-text search against AniList.
  Future<Result<List<Manga>, KumoriyaError>> searchManga(
    MangaSearchRequest request,
  );

  /// Advanced browse with filters (genre/tag/format/status/country/sort).
  Future<Result<List<Manga>, KumoriyaError>> browseManga(
    MangaBrowseRequest request,
  );

  /// Catalog metadata for a single manga.
  Future<Result<MangaDetail, KumoriyaError>> fetchMangaDetail(int anilistId);

  /// Chapter list for a manga. Implementation typically delegates to a
  /// `MangaSourcePlugin` because AniList does not expose chapter lists.
  Future<Result<List<MangaChapter>, KumoriyaError>> fetchMangaChapters(
    int anilistId,
  );

  /// Bulk fetch for warming caches / reconciling the user library.
  Future<Result<List<Manga>, KumoriyaError>> fetchBatchMangaByIds(
    List<int> ids,
  );

  /// All AniList genres applicable to manga.
  Future<Result<List<String>, KumoriyaError>> fetchGenreCollection();

  /// All AniList tags applicable to manga.
  Future<Result<List<MangaTag>, KumoriyaError>> fetchTagCollection();
}
