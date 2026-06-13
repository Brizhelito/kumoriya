import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_resolver_anime_nexus/kumoriya_resolver_anime_nexus.dart';
import 'package:kumoriya_resolver_doodstream/kumoriya_resolver_doodstream.dart';
import 'package:kumoriya_resolver_filemoon/kumoriya_resolver_filemoon.dart';
import 'package:kumoriya_resolver_hqq/kumoriya_resolver_hqq.dart';
import 'package:kumoriya_resolver_jkplayer/kumoriya_resolver_jkplayer.dart';
import 'package:kumoriya_resolver_miruro_anidb/kumoriya_resolver_miruro_anidb.dart';
import 'package:kumoriya_resolver_miruro_kwik/kumoriya_resolver_miruro_kwik.dart';
import 'package:kumoriya_resolver_miruro_vibeplayer/kumoriya_resolver_miruro_vibeplayer.dart';
import 'package:kumoriya_resolver_miruro_vidtube/kumoriya_resolver_miruro_vidtube.dart';
import 'package:kumoriya_resolver_mixdrop/kumoriya_resolver_mixdrop.dart';
import 'package:kumoriya_resolver_mp4upload/kumoriya_resolver_mp4upload.dart';
import 'package:kumoriya_resolver_okru/kumoriya_resolver_okru.dart';
import 'package:kumoriya_resolver_pixeldrain/kumoriya_resolver_pixeldrain.dart';
import 'package:kumoriya_resolver_streamtape/kumoriya_resolver_streamtape.dart';
import 'package:kumoriya_resolver_streamwish/kumoriya_resolver_streamwish.dart';
import 'package:kumoriya_resolver_upnshare/kumoriya_resolver_upnshare.dart';
import 'package:kumoriya_resolver_vidhide/kumoriya_resolver_vidhide.dart';
import 'package:kumoriya_resolver_voe/kumoriya_resolver_voe.dart';
import 'package:kumoriya_resolver_yourupload/kumoriya_resolver_yourupload.dart';
import 'package:kumoriya_resolver_zilla/kumoriya_resolver_zilla.dart';

/// All resolver plugins in the system, in priority order.
List<ResolverPlugin> buildAllResolvers() {
  return <ResolverPlugin>[
    AnimeNexusResolverPlugin(),
    const MiruroKwikResolverPlugin(),
    const MiruroAnidbResolverPlugin(),
    const MiruroVidtubeResolverPlugin(),
    const MiruroVibeplayerResolverPlugin(),
    JkPlayerJkResolverPlugin(),
    JkPlayerResolverPlugin(),
    StreamwishResolverPlugin(),
    Mp4uploadResolverPlugin(),
    PixeldrainResolverPlugin(),
    StreamtapeResolverPlugin(),
    DoodstreamResolverPlugin(),
    YouruploadResolverPlugin(),
    OkruResolverPlugin(),
    HqqResolverPlugin(),
    UpnshareResolverPlugin(),
    ZillaResolverPlugin(),
    VoeResolverPlugin(),
    MixdropResolverPlugin(),
    FilemoonResolverPlugin(),
    VidhideResolverPlugin(),
  ];
}

/// Find the resolver that supports a given URL.
ResolverPlugin? findResolverFor(Uri url, List<ResolverPlugin> resolvers) {
  final candidates = resolvers.where((r) => r.supports(url)).toList()
    ..sort((a, b) {
      final cmp = b.priority.compareTo(a.priority);
      if (cmp != 0) return cmp;
      return a.manifest.id.compareTo(b.manifest.id);
    });
  return candidates.firstOrNull;
}

/// Find a resolver by its display name (case-insensitive partial match).
ResolverPlugin? findResolverByName(
  String name,
  List<ResolverPlugin> resolvers,
) {
  final lower = name.toLowerCase();
  return resolvers.cast<ResolverPlugin?>().firstWhere(
    (r) =>
        r!.manifest.displayName.toLowerCase().contains(lower) ||
        r.manifest.id.toLowerCase().contains(lower),
    orElse: () => null,
  );
}
