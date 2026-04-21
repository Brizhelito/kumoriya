import 'dart:io' show Platform;

import 'package:http/http.dart' as http;
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_resolver_anime_nexus/kumoriya_resolver_anime_nexus.dart';
import 'package:kumoriya_resolver_doodstream/kumoriya_resolver_doodstream.dart';
import 'package:kumoriya_resolver_filemoon/kumoriya_resolver_filemoon.dart';
// import 'package:kumoriya_resolver_hqq/kumoriya_resolver_hqq.dart';
import 'package:kumoriya_resolver_jkplayer/kumoriya_resolver_jkplayer.dart';
import 'package:kumoriya_resolver_mediafire/kumoriya_resolver_mediafire.dart';
// import 'package:kumoriya_resolver_mixdrop/kumoriya_resolver_mixdrop.dart';
// import 'package:kumoriya_resolver_mp4upload/kumoriya_resolver_mp4upload.dart';
import 'package:kumoriya_resolver_okru/kumoriya_resolver_okru.dart';
import 'package:kumoriya_resolver_pixeldrain/kumoriya_resolver_pixeldrain.dart';
import 'package:kumoriya_resolver_streamtape/kumoriya_resolver_streamtape.dart';
import 'package:kumoriya_resolver_streamwish/kumoriya_resolver_streamwish.dart';
import 'package:kumoriya_resolver_upnshare/kumoriya_resolver_upnshare.dart';
import 'package:kumoriya_resolver_vidhide/kumoriya_resolver_vidhide.dart';
// import 'package:kumoriya_resolver_voe/kumoriya_resolver_voe.dart';
import 'package:kumoriya_resolver_yourupload/kumoriya_resolver_yourupload.dart';
import 'package:kumoriya_resolver_zilla/kumoriya_resolver_zilla.dart';
import 'package:kumoriya_source_anime_nexus/kumoriya_source_anime_nexus.dart';
import 'package:kumoriya_source_animeav1/kumoriya_source_animeav1.dart';
import 'package:kumoriya_source_animeflv/kumoriya_source_animeflv.dart';
import 'package:kumoriya_source_jkanime/kumoriya_source_jkanime.dart';

import '../../../player/infrastructure/native_anime_nexus_bypass_resolver.dart';

List<SourcePlugin> buildDefaultSourcePlugins() {
  return <SourcePlugin>[
    JkAnimeSourcePlugin(),
    AnimeFlvSourcePlugin(),
    AnimeAv1SourcePlugin(),
    AnimeNexusSourcePlugin(),
  ];
}

List<ResolverPlugin> buildDefaultResolverPlugins({http.Client? httpClient}) {
  return <ResolverPlugin>[
    // Native bypass for anime.nexus — Android only. Outputs the
    // `kumoriya-native://anime-nexus?watch=…` carrier URL that
    // [KumoriyaExoPlayerEngine] detects and routes into the in-process
    // HTTP+WS bootstrap (Fase 2), avoiding the ~10-14 s cold-start tax
    // of the legacy Dart loopback proxy. Its declared priority (200)
    // is higher than [AnimeNexusResolverPlugin]'s (120), so the
    // registry picks it first whenever both support the URL.
    //
    // Desktop / iOS stay on the legacy resolver because media_kit does
    // not understand the `kumoriya-native://` carrier scheme. Adding
    // the bypass unconditionally would break playback on those
    // platforms.
    if (Platform.isAndroid) const NativeAnimeNexusBypassResolver(),
    AnimeNexusResolverPlugin(),
    JkPlayerJkResolverPlugin(httpClient: httpClient),
    JkPlayerResolverPlugin(httpClient: httpClient),
    StreamwishResolverPlugin(httpClient: httpClient),
    // MP4Upload disabled: CDN too slow for acceptable user experience.
    // Mp4uploadResolverPlugin(),
    PixeldrainResolverPlugin(httpClient: httpClient),
    StreamtapeResolverPlugin(httpClient: httpClient),
    DoodstreamResolverPlugin(httpClient: httpClient),
    YouruploadResolverPlugin(httpClient: httpClient),
    OkruResolverPlugin(httpClient: httpClient),
    // HQQ disabled: 0/12 success — requires visual captcha challenge.
    // HqqResolverPlugin(),
    UpnshareResolverPlugin(httpClient: httpClient),
    ZillaResolverPlugin(httpClient: httpClient),
    // VOE disabled: 0/12 success — requires runtime JS session token.
    // VoeResolverPlugin(),
    // MixDrop disabled: CDN rejects playback despite valid resolution.
    // MixdropResolverPlugin(),
    FilemoonResolverPlugin(httpClient: httpClient),
    VidhideResolverPlugin(httpClient: httpClient),
    MediafireResolverPlugin(httpClient: httpClient),
  ];
}
