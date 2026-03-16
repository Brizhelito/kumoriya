import 'dart:async';

import 'package:dio/dio.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/anime_nexus_resolver_error.dart';
import 'models/nexus_browser_session.dart';
import 'services/cdn_edge_selector.dart';
import 'services/page_scraper.dart';
import 'services/playback_session_worker.dart';
import 'services/signed_hls_builder.dart';
import 'services/stream_data_fetcher.dart';
import 'services/ws_client.dart';
import 'utils/nexus_constants.dart';

final class AnimeNexusResolverPlugin implements ResolverPlugin {
  AnimeNexusResolverPlugin({
    Dio? dio,
    void Function(String message)? onDebugLog,
  }) : _dio = dio ?? _buildDio(),
       _debugLogSink = onDebugLog;

  final Dio _dio;
  final void Function(String message)? _debugLogSink;

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.anime_nexus',
    displayName: 'anime.nexus',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>['anime.nexus'],
    baseUrls: <String>['https://anime.nexus/watch/'],
    usesWebView: false,
  );

  @override
  int get priority => 120;

  @override
  bool supports(Uri url) {
    if ((url.scheme != 'http' && url.scheme != 'https') ||
        url.host.toLowerCase() != 'anime.nexus') {
      return false;
    }

    final segments = url.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 3 || segments.first != 'watch') {
      return false;
    }

    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    );
    if (!uuidPattern.hasMatch(segments[1].toLowerCase())) {
      return false;
    }

    return segments[2].trim().isNotEmpty;
  }

  @override
  Future<Result<List<ResolvedStream>, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        AnimeNexusUnsupportedHostError(
          message: 'Anime Nexus resolver does not support $url',
        ),
      );
    }

    try {
      _log('resolve start url=$url');
      const maxAttempts = 3;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          _log('resolve attempt=$attempt url=$url');
          final episodeId = _extractEpisodeId(url);
          var browserSession = NexusBrowserSession.generate();

          // Pre-warm the static CDN edge cache in parallel with the page
          // scrape so it's ready by the time build() needs it.
          unawaited(
            NexusCdnEdgeSelector(_dio)
                .candidateHosts(
                  fallbackHost: Uri.parse(NexusConstants.cdnBase).host,
                )
                .catchError((_) => <String>[]),
          );

          final pageData = await NexusPageScraper(
            _dio,
          ).scrape(url, session: browserSession);
          browserSession = browserSession.withCookieHeader(
            pageData.cookieHeader,
          );
          final streamDataFetcher = NexusStreamDataFetcher(_dio);
          final streamData = await streamDataFetcher.fetch(
            episodeId: episodeId,
            session: browserSession,
          );

          final signedHlsBuilder = NexusSignedHlsBuilder(
            _dio,
            onDebugLog: _debugLogSink,
          );
          final streams = await signedHlsBuilder.build(
            watchUrl: url,
            episodeId: episodeId,
            videoId: streamData.videoId,
            attestRef: pageData.attestRef,
            browserSession: browserSession,
            cookieHeader: streamData.cookieHeader,
            masterManifestUrl: streamData.hlsUrl,
          );

          if (streams.isEmpty) {
            return const Failure(
              AnimeNexusParseError(
                message: 'Anime Nexus resolver returned zero playable streams.',
              ),
            );
          }

          _log('resolve success url=$url streams=${streams.length}');
          return Success(streams);
        } on NexusPlaybackSessionWorkerException catch (error) {
          _log(
            'resolve worker-error attempt=$attempt message=${error.message}',
          );
          if (attempt < maxAttempts && _isRetryableWorkerError(error.message)) {
            continue;
          }
          return Failure(AnimeNexusParseError(message: error.message));
        } on NexusWsException catch (error) {
          _log('resolve ws-error attempt=$attempt message=${error.message}');
          if (attempt < maxAttempts && _isRetryableWorkerError(error.message)) {
            continue;
          }
          return Failure(AnimeNexusParseError(message: error.message));
        } on NexusSignedHlsException catch (error) {
          _log('resolve hls-error attempt=$attempt message=${error.message}');
          if (attempt < maxAttempts && _isRetryableWorkerError(error.message)) {
            continue;
          }
          return Failure(AnimeNexusParseError(message: error.message));
        }
      }
      return const Failure(
        AnimeNexusParseError(
          message: 'Anime Nexus resolver exhausted session retries.',
        ),
      );
    } on NexusStreamDataException catch (error) {
      _log('resolve stream-data-error message=${error.message}');
      return Failure(AnimeNexusParseError(message: error.message));
    } on NexusScraperException catch (error) {
      _log('resolve scraper-error message=${error.message}');
      return Failure(AnimeNexusParseError(message: error.message));
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final target = error.requestOptions.uri;
      _log(
        'resolve transport-error status=$status target=$target '
        'message=${error.message}',
      );
      return Failure(
        AnimeNexusTransportError(
          message:
              'Anime Nexus resolver network failure'
              '${status != null ? ' [$status]' : ''}'
              ' at $target: ${error.message}',
        ),
      );
    } catch (error) {
      _log('resolve unexpected-error error=$error');
      return Failure(
        AnimeNexusParseError(
          message: 'Anime Nexus resolver unexpected failure: $error',
        ),
      );
    }
  }

  String _extractEpisodeId(Uri url) {
    final segments = url.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.length < 3 || segments.first != 'watch') {
      throw const AnimeNexusParseError(
        message: 'Anime Nexus watch url did not expose an episode id.',
      );
    }
    return segments[1];
  }

  static Dio _buildDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 45),
        headers: <String, String>{
          'User-Agent': NexusConstants.userAgent,
          'Accept-Language': 'es-419,es;q=0.9,en;q=0.8',
          // Let dart:io negotiate encodings it can actually decode.
          // Anime Nexus serves `zstd` if we advertise it, which breaks
          // downstream HTML parsing before attestRef extraction.
        },
      ),
    );
  }

  bool _isRetryableWorkerError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('websocket auth failed') ||
        normalized.contains('authentication failed');
  }

  void _log(String message) {
    _debugLogSink?.call('[anime-nexus.resolver] $message');
  }
}
