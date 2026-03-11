import 'package:dio/dio.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/anime_nexus_resolver_error.dart';
import 'services/m3u8_resolver.dart';
import 'services/page_scraper.dart';
import 'services/stream_data_fetcher.dart';
import 'services/ws_client.dart';
import 'utils/nexus_cdn_headers.dart';
import 'utils/nexus_constants.dart';

final class AnimeNexusResolverPlugin implements ResolverPlugin {
  AnimeNexusResolverPlugin({Dio? dio}) : _dio = dio ?? _buildDio();

  final Dio _dio;

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

    return segments[2].startsWith('episode-');
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
      final episodeId = _extractEpisodeId(url);

      // 1. Fetch stream metadata (HLS URL, videoId, subtitles).
      final streamDataFetcher = NexusStreamDataFetcher(_dio);
      final streamData = await streamDataFetcher.fetch(episodeId: episodeId);

      // 2. Scrape the watch page to get the attestRef for WS auth.
      final pageScraper = NexusPageScraper(_dio);
      final pageData = await pageScraper.scrape(url);

      // 3. Generate a stable fingerprint for this session.
      final fingerprint = NexusUuid.generate();

      // 4. Establish WebSocket connection and authenticate.
      final wsClient = NexusWsClient(
        episodeId: streamData.videoId,
        fingerprint: fingerprint,
        m3u8Url: streamData.hlsUrl.toString(),
      );

      try {
        await wsClient.connect(wsRef: pageData.attestRef);
        final sessionId = wsClient.session.sessionId;

        // 5. Get the initial manifest token from the WebSocket.
        final streamToken = await wsClient.getInitialManifestToken();

        // 6. Build the tokenized manifest URL with session params.
        final tokenizedManifest = _buildTokenizedManifest(
          hlsUrl: streamData.hlsUrl,
          token: streamToken.token,
          sessionId: sessionId,
        );

        // 7. Build CDN-specific playback headers.
        final cdnHeaders = NexusCdnHeaders.build(
          fingerprint: fingerprint,
          sessionId: sessionId,
          videoId: streamData.videoId,
        );

        // 8. Resolve HLS variants using the tokenized URL + CDN headers.
        final m3u8Resolver = NexusM3u8Resolver(_dio);
        final streams = await m3u8Resolver.resolve(
          manifestUrl: tokenizedManifest,
          headers: cdnHeaders,
        );

        if (streams.isEmpty) {
          return const Failure(
            AnimeNexusParseError(
              message: 'Anime Nexus resolver returned zero playable streams.',
            ),
          );
        }

        return Success(streams);
      } finally {
        await wsClient.close();
      }
    } on NexusStreamDataException catch (error) {
      return Failure(AnimeNexusParseError(message: error.message));
    } on NexusScraperException catch (error) {
      return Failure(AnimeNexusParseError(message: error.message));
    } on NexusWsException catch (error) {
      return Failure(AnimeNexusWebSocketError(message: error.message));
    } on DioException catch (error) {
      return Failure(
        AnimeNexusTransportError(
          message: 'Anime Nexus resolver network failure: ${error.message}',
        ),
      );
    } catch (error) {
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

  /// Appends token and session params to the API-provided manifest URL.
  ///
  /// The resulting URL follows the pattern the site uses for CDN auth:
  /// `<hlsUrl>?token=<token>&requestType=manifest&sessionId=<sessionId>`
  Uri _buildTokenizedManifest({
    required Uri hlsUrl,
    required String token,
    required String sessionId,
  }) {
    final existing = Map<String, String>.from(hlsUrl.queryParameters);
    existing['token'] = token;
    existing['requestType'] = 'manifest';
    existing['sessionId'] = sessionId;
    return hlsUrl.replace(queryParameters: existing);
  }

  static Dio _buildDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: <String, String>{
          'User-Agent': NexusConstants.userAgent,
          'Accept-Language': 'es-419,es;q=0.9,en;q=0.8',
          'Accept-Encoding': 'gzip, deflate, br, zstd',
        },
      ),
    );
  }
}
