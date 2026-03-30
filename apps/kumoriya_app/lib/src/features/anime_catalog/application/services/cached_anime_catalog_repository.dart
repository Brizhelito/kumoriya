import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

final class CachedAnimeCatalogRepository implements AnimeCatalogRepository {
  CachedAnimeCatalogRepository({
    required AnimeCatalogRepository delegate,
    required AnilistCacheStore cacheStore,
    required EpisodeCacheStore episodeCacheStore,
  }) : _delegate = delegate,
       _cacheStore = cacheStore,
       _episodeCacheStore = episodeCacheStore;

  final AnimeCatalogRepository _delegate;
  final AnilistCacheStore _cacheStore;
  final EpisodeCacheStore _episodeCacheStore;

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchHomeCatalog({
    int page = 1,
    int perPage = 20,
  }) async {
    final result = await _delegate.fetchHomeCatalog(
      page: page,
      perPage: perPage,
    );
    await _persistAnimeList(result);
    return result;
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchSeasonCatalog(
    SeasonalCatalogRequest request,
  ) async {
    final result = await _delegate.fetchSeasonCatalog(request);
    await _persistAnimeList(result);
    return result;
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchUpcomingSeasonCatalog(
    SeasonalCatalogRequest request,
  ) async {
    final result = await _delegate.fetchUpcomingSeasonCatalog(request);
    await _persistAnimeList(result);
    return result;
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchSeasonRecommendations(
    SeasonalCatalogRequest request,
  ) async {
    final result = await _delegate.fetchSeasonRecommendations(request);
    await _persistAnimeList(result);
    return result;
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchAiringCalendar({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) async {
    final result = await _delegate.fetchAiringCalendar(
      from: from,
      to: to,
      page: page,
      perPage: perPage,
    );
    await _persistAnimeList(result);
    return result;
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchAiringCalendarSlots({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) async {
    final result = await _delegate.fetchAiringCalendarSlots(
      from: from,
      to: to,
      page: page,
      perPage: perPage,
    );
    await _persistAnimeList(result);
    return result;
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> searchAnime(
    AnimeSearchRequest request,
  ) async {
    final result = await _delegate.searchAnime(request);
    await _persistAnimeList(result);
    return result;
  }

  @override
  Future<Result<AnimeDetail, KumoriyaError>> fetchAnimeDetail(
    int anilistId,
  ) async {
    final result = await _delegate.fetchAnimeDetail(anilistId);

    if (result.isSuccess) {
      final detail = (result as Success<AnimeDetail, KumoriyaError>).value;
      await _persistAnimeDetail(detail);
      if (detail.episodes.isNotEmpty) {
        await _episodeCacheStore.upsertAll(anilistId, detail.episodes);
      }
      return result;
    }

    final cached = await _cacheStore.get(anilistId);
    return cached.fold(
      onFailure: (_) => result,
      onSuccess: (entry) async {
        if (entry == null) {
          return result;
        }

        final anime = Anime(
          anilistId: entry.anilistId,
          title: AnimeTitle(
            romaji: entry.titleRomaji,
            english: entry.titleEnglish,
            native: entry.titleNative,
          ),
          format: _toFormat(entry.format),
          releaseYear: entry.releaseYear,
          coverImageUrl: entry.coverImageUrl,
          totalEpisodes: entry.totalEpisodes,
          averageScore: entry.averageScore,
          status: _toStatus(entry.status),
        );

        final cachedEpisodes = await _episodeCacheStore.getAll(anilistId);
        final episodes = cachedEpisodes.fold(
          onFailure: (_) => <AnimeEpisode>[],
          onSuccess: (list) => list,
        );

        return Success(
          AnimeDetail(
            anime: anime,
            synopsis: entry.synopsis,
            genres: entry.genres ?? const <String>[],
            bannerImageUrl: entry.bannerImageUrl,
            episodes: episodes,
          ),
        );
      },
    );
  }

  @override
  Future<Result<List<AnimeEpisode>, KumoriyaError>> fetchAnimeEpisodes(
    int anilistId,
  ) async {
    final result = await _delegate.fetchAnimeEpisodes(anilistId);

    if (result.isSuccess) {
      final episodes =
          (result as Success<List<AnimeEpisode>, KumoriyaError>).value;
      if (episodes.isNotEmpty) {
        await _episodeCacheStore.upsertAll(anilistId, episodes);
      }
      return result;
    }

    return _episodeCacheStore
        .getAll(anilistId)
        .then(
          (cached) => cached.fold(
            onFailure: (_) => result,
            onSuccess: (episodes) => Success(episodes),
          ),
        );
  }

  Future<void> _persistAnimeList(
    Result<List<Anime>, KumoriyaError> result,
  ) async {
    if (result is! Success<List<Anime>, KumoriyaError>) {
      return;
    }

    final updatedAt = DateTime.now();
    for (final anime in result.value) {
      await _cacheStore.upsert(
        AnilistCacheEntry(
          anilistId: anime.anilistId,
          titleRomaji: anime.title.romaji,
          titleEnglish: anime.title.english,
          titleNative: anime.title.native,
          coverImageUrl: anime.coverImageUrl,
          status: _statusCode(anime.status),
          averageScore: anime.averageScore,
          format: _formatCode(anime.format),
          releaseYear: anime.releaseYear,
          totalEpisodes: anime.totalEpisodes,
          updatedAt: updatedAt,
        ),
      );
    }
  }

  Future<void> _persistAnimeDetail(AnimeDetail detail) {
    return _cacheStore
        .upsert(
          AnilistCacheEntry(
            anilistId: detail.anime.anilistId,
            titleRomaji: detail.anime.title.romaji,
            titleEnglish: detail.anime.title.english,
            titleNative: detail.anime.title.native,
            coverImageUrl: detail.anime.coverImageUrl,
            bannerImageUrl: detail.bannerImageUrl,
            status: _statusCode(detail.anime.status),
            averageScore: detail.anime.averageScore,
            genres: detail.genres,
            synopsis: detail.synopsis,
            format: _formatCode(detail.anime.format),
            releaseYear: detail.anime.releaseYear,
            totalEpisodes: detail.anime.totalEpisodes,
            updatedAt: DateTime.now(),
          ),
        )
        .then((_) {});
  }

  String _formatCode(AnimeFormat format) {
    return switch (format) {
      AnimeFormat.tv => 'TV',
      AnimeFormat.movie => 'MOVIE',
      AnimeFormat.ova => 'OVA',
      AnimeFormat.ona => 'ONA',
      AnimeFormat.special => 'SPECIAL',
      AnimeFormat.unknown => 'UNKNOWN',
    };
  }

  AnimeFormat _toFormat(String? format) {
    return switch (format) {
      'TV' => AnimeFormat.tv,
      'MOVIE' => AnimeFormat.movie,
      'OVA' => AnimeFormat.ova,
      'ONA' => AnimeFormat.ona,
      'SPECIAL' => AnimeFormat.special,
      _ => AnimeFormat.unknown,
    };
  }

  String _statusCode(AnimeStatus status) {
    return switch (status) {
      AnimeStatus.finished => 'FINISHED',
      AnimeStatus.releasing => 'RELEASING',
      AnimeStatus.notYetReleased => 'NOT_YET_RELEASED',
      AnimeStatus.cancelled => 'CANCELLED',
      AnimeStatus.hiatus => 'HIATUS',
      AnimeStatus.unknown => 'UNKNOWN',
    };
  }

  AnimeStatus _toStatus(String? status) {
    return switch (status) {
      'FINISHED' => AnimeStatus.finished,
      'RELEASING' => AnimeStatus.releasing,
      'NOT_YET_RELEASED' => AnimeStatus.notYetReleased,
      'CANCELLED' => AnimeStatus.cancelled,
      'HIATUS' => AnimeStatus.hiatus,
      _ => AnimeStatus.unknown,
    };
  }
}
