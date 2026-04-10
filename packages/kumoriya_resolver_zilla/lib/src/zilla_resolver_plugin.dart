import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_common/kumoriya_resolver_common.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/zilla_resolver_error.dart';

final class ZillaResolverPlugin implements ResolverPlugin {
  ZillaResolverPlugin({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const String _host = 'player.zilla-networks.com';

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.zilla',
    displayName: 'Zilla Networks Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>[_host],
    baseUrls: <String>['https://player.zilla-networks.com/play/'],
  );

  @override
  int get priority => 108;

  @override
  bool supports(Uri url) {
    if (!url.hasScheme || url.host.toLowerCase() != _host) {
      return false;
    }

    return url.path.startsWith('/play/') || url.path.startsWith('/m3u8/');
  }

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        ZillaUnsupportedHostError(
          message: 'Unsupported Zilla host/path for URL: $url',
        ),
      );
    }

    final playlistUrl = _toPlaylistUrl(url);
    if (playlistUrl == null) {
      return const Failure(
        ZillaMalformedLinkError(
          message: 'Zilla URL does not contain a playable identifier.',
        ),
      );
    }

    try {
      final response = await _httpClient
          .get(playlistUrl, headers: _headers(url))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return Failure(
          ZillaTransportError(
            message:
                'Zilla playlist request failed with status ${response.statusCode}.',
          ),
        );
      }

      if (!safeResponseBody(response).contains('#EXTM3U')) {
        return const Failure(
          ZillaParseError(
            message: 'Zilla playlist payload did not contain an HLS manifest.',
          ),
        );
      }

      return Success(
        ResolveResult(
          streams: <ResolvedStream>[
            ResolvedStream(
              url: playlistUrl,
              qualityLabel: 'auto',
              mimeType: 'application/vnd.apple.mpegurl',
              isHls: true,
              headers: _headers(url),
            ),
          ],
        ),
      );
    } catch (error) {
      return Failure(
        ZillaTransportError(message: 'Zilla resolve request failed: $error'),
      );
    }
  }
}

Uri? _toPlaylistUrl(Uri url) {
  final segments = url.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.length < 2) {
    return null;
  }
  if (segments[0] == 'm3u8') {
    // Ensure trailing slash so relative segment/variant URLs in the m3u8
    // resolve correctly (e.g. "index-v1-a1.m3u8" → /m3u8/<hash>/index-v1-a1.m3u8).
    final path = url.path.endsWith('/') ? url.path : '${url.path}/';
    return url.replace(path: path);
  }
  if (segments[0] != 'play') {
    return null;
  }
  // Trailing slash ensures relative URL resolution treats the hash as a
  // directory, not a file name to be replaced.
  return url.replace(
    path: '/m3u8/${segments[1]}/',
    query: null,
    fragment: null,
  );
}

Map<String, String> _headers(Uri url) {
  final origin = '${url.scheme}://${url.host}';
  return <String, String>{'Referer': '$origin${url.path}', 'Origin': origin};
}
