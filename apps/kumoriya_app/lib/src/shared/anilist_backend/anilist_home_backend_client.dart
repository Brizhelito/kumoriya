import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_anilist/kumoriya_anilist.dart';

/// Thin HTTP client for the public AniList-home cache endpoints served
/// by the Kumoriya Go backend (`/v1/anilist/home/*`).
///
/// These endpoints are **unauthenticated** — the payloads are public
/// AniList data identical for every user, so no JWT is attached.
///
/// Each method returns the raw `data` JSON object exactly as AniList
/// returned it to the server. Keys are preserved (`Page`, `current`,
/// `upcoming`, `recommended`, `carryover`, …) so the existing Dart
/// mappers work unchanged.
///
/// On any non-2xx response, non-JSON body, malformed shape, or network
/// error, the client returns a [Failure] with an [AnilistError] so the
/// decorator can decide whether to fall back to direct AniList.
final class AnilistHomeBackendClient {
  AnilistHomeBackendClient({
    required String baseUrl,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 4),
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _http = httpClient ?? http.Client(),
       _timeout = timeout;

  final String _baseUrl;
  final http.Client _http;
  final Duration _timeout;

  /// Closes the underlying HTTP client if it was created internally.
  void close() => _http.close();

  /// `GET /v1/anilist/home/trending?page=&perPage=`.
  Future<Result<Map<String, dynamic>, KumoriyaError>> fetchTrending({
    int page = 1,
    int perPage = 20,
  }) {
    return _get('/v1/anilist/home/trending', {
      'page': '$page',
      'perPage': '$perPage',
    });
  }

  /// `GET /v1/anilist/home/season-discovery?page=&perPage=&includeCarryover=`.
  Future<Result<Map<String, dynamic>, KumoriyaError>> fetchSeasonDiscovery({
    int page = 1,
    int perPage = 30,
    bool includeCarryover = true,
  }) {
    return _get('/v1/anilist/home/season-discovery', {
      'page': '$page',
      'perPage': '$perPage',
      'includeCarryover': includeCarryover ? 'true' : 'false',
    });
  }

  /// `GET /v1/anilist/home/manga?page=&perPage=`.
  ///
  /// Returns the aliased manga payload with `trending` / `popular` /
  /// `latest` / `topRated` keys, each carrying a `Page.media` list.
  Future<Result<Map<String, dynamic>, KumoriyaError>> fetchMangaHome({
    int page = 1,
    int perPage = 20,
  }) {
    return _get('/v1/anilist/home/manga', {
      'page': '$page',
      'perPage': '$perPage',
    });
  }

  /// `GET /v1/anilist/home/airing-calendar?airingAtGreater=&airingAtLesser=&page=&perPage=`.
  ///
  /// Uses the explicit-window form of the backend endpoint so that
  /// pagination-loop callers always reach the same cache entry regardless
  /// of clock drift between requests.
  Future<Result<Map<String, dynamic>, KumoriyaError>> fetchAiringCalendar({
    required int airingAtGreater,
    required int airingAtLesser,
    int page = 1,
    int perPage = 50,
  }) {
    return _get('/v1/anilist/home/airing-calendar', {
      'airingAtGreater': '$airingAtGreater',
      'airingAtLesser': '$airingAtLesser',
      'page': '$page',
      'perPage': '$perPage',
    });
  }

  Future<Result<Map<String, dynamic>, KumoriyaError>> _get(
    String path,
    Map<String, String> query,
  ) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    http.Response response;
    try {
      response = await _http.get(uri).timeout(_timeout);
    } on TimeoutException catch (e) {
      return Failure(
        AnilistTransportError(message: 'Kumoriya AniList backend timeout: $e'),
      );
    } catch (e) {
      return Failure(
        AnilistTransportError(message: 'Kumoriya AniList backend error: $e'),
      );
    }

    final status = response.statusCode;
    if (status < 200 || status >= 300) {
      return Failure(
        AnilistServiceUnavailableError(
          message: 'Kumoriya AniList backend returned $status',
          statusCode: status,
        ),
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (e) {
      return Failure(
        AnilistMappingError(
          message: 'Kumoriya AniList backend returned non-JSON body: $e',
        ),
      );
    }

    if (decoded is! Map<String, dynamic>) {
      return const Failure(
        AnilistMappingError(
          message: 'Kumoriya AniList backend payload is not a JSON object.',
        ),
      );
    }
    return Success(decoded);
  }
}
