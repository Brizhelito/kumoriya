import 'package:dio/dio.dart';
import 'dart:async';
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
  NexusSignedHlsBuilder(this._dio, {void Function(String message)? onDebugLog})
    : _debugLogSink = onDebugLog,
      _edgeSelector = NexusCdnEdgeSelector(_dio),
      _parser = const NexusHlsManifestParser();

  final Dio _dio;
  final NexusCdnEdgeSelector _edgeSelector;
  final NexusHlsManifestParser _parser;
  final void Function(String message)? _debugLogSink;

  Future<List<ResolvedStream>> build({
    required Uri watchUrl,
    required String episodeId,
    required String videoId,
    required String attestRef,
    required NexusBrowserSession browserSession,
    required String? cookieHeader,
    required Uri masterManifestUrl,
  }) async {
    _log(
      'build start episodeId=$episodeId videoId=$videoId '
      'manifest=$masterManifestUrl',
    );
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
    final candidateHosts = await _edgeSelector
        .candidateHosts(fallbackHost: fallbackHost)
        .timeout(
          const Duration(milliseconds: 1200),
          onTimeout: () => <String>[fallbackHost],
        );
    _log(
      'build candidate-hosts hosts=${candidateHosts.join(",")} '
      'streams=${masterManifest.streamEntries.length}',
    );

    final worker = await NexusPlaybackSessionWorker.spawn(
      episodeId: episodeId,
      fingerprint: browserSession.fingerprint,
      cookieHeader: cookieHeader,
      m3u8Url: masterManifestUrl.toString(),
      wsRef: attestRef,
      onDebugLog: _debugLogSink,
    );

    try {
      final proxySession = NexusPlaybackProxySession(
        playbackId: generateNexusPlaybackId(),
        dio: _dio,
        episodeId: episodeId,
        videoId: videoId,
        fingerprint: browserSession.fingerprint,
        candidateHosts: candidateHosts,
        masterManifest: masterManifest,
        worker: worker,
        onDebugLog: _debugLogSink,
      );
      final proxyServer = NexusPlaybackProxyServer.instance;
      await proxyServer.registerSession(proxySession);

      final sortedStreams = masterManifest.streamEntries.toList(growable: false)
        ..sort(
          (a, b) => _numericLabel(
            b.qualityLabel,
          ).compareTo(_numericLabel(a.qualityLabel)),
        );
      // Startup optimization: return playable proxy URLs immediately and
      // perform quality warmup in the background.
      _startBackgroundWarmup(
        worker: worker,
        proxyServer: proxyServer,
        proxySession: proxySession,
        masterManifest: masterManifest,
        sortedStreams: sortedStreams,
        episodeId: episodeId,
      );

      // Build local proxy URLs immediately for all qualities.
      final streams = <ResolvedStream>[];
      for (final stream in sortedStreams) {
        streams.add(
          ResolvedStream(
            url: proxyServer.qualityMasterUri(
              session: proxySession,
              stream: stream,
            ),
            qualityLabel: stream.qualityLabel,
            mimeType: 'application/vnd.apple.mpegurl',
            isHls: true,
          ),
        );
      }

      _log('build completed playable-streams=${streams.length}');
      return streams;
    } catch (error) {
      _log('build error error=$error');
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

  Future<void> _validateWorkerSession({
    required NexusPlaybackSessionWorker worker,
    required NexusMasterManifest masterManifest,
    required NexusVideoStreamEntry primaryStream,
    required String episodeId,
  }) async {
    _log(
      'validate-worker episodeId=$episodeId '
      'primaryVariant=${primaryStream.metadata.variant}',
    );
    await worker.getSessionId();

    final audioGroupId = primaryStream.audioGroupId;
    if (audioGroupId != null) {
      final audioStream = masterManifest.audioEntries.firstWhere(
        (entry) => entry.groupId == audioGroupId,
        orElse: () => throw const NexusSignedHlsException(
          'Anime Nexus primary stream did not expose a matching audio track.',
        ),
      );
      await worker.getManifestToken(
        manifestPath: audioStream.uri.path,
        videoId: episodeId,
      );
    }

    await worker.getManifestToken(
      manifestPath: primaryStream.uri.path,
      videoId: episodeId,
    );
  }

  void _startBackgroundWarmup({
    required NexusPlaybackSessionWorker worker,
    required NexusPlaybackProxyServer proxyServer,
    required NexusPlaybackProxySession proxySession,
    required NexusMasterManifest masterManifest,
    required List<NexusVideoStreamEntry> sortedStreams,
    required String episodeId,
  }) {
    unawaited(
      Future<void>(() async {
        try {
          await _validateWorkerSession(
            worker: worker,
            masterManifest: masterManifest,
            primaryStream: sortedStreams.first,
            episodeId: episodeId,
          );
        } catch (error) {
          _log('build background-validate-failed error=$error');
        }

        for (final stream in sortedStreams) {
          try {
            await proxyServer.primeStream(
              session: proxySession,
              stream: stream,
            );
            _log(
              'build prime-stream-background quality=${stream.qualityLabel} '
              'variant=${stream.metadata.variant} track=${stream.metadata.track}',
            );
          } catch (error) {
            _log(
              'build background-prime-failed quality=${stream.qualityLabel} '
              'variant=${stream.metadata.variant} track=${stream.metadata.track} error=$error',
            );
          }
        }
      }),
    );
  }

  void _log(String message) {
    _debugLogSink?.call('[anime-nexus.builder] $message');
  }
}
