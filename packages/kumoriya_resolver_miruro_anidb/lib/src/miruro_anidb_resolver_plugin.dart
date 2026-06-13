import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/miruro_anidb_resolver_error.dart';

final class MiruroAnidbResolverPlugin implements ResolverPlugin {
  const MiruroAnidbResolverPlugin();

  static const String _directHost = 'hls.anidb.app';

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.miruro_anidb',
    displayName: 'Miruro AniDB Passthrough',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>[_directHost],
    baseUrls: <String>['https://hls.anidb.app/stream/'],
  );

  @override
  int get priority => 115;

  @override
  bool supports(Uri url) {
    if (!url.hasScheme || url.host.toLowerCase() != _directHost) {
      return false;
    }
    return url.path.startsWith('/stream/');
  }

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        MiruroAnidbUnsupportedHostError(
          message: 'Unsupported Miruro AniDB host/path for URL: $url',
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
              'Referer': 'https://anidb.app/',
              'Origin': 'https://anidb.app',
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
