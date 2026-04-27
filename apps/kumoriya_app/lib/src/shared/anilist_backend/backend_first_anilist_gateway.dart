import 'dart:developer' as developer;

import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import 'anilist_home_backend_client.dart';

/// Decorator around [AnilistMetadataGateway] that routes the AniList
/// Home surfaces (`fetchHomeCatalog`, `fetchSeasonDiscovery`) through
/// the Kumoriya Go backend cache. All other calls pass through to the
/// wrapped gateway unchanged.
///
/// Fallback: on any failure from the backend client (transport,
/// service-unavailable, mapping), the decorator transparently calls
/// the inner gateway so the user never sees an error caused by the
/// Kumoriya backend being down — they just silently hit AniList.
///
/// Caching: the backend already caches with stale-while-revalidate,
/// so this decorator adds zero additional caching on the client side.
final class BackendFirstAnilistMetadataGateway
    implements AnilistMetadataGateway {
  BackendFirstAnilistMetadataGateway({
    required AnilistMetadataGateway inner,
    required AnilistHomeBackendClient backend,
  }) : _inner = inner,
       _backend = backend;

  final AnilistMetadataGateway _inner;
  final AnilistHomeBackendClient _backend;

  // ---------------------------------------------------------------------------
  // Backend-first surfaces
  // ---------------------------------------------------------------------------

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> fetchHomeCatalog({
    int page = 1,
    int perPage = 20,
  }) async {
    final result = await _backend.fetchTrending(page: page, perPage: perPage);
    return result.fold(
      onSuccess: (data) {
        final media = _extractPageMedia(data);
        if (media == null) {
          _log('trending', 'payload missing Page.media, falling back');
          return _inner.fetchHomeCatalog(page: page, perPage: perPage);
        }
        return Success(media);
      },
      onFailure: (err) {
        _log('trending', 'backend failure (${err.code}), falling back');
        return _inner.fetchHomeCatalog(page: page, perPage: perPage);
      },
    );
  }

  @override
  Future<Result<Map<String, List<Map<String, dynamic>>>, KumoriyaError>>
  fetchSeasonDiscovery(SeasonalCatalogRequest request) async {
    final result = await _backend.fetchSeasonDiscovery(
      page: request.page,
      perPage: request.perPage,
      includeCarryover: request.includeCarryovers,
    );
    return result.fold(
      onSuccess: (data) {
        final sections = _extractSeasonDiscoverySections(data);
        if (sections == null) {
          _log('season-discovery', 'payload missing current, falling back');
          return _inner.fetchSeasonDiscovery(request);
        }
        return Success(sections);
      },
      onFailure: (err) {
        _log('season-discovery', 'backend failure (${err.code}), falling back');
        return _inner.fetchSeasonDiscovery(request);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Pass-through surfaces (unchanged)
  // ---------------------------------------------------------------------------

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> fetchSeasonCatalog(
    SeasonalCatalogRequest request,
  ) => _inner.fetchSeasonCatalog(request);

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchUpcomingSeasonCatalog(SeasonalCatalogRequest request) =>
      _inner.fetchUpcomingSeasonCatalog(request);

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchSeasonRecommendations(SeasonalCatalogRequest request) =>
      _inner.fetchSeasonRecommendations(request);

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchAiringCalendar({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) {
    return _backendAiringLoop(
      from: from,
      to: to,
      page: page,
      perPage: perPage,
      dedupe: true,
      innerFallback: () => _inner.fetchAiringCalendar(
        from: from,
        to: to,
        page: page,
        perPage: perPage,
      ),
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchAiringCalendarSlots({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) {
    return _backendAiringLoop(
      from: from,
      to: to,
      page: page,
      perPage: perPage,
      dedupe: false,
      innerFallback: () => _inner.fetchAiringCalendarSlots(
        from: from,
        to: to,
        page: page,
        perPage: perPage,
      ),
    );
  }

  /// Paginates the backend airing-calendar endpoint with the same window
  /// logic as the direct AniList gateway, optionally deduplicating by
  /// anime id. On ANY per-page failure (transport, non-2xx, malformed
  /// payload), the whole call is delegated to [innerFallback] so the
  /// user sees the direct-AniList result rather than a partial / broken
  /// page.
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> _backendAiringLoop({
    required DateTime? from,
    required DateTime? to,
    required int page,
    required int perPage,
    required bool dedupe,
    required Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
    Function()
    innerFallback,
  }) async {
    final fromDate = (from ?? DateTime.now()).toUtc();
    final toDate = (to ?? fromDate.add(const Duration(days: 7))).toUtc();
    final greater = fromDate.millisecondsSinceEpoch ~/ 1000;
    final lesser = toDate.millisecondsSinceEpoch ~/ 1000;

    // Refuse invalid windows up front so we don't burn a backend round-trip
    // on a request that the inner gateway would also reject.
    if (lesser <= greater) {
      return innerFallback();
    }

    final deduped = <int, Map<String, dynamic>>{};
    final entries = <Map<String, dynamic>>[];
    var currentPage = page;
    var hasNextPage = true;

    while (hasNextPage) {
      final result = await _backend.fetchAiringCalendar(
        airingAtGreater: greater,
        airingAtLesser: lesser,
        page: currentPage,
        perPage: perPage,
      );

      final pageDataOrNull = result.fold<_AiringPage?>(
        onSuccess: (data) {
          if (dedupe) {
            final added = _mergeDedupedSchedules(data, into: deduped);
            if (!added) return null;
          } else {
            final ok = _appendScheduleEntries(data, into: entries);
            if (!ok) return null;
          }
          return _AiringPage(hasNext: _extractHasNextPage(data) ?? false);
        },
        onFailure: (_) => null,
      );

      if (pageDataOrNull == null) {
        _log('airing-calendar', 'backend page failure, falling back to inner');
        return innerFallback();
      }

      hasNextPage = pageDataOrNull.hasNext;
      currentPage += 1;
    }

    if (dedupe) {
      final merged = deduped.values.toList(growable: false)
        ..sort(
          (left, right) =>
              _nextAiringTimestamp(left).compareTo(_nextAiringTimestamp(right)),
        );
      return Success(merged);
    }
    return Success(entries);
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> searchAnime({
    required String query,
    int page = 1,
    int perPage = 20,
  }) => _inner.searchAnime(query: query, page: page, perPage: perPage);

  @override
  Future<Result<Map<String, dynamic>, KumoriyaError>> fetchAnimeDetail(
    int anilistId,
  ) => _inner.fetchAnimeDetail(anilistId);

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchBatchAnimeByIds(List<int> ids, {int page = 1, int perPage = 50}) =>
      _inner.fetchBatchAnimeByIds(ids, page: page, perPage: perPage);

  @override
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
  }) => _inner.browseAnime(
    search: search,
    genres: genres,
    tags: tags,
    formats: formats,
    season: season,
    seasonYear: seasonYear,
    statuses: statuses,
    sort: sort,
    page: page,
    perPage: perPage,
  );

  @override
  Future<Result<List<String>, KumoriyaError>> fetchGenreCollection() =>
      _inner.fetchGenreCollection();

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchTagCollection() => _inner.fetchTagCollection();

  // ---------------------------------------------------------------------------
  // Manga pass-through. The Kumoriya Go backend does not yet proxy any
  // manga-shaped surfaces; once it does, the relevant overrides should
  // route through `_backend` with the same fall-back-to-inner pattern as
  // `fetchHomeCatalog` / `fetchSeasonDiscovery` above.
  // ---------------------------------------------------------------------------

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchMangaHomeCatalog({int page = 1, int perPage = 20}) =>
      _inner.fetchMangaHomeCatalog(page: page, perPage: perPage);

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> searchManga({
    required String query,
    int page = 1,
    int perPage = 20,
  }) => _inner.searchManga(query: query, page: page, perPage: perPage);

  @override
  Future<Result<Map<String, dynamic>, KumoriyaError>> fetchMangaDetail(
    int anilistId,
  ) => _inner.fetchMangaDetail(anilistId);

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchBatchMangaByIds(List<int> ids, {int page = 1, int perPage = 50}) =>
      _inner.fetchBatchMangaByIds(ids, page: page, perPage: perPage);

  @override
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
  }) => _inner.browseManga(
    search: search,
    genres: genres,
    tags: tags,
    formats: formats,
    statuses: statuses,
    countryOfOrigin: countryOfOrigin,
    sort: sort,
    page: page,
    perPage: perPage,
  );

  // ---------------------------------------------------------------------------
  // Payload extraction helpers
  // ---------------------------------------------------------------------------

  /// Extracts `data.Page.media` as a list of JSON object maps.
  /// Returns null if the payload shape is not the expected AniList one.
  static List<Map<String, dynamic>>? _extractPageMedia(
    Map<String, dynamic> data,
  ) {
    final page = data['Page'];
    if (page is! Map<String, dynamic>) return null;
    final media = page['media'];
    if (media is! List) return null;
    return <Map<String, dynamic>>[
      for (final item in media)
        if (item is Map<String, dynamic>) item,
    ];
  }

  /// Extracts the aliased current/upcoming/recommended/carryover sections
  /// from a season-discovery combo payload. `current` is required —
  /// the other keys are optional and only included if present.
  static Map<String, List<Map<String, dynamic>>>?
  _extractSeasonDiscoverySections(Map<String, dynamic> data) {
    final sections = <String, List<Map<String, dynamic>>>{};
    for (final alias in const <String>[
      'current',
      'upcoming',
      'recommended',
      'carryover',
    ]) {
      final pageEntry = data[alias];
      if (pageEntry is! Map<String, dynamic>) continue;
      final media = pageEntry['media'];
      if (media is! List) continue;
      sections[alias] = <Map<String, dynamic>>[
        for (final item in media)
          if (item is Map<String, dynamic>) item,
      ];
    }
    if (!sections.containsKey('current')) return null;
    return sections;
  }

  void _log(String surface, String reason) {
    developer.log(
      '[anilist-backend/$surface] $reason',
      name: 'BackendFirstAnilistMetadataGateway',
    );
  }

  // ---------------------------------------------------------------------------
  // Airing-calendar payload extraction. Mirrors the logic in
  // GraphqlAnilistMetadataGateway so the backend-routed path returns the
  // same shape (anime media with injected nextAiringEpisode).
  // ---------------------------------------------------------------------------

  /// Reads `data.Page.airingSchedules`, keeps only the earliest entry per
  /// anime id, and writes into [into]. Returns false if the payload shape
  /// is invalid (caller should fall back).
  static bool _mergeDedupedSchedules(
    Map<String, dynamic> data, {
    required Map<int, Map<String, dynamic>> into,
  }) {
    final schedules = _extractSchedules(data);
    if (schedules == null) return false;

    for (final item in schedules) {
      final media = item['media'];
      final animeId = media is Map<String, dynamic> ? media['id'] : null;
      if (media is! Map<String, dynamic> || animeId is! int) continue;
      if (media['isAdult'] == true) continue;

      final enriched = Map<String, dynamic>.from(media);
      enriched['nextAiringEpisode'] = <String, dynamic>{
        'episode': item['episode'],
        'airingAt': item['airingAt'],
      };

      final existing = into[animeId];
      if (existing == null ||
          _nextAiringTimestamp(enriched) < _nextAiringTimestamp(existing)) {
        into[animeId] = enriched;
      }
    }
    return true;
  }

  /// Reads `data.Page.airingSchedules` and appends every entry to [into]
  /// without deduplicating by anime id (slots variant). Returns false if
  /// the payload shape is invalid.
  static bool _appendScheduleEntries(
    Map<String, dynamic> data, {
    required List<Map<String, dynamic>> into,
  }) {
    final schedules = _extractSchedules(data);
    if (schedules == null) return false;

    for (final item in schedules) {
      final media = item['media'];
      if (media is! Map<String, dynamic>) continue;
      final animeId = media['id'];
      if (animeId is! int) continue;
      if (media['isAdult'] == true) continue;

      final enriched = Map<String, dynamic>.from(media);
      enriched['nextAiringEpisode'] = <String, dynamic>{
        'episode': item['episode'],
        'airingAt': item['airingAt'],
      };
      into.add(enriched);
    }
    return true;
  }

  static List<dynamic>? _extractSchedules(Map<String, dynamic> data) {
    final page = data['Page'];
    if (page is! Map<String, dynamic>) return null;
    final schedules = page['airingSchedules'];
    if (schedules is! List) return null;
    return schedules;
  }

  static bool? _extractHasNextPage(Map<String, dynamic> data) {
    final page = data['Page'];
    if (page is! Map<String, dynamic>) return null;
    final pageInfo = page['pageInfo'];
    if (pageInfo is! Map<String, dynamic>) return null;
    final hasNext = pageInfo['hasNextPage'];
    return hasNext is bool ? hasNext : null;
  }

  static int _nextAiringTimestamp(Map<String, dynamic> media) {
    final next = media['nextAiringEpisode'];
    if (next is! Map<String, dynamic>) return 1 << 31;
    final airingAt = next['airingAt'];
    return airingAt is int ? airingAt : 1 << 31;
  }
}

class _AiringPage {
  const _AiringPage({required this.hasNext});
  final bool hasNext;
}
