import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/miruro_vidtube_resolver_error.dart';

final class MiruroVidtubeResolverPlugin implements ResolverPlugin {
  const MiruroVidtubeResolverPlugin();

  static const Set<String> _directHosts = <String>{'mt.nekostream.site'};
  static const List<String> _subtitleSuffixes = <String>[
    '.vtt',
    '.srt',
    '.ass',
  ];

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.miruro_vidtube',
    displayName: 'Miruro Vidtube Passthrough',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>['mt.nekostream.site'],
    baseUrls: <String>['https://mt.nekostream.site/'],
  );

  @override
  int get priority => 114;

  @override
  bool supports(Uri url) {
    if (!url.hasScheme || !_directHosts.contains(url.host.toLowerCase())) {
      return false;
    }

    final path = url.path.toLowerCase();
    if (path.isEmpty || path == '/') {
      return false;
    }
    if (path.contains('/subtitles/')) {
      return false;
    }
    return !_subtitleSuffixes.any(path.endsWith);
  }

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        MiruroVidtubeUnsupportedHostError(
          message: 'Unsupported Miruro Vidtube host/path for URL: $url',
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
              'Referer': 'https://vidtube.site/',
              'Origin': 'https://vidtube.site',
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
