import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';

import '../errors/mangaupdates_error.dart';

/// Low-level HTTP client for MangaUpdates. Exposes both `getJson` and
/// `postJson` because the v1 API mixes GET (detail endpoints) and
/// POST-with-body (search endpoints).
abstract interface class MangaUpdatesHttpClient {
  /// GETs a relative path under the configured base.
  Future<Result<Map<String, dynamic>, KumoriyaError>> getJson({
    required String path,
    Map<String, dynamic>? queryParameters,
  });

  /// POSTs a JSON body to a relative path. Used for search endpoints
  /// (`/v1/series/search`, `/v1/releases/search`).
  Future<Result<Map<String, dynamic>, KumoriyaError>> postJson({
    required String path,
    required Map<String, dynamic> body,
  });
}

/// Production implementation. Mirrors the MangaBaka client:
///
///  * minimum gap between requests
///  * `Retry-After` honoring on 429 (single retry by default)
///  * short-lived in-memory response cache keyed by request URI + body hash
///  * defensive JSON parsing with detailed error mapping
///
/// MangaUpdates returns **404 with an empty body**, so the client
/// must rely on the status code rather than a JSON envelope to
/// detect not-found.
final class HttpMangaUpdatesClient implements MangaUpdatesHttpClient {
  HttpMangaUpdatesClient({
    http.Client? httpClient,
    Uri? baseUri,
    String userAgent = _defaultUserAgent,
    Duration minRequestGap = const Duration(milliseconds: 250),
    Duration defaultRateLimitBackoff = const Duration(seconds: 4),
    Duration responseCacheTtl = const Duration(minutes: 5),
    int maxRateLimitRetries = 1,
    Duration requestTimeout = const Duration(seconds: 15),
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUri = baseUri ?? Uri.parse('https://api.mangaupdates.com/v1/'),
       _userAgent = userAgent,
       _minRequestGap = minRequestGap,
       _defaultRateLimitBackoff = defaultRateLimitBackoff,
       _responseCacheTtl = responseCacheTtl,
       _maxRateLimitRetries = maxRateLimitRetries,
       _requestTimeout = requestTimeout;

  static const String _defaultUserAgent =
      'Kumoriya/0.1 (+https://kumoriya.app) MangaUpdatesClient';

  final http.Client _httpClient;
  final Uri _baseUri;
  final String _userAgent;
  final Duration _minRequestGap;
  final Duration _defaultRateLimitBackoff;
  final Duration _responseCacheTtl;
  final int _maxRateLimitRetries;
  final Duration _requestTimeout;

  Future<void> _serialQueue = Future<void>.value();
  DateTime? _lastRequestStartedAt;
  final Map<String, _CachedResponse> _cache = <String, _CachedResponse>{};

  @override
  Future<Result<Map<String, dynamic>, KumoriyaError>> getJson({
    required String path,
    Map<String, dynamic>? queryParameters,
  }) {
    final uri = _resolveUri(path, queryParameters);
    return _runSerial(() => _execute(_Request.get(uri: uri)));
  }

  @override
  Future<Result<Map<String, dynamic>, KumoriyaError>> postJson({
    required String path,
    required Map<String, dynamic> body,
  }) {
    final uri = _resolveUri(path, null);
    return _runSerial(() => _execute(_Request.post(uri: uri, body: body)));
  }

  Future<Result<Map<String, dynamic>, KumoriyaError>> _execute(
    _Request request,
  ) async {
    final cacheKey = request.cacheKey;
    final cached = _freshCached(cacheKey);
    if (cached != null) {
      return Success(cached);
    }

    var attempt = 0;
    while (true) {
      try {
        await _waitForRequestWindow();

        final response = await _send(request).timeout(_requestTimeout);

        if (response.statusCode == 429) {
          final retryAfter = _parseRetryAfter(response.headers['retry-after']);
          if (attempt < _maxRateLimitRetries) {
            attempt += 1;
            await Future<void>.delayed(retryAfter);
            continue;
          }
          return Failure(
            MangaUpdatesRateLimitError(
              message:
                  'MangaUpdates rate limit reached. Retry after ${retryAfter.inSeconds}s.',
              retryAfter: retryAfter,
            ),
          );
        }

        if (response.statusCode == 404) {
          return const Failure(
            MangaUpdatesNotFoundError(message: 'Not found.'),
          );
        }

        if (response.statusCode >= 500) {
          return Failure(
            MangaUpdatesServiceUnavailableError(
              message:
                  _extractServerMessage(response.bodyBytes) ??
                  'MangaUpdates returned status ${response.statusCode}',
              statusCode: response.statusCode,
            ),
          );
        }

        if (response.statusCode != 200) {
          return Failure(
            MangaUpdatesTransportError(
              message:
                  _extractServerMessage(response.bodyBytes) ??
                  'MangaUpdates returned status ${response.statusCode}',
              statusCode: response.statusCode,
            ),
          );
        }

        if (response.bodyBytes.isEmpty) {
          return const Failure(
            MangaUpdatesMappingError(
              message: 'MangaUpdates response body is empty.',
            ),
          );
        }

        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! Map<String, dynamic>) {
          return const Failure(
            MangaUpdatesMappingError(
              message: 'MangaUpdates response is not a JSON object.',
            ),
          );
        }

        _cache[cacheKey] = _CachedResponse(
          storedAt: DateTime.now(),
          data: decoded,
        );
        return Success(decoded);
      } on FormatException catch (error) {
        return Failure(
          MangaUpdatesMappingError(
            message: 'MangaUpdates response could not be decoded: $error',
          ),
        );
      } on TimeoutException catch (error) {
        return Failure(
          MangaUpdatesTransportError(
            message: 'MangaUpdates request timed out: $error',
          ),
        );
      } catch (error) {
        return Failure(
          MangaUpdatesTransportError(
            message: 'MangaUpdates request failed: $error',
          ),
        );
      }
    }
  }

  Future<http.Response> _send(_Request request) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'User-Agent': _userAgent,
    };
    if (request.method == _HttpMethod.get) {
      return _httpClient.get(request.uri, headers: headers);
    }
    headers['Content-Type'] = 'application/json';
    return _httpClient.post(
      request.uri,
      headers: headers,
      body: jsonEncode(request.body),
    );
  }

  Uri _resolveUri(String path, Map<String, dynamic>? queryParameters) {
    final relative = path.startsWith('/') ? path.substring(1) : path;
    final resolved = _baseUri.resolve(relative);
    if (queryParameters == null || queryParameters.isEmpty) {
      return resolved;
    }
    final encoded = <String, dynamic>{};
    queryParameters.forEach((key, value) {
      if (value == null) return;
      if (value is Iterable) {
        encoded[key] = value.map((e) => '$e').toList(growable: false);
      } else {
        encoded[key] = '$value';
      }
    });
    return resolved.replace(queryParameters: encoded);
  }

  Map<String, dynamic>? _freshCached(String key) {
    final cached = _cache[key];
    if (cached == null) return null;
    final age = DateTime.now().difference(cached.storedAt);
    if (age <= _responseCacheTtl) return cached.data;
    _cache.remove(key);
    return null;
  }

  Future<void> _waitForRequestWindow() async {
    final last = _lastRequestStartedAt;
    if (last != null) {
      final earliestNext = last.add(_minRequestGap);
      final now = DateTime.now();
      if (now.isBefore(earliestNext)) {
        await Future<void>.delayed(earliestNext.difference(now));
      }
    }
    _lastRequestStartedAt = DateTime.now();
  }

  Duration _parseRetryAfter(String? headerValue) {
    if (headerValue == null || headerValue.trim().isEmpty) {
      return _defaultRateLimitBackoff;
    }
    final seconds = int.tryParse(headerValue.trim());
    if (seconds != null && seconds >= 0) {
      return Duration(seconds: seconds);
    }
    final retryAt = DateTime.tryParse(headerValue);
    if (retryAt == null) return _defaultRateLimitBackoff;
    final delta = retryAt.difference(DateTime.now().toUtc());
    return delta.isNegative ? Duration.zero : delta;
  }

  String? _extractServerMessage(List<int> bodyBytes) {
    if (bodyBytes.isEmpty) return null;
    try {
      final decoded = jsonDecode(utf8.decode(bodyBytes));
      if (decoded is Map<String, dynamic>) {
        for (final key in const ['message', 'reason', 'error']) {
          final v = decoded[key];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
      }
    } catch (_) {
      // Best-effort.
    }
    return null;
  }

  Future<T> _runSerial<T>(Future<T> Function() operation) {
    final previous = _serialQueue;
    final completer = Completer<void>();
    _serialQueue = completer.future;

    return previous
        .catchError((_) {})
        .then((_) => operation())
        .whenComplete(completer.complete);
  }
}

enum _HttpMethod { get, post }

class _Request {
  _Request.get({required this.uri})
    : method = _HttpMethod.get,
      body = const <String, dynamic>{};
  _Request.post({required this.uri, required this.body})
    : method = _HttpMethod.post;

  final _HttpMethod method;
  final Uri uri;
  final Map<String, dynamic> body;

  String get cacheKey => method == _HttpMethod.get
      ? 'GET ${uri.toString()}'
      : 'POST ${uri.toString()} ${jsonEncode(body)}';
}

class _CachedResponse {
  _CachedResponse({required this.storedAt, required this.data});
  final DateTime storedAt;
  final Map<String, dynamic> data;
}
