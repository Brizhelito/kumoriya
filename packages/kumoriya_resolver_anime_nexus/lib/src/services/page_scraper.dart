import 'package:dio/dio.dart';

final class NexusPageData {
  const NexusPageData({required this.episodeId, required this.attestRef});

  final String episodeId;
  final String attestRef;
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

  Future<NexusPageData> scrape(Uri watchUrl) async {
    final response = await _dio.getUri<String>(
      watchUrl,
      options: Options(
        responseType: ResponseType.plain,
        headers: <String, String>{
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': watchUrl.toString(),
          'sec-fetch-dest': 'document',
          'sec-fetch-mode': 'navigate',
          'sec-fetch-site': 'none',
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

    return NexusPageData(episodeId: episodeId, attestRef: attestRef);
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
}
