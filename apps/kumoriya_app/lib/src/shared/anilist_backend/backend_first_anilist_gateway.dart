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
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> fetchAiringCalendar({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) => _inner.fetchAiringCalendar(
    from: from,
    to: to,
    page: page,
    perPage: perPage,
  );

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchAiringCalendarSlots({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) => _inner.fetchAiringCalendarSlots(
    from: from,
    to: to,
    page: page,
    perPage: perPage,
  );

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
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> fetchBatchAnimeByIds(
    List<int> ids, {
    int page = 1,
    int perPage = 50,
  }) => _inner.fetchBatchAnimeByIds(ids, page: page, perPage: perPage);

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
  static Map<String, List<Map<String, dynamic>>>? _extractSeasonDiscoverySections(
    Map<String, dynamic> data,
  ) {
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
}
