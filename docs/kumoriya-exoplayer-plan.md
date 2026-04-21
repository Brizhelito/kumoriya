# Kumoriya ExoPlayer — Plan Maestro del Plugin Nativo

> Documento vivo. Registra el alcance, justificación, fases y criterios de done para el plugin Android `kumoriya_exoplayer` que reemplazará a `video_player` (y a media_kit en Android) como motor de reproducción.

**Estado:** Fase 0 ✅, Fase 1 ✅, Fase 2 ✅ (port nativo a Kotlin completo verificado en device: bootstrap + WS Socket.IO v4 + DataSource firmado reproducen anime.nexus sin proxy Dart). **Fase 2b en hardening — native engine detrás del playground, flow real sigue en `ExoPlayerPlaybackEngine` (legacy `video_player`) hasta cerrar el gate de promoción (§ 11).**
**Última actualización:** 2026-04-20
**Owner:** @reny
**Plataforma:** Android exclusivo (API 21+, target 34). iOS, Windows y Linux **fuera de alcance definitivo**. Desktop sigue con `media_kit`, iOS con stubs `UnimplementedError`.

---

## 1. Motivación

### Por qué migrar de `video_player` + `media_kit` a un plugin propio

| Problema hoy | Causa raíz | Se resuelve con plugin propio |
|---|---|---|
| AnimeNexus necesita proxy HTTP loopback para inyectar headers/cookies | `video_player` no expone `DataSource` custom | `DataSource.Factory` nativo en Kotlin |
| AV1 en Zilla lento en media_kit (dav1d software) | libmpv no siempre usa MediaCodec del device | ExoPlayer va directo a MediaCodec nativo |
| Subtítulos externos limitados, sin selección de tracks embebidos | `video_player` no expone `TrackSelector` | `MappingTrackSelector` completo |
| No hay Picture-in-Picture real | media_kit/video_player no integran PiP de Android | `PictureInPictureParams` + `MediaSession` |
| Sin Chromecast | Ninguno de los motores actuales lo soporta | `media3-cast` + `CastPlayer` |
| Sin descargas offline robustas | Tenemos que hacer todo a mano | `DownloadManager` + `SimpleCache` |
| URLs firmadas (MediaFire/Filemoon) expiran mid-playback | No hay hook para refresh | Intercept 403/410 → re-resolve desde Dart |
| Boost de volumen tipo mpv distorsiona | `volume > 100` clipea | `LoudnessEnhancer` + `DynamicsProcessing` |
| Sin overlay de diagnóstico nativo | No hay acceso a métricas reales del decoder | `AnalyticsListener` |
| Sync de watch party corta audio con seek | Solo tenemos `seek` como herramienta | Speed ramp 0.98x/1.02x hasta converger |

### Wins principales (orden de valor)

1. **Matar el proxy de AnimeNexus** — ~2000 LOC Dart fuera, cero sockets locales, menos batería, sin problemas de cleartext/network-security.
2. **Descargas offline nativas** — feature premium real, justifica tier pago.
3. **Chromecast** — feature que ningún cliente anime en Flutter hace bien.
4. **Audio boost para voces** — calidad percibida mucho mejor en AnimeNexus ES.
5. **PiP + watch party emoji overlay** — experiencia única.

### No objetivos explícitos

- **iOS**: fuera de alcance. Stubs `UnimplementedError`.
- **Windows / Linux / macOS**: fuera de alcance **definitivo**. Desktop se queda con `media_kit`. No se evalúa plugin alternativo.
- **Compilar FFmpeg/libmpv propio**: no.
- **Basarnos en `better_player` o `fvp`**: no. Plugin propio desde cero.

---

## 2. Arquitectura

### 2.1 Estructura del package

```
packages/kumoriya_exoplayer/
├── pubspec.yaml
├── android/
│   ├── build.gradle
│   └── src/main/kotlin/dev/kumoriya/exoplayer/
│       ├── KumoriyaExoPlayerPlugin.kt         # FlutterPlugin + MethodCallHandler
│       ├── PlayerInstance.kt                  # 1 ExoPlayer + 1 SurfaceTexture por textureId
│       ├── PlayerRegistry.kt                  # Map<textureId, PlayerInstance>
│       ├── datasource/
│       │   ├── KumoriyaDataSourceFactory.kt   # Headers/cookies desde Dart
│       │   └── UrlRefreshInterceptor.kt       # Hook 403/410 → callback Dart
│       ├── audio/
│       │   ├── LoudnessBoost.kt
│       │   └── VoiceClarityProcessor.kt       # DynamicsProcessing preset voz
│       ├── tracks/
│       │   └── TrackSelectorBridge.kt
│       ├── subtitles/
│       │   └── ExternalSubtitleAdapter.kt
│       ├── cast/
│       │   └── CastSessionBridge.kt
│       ├── pip/
│       │   └── PipController.kt
│       ├── session/
│       │   └── KumoriyaMediaSession.kt
│       ├── analytics/
│       │   └── PlayerAnalyticsDispatcher.kt
│       └── downloads/
│           ├── KumoriyaDownloadService.kt
│           ├── DownloadsRegistry.kt
│           └── OfflineDataSourceFactory.kt
├── lib/
│   ├── kumoriya_exoplayer.dart                # API pública
│   ├── src/
│   │   ├── kumoriya_exoplayer_controller.dart
│   │   ├── events/                            # PlaybackEvent, AnalyticsEvent, DownloadEvent
│   │   ├── models/                            # TrackInfo, SubtitleTrack, DownloadSpec
│   │   ├── platform_interface.dart            # MethodChannel + EventChannel
│   │   └── noop/                              # iOS/desktop stubs
└── test/
```

### 2.2 Canales de comunicación

- **MethodChannel** `dev.kumoriya.exoplayer/methods` — comandos síncronos (open, play, pause, seek, selectTrack, enqueueDownload, startCast, etc.).
- **EventChannel por textureId** `dev.kumoriya.exoplayer/events/<id>` — stream de `PlaybackEvent` (ready, buffering, position, error, trackChanged).
- **EventChannel** `dev.kumoriya.exoplayer/analytics/<id>` — métricas de diagnóstico (fps, drops, codec, bitrate, bandwidth).
- **EventChannel** `dev.kumoriya.exoplayer/downloads` — progreso global de descargas.
- **MethodChannel inverso** `dev.kumoriya.exoplayer/callbacks` — Kotlin llama a Dart para refresh de URL firmada.

### 2.3 Integración con la app

- Mantenemos la interfaz `PlaybackEngine` existente.
- Se agrega `KumoriyaExoPlayerPlaybackEngine implements PlaybackEngine`.
- `playback_engine_factory.dart` en Android:
  1. `KumoriyaExoPlayerPlaybackEngine` (default).
  2. Feature flag `USE_LEGACY_EXOPLAYER` para forzar `video_player` en caso de regresión.
  3. Feature flag `USE_MEDIA_KIT_ANDROID` para el playground A/B.
- `PlayerVideoSurface` agrega rama para `KumoriyaExoPlayerPlaybackEngine` que usa `Texture(textureId: ...)`.

---

## 3. Roadmap por fases

Cada fase tiene: **alcance**, **gate de done**, **riesgo**, **LOC estimado**.

### Fase 0 — Scaffolding (M0)
- **Alcance:** package con pubspec, Gradle, Kotlin plugin registrado, `MethodChannel` con `create()` que devuelve `textureId`, Dart controller vacío, stubs iOS/desktop.
- **Gate:** Flutter llama `KumoriyaExoPlayerController.create()`, Kotlin responde con id, surface texture viva.
- **Riesgo:** bajo. Solo plumbing.
- **LOC:** ~400.

### Fase 1 — Playback core (M1)
- **Alcance:** `open(url, headers)`, play, pause, seek, setVolume, setSpeed, dispose. Estado emitido por EventChannel. `MediaSource` DASH/HLS/MP4 auto-detect. Renderizado a `SurfaceTexture`.
- **Gate:** reproduce Zilla + anime.nexus + Streamwish sin regresión vs `ExoPlayerPlaybackEngine` actual. Playground A/B confirma paridad o mejora.
- **Riesgo:** medio. Binding Surface ↔ Flutter texture.
- **LOC:** ~900.

### Fase 2 — AnimeNexus nativo / proxy killer (M7)
- **Alcance:** `KumoriyaDataSourceFactory` acepta `Map<String,String>` de headers + cookies por request. `KumoriyaExoPlayerController.open` recibe `requestHeaders` y `cookies`. Se elimina `local_proxy_server.dart`, `anime_nexus_proxy_*`, todo el stack HTTP loopback.
- **Gate:** AnimeNexus reproduce igual o mejor que hoy, `lsof -iTCP` en debug build no muestra sockets locales del proxy, `flutter analyze` limpio, 2000+ LOC Dart eliminadas.
- **Riesgo:** medio-alto. Hay que replicar todo lo que hacía el proxy (redirects, retries, cookie jar).
- **LOC:** neto **negativo** (~-1500).

### Fase 3 — Audio tracks embebidos (M2/M3)
- **Alcance:** enumerar audio tracks embebidos vía `MappingTrackSelector`, API Dart `listAudioTracks()` / `selectAudioTrack(id)`. Switch sin reabrir stream, posición preservada. Exponer metadata: idioma, codec, sample rate, channels, label.
- **Gate:** en AnimeNexus cambiás audio JP↔ES sin recarga; `ffprobe` confirma track activo.
- **Riesgo:** medio (API de TrackSelector verbosa).
- **LOC:** ~400.

### Fase 3b — Subtítulos completos (embebidos + externos + styling)
- **Alcance:**
  - **Embebidos:** listado y selección de text tracks del contenedor (HLS `#EXT-X-MEDIA:TYPE=SUBTITLES`, MKV, MP4 tx3g) vía `TrackSelector`.
  - **Externos:** `MergingMediaSource` con `SingleSampleMediaSource` para **WebVTT, SRT, ASS/SSA**. Fetch con headers custom para sources que lo requieran (AnimeNexus). Soporte por **URL** o por **bytes inline** (cuando el resolver ya los tiene en memoria).
  - **Múltiples pistas externas simultáneas:** API acepta `List<SubtitleTrack>` y usuario elige cuál mostrar.
  - **Styling configurable desde Dart:**
    - Tamaño de fuente (S/M/L/XL o escala %)
    - Color de texto y color de fondo (con alpha)
    - Borde/sombra (edge type: outline, drop shadow, depressed, raised)
    - Familia tipográfica (system / sans / serif / mono)
    - Posición vertical (bottom offset %) para evitar tapar subs baked-in.
  - **Accesibilidad:** respeta `CaptioningManager` del sistema si el user no sobreescribe.
  - **Sync offset:** `setSubtitleOffsetMs(int)` para adelantar/atrasar subs en vivo (±10 s típico).
  - **ASS/SSA:** render básico (texto + timing). Tags avanzados (posicionamiento, karaoke) quedan fuera de scope inicial, se documenta.
- **Gate:**
  - AnimeNexus con VTT externo fetched con headers custom → se muestra.
  - Episodio con 2 subs externos (ES + EN) → usuario alterna.
  - Slider de offset corrige desync sin pausar.
  - Cambios de styling aplican en caliente.
- **Riesgo:** medio. ASS/SSA render completo sería alto; lo acotamos.
- **LOC:** ~700.

### Fase 4 — Audio boost voz (M4)
- **Alcance:**
  - `LoudnessEnhancer` para ganancia global en mB.
  - `DynamicsProcessing` (API 28+) con preset **voice clarity**: compresor suave + EQ paramétrico que levanta 1–4 kHz (rango de diálogo) y atenúa <120 Hz.
  - API Dart: `setOverallGainDb(double)`, `setVoiceClarity(double 0..1)`.
  - Fallback en API <28: solo `LoudnessEnhancer`.
- **Gate:** volumen >100% sin clipping audible en AnimeNexus ES; slider de voice clarity mejora inteligibilidad en clips con música fuerte.
- **Riesgo:** bajo-medio. Tuning de EQ requiere iteración con oído.
- **LOC:** ~400.

### Fase 5 — Diagnostics overlay (M5)
- **Alcance:** `AnalyticsListener` → EventChannel con fps, dropped frames, codec name + HW/SW flag, bitrate instantáneo, buffer health ms, bandwidth estimate, video size, audio format.
- **Gate:** overlay en debug muestra métricas en tiempo real; se puede togglear en settings.
- **Riesgo:** bajo.
- **LOC:** ~600 (Kotlin + widget Flutter).

### Fase 6 — PiP + MediaSession + Watch Party Overlay (M6)
- **Alcance:**
  - `PictureInPictureParams` con acciones play/pause/skip.
  - `MediaSessionCompat` para lockscreen, Bluetooth, Android Auto.
  - **Watch Party emoji overlay en PiP**: render custom con `RemoteViews` o capa dibujada sobre el Surface mostrando los emojis reaccionando en tiempo real desde el `WatchPartyRealtime` stream.
- **Gate:** PiP funciona, controles BT funcionan, emojis de party aparecen sobre el video también en PiP.
- **Riesgo:** medio. El overlay en PiP es limitado por Android (no podés poner Flutter widgets encima del Surface en PiP).
- **LOC:** ~800.

### Fase 7 — Chromecast (nuevo)
- **Alcance:**
  - `media3-cast` + Google Cast SDK.
  - Botón Cast en UI (`MediaRouteButton`).
  - `CastPlayer` swappeable con el ExoPlayer local; preserva posición, audio track, sub track.
  - **Limitación documentada:** AnimeNexus y cualquier source que dependa de headers custom o del proxy local **no puede castearse** (la TV no tiene acceso). Se detecta y se deshabilita el botón con tooltip explicando. Sources públicos (Zilla, Streamwish sin firma corta, etc.) funcionan.
- **Gate:** castear Zilla a Chromecast desde el teléfono, controlar play/pause/seek desde el teléfono, volver al phone player preservando posición.
- **Riesgo:** medio. Cast tiene muchos edge cases (disconnects, sesiones zombie).
- **LOC:** ~700.

### Fase 8 — URL refresh + watch party drift (M8/M9)
- **Alcance:**
  - Interceptor HTTP: ante 403/410/401, llama a Dart `onUrlExpired(oldUrl)` → Dart re-resuelve via resolver → devuelve nueva URL → ExoPlayer hace `setMediaItem` preservando posición.
  - Watch party drift: API `applySpeedRamp(targetDriftMs)` que ajusta `PlaybackParameters(speed)` a 0.98x/1.02x hasta converger y vuelve a 1.0x. Reemplaza al `seek` correctivo.
- **Gate:** MediaFire no muere en pausa larga; watch party sync no corta audio.
- **Riesgo:** medio. Timing del ramp requiere tuning.
- **LOC:** ~500.

### Fase 9 — Offline downloads (M11)
- **Alcance:**
  - `DownloadManager` + `DownloadService` foreground + notificación nativa.
  - `SimpleCache` con LRU + quota configurable.
  - API Dart: `enqueue(spec)`, `pause(id)`, `resume(id)`, `cancel(id)`, `list()`, `progress$` stream, `playOffline(id)`.
  - Soporte HLS/DASH: selector de calidad al enqueue (downloads `RepresentationKey` específicos).
  - Reproducción offline: mismo `KumoriyaExoPlayerController` detecta cache hit y usa `CacheDataSource` en vez de network.
  - Persistencia de metadata en Drift (título, poster, episodio, spec, status).
  - Sobrevive reboot, pausa/reanuda automática con cambio de red.
- **Gate:**
  - Descargar episodio de Zilla 720p, cerrar app, reabrir, reproducir sin red.
  - Pausar/reanudar funciona.
  - Notificación muestra progreso real.
  - Borrar descarga limpia cache y DB.
- **Riesgo:** alto. Es la fase más grande. Requiere UI nueva, storage slice, integración con settings (quota), tests.
- **LOC:** ~2500 (Kotlin + Dart + UI).

### Fase 9b — Features transversales (tocan varias fases, se completan al final)

Features que no merecen fase propia pero deben existir al cierre del plugin. Se implementan incrementalmente dentro de las fases previas o en una barrida final.

- **Aspect ratio modes:** `fit`, `fill`, `cover`, `16:9`, `4:3`, `zoom 1.1x`, pan manual. Expuesto via `setAspectRatioMode()`.
- **Audio sync offset:** `setAudioOffsetMs(int)` (±2 s) para corregir desync de audio en sources feos.
- **Frame step:** `stepForward()` / `stepBack()` cuadro a cuadro cuando está pausado.
- **Screenshot / frame capture:** `captureFrame() -> Uint8List` PNG del frame actual (útil para reportes de bug y share).
- **Preload / gapless next episode:** API `preload(nextUrl, headers)` que arma un `MediaSource` secundario; al terminar el actual, swap inmediato.
- **ABR controls (HLS/DASH):** `setMaxBitrate`, `setMinBitrate`, `forceQuality(height)`, `autoQuality()`. Default: auto.
- **Buffer tuning:** exponer `minBufferMs`, `maxBufferMs`, `bufferForPlaybackMs`, `bufferForPlaybackAfterRebufferMs`. Presets: `low_latency`, `balanced` (default), `high_buffer` (redes inestables).
- **Retry policy:** backoff exponencial configurable ante errores de red transitorios antes de escalar a Dart.
- **User-Agent / headers globales:** override por open() y default por app.
- **Cookies jar persistente:** coordinado con Fase 2 (proxy killer). Survive restarts.
- **TLS/JA3 fingerprint mimicking:** usar OkHttp con `ConnectionSpec` + `CipherSuite` custom para emular browsers en sources que bloquean clientes no-browser. (Spike antes de comprometer.)
- **Background audio mode:** seguir reproduciendo solo audio cuando pantalla se apaga (separado de PiP). Toggle en settings.
- **Sleep timer:** parte de UI, pero plugin expone `pauseAfter(duration)` para no depender de timers Dart que mueren en background.
- **Wake lock inteligente:** solo mientras reproduce, liberado en pausa/PiP.
- **Thumbnail scrubbing (opcional, post-v1):** si el source provee storyboard VTT, mostrar preview al hacer seek.
- **Equalizer presets (opcional):** `flat`, `voice`, `bass_boost`, `treble_boost`, `custom (5-band)`. `voice` coincide con voice-clarity de Fase 4.
- **Error taxonomy estructurada:** enum `KumoriyaPlayerError` (network, decoder, drm, source_gone, unsupported_codec, timeout) + payload con detalles, en vez de strings.
- **Locale-aware:** mensajes de error y labels de tracks respetan idioma de la app.

---

## 4. Dependencias externas nuevas

Android (`build.gradle`):
```
androidx.media3:media3-exoplayer:1.4.x
androidx.media3:media3-exoplayer-hls:1.4.x
androidx.media3:media3-exoplayer-dash:1.4.x
androidx.media3:media3-datasource-okhttp:1.4.x     // headers custom
androidx.media3:media3-cast:1.4.x                   // Fase 7
androidx.media3:media3-session:1.4.x                // Fase 6
androidx.media3:media3-ui:1.4.x
androidx.media3:media3-exoplayer-workmanager:1.4.x  // Fase 9
com.google.android.gms:play-services-cast-framework:21.x  // Fase 7
```

Dart:
- Ninguna nueva obligatoria en fases 0–8. Fase 9 podría agregar `path_provider` si no está ya.

---

## 5. Feature flags y rollout

| Flag | Default | Propósito |
|---|---|---|
| `player.engine.kumoriya_exoplayer` | `true` en Android tras Fase 1 | Activa el plugin nuevo |
| `player.engine.fallback_video_player` | `false` | Kill switch ante regresión |
| `player.downloads.enabled` | `false` hasta Fase 9 estable | Feature gate de offline |
| `player.cast.enabled` | `false` hasta Fase 7 estable | Feature gate de Cast |
| `player.audio.voice_clarity.enabled` | `true` tras Fase 4 | |
| `player.debug.analytics_overlay` | controlado por toggle en settings debug | |

Rollout sugerido:
1. Fases 0–2 detrás de flag en builds internos (playground A/B).
2. Flag a `true` para AnimeNexus solamente (el del proxy).
3. Flag a `true` global una vez que Fase 3 está verde.
4. Eliminar `video_player` del `pubspec` cuando todo lo anterior lleva 2 releases estables.

---

## 6. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Regresión de performance vs video_player actual | Alto | Playground A/B obligatorio en cada PR de Fase 1 |
| SurfaceTexture ↔ Flutter texture lag/tearing | Medio | Benchmark fps en device real antes de cerrar Fase 1 |
| Cast con sources privados confunde al usuario | Medio | UI deshabilita botón Cast + tooltip explicativo |
| Quota de descargas llena el device | Alto | Quota configurable + aviso proactivo + cleanup LRU |
| Cambios de API Media3 entre versiones | Medio | Pin de versión; upgrade controlado |
| iOS builds rompen por stubs | Medio | CI ejecuta `flutter build ios` aunque sea sin firma |
| Crash nativo tira toda la app | Alto | `ErrorHandler` global + reporte estructurado a Dart antes de crash |

---

## 7. Testing strategy

- **Unit tests Dart:** `KumoriyaExoPlayerController` con `MethodChannel` mockeado.
- **Instrumentation tests Kotlin:** abrir URL de test fixture, assert estado ready.
- **Integration tests Flutter:** golden flow de AnimeNexus, Zilla, Streamwish en el playground.
- **Manual gates por fase:** documentados arriba, ejecutados en moto g72 (`192.168.0.214:5555`) y emulator API 34.
- **Regression matrix:** tras cada fase, correr playground completo con todos los resolvers, comparar `first_progress_ms` vs baseline, no permitir >10% de regresión.

---

## 8. Entregables de documentación por fase

Cada fase cierra con:
1. Entry en `docs/dev-diary/YYYY-MM-DD.md` (skill `dev-diary`).
2. Update de `CHANGELOG.md` (skill `changelog-release-notes`).
3. Update de este documento marcando la fase como ✅.
4. Si hay decisión arquitectónica, ADR en `docs/architecture/`.

---

## 9. Open questions

- ¿Quota default de descargas? Sugerido: 4 GB, configurable 1–32 GB.
- ¿Permitir descargas solo en Wi-Fi por default? Sí, con toggle.
- ¿Emoji overlay en PiP — dibujar sobre Surface o RemoteViews? Decidir en Fase 6 tras spike.
- ¿Cast receiver custom para AnimeNexus? Aplazado post-Fase 7.
- ¿Migrar también el player del watch party host? Sí, mismo engine.

---

## 10. Checklist de cierre total

- [x] Fase 0 — scaffolding (package, MethodChannel, `create/dispose/ping`, `PlayerRegistry`, runtime Android verificado en moto g72)
- [x] Fase 1 — playback core (ExoPlayer + Surface + eventos tipados, API open/play/pause/seek/setVolume/setSpeed; gate runtime verificado: Zilla, AnimeNexus y Streamwish reproducen en el playground nativo en moto g72)
- [x] Fase 2 — proxy killer (port completo a Kotlin: bootstrap HTTP + WS Socket.IO v4 + `NexusDataSource` firmando por-request; `openAnimeNexus(watchUrl)` expuesto en API; runtime verificado en moto g72 contra anime.nexus real; próximo paso: borrar el proxy Dart `playback_proxy_server.dart` ~5000 LOC)
- [~] Fase 3 — audio tracks embebidos (Kotlin `emitAudioTracksEvent` + `selectAudioTrack` + Dart `AudioTrack`/`audioTracksStream`/`selectAudioTrack` + wiring a `EmbeddedTracks` stream del engine listos; falta runtime gate con un stream multi-audio real en anime.nexus ES/JP para confirmar switch sin recarga y `ffprobe` del track activo)
- [~] Fase 3b — subtítulos completos (embebidos + externos + styling + offset) (enumeración + selección + clear de embebidos listos; sideload externo VTT/SRT/ASS por URL vía `MergingMediaSource` preservando posición listo; pendiente: styling/edgeType/fuente/posición, offset, accesibilidad `CaptioningManager`, ASS rendering avanzado, soporte de `data` inline para subtítulos in-memory — cada uno merece su propia slice)
- [~] Fase 4 — audio boost voz (Kotlin `LoudnessEnhancer` + `DynamicsProcessing` preset 3-band voz; API Dart `setOverallGainDb(db)` + `setVoiceClarity(0..1)` en controller; engine `setSmartAudioBoost(enabled)` mapea a +6 dB / 0.7 clarity cuando se enciende; pendiente: gate runtime con oído en AnimeNexus ES para tunear números finales, fallback API<28 documentado)
- [~] Fase 5 — diagnostics overlay (Kotlin `DiagnosticsCollector` implementa `AnalyticsListener` con frame drops, codec, decoder, HW flag, audio format, bandwidth; `setDiagnosticsEnabled(enabled)` adjunta/desmonta el listener y polling de 1 Hz con evento `diagnostics`; Dart `DiagnosticsSnapshot` + `DiagnosticsReport` + `controller.diagnosticsStream`; engine `KumoriyaExoPlayerEngine.diagnosticsStream` mapea onto `PlayerDiagnostics` con lazy-enable via `onListen` para no pagar el costo cuando el overlay está cerrado; pendiente: widget overlay Media3-aware, campos extra de FPS real si aparecen)
- [ ] Fase 6 — PiP + MediaSession + party overlay
- [ ] Fase 7 — Chromecast
- [~] Fase 8 — URL refresh + drift (Kotlin detecta 401/403/410 en `onPlayerError` y emite `urlExpired` con la URL base; `swapUrl(url, headers, mimeType, startPositionMs)` preserva posición; Dart `UrlExpired` event + `swapUrl` en controller + hook `UrlExpiredResolver` en `KumoriyaExoPlayerEngine`; pendiente: wiring con el resolver chain del orchestrator para cerrar el gate MediaFire, speed ramp `applySpeedRamp` para watch party drift)
- [ ] Fase 9 — offline downloads
- [ ] Fase 9b — features transversales (aspect ratio, preload, ABR, TLS, etc.)
- [x] Engine nativo promovido a default Android — `createPlaybackEngine` devuelve `KumoriyaExoPlayerEngine` en `Platform.isAndroid`; `buildDefaultResolverPlugins` antepone `NativeAnimeNexusBypassResolver` solo en Android (priority 200 > 120 legacy); test de regresión en `test/plugin_runtime_catalog_test.dart` pin el orden. Flip DURO sin feature flag — decidido explícitamente por el usuario 2026-04-20 contra mi recomendación. Riesgos residuales abiertos: runtime gates de Fase 3/3b/4/5 no corridos en device, MediaFire va a fallar hasta cerrar el wiring de Fase 8 con el orchestrator, Desu/Magi nunca smokeados con este engine.
- [ ] `video_player` removido del `pubspec` (pendiente hasta cerrar los gates runtime arriba)
- [ ] `local_proxy_server` removido
- [ ] CHANGELOG + release notes publicados
- [ ] ADR final cerrando la migración

---

## 11. Gate de promoción del engine nativo a default en Android

**Estado 2026-04-20 (tarde):** el usuario re-promovió `KumoriyaExoPlayerEngine` como default Android **sin correr los gates abajo**, explícitamente contra mi recomendación. Los criterios siguen siendo los correctos — quedan listados acá como deuda de validación pendiente, no como puerta a re-cruzar.

### Estado actual del routing (post-promoción dura, sin gates completos)

```
@apps/kumoriya_app/lib/src/features/player/infrastructure/playback_engine_factory.dart
  Android  → KumoriyaExoPlayerEngine(onDebugLog: ...)   // nativo, Fase 3/3b/4/5/8 plumbing
  Desktop  → MediaKitPlaybackEngine(...)                // libmpv

@apps/kumoriya_app/lib/src/features/anime_catalog/application/services/plugin_runtime_catalog.dart
  if (Platform.isAndroid) NativeAnimeNexusBypassResolver()   // priority 200
  AnimeNexusResolverPlugin()                                 // priority 120, fallback desktop/iOS
  ...
```

Regresión test nueva: `@apps/kumoriya_app/test/plugin_runtime_catalog_test.dart:7-33` pin el orden — native bypass gana en Android, legacy gana elsewhere.

Rollback: revertir `playback_engine_factory.dart` a `ExoPlayerPlaybackEngine()` y quitar el `if (Platform.isAndroid)` del catálogo. Cambios son auto-contenidos y reversibles en un commit.

### Regresiones **no re-verificadas** en esta promoción

Las regresiones listadas abajo se documentaron en la promoción fallida previa. Algunas fueron arregladas en código (aspect ratio, UA header matching con `video_player_android`), pero **ninguna** se validó visualmente en device en esta ventana. Si el usuario ve algo roto: rollback inmediato, no debugging online.

### Regresiones detectadas al promover

1. **Aspect ratio del surface roto** — el `Texture` widget de `@apps/kumoriya_app/lib/src/features/player/presentation/widgets/player_video_surface.dart:49-53` no envuelve con `AspectRatio` (legacy sí lo hace). Video sale estirado a `BoxFit.contain` del padre. **Pendiente, no arreglado todavía.** Mitigación actual: volver a legacy ya restaura el surface con aspect ratio correcto.
2. **Desu/Magi timeouts de apertura** — `nika.playmudos.com` (CDN JKPlayer) está detrás de un Cloudflare bot-challenge silencioso intermitente (TLS OK, request enviado, server nunca manda headers). Diagnóstico de ese día:
   - TCP + TLS 1.3 + HTTP/2 negocian bien desde PC y desde phone.
   - Ping ICMP a `nika.playmudos.com` OK.
   - `GET /` con cualquier UA → timeout de 8 s sin bytes.
   - `jkanime.net` (misma Cloudflare) responde 200.
   - Error en Media3: `UnknownHostException (no network)` — mensaje engañoso; realmente es read timeout del response body, no fallo de DNS.
   - No es culpa del engine nativo: legacy `video_player` también timeouteaba durante la ventana de challenge.
3. **Diferencia sutil de configuración HTTP vs `video_player_android`** — antes del rollback el engine nativo construía `DefaultHttpDataSource.Factory` sin `setUserAgent(...)` y metía UA en `setDefaultRequestProperties(...)`. Media3 `DefaultHttpDataSource.open()` deja que el campo `userAgent` **override** cualquier UA de `defaultRequestProperties`. Ya corregido: `@packages/kumoriya_exoplayer/android/src/main/kotlin/dev/kumoriya/exoplayer/PlayerInstance.kt` ahora replica byte-a-byte el patrón del plugin legacy (`setUserAgent("ExoPlayer")` + headers sin UA en `defaultRequestProperties`). Pendiente: validar in-device cuando Cloudflare suelte el bucket de JKAnime.

### Checklist para re-habilitar el engine nativo como default en Android

- [ ] **Aspect ratio** — envolver el `Texture` en `AspectRatio` con el ratio del primer `onVideoSizeChanged` del player; exponer `videoSizeStream` desde `KumoriyaExoPlayerController`. Tests: reproducir un video 16:9 y uno 4:3 en el playground, verificar que ambos respeten el ratio sin estirar. **Código + tests unitarios 2026-04-20 (sesión noche)**: `PlayerInstance.onVideoSizeChanged` emite `videoSize`, `KumoriyaExoPlayerController.videoSizeStream` fan-out, `KumoriyaExoPlayerEngine.aspectRatio` (ValueNotifier), `PlayerVideoSurface` wrappea el Texture en `AspectRatio`. 5 tests verdes en `packages/kumoriya_exoplayer/test/controller_test.dart`. **Pendiente el gate visual en device** (rebuild + playback de 16:9 y 4:3).
- [ ] **Desu/Magi funcionales** — sweep del Player Flow Playground con `PlaybackEngineKind.kumoriyaExoPlayer` en una ventana donde Cloudflare **no** esté challenging a nika.playmudos. Target: open\_ms < 2 s, first\_playing\_ms < 3 s, paridad o mejor que legacy.
- [ ] **Anime.nexus native end-to-end** — reproducir 3 episodios con `NativeAnimeNexusBypassResolver` activo, verificar que `playback_proxy_server.dart` nunca arranca (grep del log). Confirmar que los logs Kotlin (`adb logcat -s KumoriyaExoPlayer`) muestran bootstrap → WS ready → HlsMediaSource ready en < 3 s.
- [ ] **Audio tracks + subtítulos embebidos** — por lo menos leer pistas disponibles (Fase 3/3b) para no regresar de un set rico a uno vacío vs legacy.
- [ ] **Dispose lifecycle limpio** — navegar al player, volver atrás y entrar a otro episodio sin quedar con texturas zombies (logcat de `SurfaceTexture` sin warnings).
- [ ] **MediaKit fallback** — mantener `media_kit` accesible desde el selector del playground para A/B durante al menos 2 semanas tras la promoción.
- [ ] **Dev diary + CHANGELOG** — documentar la promoción y linkear la evidencia (JSON del sweep, screenshots del playground).

Cuando **todos** estén verdes:

```dart
// apps/kumoriya_app/lib/src/features/player/infrastructure/playback_engine_factory.dart
if (Platform.isAndroid) {
  return KumoriyaExoPlayerEngine();
}
```

Y registrar el bypass globalmente:

```dart
// apps/kumoriya_app/lib/src/features/anime_catalog/application/services/plugin_runtime_catalog.dart
if (!kIsWeb && Platform.isAndroid)
  const NativeAnimeNexusBypassResolver(),
AnimeNexusResolverPlugin(),  // fallback desktop/web
```
