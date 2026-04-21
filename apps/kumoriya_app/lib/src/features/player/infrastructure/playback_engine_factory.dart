import 'dart:io';

import '../application/services/playback_engine.dart';
import 'kumoriya_exoplayer_engine.dart';
import 'media_kit_playback_engine.dart';

/// Platform-aware factory that picks the right [PlaybackEngine] backend.
///
/// Routing rationale (validated in the Player Flow Playground, see
/// `docs/dev-diary/`):
///
/// - **Android → `kumoriya_exoplayer` (first-party Media3 plugin).** All
///   playback flows through the native `PlayerInstance`: ExoPlayer for
///   the base pipeline, an in-process HTTP/WS bootstrap for anime.nexus
///   (Fase 2 proxy killer), and AudioFX / Analytics plumbing for the
///   Fase 3/3b/4/5/8 feature surface. Replaces the legacy
///   `video_player`-backed [ExoPlayerPlaybackEngine] which is kept only
///   for the settings playground as a reference engine.
/// - **Desktop (Linux/Windows/macOS) → media_kit.** Libmpv is mature on
///   desktop and ships its own HTTP stack (with curl TLS), which side-
///   steps the JA3/cleartext issues that bite ExoPlayer on Android and
///   unlocks features (embedded subtitle switching, smart audio boost,
///   diagnostics overlay) that Media3 needs custom plumbing for on
///   mobile. iOS also falls here until the plugin learns AVPlayer.
///
/// Residual gaps on Android (tracked in `docs/kumoriya-exoplayer-plan.md`):
/// - Fase 8 URL-refresh hook is plumbed through the controller and the
///   engine's `onUrlExpired` callback, but `createPlaybackEngine` does
///   **not** wire a resolver-chain re-resolver yet. Streams whose URLs
///   rotate mid-playback (e.g. MediaFire) surface the HTTP error
///   unchanged until that orchestrator wiring lands.
/// - Runtime gates for Fase 3 (multi-audio switch), 3b (external subs
///   in real resolvers), 4 (audio tuning), 5 (overlay visibility) are
///   open — the plumbing is complete end-to-end but has not been
///   exercised on a physical device in this promotion window.
///
/// The factory keeps the decision centralised so the rest of the player
/// stack only depends on the [PlaybackEngine] interface.
PlaybackEngine createPlaybackEngine({
  void Function(String message)? onDebugLog,
  bool forceSoftwareVideoOutput = false,
  void Function(String reason)? onVideoOutputFallbackRequested,
}) {
  if (Platform.isAndroid) {
    // `forceSoftwareVideoOutput` and `onVideoOutputFallbackRequested` are
    // libmpv-specific knobs; Media3 routes hardware/software decoder
    // selection internally via its `Renderer` factory so there is no
    // equivalent forward.
    return KumoriyaExoPlayerEngine(onDebugLog: onDebugLog);
  }
  return MediaKitPlaybackEngine(
    onDebugLog: onDebugLog,
    forceSoftwareVideoOutput: forceSoftwareVideoOutput,
    onVideoOutputFallbackRequested: onVideoOutputFallbackRequested,
  );
}
