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
    // O6: Parallelize worker spawn with CDN edge selection.  They are
    // independent — the worker needs masterManifestUrl (already available)
    // while edge selection needs fallbackHost (just computed).  Running
    // both concurrently saves ~200-500ms on the critical open path.
    late final List<String> candidateHosts;
    late final NexusPlaybackSessionWorker worker;
    final results = await Future.wait(<Future<Object>>[
      _edgeSelector
          .candidateHosts(fallbackHost: fallbackHost)
          .timeout(
            const Duration(milliseconds: 1200),
            onTimeout: () => <String>[fallbackHost],
          ),
      NexusPlaybackSessionWorker.spawn(
        episodeId: episodeId,
        fingerprint: browserSession.fingerprint,
        cookieHeader: cookieHeader,
        m3u8Url: masterManifestUrl.toString(),
        wsRef: attestRef,
        onDebugLog: _debugLogSink,
      ),
    ]);
    candidateHosts = results[0] as List<String>;
    worker = results[1] as NexusPlaybackSessionWorker;
    _log(
      'build candidate-hosts hosts=${candidateHosts.join(",")} '
      'streams=${masterManifest.streamEntries.length}',
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
        proxyServer: proxyServer,
        proxySession: proxySession,
        sortedStreams: sortedStreams,
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

  void _startBackgroundWarmup({
    required NexusPlaybackProxyServer proxyServer,
    required NexusPlaybackProxySession proxySession,
    required List<NexusVideoStreamEntry> sortedStreams,
  }) {
    unawaited(
      Future<void>(() async {
        try {
          // Grace period so the first player open gets priority on the WS
          // command channel.  Increased back to 1500ms from 300ms: the active
          // variant needs several WS round-trips for manifests + init segments
          // before background priming should compete for WS bandwidth.
          await Future<void>.delayed(const Duration(milliseconds: 1500));
        } catch (error) {
          _log('build background-warmup-delay-failed error=$error');
        }

        // Conservative warmup on mobile: avoid priming all qualities in the
        // background, which can starve the initial open and cause 500s on
        // init/segment fetch under constrained devices.
        final primary = sortedStreams.first;
        try {
          await proxyServer.primeStream(session: proxySession, stream: primary);
          _log(
            'build prime-stream-background quality=${primary.qualityLabel} '
            'variant=${primary.metadata.variant} track=${primary.metadata.track}',
          );
        } catch (error) {
          _log(
            'build background-prime-failed quality=${primary.qualityLabel} '
            'variant=${primary.metadata.variant} track=${primary.metadata.track} error=$error',
          );
        }
      }),
    );
  }

  void _log(String message) {
    _debugLogSink?.call('[anime-nexus.builder] $message');
  }
}
