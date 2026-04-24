# APK Size Analysis — Android Release Build

**Fecha:** 2026-04-23
**Contexto:** Post-remoción de `media_kit_libs_android_video` (Fase 9 del downloader rebuild). Medición del tamaño real tras eliminar libmpv / libavcodec / libdav1d del APK Android.

## Tamaños actuales (release, per-ABI)

| ABI | Tamaño APK | Notas |
|---|---|---|
| `armeabi-v7a` | 35.4 MB | Phones 32-bit (<2018) |
| `arm64-v8a` | **42.3 MB** | 95%+ usuarios modernos |
| `x86_64` | 45.1 MB | Emuladores / Chromebooks |

Build command usado:
```bash
flutter build apk --release --split-per-abi \
  --target-platform android-arm,android-arm64,android-x64
```

R8 + resource shrinking activos (`@/home/reny/Projects/Kumoriya/apps/kumoriya_app/android/app/build.gradle.kts`):
```kotlin
release {
    isMinifyEnabled = true
    isShrinkResources = true
    proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
}
```

## Desglose del APK arm64-v8a (42.3 MB)

| Componente | Tamaño | Origen | Reducible? |
|---|---|---|---|
| `libapp.so` | 12.1 MB | Dart AOT compilado | Solo reduciendo deps / código |
| **`libjingle_peerconnection_so.so`** | **11.4 MB** | `flutter_webrtc` (via watch party P2P legacy) | **Sí** — feature flag / remove |
| `libflutter.so` | 11.3 MB | Flutter engine nativo | No |
| `classes.dex` | 7.4 MB | Kotlin/Java bytecode (Media3, OkHttp, Firebase, Drift) | R8 ya activo |
| `libsqlite3.so` | 1.7 MB | sqlite3_flutter_libs (drift) | No — requerido |
| `libsentry.so` | 740 KB | sentry_flutter | Removible si no hay telemetría release |
| `resources.arsc` | 460 KB | Android resources | Ya shrinkReado |
| `hls1.4.10.js` | 374 KB | `media_kit/assets/web/` | Sí — asset solo-web |
| `tika-mimetypes.xml` | 327 KB | `org.apache.tika` via `file_picker` | No — lo usa file_picker |
| `classes2.dex` | 215 KB | Overflow de multi-dex | No |
| `libdartjni.so` | 124 KB | jni interop | No |
| Assets Flutter + resources | ~1 MB | iconos, shaders, NOTICES | Marginalmente shrinkeable |

## Qué ya fue optimizado (2026-04-23)

1. **Removido `media_kit_libs_video` meta-package** en favor de `media_kit_libs_linux` + `media_kit_libs_windows_video` + `media_kit_libs_macos_video` explícitos.
   - Ahorro: ~30-50 MB por ABI en `.so` nativos (libmpv, libavcodec, libavformat, libswresample, libswscale, libavutil, libdav1d).
   - APK Android ya no carga código libmpv — playback va 100% por `kumoriya_exoplayer` (Media3).
   - `MediaKit.ensureInitialized()` gateado con `!Platform.isAndroid` en `@/home/reny/Projects/Kumoriya/apps/kumoriya_app/lib/main.dart:83-89`.

2. R8 full mode + resource shrinking activos desde el inicio.
3. Tree-shaking de MaterialIcons (1.6 MB → 22 KB, −98.6%).

## Oportunidades pendientes (ordenadas por ROI)

### 1. Migrar a Android App Bundle (AAB) — ROI altísimo, 0 riesgo

`flutter build appbundle --release` en vez de `flutter build apk`. Google Play genera APKs split-per-device automáticamente (ABI + language + density + dynamic features). Usuario real descarga **~25-30 MB** en vez de 42 MB, sin tocar código.

**Requisito:** publicar vía Play Console (no sideload). Para sideload seguir generando `.apk` universal o split-per-abi.

### 2. Remover `flutter_webrtc` — −11.4 MB arm64

Dep usado solo por Watch Party legacy (P2P mesh) en:
- `@/home/reny/Projects/Kumoriya/apps/kumoriya_app/lib/src/features/watch_party/infrastructure/webrtc_peer_manager.dart`
- `@/home/reny/Projects/Kumoriya/apps/kumoriya_app/lib/src/features/watch_party/application/party_sync_engine.dart`
- Tests: `watch_party_p2p_sync_*_test.dart`

El código hace referencia a un flag `kWatchPartyRealtimeV2` sugiriendo que ya existe un reemplazo server-side. Si la v2 cubre el caso de uso, el P2P es candidato de eliminación completa.

**Impacto estimado:**
- APK `.so`: −11.4 MB arm64, −6.5 MB armv7, −12.7 MB x86_64
- Código Dart: reducción de ~1 MB de `libapp.so` (código WebRTC + signaling + sync engine)
- Tests: 2 archivos de watch party P2P específicos a borrar

**Pre-requisito:** confirmar que Watch Party v2 está en producción y cubre los mismos flujos (playback sync, room control, reactions).

### 3. Excluir `hls1.4.10.js` de media_kit — −374 KB

Asset solo-web en `media_kit/assets/web/`. Se bundlea con el app en todas las plataformas. Opciones:
- **A**: `.gitignore` / filter en `pubspec.yaml` `flutter.assets` (requiere enumerar todos los assets manualmente).
- **B**: Override package local stripeado.
- **C**: Dejar (solo 374 KB, impacto marginal).

### 4. Sentry solo en debug builds — −740 KB + overhead runtime

Si la telemetría de release no se consume, `sentry_flutter` puede quedar en `dev_dependencies` o gateado con `--dart-define=SENTRY_ENABLED=false` en release. Ahorro solo en release.

### 5. Deep-dive en `classes.dex` (7.4 MB)

R8 ya está activo pero podrías:
- Añadir `-dontobfuscate` solo durante debugging para leer reportes tamaño por paquete.
- Auditar reglas ProGuard en `@/home/reny/Projects/Kumoriya/apps/kumoriya_app/android/app/proguard-rules.pro` — reglas `-keep` demasiado amplias bloquean el shrinking.
- Posible `minifyEnabled true` para debug builds puntuales para estimar piso real.

## Benchmark contra apps Flutter comparables

| App | APK arm64-v8a release | Notas |
|---|---|---|
| **Kumoriya (actual)** | 42.3 MB | Con flutter_webrtc |
| **Kumoriya (sin WebRTC)** | ~31 MB | Estimado |
| **Kumoriya (AAB + sin WebRTC)** | ~22 MB descarga real | Estimado |
| Plex mobile | ~50 MB | |
| VLC Android | ~50 MB | Con libvlc |
| Just Player (Media3-only) | ~30 MB | |

Nuestro target realista sin sacrificar features: **~30 MB APK arm64** tras quitar WebRTC legacy, o **~22 MB download real vía Play Store** con AAB.

## Comandos de verificación

Medir APK release:
```bash
cd apps/kumoriya_app
flutter build apk --release --split-per-abi \
  --target-platform android-arm,android-arm64,android-x64
ls -lh build/app/outputs/flutter-apk/*.apk
```

Desglosar tamaños del APK:
```bash
unzip -l build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
  | awk 'NR>3 && $1 ~ /^[0-9]+$/ {print $1, $4}' \
  | sort -rn | head -n 30
```

Auditar deps nativas por plugin:
```bash
cd apps/kumoriya_app/android
./gradlew :app:dependencies --configuration releaseRuntimeClasspath
```

Size report oficial de Flutter (incluye análisis detallado):
```bash
flutter build apk --release --analyze-size --target-platform android-arm64
```

## Decisión actual

**D) Solo medir + documentar** (2026-04-23). Las optimizaciones A/B/C se aplican como follow-up fuera de la Fase 9 del downloader rebuild. Este documento sirve como baseline para comparar tras cualquier cambio futuro de deps.
