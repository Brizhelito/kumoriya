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

  static final _uuidRe = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

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

    if (!_uuidRe.hasMatch(segments[1].toLowerCase())) {
      return false;
    }

    return segments[2].trim().isNotEmpty;
  }

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
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

          final subtitleTracks = await _buildSubtitleTracks(
            subtitles: streamData.subtitles,
            episodeId: episodeId,
            cookieHeader: streamData.cookieHeader,
            fingerprint: browserSession.fingerprint,
          );
          _log(
            'resolve success url=$url streams=${streams.length} '
            'subtitles=${subtitleTracks.length}',
          );
          return Success(
            ResolveResult(streams: streams, externalSubtitles: subtitleTracks),
          );
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

  /// Converts [NexusSubtitle] entries from the stream API into
  /// [ExternalSubtitleTrack] instances, fetching the VTT content inline
  /// when possible so media_kit can use the data payload directly.
  Future<List<ExternalSubtitleTrack>> _buildSubtitleTracks({
    required List<NexusSubtitle> subtitles,
    required String episodeId,
    required String? cookieHeader,
    required String fingerprint,
  }) async {
    if (subtitles.isEmpty) return const <ExternalSubtitleTrack>[];

    final tracks = <ExternalSubtitleTrack>[];
    for (final sub in subtitles) {
      final rawUri = Uri.tryParse(sub.src);
      if (rawUri == null) continue;

      final uri = rawUri.hasScheme
          ? rawUri
          : Uri.parse(NexusConstants.apiBase).resolveUri(rawUri);

      final data = await _fetchSubtitleData(
        uri: uri,
        episodeId: episodeId,
        cookieHeader: cookieHeader,
        fingerprint: fingerprint,
      );

      tracks.add(
        ExternalSubtitleTrack(
          id: 'subtitle-${tracks.length}',
          label: sub.label,
          language: sub.srcLang,
          uri: data == null ? uri : null,
          data: data,
          isDefault: tracks.isEmpty,
        ),
      );
    }
    return tracks;
  }

  /// Fetches VTT/SRT content from [uri] using the authenticated session.
  Future<String?> _fetchSubtitleData({
    required Uri uri,
    required String episodeId,
    required String? cookieHeader,
    required String fingerprint,
  }) async {
    try {
      final response = await _dio.get<String>(
        uri.toString(),
        options: Options(
          responseType: ResponseType.plain,
          headers: <String, String>{
            'Accept': 'text/vtt,text/plain,application/x-subrip,*/*',
            'Referer': '${NexusConstants.mainBase}/watch/$episodeId',
            'Origin': NexusConstants.mainBase,
            'x-client-fingerprint': fingerprint,
            'x-fingerprint': fingerprint,
            if (cookieHeader != null) 'Cookie': cookieHeader,
          },
        ),
      );
      final body = response.data?.trim();
      if (body == null || body.isEmpty) return null;
      return body;
    } catch (_) {
      return null;
    }
  }

  void _log(String message) {
    _debugLogSink?.call('[anime-nexus.resolver] $message');
  }
}
