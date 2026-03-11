import 'package:dio/dio.dart';

import '../models/nexus_browser_session.dart';

final class NexusPageData {
  const NexusPageData({
    required this.episodeId,
    required this.attestRef,
    this.cookieHeader,
  });

  final String episodeId;
  final String attestRef;
  final String? cookieHeader;
}

final class NexusScraperException implements Exception {
  const NexusScraperException(this.message);

  final String message;

  @override
  String toString() => 'NexusScraperException: $message';
}

final class NexusPageScraper {
  const NexusPageScraper(this._dio);

  final Dio _dio;

  Future<NexusPageData> scrape(
    Uri watchUrl, {
    NexusBrowserSession? session,
  }) async {
    final cookieHeader = session?.cookieHeader;
    final response = await _dio.getUri<String>(
      watchUrl,
      options: Options(
        responseType: ResponseType.plain,
        headers: <String, String>{
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'sec-fetch-dest': 'document',
          'sec-fetch-mode': 'navigate',
          'sec-fetch-site': 'none',
          if (cookieHeader != null) 'Cookie': cookieHeader,
        },
      ),
    );

    final html = response.data?.trim() ?? '';
    if (html.isEmpty) {
      throw const NexusScraperException(
        'Anime Nexus watch page returned empty HTML.',
      );
    }

    final segments = watchUrl.pathSegments;
    final watchIndex = segments.indexOf('watch');
    final episodeId = watchIndex >= 0 && watchIndex + 1 < segments.length
        ? segments[watchIndex + 1]
        : _extractEpisodeIdFromHtml(html);
    if (episodeId == null || episodeId.isEmpty) {
      throw const NexusScraperException(
        'Anime Nexus watch page did not expose an episode id.',
      );
    }

    final attestRef = _extractAttestRef(html);
    if (attestRef == null) {
      throw const NexusScraperException(
        'Anime Nexus watch page did not expose attestRef.',
      );
    }

    return NexusPageData(
      episodeId: episodeId,
      attestRef: attestRef,
      cookieHeader: _mergeSetCookieHeaders(response.headers['set-cookie']),
    );
  }

  String? _extractAttestRef(String html) {
    final match = RegExp(r'attestRef:"([0-9a-f]{64})"').firstMatch(html);
    return match?.group(1);
  }

  String? _extractEpisodeIdFromHtml(String html) {
    final match = RegExp(
      r'episode:\$R\[\d+\]=\{id:"([0-9a-f-]{36})"',
    ).firstMatch(html);
    return match?.group(1);
  }

  String? _mergeSetCookieHeaders(List<String>? setCookies) {
    if (setCookies == null || setCookies.isEmpty) {
      return null;
    }

    final merged = <String, String>{};
    for (final raw in setCookies) {
      final cookie = raw.split(';').first.trim();
      if (cookie.isEmpty) {
        continue;
      }
      final separator = cookie.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      merged[cookie.substring(0, separator)] = cookie.substring(separator + 1);
    }

    if (merged.isEmpty) {
      return null;
    }

    return merged.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }
}
