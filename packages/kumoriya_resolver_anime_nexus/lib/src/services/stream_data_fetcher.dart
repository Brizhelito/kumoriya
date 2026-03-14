import 'package:dio/dio.dart';

import '../models/nexus_browser_session.dart';
import '../utils/nexus_constants.dart';

final class NexusSubtitle {
  const NexusSubtitle({required this.src, required this.label, this.srcLang});

  final String src;
  final String label;
  final String? srcLang;
}

final class NexusStreamData {
  const NexusStreamData({
    required this.hlsUrl,
    required this.videoId,
    this.cookieHeader,
    this.subtitles = const <NexusSubtitle>[],
  });

  /// The raw HLS URL from the API (not yet tokenized).
  final Uri hlsUrl;

  /// The video UUID used for CDN headers and WebSocket params.
  final String videoId;

  /// The real cookies returned by Anime Nexus API responses.
  final String? cookieHeader;

  /// Subtitles exposed by the API in `data.subtitles`.
  final List<NexusSubtitle> subtitles;
}

final class NexusStreamDataException implements Exception {
  const NexusStreamDataException(this.message);

  final String message;

  @override
  String toString() => 'NexusStreamDataException: $message';
}

final class NexusStreamDataFetcher {
  const NexusStreamDataFetcher(this._dio);

  final Dio _dio;

  Future<NexusStreamData> fetch({
    required String episodeId,
    NexusBrowserSession? session,
  }) async {
    final resolvedSession = session ?? NexusBrowserSession.generate();
    var cookieHeader = resolvedSession.cookieHeader;

    // Auth session and episode view bootstraps are independent cookie
    // sources — run them in parallel to save one round-trip.
    final bootstrapResults = await Future.wait(<Future<List<String>?>>[
      _bootstrapAuthSession(cookieHeader: cookieHeader),
      _bootstrapEpisodeView(
        episodeId: episodeId,
        cookieHeader: cookieHeader,
        fingerprint: resolvedSession.fingerprint,
      ),
    ]);
    final authCookies = bootstrapResults[0];
    final viewCookies = bootstrapResults[1];
    cookieHeader = _mergeCookieHeaders(cookieHeader, authCookies);
    cookieHeader = _mergeCookieHeaders(cookieHeader, viewCookies);

    var response = await _request(
      episodeId: episodeId,
      cookieHeader: cookieHeader,
      fingerprint: resolvedSession.fingerprint,
    );
    if (response.statusCode == 403) {
      final cookies = _mergeCookieHeaders(
        cookieHeader,
        response.headers['set-cookie'],
      );
      if (cookies != null) {
        cookieHeader = cookies;
        response = await _request(
          episodeId: episodeId,
          cookieHeader: cookies,
          fingerprint: resolvedSession.fingerprint,
        );
      }
    }

    if (response.statusCode != 200) {
      throw NexusStreamDataException(
        'Anime Nexus stream metadata responded with status ${response.statusCode}.',
      );
    }

    final payload = response.data;
    if (payload == null) {
      throw const NexusStreamDataException(
        'Anime Nexus stream metadata response was empty.',
      );
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const NexusStreamDataException(
        'Anime Nexus stream metadata did not expose a data object.',
      );
    }

    final hlsRaw = data['hls']?.toString().trim() ?? '';
    final hlsUrl = Uri.tryParse(hlsRaw);
    if (hlsUrl == null) {
      throw const NexusStreamDataException(
        'Anime Nexus stream metadata did not expose a valid HLS url.',
      );
    }

    final videoId = _extractVideoId(data, hlsUrl);
    if (videoId.isEmpty) {
      throw const NexusStreamDataException(
        'Anime Nexus stream metadata did not expose a video id.',
      );
    }

    final subtitles = _parseSubtitles(data['subtitles']);
    final resolvedCookieHeader = _mergeCookieHeaders(
      cookieHeader,
      response.headers['set-cookie'],
    );

    return NexusStreamData(
      hlsUrl: hlsUrl,
      videoId: videoId,
      cookieHeader: resolvedCookieHeader,
      subtitles: subtitles,
    );
  }

  /// Extracts the video UUID from the API payload or the HLS URL path.
  ///
  /// The HLS URL typically looks like:
  /// `https://api.anime.nexus/api/anime/video/<videoId>/stream/video.m3u8`
  String _extractVideoId(Map<String, dynamic> data, Uri hlsUrl) {
    // Try from nested video object first.
    final video = data['video'];
    if (video is Map<String, dynamic>) {
      final id = video['id']?.toString().trim() ?? '';
      if (id.isNotEmpty) return id;
    }

    // Try from video_meta.
    final videoMeta = data['video_meta'];
    if (videoMeta is Map<String, dynamic>) {
      final id = videoMeta['id']?.toString().trim() ?? '';
      if (id.isNotEmpty) return id;
    }

    // Fallback: parse from HLS URL path segments.
    // Path: /api/anime/video/<videoId>/stream/video.m3u8
    final segments = hlsUrl.pathSegments;
    final videoIndex = segments.indexOf('video');
    if (videoIndex >= 0 && videoIndex + 1 < segments.length) {
      final candidate = segments[videoIndex + 1].trim();
      if (candidate.isNotEmpty && candidate != 'stream') {
        return candidate;
      }
    }

    return '';
  }

  List<NexusSubtitle> _parseSubtitles(Object? raw) {
    if (raw is! List<dynamic>) return const <NexusSubtitle>[];

    final result = <NexusSubtitle>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;

      final src = item['src']?.toString().trim() ?? '';
      if (src.isEmpty) continue;

      final label = item['label']?.toString().trim() ?? 'Subtitles';
      final srcLang = item['srcLang']?.toString().trim();

      result.add(
        NexusSubtitle(
          src: src,
          label: label,
          srcLang: srcLang?.isEmpty == true ? null : srcLang,
        ),
      );
    }
    return result;
  }

  Future<Response<Map<String, dynamic>>> _request({
    required String episodeId,
    String? cookieHeader,
    String? fingerprint,
  }) {
    return _dio.get<Map<String, dynamic>>(
      '${NexusConstants.apiBase}/api/anime/details/episode/stream',
      queryParameters: <String, Object>{
        'id': episodeId,
        'fillers': true,
        'recaps': true,
      },
      options: Options(
        validateStatus: (status) => status != null && status < 500,
        headers: <String, String>{
          'Accept': 'application/json, text/plain, */*',
          'Referer': '${NexusConstants.mainBase}/',
          'Origin': NexusConstants.mainBase,
          'sec-fetch-dest': 'empty',
          'sec-fetch-mode': 'cors',
          'sec-fetch-site': 'same-site',
          if (fingerprint != null) 'x-client-fingerprint': fingerprint,
          if (fingerprint != null) 'x-fingerprint': fingerprint,
          if (cookieHeader != null) 'Cookie': cookieHeader,
        },
      ),
    );
  }

  Future<List<String>?> _bootstrapAuthSession({
    required String? cookieHeader,
  }) async {
    final response = await _dio.get<dynamic>(
      '${NexusConstants.mainBase}/api/auth/session',
      options: Options(
        validateStatus: (status) => status != null && status < 500,
        headers: <String, String>{
          'Accept': 'application/json, text/plain, */*',
          'Referer': '${NexusConstants.mainBase}/',
          'sec-fetch-dest': 'empty',
          'sec-fetch-mode': 'cors',
          'sec-fetch-site': 'same-origin',
          if (cookieHeader != null) 'Cookie': cookieHeader,
        },
      ),
    );

    return response.headers['set-cookie'];
  }

  Future<List<String>?> _bootstrapEpisodeView({
    required String episodeId,
    required String? cookieHeader,
    required String fingerprint,
  }) async {
    final response = await _dio.post<void>(
      '${NexusConstants.apiBase}/api/anime/details/episode/view',
      data: <String, String>{'id': episodeId},
      options: Options(
        validateStatus: (status) => status != null && status < 500,
        headers: <String, String>{
          'Accept': 'application/json, text/plain, */*',
          'Referer': '${NexusConstants.mainBase}/',
          'Origin': NexusConstants.mainBase,
          'sec-fetch-dest': 'empty',
          'sec-fetch-mode': 'cors',
          'sec-fetch-site': 'same-site',
          'x-client-fingerprint': fingerprint,
          'x-fingerprint': fingerprint,
          if (cookieHeader != null) 'Cookie': cookieHeader,
        },
      ),
    );

    return response.headers['set-cookie'];
  }

  String? _mergeCookieHeaders(String? existing, List<String>? setCookies) {
    final merged = <String, String>{};

    if (existing != null && existing.isNotEmpty) {
      for (final part in existing.split(';')) {
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

    if (setCookies == null || setCookies.isEmpty) {
      if (merged.isEmpty) {
        return null;
      }
      return merged.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');
    }

    for (final raw in setCookies) {
      final cookie = raw.split(';').first.trim();
      if (cookie.isNotEmpty) {
        final separator = cookie.indexOf('=');
        if (separator <= 0) {
          continue;
        }
        merged[cookie.substring(0, separator)] = cookie.substring(
          separator + 1,
        );
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
