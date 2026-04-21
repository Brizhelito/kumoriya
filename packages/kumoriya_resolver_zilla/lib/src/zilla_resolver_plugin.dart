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

    // Only fetch the first ~1 KiB of the manifest via Range — enough to
    // verify the `#EXTM3U` header without pulling the entire playlist
    // (which can exceed 100 KiB on multi-variant streams). If the server
    // ignores Range and returns the full body, we still succeed because
    // the header appears at byte 0 either way.
    final probeHeaders = <String, String>{
      ..._headers(url),
      'Range': 'bytes=0-1023',
    };

    final http.Response response;
    try {
      response = await _httpClient
          .get(playlistUrl, headers: probeHeaders)
          .timeout(const Duration(seconds: 8));
    } catch (error) {
      return Failure(
        ZillaTransportError(message: 'Zilla resolve request failed: $error'),
      );
    }

    // 200 = Range ignored, 206 = Range honoured. Both are valid for us.
    if (response.statusCode != 200 && response.statusCode != 206) {
      return Failure(
        ZillaTransportError(
          message:
              'Zilla playlist request failed with status ${response.statusCode}.',
        ),
      );
    }

    try {
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
        ZillaParseError(message: 'Failed to parse Zilla playlist: $error'),
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
    return url;
  }
  if (segments[0] != 'play') {
    return null;
  }
  return url.replace(path: '/m3u8/${segments[1]}', query: null, fragment: null);
}

Map<String, String> _headers(Uri url) {
  final origin = '${url.scheme}://${url.host}';
  return <String, String>{
    'Referer': '$origin${url.path}',
    'Origin': origin,
    // Zilla edge servers close HLS segment connections with mid-transfer
    // `End of file` errors when the request arrives without a browser UA,
    // forcing ffmpeg to burn two to three reconnect cycles per segment
    // (~6 s lost before first frame). A consistent desktop UA is enough
    // to get clean 200s.
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  };
}
