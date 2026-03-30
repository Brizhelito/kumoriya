import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';

import '../errors/anilist_error.dart';

abstract interface class AnilistGraphqlClient {
  Future<Result<Map<String, dynamic>, KumoriyaError>> execute({
    required String query,
    Map<String, dynamic> variables,
  });
}

enum AnilistClientLogLevel { off, summary, verbose }

final class AnilistClientConfig {
  const AnilistClientConfig({
    this.collectDebugMetrics = false,
    this.debugLogLevel = AnilistClientLogLevel.off,
  });

  final bool collectDebugMetrics;
  final AnilistClientLogLevel debugLogLevel;
}

final class AnilistClientDebugMetrics {
  const AnilistClientDebugMetrics({
    required this.totalExecutions,
    required this.networkRequests,
    required this.freshCacheHits,
    required this.staleCacheHits,
    required this.rateLimitEvents,
    required this.queryNetworkRequests,
    required this.queryCacheHits,
  });

  final int totalExecutions;
  final int networkRequests;
  final int freshCacheHits;
  final int staleCacheHits;
  final int rateLimitEvents;
  final Map<String, int> queryNetworkRequests;
  final Map<String, int> queryCacheHits;
}

final class _AnilistClientMetricsAccumulator {
  int _totalExecutions = 0;
  int _networkRequests = 0;
  int _freshCacheHits = 0;
  int _staleCacheHits = 0;
  int _rateLimitEvents = 0;
  final Map<String, int> _queryNetworkRequests = <String, int>{};
  final Map<String, int> _queryCacheHits = <String, int>{};

  void onExecute() {
    _totalExecutions += 1;
  }

  void onNetworkRequest(String queryLabel) {
    _networkRequests += 1;
    _queryNetworkRequests.update(
      queryLabel,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }

  void onFreshCacheHit(String queryLabel) {
    _freshCacheHits += 1;
    _queryCacheHits.update(queryLabel, (value) => value + 1, ifAbsent: () => 1);
  }

  void onStaleCacheHit(String queryLabel) {
    _staleCacheHits += 1;
    _queryCacheHits.update(queryLabel, (value) => value + 1, ifAbsent: () => 1);
  }

  void onRateLimit() {
    _rateLimitEvents += 1;
  }

  AnilistClientDebugMetrics snapshot() {
    return AnilistClientDebugMetrics(
      totalExecutions: _totalExecutions,
      networkRequests: _networkRequests,
      freshCacheHits: _freshCacheHits,
      staleCacheHits: _staleCacheHits,
      rateLimitEvents: _rateLimitEvents,
      queryNetworkRequests: Map<String, int>.unmodifiable(
        _queryNetworkRequests,
      ),
      queryCacheHits: Map<String, int>.unmodifiable(_queryCacheHits),
    );
  }

  void reset() {
    _totalExecutions = 0;
    _networkRequests = 0;
    _freshCacheHits = 0;
    _staleCacheHits = 0;
    _rateLimitEvents = 0;
    _queryNetworkRequests.clear();
    _queryCacheHits.clear();
  }
}

final class HttpAnilistGraphqlClient implements AnilistGraphqlClient {
  HttpAnilistGraphqlClient({
    http.Client? httpClient,
    Uri? endpoint,
    AnilistClientConfig config = const AnilistClientConfig(),
    Duration minRequestGap = const Duration(milliseconds: 350),
    Duration defaultRateLimitBackoff = const Duration(seconds: 4),
    Duration responseCacheTtl = const Duration(minutes: 5),
    Duration staleOnRateLimitTtl = const Duration(minutes: 20),
    int maxRateLimitRetries = 1,
  }) : _httpClient = httpClient ?? http.Client(),
       _endpoint = endpoint ?? Uri.parse('https://graphql.anilist.co'),
       _config = config,
       _minRequestGap = minRequestGap,
       _defaultRateLimitBackoff = defaultRateLimitBackoff,
       _responseCacheTtl = responseCacheTtl,
       _staleOnRateLimitTtl = staleOnRateLimitTtl,
       _maxRateLimitRetries = maxRateLimitRetries;

  final http.Client _httpClient;
  final Uri _endpoint;
  final AnilistClientConfig _config;
  final Duration _minRequestGap;
  final Duration _defaultRateLimitBackoff;
  final Duration _responseCacheTtl;
  final Duration _staleOnRateLimitTtl;
  final int _maxRateLimitRetries;

  Future<void> _serialQueue = Future<void>.value();
  DateTime? _cooldownUntil;
  DateTime? _lastRequestStartedAt;
  final Map<String, _CachedAniListResponse> _responseCache =
      <String, _CachedAniListResponse>{};
  static final _AnilistClientMetricsAccumulator _metrics =
      _AnilistClientMetricsAccumulator();

  static AnilistClientDebugMetrics debugMetricsSnapshot() {
    return _metrics.snapshot();
  }

  static void resetDebugMetrics() {
    _metrics.reset();
  }

  @override
  Future<Result<Map<String, dynamic>, KumoriyaError>> execute({
    required String query,
    Map<String, dynamic> variables = const <String, dynamic>{},
  }) async {
    final queryLabel = _queryLabel(query);
    _recordMetric((metrics) => metrics.onExecute());
    final cacheKey = _buildCacheKey(query, variables);
    _evictExpiredCache();

    final freshCache = _freshCache(cacheKey);
    if (freshCache != null) {
      _recordMetric((metrics) => metrics.onFreshCacheHit(queryLabel));
      _logSummary(event: 'cache_hit_fresh', queryLabel: queryLabel);
      return Success(freshCache.data);
    }

    return _runSerial(() async {
      final freshCacheInsideQueue = _freshCache(cacheKey);
      if (freshCacheInsideQueue != null) {
        _recordMetric((metrics) => metrics.onFreshCacheHit(queryLabel));
        _logSummary(event: 'cache_hit_fresh_in_queue', queryLabel: queryLabel);
        return Success(freshCacheInsideQueue.data);
      }

      final staleCache = _staleCache(cacheKey);
      if (_isCoolingDown && staleCache != null) {
        _recordMetric((metrics) => metrics.onStaleCacheHit(queryLabel));
        _logSummary(event: 'cache_hit_stale_cooldown', queryLabel: queryLabel);
        return Success(staleCache.data);
      }

      var attempt = 0;
      while (true) {
        try {
          await _waitForRequestWindow();
          _recordMetric((metrics) => metrics.onNetworkRequest(queryLabel));
          _logSummary(event: 'network_request', queryLabel: queryLabel);

          final response = await _httpClient
              .post(
                _endpoint,
                headers: const <String, String>{
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: jsonEncode(<String, dynamic>{
                  'query': query,
                  'variables': variables,
                }),
              )
              .timeout(const Duration(seconds: 15));

          if (response.statusCode == 429) {
            _recordMetric((metrics) => metrics.onRateLimit());
            final retryAfter = _parseRetryAfter(
              response.headers['retry-after'],
            );
            _cooldownUntil = DateTime.now().add(retryAfter);
            _logSummary(
              event: 'rate_limit_429',
              queryLabel: queryLabel,
              extra: <String, Object?>{'retry_after_s': retryAfter.inSeconds},
            );

            if (attempt < _maxRateLimitRetries) {
              attempt += 1;
              await Future<void>.delayed(retryAfter);
              continue;
            }

            if (staleCache != null) {
              _recordMetric((metrics) => metrics.onStaleCacheHit(queryLabel));
              _logSummary(
                event: 'cache_hit_stale_rate_limit_fallback',
                queryLabel: queryLabel,
              );
              return Success(staleCache.data);
            }

            return Failure(
              AnilistRateLimitError(
                message:
                    'AniList rate limit reached. Retry after ${retryAfter.inSeconds}s.',
                retryAfter: retryAfter,
              ),
            );
          }

          if (response.statusCode != 200) {
            // Try to extract a GraphQL error message from the body
            // (AniList sometimes returns 403 with a descriptive GraphQL error).
            String? serverMessage;
            try {
              final body = jsonDecode(utf8.decode(response.bodyBytes));
              if (body is Map<String, dynamic>) {
                final errors = body['errors'];
                if (errors is List && errors.isNotEmpty) {
                  final first = errors.first;
                  if (first is Map<String, dynamic> &&
                      first['message'] is String) {
                    serverMessage = first['message'] as String;
                  }
                }
              }
            } catch (_) {
              // Ignore decode failures — fall through to generic message.
            }

            if (response.statusCode == 403 || response.statusCode >= 500) {
              return Failure(
                AnilistServiceUnavailableError(
                  message:
                      serverMessage ??
                      'AniList returned status ${response.statusCode}',
                  statusCode: response.statusCode,
                ),
              );
            }

            return Failure(
              AnilistTransportError(
                message:
                    serverMessage ??
                    'AniList returned status ${response.statusCode}',
                statusCode: response.statusCode,
              ),
            );
          }

          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is! Map<String, dynamic>) {
            return const Failure(
              AnilistMappingError(
                message: 'AniList response is not a JSON object.',
              ),
            );
          }

          final errors = decoded['errors'];
          if (errors is List && errors.isNotEmpty) {
            final first = errors.first;
            final message =
                first is Map<String, dynamic> && first['message'] is String
                ? first['message'] as String
                : 'AniList returned an unknown GraphQL error.';

            return Failure(AnilistUnexpectedError(message: message));
          }

          final data = decoded['data'];
          if (data is! Map<String, dynamic>) {
            return const Failure(
              AnilistMappingError(
                message: 'AniList payload does not contain data.',
              ),
            );
          }

          _responseCache[cacheKey] = _CachedAniListResponse(
            storedAt: DateTime.now(),
            data: data,
          );
          return Success(data);
        } on FormatException catch (error) {
          return Failure(
            AnilistMappingError(
              message: 'AniList response could not be decoded: $error',
            ),
          );
        } catch (error) {
          if (staleCache != null && _isCoolingDown) {
            _recordMetric((metrics) => metrics.onStaleCacheHit(queryLabel));
            _logSummary(
              event: 'cache_hit_stale_transport_fallback',
              queryLabel: queryLabel,
              extra: <String, Object?>{'error': '$error'},
            );
            return Success(staleCache.data);
          }

          return Failure(
            AnilistTransportError(message: 'AniList request failed: $error'),
          );
        }
      }
    });
  }

  bool get _isCoolingDown {
    final cooldownUntil = _cooldownUntil;
    return cooldownUntil != null && DateTime.now().isBefore(cooldownUntil);
  }

  String _buildCacheKey(String query, Map<String, dynamic> variables) {
    return jsonEncode(<String, dynamic>{
      'query': query,
      'variables': variables,
    });
  }

  _CachedAniListResponse? _freshCache(String key) {
    final cached = _responseCache[key];
    if (cached == null) {
      return null;
    }

    final age = DateTime.now().difference(cached.storedAt);
    if (age <= _responseCacheTtl) {
      return cached;
    }

    return null;
  }

  _CachedAniListResponse? _staleCache(String key) {
    final cached = _responseCache[key];
    if (cached == null) {
      return null;
    }

    final age = DateTime.now().difference(cached.storedAt);
    if (age <= _staleOnRateLimitTtl) {
      return cached;
    }

    return null;
  }

  void _evictExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = _responseCache.entries
        .where(
          (entry) =>
              now.difference(entry.value.storedAt) > _staleOnRateLimitTtl,
        )
        .map((entry) => entry.key)
        .toList(growable: false);

    for (final key in expiredKeys) {
      _responseCache.remove(key);
    }
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

  Future<void> _waitForRequestWindow() async {
    final now = DateTime.now();
    final cooldownUntil = _cooldownUntil;
    if (cooldownUntil != null && now.isBefore(cooldownUntil)) {
      await Future<void>.delayed(cooldownUntil.difference(now));
    }

    final lastRequestStartedAt = _lastRequestStartedAt;
    if (lastRequestStartedAt != null) {
      final nextRequestAt = lastRequestStartedAt.add(_minRequestGap);
      final current = DateTime.now();
      if (current.isBefore(nextRequestAt)) {
        await Future<void>.delayed(nextRequestAt.difference(current));
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
    if (retryAt == null) {
      return _defaultRateLimitBackoff;
    }

    final delta = retryAt.difference(DateTime.now().toUtc());
    if (delta.isNegative) {
      return Duration.zero;
    }

    return delta;
  }

  String _queryLabel(String query) {
    final match = RegExp(
      r'query\s+([A-Za-z0-9_]+)',
      caseSensitive: false,
    ).firstMatch(query);
    if (match != null) {
      return match.group(1) ?? 'AnonymousQuery';
    }
    return 'AnonymousQuery';
  }

  String _metricsSummary() {
    final snapshot = _metrics.snapshot();
    return 'exec=${snapshot.totalExecutions}, net=${snapshot.networkRequests}, '
        'fresh=${snapshot.freshCacheHits}, stale=${snapshot.staleCacheHits}, '
        '429=${snapshot.rateLimitEvents}';
  }

  void _recordMetric(
    void Function(_AnilistClientMetricsAccumulator metrics) op,
  ) {
    if (!_config.collectDebugMetrics) {
      return;
    }
    op(_metrics);
  }

  void _logSummary({
    required String event,
    required String queryLabel,
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    if (_config.debugLogLevel == AnilistClientLogLevel.off) {
      return;
    }

    if (_config.debugLogLevel == AnilistClientLogLevel.summary) {
      _debugLog(<String, Object?>{
        'event': event,
        'query': queryLabel,
        'metrics': _metricsSummary(),
        ...extra,
      });
      return;
    }

    final snapshot = _metrics.snapshot();
    _debugLog(<String, Object?>{
      'event': event,
      'query': queryLabel,
      'metrics': <String, Object?>{
        'executions': snapshot.totalExecutions,
        'network_requests': snapshot.networkRequests,
        'fresh_cache_hits': snapshot.freshCacheHits,
        'stale_cache_hits': snapshot.staleCacheHits,
        'rate_limit_events': snapshot.rateLimitEvents,
      },
      ...extra,
    });
  }

  void _debugLog(Map<String, Object?> payload) {
    assert(() {
      // ignore: avoid_print
      print('[AniListClient] ${jsonEncode(payload)}');
      return true;
    }());
  }
}

final class _CachedAniListResponse {
  const _CachedAniListResponse({required this.storedAt, required this.data});

  final DateTime storedAt;
  final Map<String, dynamic> data;
}
