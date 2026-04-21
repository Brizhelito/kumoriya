import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

/// Android-only resolver that replaces the Dart `AnimeNexusResolverPlugin`.
///
/// Instead of spinning up the local HTTP loopback proxy (which costs
/// ~10-14 s of scrape + WS handshake + manifest rewrite on cold start),
/// it returns a carrier URL that [KumoriyaExoPlayerEngine] detects and
/// feeds straight into the native Kotlin pipeline (`openAnimeNexus`).
///
/// The native path:
///   1. runs the scrape + WS handshake on an IO thread,
///   2. attaches an [HlsMediaSource] backed by a custom OkHttp-based
///      [DataSource] that signs every segment request on the fly.
///
/// End-to-end start-up drops from ~12 s to <2 s on the moto g72 baseline
/// and removes the "loopback HTTP hop per segment" tax.
final class NativeAnimeNexusBypassResolver implements ResolverPlugin {
  const NativeAnimeNexusBypassResolver();

  @override
  PluginManifest get manifest => const PluginManifest(
        id: 'kumoriya.resolver.anime_nexus.native_bypass',
        displayName: 'anime.nexus (native)',
        type: PluginType.resolver,
        capabilities: <PluginCapability>{PluginCapability.streamResolution},
        supportedHosts: <String>['anime.nexus'],
      );

  /// Must be strictly greater than `AnimeNexusResolverPlugin.priority`
  /// (120) so the registry picks us first on Android.
  @override
  int get priority => 200;

  @override
  bool supports(Uri url) {
    if (url.scheme != 'http' && url.scheme != 'https') return false;
    if (url.host.toLowerCase() != 'anime.nexus') return false;
    // Accept both `/watch/<id>/...` and `/watch/<slug>` shapes.
    return url.pathSegments.isNotEmpty && url.pathSegments.first == 'watch';
  }

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return const Failure(
        SimpleError(
          code: 'kumoriya.resolver.anime_nexus.native_bypass.unsupported',
          message: 'Not an anime.nexus watch URL',
          kind: KumoriyaErrorKind.notFound,
        ),
      );
    }

    // NOTE: the `//` is mandatory — without it `Uri.parse` treats
    // `anime-nexus` as the opaque path and `url.host` is empty, which
    // breaks `KumoriyaExoPlayerEngine._nativeAnimeNexusWatchUrl`. A
    // regression test pins both ends together.
    final encoded = Uri.encodeComponent(url.toString());
    final carrier = Uri.parse('kumoriya-native://anime-nexus?watch=$encoded');

    return Success(
      ResolveResult(
        streams: <ResolvedStream>[
          ResolvedStream(
            url: carrier,
            qualityLabel: 'auto',
            mimeType: 'application/x-mpegURL',
            isHls: true,
            headers: const <String, String>{},
            supportsEmbeddedTrackSelection: true,
          ),
        ],
      ),
    );
  }
}
