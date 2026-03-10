# Deferred Work

## Rule

These items are intentionally deferred until the app is functionally complete.

Priority order:
1. Finish the app.
2. Revisit deferred technical debt and hard bugs.

## Deferred Items

### HLS / UPNShare seek freeze after resume or manual seek

Status: deferred until after the app is finished.

Problem:
- HLS and UPNShare can open and jump to the requested timestamp.
- After landing on the target time, playback may freeze with:
  - `playing = true`
  - `buffering = false`
  - `completed = false`
  - `buffer = 0`
  - `bufferingPercentage = 100`
- After some seconds, `media_kit/mpv` may flip into a false EOF and jump to the end.

What was verified:
- The UI slider is not the root cause.
- The orchestrator is not the root cause.
- `seek` reaches the requested target.
- `Media(start: target)` also reaches the target.
- A preroll reopen strategy was tested and can still stall in the same way.
- The issue appears to live in the native playback backend path for HLS-like streams.

Current temporary state:
- The player has defensive recovery logic for false EOF.
- The engine contains instrumentation to inspect:
  - native `mpv/ffmpeg` logs
  - buffering state
  - buffer time
  - buffering percentage
  - progress after target landing

Likely next step when revisiting:
1. Patch or override the native playback strategy for HLS in `media_kit/mpv`.
2. Test mpv property changes for HLS:
   - `hr-seek`
   - network timeout
   - demux/cache behavior
3. Validate with real resume and non-buffered seeks on:
   - HLS
   - UPNShare
4. Remove temporary debug instrumentation once the behavior is stable.

Relevant files:
- [player_session_orchestrator.dart](C:/Users/Reny/Documents/Kumoriya/apps/kumoriya_app/lib/src/features/player/application/services/player_session_orchestrator.dart)
- [media_kit_playback_engine.dart](C:/Users/Reny/Documents/Kumoriya/apps/kumoriya_app/lib/src/features/player/infrastructure/media_kit_playback_engine.dart)
- [player_page.dart](C:/Users/Reny/Documents/Kumoriya/apps/kumoriya_app/lib/src/features/player/presentation/pages/player_page.dart)
- [player_session_orchestrator_test.dart](C:/Users/Reny/Documents/Kumoriya/apps/kumoriya_app/test/player_session_orchestrator_test.dart)
