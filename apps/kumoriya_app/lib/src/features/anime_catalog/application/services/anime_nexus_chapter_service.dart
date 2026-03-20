import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../models/source_availability.dart';
import 'mal_metadata_bridge_service.dart';
import 'source_availability_cache_codec.dart';

typedef AnimeDetailLoader =
    Future<Result<AnimeDetail, KumoriyaError>> Function(int anilistId);
typedef SourceAvailabilitySummaryLoader =
    Future<Result<SourceAvailabilitySummary, KumoriyaError>> Function(
      AnimeDetail detail,
    );

final class AnimeNexusChapterService {
  AnimeNexusChapterService({
    http.Client? httpClient,
    SourceAvailabilityStore? sourceAvailabilityStore,
    SourceAvailabilityCacheCodec? sourceAvailabilityCacheCodec,
    AnimeDetailLoader? loadAnimeDetail,
    SourceAvailabilitySummaryLoader? loadSourceAvailability,
  }) : _httpClient = httpClient ?? http.Client(),
       _sourceAvailabilityStore = sourceAvailabilityStore,
       _sourceAvailabilityCacheCodec = sourceAvailabilityCacheCodec,
       _loadAnimeDetail = loadAnimeDetail,
       _loadSourceAvailability = loadSourceAvailability;

  static const String animeNexusSourcePluginId = 'kumoriya.source.anime_nexus';
  static const String _mainBase = 'https://anime.nexus';
  static const String _apiBase = 'https://api.anime.nexus';
  static final Uri _authSessionEndpoint = Uri.parse(
    '$_mainBase/api/auth/session',
  );
  static final Uri _episodeViewEndpoint = Uri.parse(
    '$_apiBase/api/anime/details/episode/view',
  );
  static final Uri _episodeStreamEndpoint = Uri.parse(
    '$_apiBase/api/anime/details/episode/stream',
  );
  static final RegExp _hlsVideoIdPattern = RegExp(
    r'/api/anime/video/([0-9a-f-]+)/stream/video\.m3u8',
  );

  final http.Client _httpClient;
  final SourceAvailabilityStore? _sourceAvailabilityStore;
  final SourceAvailabilityCacheCodec? _sourceAvailabilityCacheCodec;
  final AnimeDetailLoader? _loadAnimeDetail;
  final SourceAvailabilitySummaryLoader? _loadSourceAvailability;

  final Map<int, Future<SourceAvailabilitySummary?>> _pendingSummaryByAnime =
      <int, Future<SourceAvailabilitySummary?>>{};
  final Map<String, Future<List<AniSkipSegment>>> _pendingSegmentsByEpisode =
      <String, Future<List<AniSkipSegment>>>{};

  Future<List<AniSkipSegment>> getEpisodeSegments({
    required int anilistId,
    required int episodeNumber,
  }) async {
    if (episodeNumber <= 0) {
      return const <AniSkipSegment>[];
    }

    final summary = await _loadSummary(anilistId, episodeNumber);
    final sourceEpisode = _findAnimeNexusEpisode(summary, episodeNumber);
    if (sourceEpisode == null) {
      return const <AniSkipSegment>[];
    }

    final episodeId = sourceEpisode.sourceEpisodeId;
    final pending = _pendingSegmentsByEpisode[episodeId];
    if (pending != null) {
      return pending;
    }

    final future = _loadEpisodeSegments(sourceEpisode);
    _pendingSegmentsByEpisode[episodeId] = future;
    try {
      return await future;
    } finally {
      _pendingSegmentsByEpisode.remove(episodeId);
    }
  }

  void dispose() {
    _httpClient.close();
  }

  Future<SourceAvailabilitySummary?> _loadSummary(
    int anilistId,
    int episodeNumber,
  ) async {
    final pending = _pendingSummaryByAnime[anilistId];
    if (pending != null) {
      return pending;
    }

    final future = _readSummaryFromCacheOrRefresh(anilistId, episodeNumber);
    _pendingSummaryByAnime[anilistId] = future;
    try {
      return await future;
    } finally {
      _pendingSummaryByAnime.remove(anilistId);
    }
  }

  Future<SourceAvailabilitySummary?> _readSummaryFromCacheOrRefresh(
    int anilistId,
    int episodeNumber,
  ) async {
    final cached = await _readCachedSummary(anilistId);
    if (_findAnimeNexusEpisode(cached, episodeNumber) != null) {
      return cached;
    }

    final detailLoader = _loadAnimeDetail;
    final availabilityLoader = _loadSourceAvailability;
    if (detailLoader == null || availabilityLoader == null) {
      return cached;
    }

    final detailResult = await detailLoader(anilistId);
    if (detailResult case final Failure<AnimeDetail, KumoriyaError> _) {
      return cached;
    }

    final detail = (detailResult as Success<AnimeDetail, KumoriyaError>).value;
    final availabilityResult = await availabilityLoader(detail);
    if (availabilityResult
        case final Success<SourceAvailabilitySummary, KumoriyaError> success) {
      return success.value;
    }

    return cached;
  }

  Future<SourceAvailabilitySummary?> _readCachedSummary(int anilistId) async {
    final store = _sourceAvailabilityStore;
    final codec = _sourceAvailabilityCacheCodec;
    if (store == null || codec == null) {
      return null;
    }

    final result = await store.getAvailability(anilistId);
    if (result
        case final Success<List<SourceAvailabilityCacheRecord>, KumoriyaError>
            success) {
      return codec.decode(success.value)?.summary;
    }

    return null;
  }

  SourceEpisode? _findAnimeNexusEpisode(
    SourceAvailabilitySummary? summary,
    int episodeNumber,
  ) {
    if (summary == null) {
      return null;
    }

    for (final source in summary.sources) {
      if (source.manifest.id != animeNexusSourcePluginId) {
        continue;
      }
      for (final episode in source.episodes) {
        if ((episode.number - episodeNumber).abs() < 0.001) {
          return episode;
        }
      }
    }

    return null;
  }

  Future<List<AniSkipSegment>> _loadEpisodeSegments(
    SourceEpisode sourceEpisode,
  ) async {
    final payload = await _fetchEpisodeStreamPayload(sourceEpisode);
    final chapterUrl = _extractChapterUrl(payload);
    if (chapterUrl == null) {
      return const <AniSkipSegment>[];
    }

    final response = await _httpClient.get(chapterUrl, headers: _vttHeaders());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const <AniSkipSegment>[];
    }

    return _parseWebVttSegments(response.body);
  }

  Future<Map<String, dynamic>?> _fetchEpisodeStreamPayload(
    SourceEpisode sourceEpisode,
  ) async {
    final session = _generateBrowserSession();
    String? cookieHeader = session.cookieHeader;

    final watchPageResponse = await _httpClient.get(
      sourceEpisode.episodeUrl,
      headers: _watchPageHeaders(cookieHeader),
    );
    cookieHeader = _mergeCookieHeaders(
      cookieHeader,
      watchPageResponse.headers['set-cookie'],
    );

    final authSessionResponse = await _httpClient.get(
      _authSessionEndpoint,
      headers: _authHeaders(cookieHeader),
    );
    cookieHeader = _mergeCookieHeaders(
      cookieHeader,
      authSessionResponse.headers['set-cookie'],
    );

    final episodeViewResponse = await _httpClient.post(
      _episodeViewEndpoint,
      headers: _episodeViewHeaders(
        cookieHeader: cookieHeader,
        fingerprint: session.fingerprint,
      ),
      body: <String, String>{'id': sourceEpisode.sourceEpisodeId},
    );
    cookieHeader = _mergeCookieHeaders(
      cookieHeader,
      episodeViewResponse.headers['set-cookie'],
    );

    final uri = _episodeStreamEndpoint.replace(
      queryParameters: <String, String>{
        'id': sourceEpisode.sourceEpisodeId,
        'fillers': 'true',
        'recaps': 'true',
      },
    );
    var response = await _httpClient.get(
      uri,
      headers: _episodeStreamHeaders(
        cookieHeader: cookieHeader,
        fingerprint: session.fingerprint,
      ),
    );
    if (response.statusCode == 403) {
      final refreshedCookieHeader = _mergeCookieHeaders(
        cookieHeader,
        response.headers['set-cookie'],
      );
      if (refreshedCookieHeader != null) {
        response = await _httpClient.get(
          uri,
          headers: _episodeStreamHeaders(
            cookieHeader: refreshedCookieHeader,
            fingerprint: session.fingerprint,
          ),
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final data = decoded['data'];
    return data is Map<String, dynamic> ? data : null;
  }

  Uri? _extractChapterUrl(Map<String, dynamic>? payload) {
    if (payload == null) {
      return null;
    }

    final raw = payload['chapters'];
    if (raw is String && raw.trim().isNotEmpty) {
      return Uri.tryParse(raw.trim());
    }

    return _deriveCuesUrlFromHls(payload);
  }

  Uri? _deriveCuesUrlFromHls(Map<String, dynamic> payload) {
    final hls = payload['hls'];
    if (hls is! String || hls.trim().isEmpty) {
      return null;
    }

    final match = _hlsVideoIdPattern.firstMatch(hls.trim());
    if (match == null) {
      return null;
    }

    final videoId = match.group(1)!;
    return Uri.parse('$_apiBase/api/anime/video/$videoId/stream/cues.vtt');
  }

  List<AniSkipSegment> _parseWebVttSegments(String body) {
    final lines = body
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceFirst('\uFEFF', ''))
        .toList(growable: false);
    final segments = <AniSkipSegment>[];

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      if (!line.contains('-->')) {
        continue;
      }

      final parts = line.split('-->');
      if (parts.length != 2) {
        continue;
      }

      final start = _parseWebVttTimestamp(parts.first.trim());
      final end = _parseWebVttTimestamp(
        parts.last.trim().split(RegExp(r'\s+')).first,
      );
      if (start == null || end == null || end <= start) {
        continue;
      }

      final textLines = <String>[];
      for (var cursor = index + 1; cursor < lines.length; cursor++) {
        final text = lines[cursor].trim();
        if (text.isEmpty) {
          break;
        }
        textLines.add(text);
        index = cursor;
      }

      final kind = _mapCueLabelToKind(textLines.join(' ').trim());
      if (kind == null) {
        continue;
      }

      segments.add(AniSkipSegment(kind: kind, start: start, end: end));
    }

    segments.sort((left, right) => left.start.compareTo(right.start));
    return segments;
  }

  Duration? _parseWebVttTimestamp(String value) {
    final parts = value.trim().split('.');
    if (parts.length != 2) {
      return null;
    }

    final timeParts = parts.first.split(':');
    if (timeParts.length < 2 || timeParts.length > 3) {
      return null;
    }

    final milliseconds = int.tryParse(parts.last);
    final hours = timeParts.length == 3 ? int.tryParse(timeParts[0]) : 0;
    final minutes = int.tryParse(timeParts[timeParts.length - 2]);
    final seconds = int.tryParse(timeParts.last);
    if (milliseconds == null ||
        hours == null ||
        minutes == null ||
        seconds == null) {
      return null;
    }

    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
    );
  }

  AniSkipSegmentKind? _mapCueLabelToKind(String label) {
    final normalized = label.trim().toLowerCase();
    return switch (normalized) {
      'opening' || 'op' => AniSkipSegmentKind.opening,
      'ending' || 'ed' => AniSkipSegmentKind.ending,
      _ => null,
    };
  }

  Map<String, String> _vttHeaders() {
    return <String, String>{
      'Accept': '*/*',
      'Origin': _mainBase,
      'Referer': '$_mainBase/',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'same-site',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/146.0.0.0 Safari/537.36',
      'Accept-Language': 'es-419,es;q=0.9',
    };
  }

  Map<String, String> _apiHeaders() {
    return const <String, String>{
      'Referer': 'https://anime.nexus/',
      'Origin': 'https://anime.nexus',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'same-site',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/146.0.0.0 Safari/537.36',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'es-419,es;q=0.9,en;q=0.8',
    };
  }

  Map<String, String> _authHeaders(String? cookieHeader) {
    return <String, String>{
      ..._apiHeaders(),
      'sec-fetch-site': 'same-origin',
      if (cookieHeader != null) 'Cookie': cookieHeader,
    };
  }

  Map<String, String> _watchPageHeaders(String? cookieHeader) {
    return <String, String>{
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Origin': _mainBase,
      'Referer': '$_mainBase/',
      'sec-fetch-dest': 'document',
      'sec-fetch-mode': 'navigate',
      'sec-fetch-site': 'none',
      'User-Agent': _apiHeaders()['User-Agent']!,
      'Accept-Language': _apiHeaders()['Accept-Language']!,
      if (cookieHeader != null) 'Cookie': cookieHeader,
    };
  }

  Map<String, String> _episodeViewHeaders({
    required String? cookieHeader,
    required String fingerprint,
  }) {
    return <String, String>{
      ..._apiHeaders(),
      'x-client-fingerprint': fingerprint,
      'x-fingerprint': fingerprint,
      if (cookieHeader != null) 'Cookie': cookieHeader,
    };
  }

  Map<String, String> _episodeStreamHeaders({
    required String? cookieHeader,
    required String fingerprint,
  }) {
    return <String, String>{
      ..._apiHeaders(),
      'x-client-fingerprint': fingerprint,
      'x-fingerprint': fingerprint,
      if (cookieHeader != null) 'Cookie': cookieHeader,
    };
  }

  _AnimeNexusBrowserSession _generateBrowserSession() {
    final random = Random.secure();

    String hex(int bytes) => List<String>.generate(
      bytes,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

    final p1 = hex(4);
    final p2 = hex(2);
    final p3 = '4${hex(2).substring(1)}';
    final p4 =
        '${(8 + random.nextInt(4)).toRadixString(16)}${hex(2).substring(1)}';
    final p5 = hex(6);

    return _AnimeNexusBrowserSession(
      fingerprint: '$p1-$p2-$p3-$p4-$p5',
      cookieHeader: 'sid=${hex(16)}',
    );
  }

  String? _mergeCookieHeaders(String? existing, String? incoming) {
    final merged = <String, String>{};

    void absorb(String? header) {
      if (header == null || header.trim().isEmpty) {
        return;
      }

      for (final part in header.split(';')) {
        final cookie = part.trim();
        if (cookie.isEmpty) {
          continue;
        }
        final separator = cookie.indexOf('=');
        if (separator <= 0) {
          continue;
        }
        merged[cookie.substring(0, separator)] = cookie.substring(
          separator + 1,
        );
      }
    }

    absorb(existing);
    if (incoming != null) {
      for (final header in incoming.split(RegExp(r',(?=\s*[^;,\s]+=)'))) {
        absorb(header.trim());
      }
    }

    if (merged.isEmpty) {
      return null;
    }

    return merged.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }
}

final class _AnimeNexusBrowserSession {
  const _AnimeNexusBrowserSession({
    required this.fingerprint,
    required this.cookieHeader,
  });

  final String fingerprint;
  final String cookieHeader;
}
