import 'package:flutter/foundation.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

enum FallbackReason { none, offline, anilistDown }

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

  /// Indicates why the most recent catalog fetch fell back to locally-cached
  /// data, or [FallbackReason.none] when operating normally.
  final ValueNotifier<FallbackReason> fallbackReason = ValueNotifier(
    FallbackReason.none,
  );

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchHomeCatalog({
    int page = 1,
    int perPage = 20,
  }) async {
    final result = await _delegate.fetchHomeCatalog(
      page: page,
      perPage: perPage,
    );
    if (result.isSuccess) {
      fallbackReason.value = FallbackReason.none;
      await _persistAnimeList(result);
      return result;
    }
    return _fallbackFromCache(
      result,
      () => _cacheStore.getRecent(limit: perPage, offset: (page - 1) * perPage),
    );
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchSeasonCatalog(
    SeasonalCatalogRequest request,
  ) async {
    final result = await _delegate.fetchSeasonCatalog(request);
    if (result.isSuccess) {
      fallbackReason.value = FallbackReason.none;
      await _persistAnimeList(result);
      return result;
    }
    return _fallbackFromCache(
      result,
      () => _cacheStore.getByYearAndStatus(
        request.year,
        status: 'RELEASING',
        limit: request.perPage,
        offset: (request.page - 1) * request.perPage,
      ),
    );
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchUpcomingSeasonCatalog(
    SeasonalCatalogRequest request,
  ) async {
    final result = await _delegate.fetchUpcomingSeasonCatalog(request);
    if (result.isSuccess) {
      fallbackReason.value = FallbackReason.none;
      await _persistAnimeList(result);
      return result;
    }
    return _fallbackFromCache(
      result,
      () => _cacheStore.getByStatus(
        'NOT_YET_RELEASED',
        limit: request.perPage,
        offset: (request.page - 1) * request.perPage,
      ),
    );
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchSeasonRecommendations(
    SeasonalCatalogRequest request,
  ) async {
    final result = await _delegate.fetchSeasonRecommendations(request);
    if (result.isSuccess) {
      fallbackReason.value = FallbackReason.none;
      await _persistAnimeList(result);
      return result;
    }
    return _fallbackFromCache(
      result,
      () => _cacheStore.getByYearAndStatus(
        request.year,
        limit: request.perPage,
        offset: (request.page - 1) * request.perPage,
      ),
    );
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
    if (result.isSuccess) {
      fallbackReason.value = FallbackReason.none;
      await _persistAnimeList(result);
      return result;
    }
    return _fallbackFromCache(
      result,
      () => _cacheStore.getByStatus(
        'RELEASING',
        limit: perPage,
        offset: (page - 1) * perPage,
      ),
    );
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
    if (result.isSuccess) {
      fallbackReason.value = FallbackReason.none;
      await _persistAnimeList(result);
      return result;
    }
    return _fallbackFromCache(
      result,
      () => _cacheStore.getByStatus(
        'RELEASING',
        limit: perPage,
        offset: (page - 1) * perPage,
      ),
    );
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> searchAnime(
    AnimeSearchRequest request,
  ) async {
    final result = await _delegate.searchAnime(request);
    if (result.isSuccess) {
      fallbackReason.value = FallbackReason.none;
      await _persistAnimeList(result);
      return result;
    }
    return _fallbackFromCache(
      result,
      () => _cacheStore.searchByTitle(
        request.query,
        limit: request.perPage,
        offset: (request.page - 1) * request.perPage,
      ),
    );
  }

  @override
  Future<Result<AnimeDetail, KumoriyaError>> fetchAnimeDetail(
    int anilistId,
  ) async {
    // Smart freshness: serve from cache if we have complete, fresh data.
    final freshDetail = await _tryServeFreshDetail(anilistId);
    if (freshDetail != null) {
      fallbackReason.value = FallbackReason.none;
      return Success(freshDetail);
    }

    final result = await _delegate.fetchAnimeDetail(anilistId);

    if (result.isSuccess) {
      fallbackReason.value = FallbackReason.none;
      final detail = (result as Success<AnimeDetail, KumoriyaError>).value;
      await _persistAnimeDetail(detail);
      if (detail.episodes.isNotEmpty) {
        await _episodeCacheStore.upsertAll(anilistId, detail.episodes);
      }
      return result;
    }

    final reason = _classifyTransportError(result);
    if (reason == null) return result;

    final cached = await _cacheStore.get(anilistId);
    return cached.fold(
      onFailure: (_) => result,
      onSuccess: (entry) async {
        if (entry == null) return result;

        fallbackReason.value = reason;

        final anime = _entryToAnime(entry);

        final cachedEpisodes = await _episodeCacheStore.getAll(anilistId);
        final episodes = cachedEpisodes.fold(
          onFailure: (_) => <AnimeEpisode>[],
          onSuccess: (list) => list,
        );

        return Success(AnimeDetail(anime: anime, episodes: episodes));
      },
    );
  }

  @override
  Future<Result<List<AnimeEpisode>, KumoriyaError>> fetchAnimeEpisodes(
    int anilistId,
  ) async {
    final result = await _delegate.fetchAnimeEpisodes(anilistId);

    if (result.isSuccess) {
      fallbackReason.value = FallbackReason.none;
      final episodes =
          (result as Success<List<AnimeEpisode>, KumoriyaError>).value;
      if (episodes.isNotEmpty) {
        await _episodeCacheStore.upsertAll(anilistId, episodes);
      }
      return result;
    }

    final reason = _classifyTransportError(result);
    if (reason == null) return result;

    final cached = await _episodeCacheStore.getAll(anilistId);
    return cached.fold(
      onFailure: (_) => result,
      onSuccess: (episodes) {
        if (episodes.isEmpty) return result;
        fallbackReason.value = reason;
        return Success(episodes);
      },
    );
  }

  @override
  Future<Result<SeasonDiscoveryResult, KumoriyaError>> fetchSeasonDiscovery(
    SeasonalCatalogRequest request,
  ) async {
    final result = await _delegate.fetchSeasonDiscovery(request);

    if (result.isSuccess) {
      fallbackReason.value = FallbackReason.none;
      final discovery =
          (result as Success<SeasonDiscoveryResult, KumoriyaError>).value;
      // Persist all anime from all three lists.
      await _persistAnimeList(Success(discovery.inSeason));
      await _persistAnimeList(Success(discovery.upcoming));
      await _persistAnimeList(Success(discovery.recommended));
      return result;
    }

    // For season discovery, fall back to individual cached queries.
    final reason = _classifyTransportError(result);
    if (reason == null) return result;

    final cachedCurrent = await _cacheStore.getByYearAndStatus(
      request.year,
      status: 'RELEASING',
      limit: request.perPage,
    );
    final currentAnime = cachedCurrent.fold(
      onSuccess: (entries) =>
          entries.map(_entryToAnime).toList(growable: false),
      onFailure: (_) => const <Anime>[],
    );

    if (currentAnime.isEmpty) {
      return result; // No useful cached data.
    }

    fallbackReason.value = reason;

    final cachedUpcoming = await _cacheStore.getByStatus(
      'NOT_YET_RELEASED',
      limit: request.perPage,
    );
    final upcomingAnime = cachedUpcoming.fold(
      onSuccess: (entries) =>
          entries.map(_entryToAnime).toList(growable: false),
      onFailure: (_) => const <Anime>[],
    );

    final cachedRecommended = await _cacheStore.getByYearAndStatus(
      request.year,
      limit: request.perPage,
    );
    final recommendedAnime = cachedRecommended.fold(
      onSuccess: (entries) =>
          entries.map(_entryToAnime).toList(growable: false),
      onFailure: (_) => const <Anime>[],
    );

    return Success(
      SeasonDiscoveryResult(
        inSeason: currentAnime,
        upcoming: upcomingAnime,
        recommended: recommendedAnime,
      ),
    );
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchBatchAnimeByIds(
    List<int> ids,
  ) async {
    final result = await _delegate.fetchBatchAnimeByIds(ids);
    if (result.isSuccess) {
      fallbackReason.value = FallbackReason.none;
      await _persistAnimeList(result);
      return result;
    }
    return _fallbackFromCache(result, () => _cacheStore.getByIds(ids));
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> browseAnime(
    AnimeBrowseRequest request,
  ) {
    return _delegate.browseAnime(request);
  }

  @override
  Future<Result<List<String>, KumoriyaError>> fetchGenreCollection() {
    return _delegate.fetchGenreCollection();
  }

  @override
  Future<Result<List<AnimeTag>, KumoriyaError>> fetchTagCollection() {
    return _delegate.fetchTagCollection();
  }

  // ---------------------------------------------------------------------------
  // Cache fallback helpers
  // ---------------------------------------------------------------------------

  /// Classifies a transport-level failure into [FallbackReason.offline] or
  /// [FallbackReason.anilistDown].  Returns `null` when the result is not a
  /// transport error.
  FallbackReason? _classifyTransportError(
    Result<dynamic, KumoriyaError> result,
  ) {
    if (result is! Failure<dynamic, KumoriyaError>) return null;
    if (result.error.kind != KumoriyaErrorKind.transport) return null;
    // anilist.service_unavailable → 403 / 5xx
    // anilist.rate_limit          → 429
    // anilist.transport            → SocketException / timeout (offline)
    return switch (result.error.code) {
      'anilist.service_unavailable' ||
      'anilist.rate_limit' => FallbackReason.anilistDown,
      _ => FallbackReason.offline,
    };
  }

  /// Returns a complete [AnimeDetail] from cache if the entry has synopsis
  /// and is within its freshness TTL.  Returns `null` when a network fetch
  /// is needed.
  Future<AnimeDetail?> _tryServeFreshDetail(int anilistId) async {
    final cached = await _cacheStore.get(anilistId);
    final entry = cached.fold<AnilistCacheEntry?>(
      onSuccess: (e) => e,
      onFailure: (_) => null,
    );

    // Require synopsis to consider the entry "complete" (detail-level data).
    if (entry == null || entry.synopsis == null) return null;

    final age = DateTime.now().difference(entry.updatedAt);
    if (age > _freshnessTtl(entry.status)) return null;

    // If the show should have episodes, verify episode cache is populated.
    final cachedEpisodes = await _episodeCacheStore.getAll(anilistId);
    final episodes = cachedEpisodes.fold<List<AnimeEpisode>>(
      onSuccess: (list) => list,
      onFailure: (_) => <AnimeEpisode>[],
    );

    final expectsEpisodes =
        entry.totalEpisodes != null && entry.totalEpisodes! > 0;
    if (expectsEpisodes && episodes.isEmpty) return null;

    return AnimeDetail(anime: _entryToAnime(entry), episodes: episodes);
  }

  /// Returns the maximum cache age before a re-fetch is needed, based on
  /// the anime's airing status.
  ///
  /// Rationale:
  /// - RELEASING: airing schedule changes at most once per week; 4 h gives
  ///   reasonably fresh "next episode" data without hammering the API.
  /// - NOT_YET_RELEASED: premiere details stabilise days before release; 6 h
  ///   is safe for the preview period.
  /// - FINISHED / CANCELLED: synopsis, genres, and relations are effectively
  ///   immutable once the run is over; 24 h catches any AniList corrections.
  /// - HIATUS: show may return to RELEASING at any time, but core metadata
  ///   changes infrequently; 12 h balances freshness and API usage.
  /// - unknown/other: conservative fallback of 3 h.
  static Duration _freshnessTtl(String? status) {
    return switch (status) {
      'RELEASING' => const Duration(hours: 4),
      'NOT_YET_RELEASED' => const Duration(hours: 6),
      'FINISHED' || 'CANCELLED' => const Duration(hours: 24),
      'HIATUS' => const Duration(hours: 12),
      _ => const Duration(hours: 3),
    };
  }

  /// Generic list-level fallback: if [networkResult] failed due to a transport
  /// error, runs [cacheQuery] and converts cached entries to domain [Anime]
  /// objects.  Returns [networkResult] unchanged when:
  /// - the network call succeeded,
  /// - the error is not transport-related, or
  /// - the cache query yields no entries.
  Future<Result<List<Anime>, KumoriyaError>> _fallbackFromCache(
    Result<List<Anime>, KumoriyaError> networkResult,
    Future<Result<List<AnilistCacheEntry>, KumoriyaError>> Function()
    cacheQuery,
  ) async {
    final reason = _classifyTransportError(networkResult);
    if (reason == null) return networkResult;

    final cached = await cacheQuery();
    return cached.fold(
      onSuccess: (entries) {
        if (entries.isEmpty) return networkResult;
        fallbackReason.value = reason;
        return Success(entries.map(_entryToAnime).toList(growable: false));
      },
      onFailure: (_) => networkResult,
    );
  }

  Anime _entryToAnime(AnilistCacheEntry entry) {
    return Anime(
      anilistId: entry.anilistId,
      title: AnimeTitle(
        romaji: entry.titleRomaji,
        english: entry.titleEnglish,
        native: entry.titleNative,
        synonyms: entry.synonyms ?? const <String>[],
      ),
      format: _toFormat(entry.format),
      releaseYear: entry.releaseYear,
      coverImageUrl: entry.coverImageUrl,
      bannerImageUrl: entry.bannerImageUrl,
      totalEpisodes: entry.totalEpisodes,
      nextAiringEpisodeNumber: entry.nextAiringEpisode,
      nextAiringAt: entry.nextAiringAt,
      averageScore: entry.averageScore,
      popularity: entry.popularity,
      season: entry.season,
      synopsis: entry.synopsis,
      genres: entry.genres ?? const <String>[],
      status: _toStatus(entry.status),
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
          synonyms: anime.title.synonyms.isNotEmpty
              ? anime.title.synonyms
              : null,
          coverImageUrl: anime.coverImageUrl,
          bannerImageUrl: anime.bannerImageUrl,
          status: _statusCode(anime.status),
          season: anime.season,
          averageScore: anime.averageScore,
          popularity: anime.popularity,
          genres: anime.genres.isNotEmpty ? anime.genres : null,
          synopsis: anime.synopsis,
          format: _formatCode(anime.format),
          releaseYear: anime.releaseYear,
          totalEpisodes: anime.totalEpisodes,
          nextAiringEpisode: anime.nextAiringEpisodeNumber,
          nextAiringAt: anime.nextAiringAt,
          updatedAt: updatedAt,
        ),
      );
    }
  }

  Future<void> _persistAnimeDetail(AnimeDetail detail) {
    final anime = detail.anime;
    return _cacheStore
        .upsert(
          AnilistCacheEntry(
            anilistId: anime.anilistId,
            titleRomaji: anime.title.romaji,
            titleEnglish: anime.title.english,
            titleNative: anime.title.native,
            synonyms: anime.title.synonyms.isNotEmpty
                ? anime.title.synonyms
                : null,
            coverImageUrl: anime.coverImageUrl,
            bannerImageUrl: anime.bannerImageUrl,
            status: _statusCode(anime.status),
            season: anime.season,
            averageScore: anime.averageScore,
            popularity: anime.popularity,
            genres: anime.genres.isNotEmpty ? anime.genres : null,
            synopsis: anime.synopsis,
            format: _formatCode(anime.format),
            releaseYear: anime.releaseYear,
            totalEpisodes: anime.totalEpisodes,
            nextAiringEpisode: anime.nextAiringEpisodeNumber,
            nextAiringAt: anime.nextAiringAt,
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
