# kumoriya_exoplayer

Kumoriya native Android playback plugin built on AndroidX Media3 / ExoPlayer.

Replaces `video_player` and `media_kit` on Android and eventually owns
downloads, notifications, Chromecast and PiP. Other platforms get
`UnimplementedError` stubs — iOS, Windows, Linux and macOS are **out of
scope**.

Scope, phases, gates and risks are tracked in `docs/kumoriya-exoplayer-plan.md`.

## Fase actual

**Fase 1 ✅ — playback core**. `KumoriyaExoPlayerController` monta un
`ExoPlayer` nativo, lo renderiza a `Texture(textureId: ...)` y expone
`open` / `play` / `pause` / `seekTo` / `setVolume` / `setPlaybackSpeed`
más streams tipados de estado (`playing`, `buffering`, `position`,
`duration`, `completed`, `error`). Auto-detección HLS / DASH / MP4 via
`DefaultMediaSourceFactory`. Gate runtime cerrado en device: Zilla,
AnimeNexus y Streamwish reproducen vía el playground nativo del app.
Tracks embebidos, subs, Cast y downloads llegan en fases posteriores.

