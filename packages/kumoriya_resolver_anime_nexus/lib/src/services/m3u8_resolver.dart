import 'package:dio/dio.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../utils/nexus_constants.dart';

final class NexusM3u8Resolver {
  const NexusM3u8Resolver(this._dio);

  final Dio _dio;

  /// Resolves HLS variants from [manifestUrl].
  ///
  /// When [headers] is provided, those headers are used both for fetching
  /// the manifest and as playback headers in the returned [ResolvedStream]s.
  /// When omitted, default headers with Origin/Referer are used.
  Future<List<ResolvedStream>> resolve({
    required Uri manifestUrl,
    Map<String, String>? headers,
  }) async {
    final requestHeaders = headers ?? _defaultHeaders();

    final response = await _dio.get<String>(
      manifestUrl.toString(),
      options: Options(
        responseType: ResponseType.plain,
        followRedirects: true,
        maxRedirects: 5,
        headers: requestHeaders,
      ),
    );

    final body = response.data?.trim() ?? '';
    final finalUri = response.realUri;
    if (body.startsWith('#EXTM3U')) {
      return _parseStreams(
        content: body,
        baseUri: finalUri,
        headers: requestHeaders,
      );
    }

    if (finalUri.path.toLowerCase().contains('.m3u8')) {
      return <ResolvedStream>[
        ResolvedStream(
          url: finalUri,
          qualityLabel: 'auto',
          mimeType: 'application/vnd.apple.mpegurl',
          isHls: true,
          headers: requestHeaders,
        ),
      ];
    }

    return const <ResolvedStream>[];
  }

  List<ResolvedStream> _parseStreams({
    required String content,
    required Uri baseUri,
    required Map<String, String> headers,
  }) {
    final lines = content.split('\n');
    final streams = <ResolvedStream>[];

    for (var index = 0; index < lines.length - 1; index++) {
      final line = lines[index].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF')) {
        continue;
      }

      final variant = lines[index + 1].trim();
      if (variant.isEmpty || variant.startsWith('#')) {
        continue;
      }

      final variantUri = baseUri.resolve(variant);
      streams.add(
        ResolvedStream(
          url: variantUri,
          qualityLabel: _parseQualityLabel(line),
          mimeType: 'application/vnd.apple.mpegurl',
          isHls: true,
          headers: headers,
        ),
      );
    }

    streams.sort((a, b) {
      final aBandwidth = _numericLabel(a.qualityLabel);
      final bBandwidth = _numericLabel(b.qualityLabel);
      return bBandwidth.compareTo(aBandwidth);
    });

    return streams;
  }

  Map<String, String> _defaultHeaders() {
    return <String, String>{
      'User-Agent': NexusConstants.userAgent,
      'Origin': NexusConstants.mainBase,
      'Referer': '${NexusConstants.mainBase}/',
      'Accept': '*/*',
      'Accept-Language': 'es-419,es;q=0.9,en;q=0.8',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'cross-site',
    };
  }

  String _parseQualityLabel(String line) {
    final resolutionMatch = RegExp(r'RESOLUTION=(\d+)x(\d+)').firstMatch(line);
    if (resolutionMatch != null) {
      return '${resolutionMatch.group(2)}p';
    }

    final bandwidthMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
    if (bandwidthMatch != null) {
      final bps = int.tryParse(bandwidthMatch.group(1)!) ?? 0;
      return _estimateResolutionFromBandwidth(bps);
    }

    return 'auto';
  }

  String _estimateResolutionFromBandwidth(int bps) {
    final kbps = bps ~/ 1000;
    if (kbps >= 8000) return '2160p';
    if (kbps >= 4000) return '1080p';
    if (kbps >= 1500) return '720p';
    if (kbps >= 800) return '480p';
    if (kbps >= 400) return '360p';
    return '240p';
  }

  int _numericLabel(String? label) {
    return int.tryParse(label?.replaceAll(RegExp(r'[^0-9]'), '') ?? '') ?? 0;
  }
}
