import 'package:dio/dio.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../models/nexus_browser_session.dart';
import '../services/cdn_edge_selector.dart';
import '../services/hls_manifest_parser.dart';
import '../services/playback_proxy_server.dart';
import '../services/playback_session_worker.dart';
import '../utils/nexus_constants.dart';

final class NexusSignedHlsException implements Exception {
  const NexusSignedHlsException(this.message);

  final String message;

  @override
  String toString() => 'NexusSignedHlsException: $message';
}

final class NexusSignedHlsBuilder {
  NexusSignedHlsBuilder(this._dio)
    : _edgeSelector = NexusCdnEdgeSelector(_dio),
      _parser = const NexusHlsManifestParser();

  final Dio _dio;
  final NexusCdnEdgeSelector _edgeSelector;
  final NexusHlsManifestParser _parser;

  Future<List<ResolvedStream>> build({
    required Uri watchUrl,
    required String episodeId,
    required String attestRef,
    required NexusBrowserSession browserSession,
    required String? cookieHeader,
    required Uri masterManifestUrl,
  }) async {
    final masterResponse = await _dio.get<String>(
      masterManifestUrl.toString(),
      options: Options(
        responseType: ResponseType.plain,
        headers: _browserFetchHeaders(),
      ),
    );

    final masterBody = masterResponse.data?.trim() ?? '';
    if (!masterBody.startsWith('#EXTM3U')) {
      throw const NexusSignedHlsException(
        'Anime Nexus master manifest was empty or invalid.',
      );
    }

    final masterManifest = _parser.parseMasterManifest(
      content: masterBody,
      baseUri: masterResponse.realUri,
    );
    if (masterManifest.streamEntries.isEmpty) {
      throw const NexusSignedHlsException(
        'Anime Nexus master manifest did not expose video streams.',
      );
    }

    final fallbackHost = masterManifest.streamEntries.first.uri.host.isNotEmpty
        ? masterManifest.streamEntries.first.uri.host
        : Uri.parse(NexusConstants.cdnBase).host;
    final candidateHosts = await _edgeSelector.candidateHosts(
      fallbackHost: fallbackHost,
    );

    final worker = await NexusPlaybackSessionWorker.spawn(
      episodeId: episodeId,
      fingerprint: browserSession.fingerprint,
      cookieHeader: cookieHeader,
      m3u8Url: masterManifestUrl.toString(),
      wsRef: attestRef,
    );

    try {
      final proxySession = NexusPlaybackProxySession(
        playbackId: generateNexusPlaybackId(),
        dio: _dio,
        episodeId: episodeId,
        fingerprint: browserSession.fingerprint,
        candidateHosts: candidateHosts,
        masterManifest: masterManifest,
        worker: worker,
      );
      final proxyServer = NexusPlaybackProxyServer.instance;
      await proxyServer.registerSession(proxySession);

      final sortedStreams = masterManifest.streamEntries.toList(growable: false)
        ..sort(
          (a, b) => _numericLabel(
            b.qualityLabel,
          ).compareTo(_numericLabel(a.qualityLabel)),
        );

      await proxyServer.primeStream(
        session: proxySession,
        stream: sortedStreams.first,
      );

      final streams = sortedStreams
          .map(
            (stream) => ResolvedStream(
              url: proxyServer.qualityMasterUri(
                session: proxySession,
                stream: stream,
              ),
              qualityLabel: stream.qualityLabel,
              mimeType: 'application/vnd.apple.mpegurl',
              isHls: true,
            ),
          )
          .toList(growable: false);

      return streams;
    } catch (error) {
      await worker.close();
      rethrow;
    }
  }

  Map<String, String> _browserFetchHeaders() {
    return <String, String>{
      'User-Agent': NexusConstants.userAgent,
      'Accept': '*/*',
      'Accept-Language': 'es-419,es;q=0.9,en;q=0.8',
      'Origin': NexusConstants.mainBase,
      'Referer': '${NexusConstants.mainBase}/',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'cross-site',
    };
  }

  int _numericLabel(String? label) {
    return int.tryParse(label?.replaceAll(RegExp(r'[^0-9]'), '') ?? '') ?? 0;
  }
}
