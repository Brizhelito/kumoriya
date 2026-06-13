import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/miruro_kwik_resolver_error.dart';

final class MiruroKwikResolverPlugin implements ResolverPlugin {
  const MiruroKwikResolverPlugin();

  static const Set<String> _supportedHosts = <String>{
    'uwucdn.top',
    'cdn.kwik.si',
    'owocdn.top',
    'kwik.cx',
  };

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.miruro_kwik',
    displayName: 'Miruro Kwik Passthrough',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>['uwucdn.top', 'cdn.kwik.si', 'owocdn.top', 'kwik.cx'],
    baseUrls: <String>[
      'https://vault-05.uwucdn.top/stream/',
      'https://cdn.kwik.si/hls/',
    ],
  );

  @override
  int get priority => 116;

  @override
  bool supports(Uri url) {
    if (!url.hasScheme || url.host.trim().isEmpty) {
      return false;
    }

    final host = url.host.toLowerCase();
    final hostAllowed = _supportedHosts.any(
      (supportedHost) =>
          host == supportedHost || host.endsWith('.$supportedHost'),
    );
    if (!hostAllowed) {
      return false;
    }

    final path = url.path.toLowerCase();
    return path.contains('/stream/') ||
        path.contains('/hls/') ||
        path.endsWith('.m3u8') ||
        path.endsWith('.mp4');
  }

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        MiruroKwikUnsupportedHostError(
          message: 'Unsupported Miruro Kwik host/path for URL: $url',
        ),
      );
    }

    return Success(
      ResolveResult(
        streams: <ResolvedStream>[
          ResolvedStream(
            url: url,
            qualityLabel: _inferQuality(url),
            mimeType: _inferMimeType(url),
            isHls: _isHls(url),
            headers: _headers(),
            supportsEmbeddedTrackSelection: !_isHls(url),
          ),
        ],
      ),
    );
  }
}

Map<String, String> _headers() {
  return const <String, String>{
    'Referer': 'https://kwik.cx/',
    'Origin': 'https://kwik.cx',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  };
}

bool _isHls(Uri url) => url.path.toLowerCase().endsWith('.mp4') ? false : true;

String _inferMimeType(Uri url) {
  return _isHls(url) ? 'application/vnd.apple.mpegurl' : 'video/mp4';
}

String _inferQuality(Uri url) {
  final match = RegExp(
    r'(2160|1440|1080|720|480|360)p',
  ).firstMatch(url.toString().toLowerCase());
  return match == null ? 'auto' : '${match.group(1)}p';
}
