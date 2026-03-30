import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

final class MalEpisodeMetadata {
  const MalEpisodeMetadata({this.title, this.airedAt});

  final String? title;
  final DateTime? airedAt;
}

enum AniSkipSegmentKind { opening, ending }

final class AniSkipSegment {
  const AniSkipSegment({
    required this.kind,
    required this.start,
    required this.end,
  });

  final AniSkipSegmentKind kind;
  final Duration start;
  final Duration end;
}

final class AniSkipPrefetchReport {
  const AniSkipPrefetchReport({
    required this.requestedEpisodes,
    required this.cachedEpisodes,
    required this.fetchedEpisodes,
    required this.failedEpisodes,
  });

  final int requestedEpisodes;
  final int cachedEpisodes;
  final int fetchedEpisodes;
  final int failedEpisodes;
}

typedef AnimeNexusSegmentLoader =
    Future<List<AniSkipSegment>> Function({
      required int anilistId,
      required int episodeNumber,
    });

final class _CachedAniSkipEntry {
  const _CachedAniSkipEntry({
    required this.segments,
    required this.updatedAt,
    this.requestedEpisodeLengthSeconds,
  });

  final List<AniSkipSegment> segments;
  final DateTime updatedAt;
  final int? requestedEpisodeLengthSeconds;

  bool isFresh(Duration maxAge) =>
      DateTime.now().difference(updatedAt) <= maxAge;
}

final class MalMetadataBridgeService {
  MalMetadataBridgeService({
    http.Client? httpClient,
    AniSkipCacheStore? aniSkipCacheStore,
    AnimeNexusSegmentLoader? animeNexusSegmentLoader,
  }) : _httpClient = httpClient ?? http.Client(),
       _aniSkipCacheStore = aniSkipCacheStore,
       _animeNexusSegmentLoader = animeNexusSegmentLoader;

  static final Uri _anilistGraphQlEndpoint = Uri.parse(
    'https://graphql.anilist.co',
  );
  static const Duration _aniSkipCacheMaxAge = Duration(days: 90);
  static const Duration _aniSkipEmptyCacheMaxAge = Duration(days: 7);
  static const int _defaultAniSkipEpisodeLengthSeconds = 24 * 60;
  static const int _aniSkipPrefetchBatchSize = 6;
  static const int _aniSkipLengthToleranceSeconds = 20;

  final http.Client _httpClient;
  final AniSkipCacheStore? _aniSkipCacheStore;
  final AnimeNexusSegmentLoader? _animeNexusSegmentLoader;

  final Map<int, int?> _malIdCache = <int, int?>{};
  final Map<int, Future<int?>> _pendingMalId = <int, Future<int?>>{};

  final Map<int, Map<int, MalEpisodeMetadata>> _jikanEpisodeCache =
      <int, Map<int, MalEpisodeMetadata>>{};
  final Map<int, Future<Map<int, MalEpisodeMetadata>>> _pendingJikanEpisodes =
      <int, Future<Map<int, MalEpisodeMetadata>>>{};

  final Map<String, _CachedAniSkipEntry> _aniSkipCache =
      <String, _CachedAniSkipEntry>{};
  final Map<String, Future<List<AniSkipSegment>>> _pendingAniSkip =
      <String, Future<List<AniSkipSegment>>>{};

  Future<int?> getMalIdForAnilist(int anilistId) async {
    final cached = _malIdCache[anilistId];
    if (cached != null || _malIdCache.containsKey(anilistId)) {
      return cached;
    }

    final pending = _pendingMalId[anilistId];
    if (pending != null) {
      return pending;
    }

    final future = _fetchMalIdForAnilist(anilistId);
    _pendingMalId[anilistId] = future;
    try {
      final malId = await future;
      _malIdCache[anilistId] = malId;
      return malId;
    } finally {
      _pendingMalId.remove(anilistId);
    }
  }

  Future<Map<int, MalEpisodeMetadata>> getEpisodeMetadataByMalId(
    int malId,
  ) async {
    final cached = _jikanEpisodeCache[malId];
    if (cached != null) {
      return cached;
    }

    final pending = _pendingJikanEpisodes[malId];
    if (pending != null) {
      return pending;
    }

    final future = _fetchJikanEpisodes(malId);
    _pendingJikanEpisodes[malId] = future;
    try {
      final episodes = await future;
      _jikanEpisodeCache[malId] = episodes;
      return episodes;
    } finally {
      _pendingJikanEpisodes.remove(malId);
    }
  }

  Future<List<AniSkipSegment>> getAniSkipSegments({
    required int anilistId,
    required int episodeNumber,
    required int episodeLengthSeconds,
  }) async {
    final key = _aniSkipKey(anilistId, episodeNumber);
    final cached = await _readAniSkipCacheEntry(
      anilistId: anilistId,
      episodeNumber: episodeNumber,
    );
    if (_shouldUseCachedAniSkip(
      cached: cached,
      requestedEpisodeLengthSeconds: episodeLengthSeconds,
    )) {
      return cached!.segments;
    }

    final pending = _pendingAniSkip[key];
    if (pending != null) {
      return pending;
    }

    final future = _loadAniSkipSegments(
      anilistId: anilistId,
      episodeNumber: episodeNumber,
      episodeLengthSeconds: episodeLengthSeconds,
      cached: cached,
    );
    _pendingAniSkip[key] = future;
    try {
      return await future;
    } finally {
      _pendingAniSkip.remove(key);
    }
  }

  Future<AniSkipPrefetchReport> prefetchAniSkipForAnime({
    required int anilistId,
    required Iterable<int> episodeNumbers,
    int episodeLengthSeconds = _defaultAniSkipEpisodeLengthSeconds,
  }) async {
    final uniqueEpisodes =
        episodeNumbers.where((episode) => episode > 0).toSet().toList()..sort();
    if (uniqueEpisodes.isEmpty) {
      return const AniSkipPrefetchReport(
        requestedEpisodes: 0,
        cachedEpisodes: 0,
        fetchedEpisodes: 0,
        failedEpisodes: 0,
      );
    }

    final existingResult = await _aniSkipCacheStore?.getEpisodesForAnime(
      anilistId,
    );
    final existingByEpisode = <int, _CachedAniSkipEntry>{};
    if (existingResult
        case final Success<List<AniSkipCacheRecord>, dynamic> success) {
      for (final record in success.value) {
        final entry = _decodeAniSkipRecord(record);
        if (entry != null) {
          final key = _aniSkipKey(anilistId, record.episodeNumber);
          _aniSkipCache[key] = entry;
          existingByEpisode[record.episodeNumber] = entry;
        }
      }
    }

    final malId = await getMalIdForAnilist(anilistId);
    var cachedEpisodes = 0;
    var fetchedEpisodes = 0;
    var failedEpisodes = 0;

    for (
      var index = 0;
      index < uniqueEpisodes.length;
      index += _aniSkipPrefetchBatchSize
    ) {
      final batch = uniqueEpisodes.skip(index).take(_aniSkipPrefetchBatchSize);
      final results = await Future.wait(
        batch.map(
          (episodeNumber) => _prefetchAniSkipEpisode(
            anilistId: anilistId,
            malId: malId,
            episodeNumber: episodeNumber,
            episodeLengthSeconds: episodeLengthSeconds,
            cached: existingByEpisode[episodeNumber],
          ),
        ),
      );
      for (final result in results) {
        switch (result) {
          case _AniSkipPrefetchResult.cached:
            cachedEpisodes++;
          case _AniSkipPrefetchResult.fetched:
            fetchedEpisodes++;
          case _AniSkipPrefetchResult.failed:
            failedEpisodes++;
        }
      }
    }

    return AniSkipPrefetchReport(
      requestedEpisodes: uniqueEpisodes.length,
      cachedEpisodes: cachedEpisodes,
      fetchedEpisodes: fetchedEpisodes,
      failedEpisodes: failedEpisodes,
    );
  }

  void dispose() {
    _httpClient.close();
  }

  Future<List<AniSkipSegment>> _loadAniSkipSegments({
    required int anilistId,
    required int episodeNumber,
    required int episodeLengthSeconds,
    required _CachedAniSkipEntry? cached,
  }) async {
    final malId = await getMalIdForAnilist(anilistId);
    try {
      final segments = await _fetchSegmentsWithFallback(
        anilistId: anilistId,
        malId: malId,
        episodeNumber: episodeNumber,
        episodeLengthSeconds: episodeLengthSeconds,
      );
      await _storeAniSkipSegments(
        anilistId: anilistId,
        episodeNumber: episodeNumber,
        episodeLengthSeconds: episodeLengthSeconds,
        segments: segments,
      );
      return segments;
    } on Exception {
      return cached?.segments ?? const <AniSkipSegment>[];
    }
  }

  Future<_AniSkipPrefetchResult> _prefetchAniSkipEpisode({
    required int anilistId,
    required int? malId,
    required int episodeNumber,
    required int episodeLengthSeconds,
    required _CachedAniSkipEntry? cached,
  }) async {
    if (_shouldUseCachedAniSkip(
      cached: cached,
      requestedEpisodeLengthSeconds: episodeLengthSeconds,
    )) {
      return _AniSkipPrefetchResult.cached;
    }

    try {
      final segments = await _fetchSegmentsWithFallback(
        anilistId: anilistId,
        malId: malId,
        episodeNumber: episodeNumber,
        episodeLengthSeconds: episodeLengthSeconds,
      );
      await _storeAniSkipSegments(
        anilistId: anilistId,
        episodeNumber: episodeNumber,
        episodeLengthSeconds: episodeLengthSeconds,
        segments: segments,
      );
      return _AniSkipPrefetchResult.fetched;
    } on Exception {
      return cached != null
          ? _AniSkipPrefetchResult.cached
          : _AniSkipPrefetchResult.failed;
    }
  }

  Future<List<AniSkipSegment>> _fetchSegmentsWithFallback({
    required int anilistId,
    required int? malId,
    required int episodeNumber,
    required int episodeLengthSeconds,
  }) async {
    List<AniSkipSegment> primary = const <AniSkipSegment>[];
    if (malId != null) {
      primary = await _fetchAniSkipSegments(
        malId: malId,
        episodeNumber: episodeNumber,
        episodeLengthSeconds: episodeLengthSeconds,
      );
    }

    final fallbackLoader = _animeNexusSegmentLoader;
    if (fallbackLoader == null ||
        (_containsSegment(primary, AniSkipSegmentKind.opening) &&
            _containsSegment(primary, AniSkipSegmentKind.ending))) {
      return primary;
    }

    try {
      final fallback = await fallbackLoader(
        anilistId: anilistId,
        episodeNumber: episodeNumber,
      );
      return _mergeSegments(primary: primary, fallback: fallback);
    } on Exception {
      return primary;
    }
  }

  bool _containsSegment(
    List<AniSkipSegment> segments,
    AniSkipSegmentKind kind,
  ) {
    return segments.any((segment) => segment.kind == kind);
  }

  List<AniSkipSegment> _mergeSegments({
    required List<AniSkipSegment> primary,
    required List<AniSkipSegment> fallback,
  }) {
    if (primary.isEmpty) {
      return fallback;
    }
    if (fallback.isEmpty) {
      return primary;
    }

    final merged = <AniSkipSegment>[...primary];
    for (final kind in AniSkipSegmentKind.values) {
      if (_containsSegment(primary, kind)) {
        continue;
      }
      final candidate = _selectFallbackSegment(fallback, kind);
      if (candidate != null) {
        merged.add(candidate);
      }
    }
    merged.sort((left, right) => left.start.compareTo(right.start));
    return merged;
  }

  AniSkipSegment? _selectFallbackSegment(
    List<AniSkipSegment> segments,
    AniSkipSegmentKind kind,
  ) {
    final matches = segments.where((segment) => segment.kind == kind);
    if (matches.isEmpty) {
      return null;
    }
    return kind == AniSkipSegmentKind.opening
        ? matches.reduce(
            (best, current) => current.start < best.start ? current : best,
          )
        : matches.reduce(
            (best, current) => current.start > best.start ? current : best,
          );
  }

  Future<_CachedAniSkipEntry?> _readAniSkipCacheEntry({
    required int anilistId,
    required int episodeNumber,
  }) async {
    final key = _aniSkipKey(anilistId, episodeNumber);
    final memory = _aniSkipCache[key];
    if (memory != null) {
      return memory;
    }
    final store = _aniSkipCacheStore;
    if (store == null) {
      return null;
    }
    final result = await store.getEpisode(anilistId, episodeNumber);
    if (result case final Success<AniSkipCacheRecord?, dynamic> success) {
      final record = success.value;
      if (record == null) {
        return null;
      }
      final decoded = _decodeAniSkipRecord(record);
      if (decoded != null) {
        _aniSkipCache[key] = decoded;
      }
      return decoded;
    }
    return null;
  }

  Future<void> _storeAniSkipSegments({
    required int anilistId,
    required int episodeNumber,
    required int episodeLengthSeconds,
    required List<AniSkipSegment> segments,
  }) async {
    final entry = _CachedAniSkipEntry(
      segments: segments,
      updatedAt: DateTime.now(),
      requestedEpisodeLengthSeconds: episodeLengthSeconds,
    );
    _aniSkipCache[_aniSkipKey(anilistId, episodeNumber)] = entry;
    final store = _aniSkipCacheStore;
    if (store == null) {
      return;
    }
    await store.upsert(
      AniSkipCacheRecord(
        anilistId: anilistId,
        episodeNumber: episodeNumber,
        payloadJson: _encodeAniSkipSegments(segments),
        updatedAt: entry.updatedAt,
        requestedEpisodeLengthSeconds: episodeLengthSeconds,
      ),
    );
  }

  Future<int?> _fetchMalIdForAnilist(int anilistId) async {
    const query = r'''
query MalIdByAnilist($id: Int) {
  Media(id: $id, type: ANIME) {
    idMal
  }
}
''';

    final response = await _httpClient.post(
      _anilistGraphQlEndpoint,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'query': query,
        'variables': <String, dynamic>{'id': anilistId},
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final media = data['Media'];
    if (media is! Map<String, dynamic>) {
      return null;
    }

    final malId = media['idMal'];
    return malId is int && malId > 0 ? malId : null;
  }

  Future<Map<int, MalEpisodeMetadata>> _fetchJikanEpisodes(int malId) async {
    final output = <int, MalEpisodeMetadata>{};

    for (var page = 1; page <= 25; page++) {
      final uri = Uri.parse(
        'https://api.jikan.moe/v4/anime/$malId/episodes?page=$page',
      );
      final response = await _httpClient.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        break;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        break;
      }

      final data = decoded['data'];
      if (data is! List) {
        break;
      }

      for (final item in data) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final malEpisode = item['mal_id'];
        if (malEpisode is! int || malEpisode <= 0) {
          continue;
        }

        final title = _firstNonEmptyString(<dynamic>[
          item['title'],
          item['title_japanese'],
          item['title_romanji'],
        ]);

        final aired = item['aired'];
        DateTime? airedAt;
        if (aired is String && aired.trim().isNotEmpty) {
          airedAt = DateTime.tryParse(aired)?.toLocal();
        }

        output[malEpisode] = MalEpisodeMetadata(title: title, airedAt: airedAt);
      }

      final pagination = decoded['pagination'];
      if (pagination is! Map<String, dynamic>) {
        break;
      }

      final hasNextPage = pagination['has_next_page'];
      if (hasNextPage is! bool || !hasNextPage) {
        break;
      }
    }

    return output;
  }

  /// Known high-coverage fallback lengths derived from probing 35 anime
  /// (1050 queries): 1440 covers 80%, 1500 catches 25min episodes and
  /// long OPs, 1380 catches 23min episodes (Ranking of Kings, etc).
  static const _aniSkipFallbackLengths = <int>[1440, 1500, 1380];

  Future<List<AniSkipSegment>> _fetchAniSkipSegments({
    required int malId,
    required int episodeNumber,
    required int episodeLengthSeconds,
  }) async {
    // Build candidate list: real duration first, then known fallbacks.
    // Deduplicate and skip values already tested.
    final seen = <int>{};
    final candidateLengths = <int>[];
    void addCandidate(int length) {
      if (length > 0 && seen.add(length)) candidateLengths.add(length);
    }

    if (episodeLengthSeconds > 0) addCandidate(episodeLengthSeconds);
    for (final fallback in _aniSkipFallbackLengths) {
      addCandidate(fallback);
    }

    var best = const <AniSkipSegment>[];
    for (final length in candidateLengths) {
      final segments = await _fetchAniSkipSegmentsForLength(
        malId: malId,
        episodeNumber: episodeNumber,
        episodeLengthSeconds: length,
      );
      if (segments.isEmpty) continue;

      if (segments.any((s) => s.kind == AniSkipSegmentKind.opening)) {
        return segments;
      }
      if (best.isEmpty) best = segments;
    }

    return best;
  }

  Future<List<AniSkipSegment>> _fetchAniSkipSegmentsForLength({
    required int malId,
    required int episodeNumber,
    required int episodeLengthSeconds,
  }) async {
    final uri = Uri.parse(
      'https://api.aniskip.com/v2/skip-times/$malId/$episodeNumber?types[]=op&types[]=ed&episodeLength=$episodeLengthSeconds',
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const <AniSkipSegment>[];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return const <AniSkipSegment>[];
    }

    final results = decoded['results'];
    if (results is! List) {
      return const <AniSkipSegment>[];
    }

    final segments = <AniSkipSegment>[];
    for (final entry in results) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }

      final interval = entry['interval'];
      if (interval is! Map<String, dynamic>) {
        continue;
      }

      final rawType = (entry['skip_type'] ?? entry['skipType'] ?? '')
          .toString()
          .toLowerCase();
      final kind = switch (rawType) {
        'op' => AniSkipSegmentKind.opening,
        'ed' => AniSkipSegmentKind.ending,
        _ => null,
      };
      if (kind == null) {
        continue;
      }

      final start = _parseDouble(
        interval['start_time'] ?? interval['startTime'],
      );
      final end = _parseDouble(interval['end_time'] ?? interval['endTime']);
      if (start == null || end == null || end <= start) {
        continue;
      }

      segments.add(
        AniSkipSegment(
          kind: kind,
          start: Duration(milliseconds: (start * 1000).round()),
          end: Duration(milliseconds: (end * 1000).round()),
        ),
      );
    }

    segments.sort((left, right) => left.start.compareTo(right.start));
    return segments;
  }

  String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  double? _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  _CachedAniSkipEntry? _decodeAniSkipRecord(AniSkipCacheRecord record) {
    try {
      final decoded = jsonDecode(record.payloadJson);
      if (decoded is! List) {
        return null;
      }
      final segments = <AniSkipSegment>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final kind = switch (item['kind']) {
          'opening' => AniSkipSegmentKind.opening,
          'ending' => AniSkipSegmentKind.ending,
          _ => null,
        };
        final startMs = item['startMs'];
        final endMs = item['endMs'];
        if (kind == null ||
            startMs is! int ||
            endMs is! int ||
            endMs <= startMs) {
          continue;
        }
        segments.add(
          AniSkipSegment(
            kind: kind,
            start: Duration(milliseconds: startMs),
            end: Duration(milliseconds: endMs),
          ),
        );
      }
      return _CachedAniSkipEntry(
        segments: List<AniSkipSegment>.unmodifiable(segments),
        updatedAt: record.updatedAt,
        requestedEpisodeLengthSeconds: record.requestedEpisodeLengthSeconds,
      );
    } on FormatException {
      return null;
    }
  }

  bool _shouldUseCachedAniSkip({
    required _CachedAniSkipEntry? cached,
    required int requestedEpisodeLengthSeconds,
  }) {
    if (cached == null) {
      return false;
    }

    // Empty results use a shorter TTL to allow re-checking when community
    // submissions arrive, but still avoid hammering the API every playback.
    final maxAge = cached.segments.isEmpty
        ? _aniSkipEmptyCacheMaxAge
        : _aniSkipCacheMaxAge;
    if (!cached.isFresh(maxAge)) {
      return false;
    }

    final cachedLength = cached.requestedEpisodeLengthSeconds;
    if (cachedLength == null || requestedEpisodeLengthSeconds <= 0) {
      return true;
    }

    final delta = (cachedLength - requestedEpisodeLengthSeconds).abs();
    return delta <= _aniSkipLengthToleranceSeconds;
  }

  String _encodeAniSkipSegments(List<AniSkipSegment> segments) {
    return jsonEncode(
      segments
          .map(
            (segment) => <String, Object>{
              'kind': switch (segment.kind) {
                AniSkipSegmentKind.opening => 'opening',
                AniSkipSegmentKind.ending => 'ending',
              },
              'startMs': segment.start.inMilliseconds,
              'endMs': segment.end.inMilliseconds,
            },
          )
          .toList(growable: false),
    );
  }

  String _aniSkipKey(int anilistId, int episodeNumber) {
    return '$anilistId:$episodeNumber';
  }
}

enum _AniSkipPrefetchResult { cached, fetched, failed }
