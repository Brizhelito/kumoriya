import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';

import '../errors/mangabaka_error.dart';

/// Low-level HTTP client for MangaBaka. Returns parsed JSON maps as
/// `Result`. Higher-level operations (search, fetch by id, mapping)
/// live in `HttpMangaBakaMetadataGateway`.
abstract interface class MangaBakaHttpClient {
  /// GETs a relative path under the configured base. `queryParameters`
  /// values can be `String` or `Iterable<String>`; null is dropped.
  Future<Result<Map<String, dynamic>, KumoriyaError>> getJson({
    required String path,
    Map<String, dynamic>? queryParameters,
  });
}

/// Production implementation. Adds:
///
///  * minimum gap between requests (rate-limit friendliness)
///  * `Retry-After` honoring on 429 (single retry by default)
///  * short-lived in-memory response cache keyed by request URI
///  * defensive JSON parsing with detailed error mapping
final class HttpMangaBakaClient implements MangaBakaHttpClient {
  HttpMangaBakaClient({
    http.Client? httpClient,
    Uri? baseUri,
    String userAgent = _defaultUserAgent,
    Duration minRequestGap = const Duration(milliseconds: 250),
    Duration defaultRateLimitBackoff = const Duration(seconds: 4),
    Duration responseCacheTtl = const Duration(minutes: 5),
    int maxRateLimitRetries = 1,
    Duration requestTimeout = const Duration(seconds: 15),
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUri = baseUri ?? Uri.parse('https://api.mangabaka.dev/v1/'),
       _userAgent = userAgent,
       _minRequestGap = minRequestGap,
       _defaultRateLimitBackoff = defaultRateLimitBackoff,
       _responseCacheTtl = responseCacheTtl,
       _maxRateLimitRetries = maxRateLimitRetries,
       _requestTimeout = requestTimeout;

  static const String _defaultUserAgent =
      'Kumoriya/0.1 (+https://kumoriya.app) MangaBakaClient';

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
    return _runSerial(() => _execute(uri));
  }

  Future<Result<Map<String, dynamic>, KumoriyaError>> _execute(Uri uri) async {
    final cacheKey = uri.toString();
    final cached = _freshCached(cacheKey);
    if (cached != null) {
      return Success(cached);
    }

    var attempt = 0;
    while (true) {
      try {
        await _waitForRequestWindow();

        final response = await _httpClient
            .get(
              uri,
              headers: <String, String>{
                'Accept': 'application/json',
                'User-Agent': _userAgent,
              },
            )
            .timeout(_requestTimeout);

        if (response.statusCode == 429) {
          final retryAfter = _parseRetryAfter(response.headers['retry-after']);
          if (attempt < _maxRateLimitRetries) {
            attempt += 1;
            await Future<void>.delayed(retryAfter);
            continue;
          }
          return Failure(
            MangaBakaRateLimitError(
              message:
                  'MangaBaka rate limit reached. Retry after ${retryAfter.inSeconds}s.',
              retryAfter: retryAfter,
            ),
          );
        }

        if (response.statusCode == 404) {
          return Failure(
            MangaBakaNotFoundError(
              message:
                  _extractServerMessage(response.bodyBytes) ?? 'Not found.',
            ),
          );
        }

        if (response.statusCode >= 500) {
          return Failure(
            MangaBakaServiceUnavailableError(
              message:
                  _extractServerMessage(response.bodyBytes) ??
                  'MangaBaka returned status ${response.statusCode}',
              statusCode: response.statusCode,
            ),
          );
        }

        if (response.statusCode != 200) {
          return Failure(
            MangaBakaTransportError(
              message:
                  _extractServerMessage(response.bodyBytes) ??
                  'MangaBaka returned status ${response.statusCode}',
              statusCode: response.statusCode,
            ),
          );
        }

        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! Map<String, dynamic>) {
          return const Failure(
            MangaBakaMappingError(
              message: 'MangaBaka response is not a JSON object.',
            ),
          );
        }

        // The API also signals logical 404 inside a 200 envelope when
        // a series is permanently deleted. Honor that contract too.
        final logicalStatus = decoded['status'];
        if (logicalStatus is int && logicalStatus == 404) {
          return Failure(
            MangaBakaNotFoundError(
              message: decoded['message'] is String
                  ? decoded['message'] as String
                  : 'Not found.',
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
          MangaBakaMappingError(
            message: 'MangaBaka response could not be decoded: $error',
          ),
        );
      } on TimeoutException catch (error) {
        return Failure(
          MangaBakaTransportError(
            message: 'MangaBaka request timed out: $error',
          ),
        );
      } catch (error) {
        return Failure(
          MangaBakaTransportError(message: 'MangaBaka request failed: $error'),
        );
      }
    }
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
        final msg = decoded['message'];
        if (msg is String && msg.trim().isNotEmpty) return msg.trim();
      }
    } catch (_) {
      // Best-effort only.
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

class _CachedResponse {
  _CachedResponse({required this.storedAt, required this.data});
  final DateTime storedAt;
  final Map<String, dynamic> data;
}
