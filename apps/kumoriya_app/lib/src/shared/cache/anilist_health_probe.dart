import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

/// Thin HTTP client for the Kumoriya Go backend's
/// `GET /v1/anilist/health` probe.
///
/// The endpoint is unauthenticated, idempotent, and computes its
/// answer entirely from the in-process SWR cache (no fan-out to AniList
/// itself), so probing it cheaply is the intended use.
///
/// On any failure (timeout, non-2xx, malformed JSON) we return `false`.
/// We treat "we don't know" the same as "still degraded" — the caller
/// will keep polling, and the user keeps seeing the offline banner
/// rather than a flicker of premature recovery.
final class AnilistHealthProbe {
  AnilistHealthProbe({
    required String baseUrl,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 3),
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _http = httpClient ?? http.Client(),
       _timeout = timeout;

  final String _baseUrl;
  final http.Client _http;
  final Duration _timeout;

  /// Closes the underlying HTTP client if owned.
  void close() => _http.close();

  /// Returns `true` when the backend reports AniList is reachable
  /// (`anilist_reachable: true`). Any failure path returns `false`.
  Future<bool> isAnilistReachable() async {
    final uri = Uri.parse('$_baseUrl/v1/anilist/health');
    try {
      final resp = await _http.get(uri).timeout(_timeout);
      if (resp.statusCode != 200) {
        return false;
      }
      final body = json.decode(resp.body);
      if (body is! Map<String, dynamic>) return false;
      final reachable = body['anilist_reachable'];
      return reachable is bool && reachable;
    } catch (e, st) {
      developer.log(
        'AnilistHealthProbe failed: $e',
        name: 'AnilistHealthProbe',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }
}
