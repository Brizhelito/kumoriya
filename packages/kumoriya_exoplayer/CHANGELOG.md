## 0.0.3

* Fase 2 ✅ — port completo del pipeline anime.nexus a Kotlin verificado
  en device (moto g72). Reproduce anime.nexus sin proxy Dart.
  - Clasificador de URL corregido: reconoce hosts `*.cdn.nexus`
    (`cl1.cdn.nexus`, `us1.cdn.nexus`, …) además de `*.anime.nexus`.
  - Init fMP4 (`<base>_<variant>_init-<track>.mp4`) se firma con
    `getManifestToken` pero se pide con `requestType=segment`
    (mirrorea `_fetchManifestProtectedBytes` del proxy Dart).
  - Media segments (`<base>_<variant>_<NNNN>-<track>.m4s`) se firman
    con `getSegmentToken(variant,segIdx,track)` y `requestType=segment`.
  - Variant manifests (`<base>_<variant>-<track>.m3u8`) con
    `getManifestToken(path)` y `requestType=manifest`.
  - Logcat tags `NexusSession` y `NexusDataSource` con kind + URL por
    request e `InterruptedIOException` degradado a INFO (es cancel de
    ABR, no falla real).
  - Próximo: borrar `playback_proxy_server.dart`, `signed_hls_builder`,
    `playback_session_worker` y friends (~5000 LOC) del resolver Dart.
  - Módulo `dev.kumoriya.exoplayer.nexus` nuevo: `NexusConstants`,
    `NexusBrowserSession`, `NexusCookieJar` (OkHttp `CookieJar`),
    `NexusHttpClient`, `NexusPageScraper`, `NexusStreamDataFetcher`,
    `NexusHlsParser`, `NexusStreamToken`, `NexusWsClient`
    (Socket.IO v4 sobre OkHttp WebSocket), `NexusPlaybackSession`,
    `NexusDataSource` + `NexusDataSourceFactory`.
  - `PlayerInstance.bootstrapNexusSession` / `attachNexusSession`:
    bootstrap off-main, `player.setMediaSource` on-main, con
    `HlsMediaSource.Factory` atado al DataSource firmado.
  - Plugin: método nuevo `openNexus(textureId, watchUrl)` con executor
    IO single-thread y hop a main al final.
  - Dart: `KumoriyaExoPlayerController.openAnimeNexus(watchUrl)` y
    `logStream` para logs nativos; evento `NativeLog` en el parser.
  - Gradle: OkHttp 4.12.0 + kotlinx-coroutines 1.8.1 pinneados.

## 0.0.2

* Fase 1 ✅ — playback core. Gate runtime cerrado en moto g72:
  playground nativo reproduce Zilla, AnimeNexus y Streamwish sin
  regresión vs `ExoPlayerPlaybackEngine`.
  - Kotlin: `PlayerInstance` ahora hospeda un `ExoPlayer` real, lo
    conecta al `SurfaceTexture` de Flutter y reenvía estado (playing,
    buffering, duration, position tick @200 ms, completed, error) a un
    `EventChannel` `dev.kumoriya.exoplayer/events/<id>`.
  - Plugin: nuevos métodos `open`, `play`, `pause`, `seek`, `setVolume`,
    `setSpeed`, ejecutados en el main thread de Android.
  - Android deps: se suman `media3-exoplayer-hls` y `media3-exoplayer-dash`
    para auto-detección HLS/DASH/MP4.
  - Dart: `KumoriyaExoPlayerController` expone streams tipados
    (`playingStream`, `bufferingStream`, `positionStream`,
    `durationStream`, `completedStream`, `errorStream`) y cachea los
    últimos valores; API imperativa completa (`open`, `play`, `pause`,
    `seekTo`, `setVolume`, `setPlaybackSpeed`).
  - Nuevo modelo `PlaybackEvent` sellado con `tryParse` defensivo.
  - Tests Dart: 4 casos cubriendo forwarding, decodificación de eventos,
    cacheo de estado y guardas post-dispose.

## 0.0.1

* Fase 0 — scaffolding. `KumoriyaExoPlayerController.create()` reserves a
  Flutter texture id backed by a real Android `SurfaceTexture` via a
  `PlayerRegistry` keyed by texture id.
