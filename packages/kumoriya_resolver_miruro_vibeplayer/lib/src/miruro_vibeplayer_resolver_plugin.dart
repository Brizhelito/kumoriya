import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/miruro_vibeplayer_resolver_error.dart';

final class MiruroVibeplayerResolverPlugin implements ResolverPlugin {
  const MiruroVibeplayerResolverPlugin();

  static const String _host = 'vibeplayer.site';

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.miruro_vibeplayer',
    displayName: 'Miruro Vibeplayer Passthrough',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>[_host],
    baseUrls: <String>['https://vibeplayer.site/public/stream/'],
  );

  @override
  int get priority => 113;

  @override
  bool supports(Uri url) {
    if (!url.hasScheme || url.host.toLowerCase() != _host) {
      return false;
    }
    return url.path.startsWith('/public/stream/') ||
        (url.pathSegments.length == 1 &&
            url.pathSegments.first.isNotEmpty &&
            url.pathSegments.first.length == 36);
  }

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        MiruroVibeplayerUnsupportedHostError(
          message: 'Unsupported Miruro Vibeplayer host/path for URL: $url',
        ),
      );
    }

    return Success(
      ResolveResult(
        streams: <ResolvedStream>[
          ResolvedStream(
            url: url,
            qualityLabel: 'auto',
            mimeType: 'application/vnd.apple.mpegurl',
            isHls: true,
            headers: const <String, String>{
              'Referer': 'https://vibeplayer.site/',
              'Origin': 'https://vibeplayer.site',
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            },
            supportsEmbeddedTrackSelection: false,
          ),
        ],
      ),
    );
  }
}
