---
name: player-slice
description: >-
  This skill should be used when implementing vertical slices for the Kumoriya
  video player. Covers playback session orchestration, transport controls,
  server/quality switching, progress persistence and resume, error states,
  fallback policies, and player UX validation using pre-resolved playback
  inputs via media_kit. Triggers on mentions of player, playback, media_kit,
  PlayerSessionOrchestrator, PlaybackEngine, PlayerSessionState, video
  controls, seek, resume, server switch, quality switch, or player error
  handling in the Kumoriya context.
---

# player-slice

## Purpose

Implement focused vertical slices for the Kumoriya video player. The player consumes pre-resolved playback inputs (`ResolvedStream`) and is strictly isolated from scraping and link resolution. This skill covers session orchestration, transport controls, server/quality switching, progress persistence, error handling, and fallback policies. It enforces the boundary between playback and resolution at every step.

## Use When

- Implementing new player features (controls, progress bar, quality selector, server switcher).
- Modifying `PlayerSessionOrchestrator` behavior (state transitions, fallback logic, retry policy).
- Working on `PlaybackEngine` integration (media_kit adapter).
- Adding or fixing progress persistence and resume logic.
- Implementing error states and fallback behavior in the player.
- Building player UI components (player page, controls overlay, error banners).
- Fixing bugs in playback lifecycle (load, play, pause, seek, stop, dispose).

## Do Not Use When

- Implementing source plugins or scraping logic (use `source-plugin-jkanime` or equivalent).
- Implementing resolver plugins (use `resolver-plugin`).
- Debugging resolver runtime failures (use `resolver-runtime-audit`).
- Making architecture decisions about package boundaries (use `kumoriya-architecture`).
- The task involves link resolution, URL extraction, or host gating.

## What This Skill Does

1. Enforces strict separation between player and resolution: the player receives `List<ResolvedStream>` as input, never URLs that need resolving.
2. Works through the `PlayerSessionOrchestrator` which manages the playback lifecycle state machine: idle -> opening -> buffering -> playing -> paused -> error.
3. Handles server/quality switching by moving to another pre-resolved candidate from the candidate list.
4. Implements deterministic fallback order: same server lower quality, then next server, with capped retry attempts.
5. Persists playback progress periodically and on lifecycle events through application/storage contracts.
6. Resumes playback only when saved progress passes minimum threshold and is below near-end threshold.
7. Models errors explicitly: invalid precondition (no candidates), media load failure, server switch failure, timeout/stall.
8. Keeps UI thin: widgets observe `PlayerSessionState` and dispatch actions to the orchestrator.
9. Validates player flows with testable state transitions (not just UI rendering).
10. Does not touch scraping, resolver, or source plugin code except at the contract boundary (reading `ResolvedStream`).

## Required Inputs

- Access to `apps/kumoriya_app/lib/src/features/player/`.
- Knowledge of key files:
  - `application/services/player_session_orchestrator.dart` -- main orchestrator.
  - `application/services/playback_engine.dart` -- abstract engine interface.
  - `application/models/player_session_state.dart` -- state model with `PlayerSessionStatus` enum.
  - `presentation/pages/player_page.dart` -- player UI.
- Knowledge of `ResolvedStream` from `packages/kumoriya_plugins/` (url, qualityLabel, mimeType, isHls, headers).
- Knowledge of `ExternalSubtitleTrack` for subtitle management.
- Pre-resolved playback candidates (the player does not call resolvers).

## Preconditions

- The player feature compiles without errors.
- Existing player tests pass.
- The agent understands the current `PlayerSessionStatus` state machine (idle/opening/buffering/fallbacking/playing/paused/error).
- Pre-resolved `ResolvedStream` candidates are available as input to the slice.

## Procedure

1. **Read current player implementation.** Open `player_session_orchestrator.dart`, `playback_engine.dart`, `player_session_state.dart`, and `player_page.dart`. Understand current state transitions, fallback logic, and UI binding.

2. **Publish scope lock.**
   ```
   Player Slice Scope
   - Request: [what to implement/fix]
   - In scope: [player-specific changes]
   - Out of scope: scraping, resolution, resolver plugins
   - Preconditions: resolved candidates provided by upstream pipeline
   - Done when: [acceptance criteria]
   ```

3. **Map player architecture for the slice.**
   ```
   Player Architecture Slice
   - Orchestrator responsibilities: [what changes in orchestrator]
   - PlaybackEngine boundary: [what engine methods are used]
   - UI boundary: [what state the UI observes/dispatches]
   - External dependencies: [only ResolvedStream, subtitle tracks, storage contracts]
   ```

4. **Implement the slice.** Follow state machine patterns. Make state transitions explicit. Keep media_kit interaction centralized in the engine/orchestrator layer. Keep widgets thin.

5. **Define error and fallback behavior** for any new player flow:
   ```
   Player Error Policy
   - Error type: [invalid precondition / media failure / switch failure / timeout]
   - Retry/fallback behavior: [specific policy]
   - Terminal condition: [when to give up]
   - User-visible state: [what the user sees]
   ```

6. **Handle progress persistence** if the slice touches progress/resume:
   - Persist periodically and on pause/stop/background.
   - Throttle writes (no write on every position tick).
   - Resume only when: saved position > minimum threshold AND < near-end threshold.
   - Write through application/storage contracts, not in widgets.

7. **Add tests.** Minimum for the slice:
   - Orchestrator state transition test for the new/changed flow.
   - Fallback policy test (success + exhausted paths).
   - Progress/resume logic test if touched.
   - Widget-level test for critical controls if UI changed.

8. **Run validation.**
   ```
   dart format apps/kumoriya_app/lib/src/features/player/
   dart analyze apps/kumoriya_app/
   dart test apps/kumoriya_app/test/ --name "player"
   ```

9. **Report.**
   ```
   Player Slice Report
   - Scope executed: [recap]
   - Session/orchestrator changes: [what changed]
   - Controls/UI changes: [what changed]
   - Error/fallback behavior: [new policies]
   - Tests run: [commands + results]
   - Known limitations: [what is not covered]
   - Residual risk: [honest assessment]
   ```

## Required Checks

- [ ] `dart format` passes on affected player paths.
- [ ] `dart analyze` reports no new issues.
- [ ] Player tests pass.
- [ ] No resolver/source plugin import was added to player code.
- [ ] State transitions are explicit (no implicit status changes).
- [ ] Fallback attempts are capped (no infinite retry loops).
- [ ] Progress writes are throttled (not per-tick).

## Expected Outputs

- Player slice code (orchestrator logic, UI components, state model changes).
- Tests for new state transitions and fallback paths.
- Error policy documentation for new error types.
- Validation evidence.
- Residual risk statement.

## Anti-Patterns

- **Resolving links in the player.** The player never calls resolvers or source plugins.
- **Implicit state transitions.** Changing `PlayerSessionStatus` without going through explicit orchestrator logic.
- **Infinite fallback loops.** Retrying without a cap or giving up condition.
- **Writing progress on every tick.** Causes performance issues; always throttle.
- **Fat widgets.** Putting orchestration logic in widget `build()` methods or `onPressed` callbacks.
- **Mixing player and resolver fixes.** If a resolver fails, that is a `resolver-plugin` or `resolver-runtime-audit` task, not a player task.
- **Ignoring the completed state.** Not handling end-of-playback correctly (auto-advance, cleanup, or idle transition).

## Constraints

- The player consumes `ResolvedStream` from `kumoriya_plugins`. It never constructs stream URLs itself.
- `PlaybackEngine` is the abstract interface; media_kit is an implementation detail behind it.
- `PlayerSessionOrchestrator` is the single source of truth for playback lifecycle.
- `PlayerSessionState` is immutable; updates go through `copyWith`.
- Riverpod providers expose the orchestrator and state to the UI.
- Progress persistence uses application-layer storage contracts, not direct Drift access.
- Player does not know about source plugins, resolver plugins, or AniList.

## Minimal Example

Task: "Add server switching to the player when the current stream fails."

1. Scope: implement fallback to next `ResolvedStream` candidate when current stream errors. In scope: orchestrator fallback logic, error state transition, UI feedback. Out of scope: resolution, scraping.
2. Read `player_session_orchestrator.dart` to understand current error handling.
3. Implement: on media error, transition to `fallbacking` state, attempt `candidates[currentIndex + 1]`, cap at `totalCandidates`. If exhausted, transition to `error` with "No more servers available."
4. Test: state transition from `playing` -> `error` -> `fallbacking` -> `playing` (success path) and `playing` -> `error` -> `fallbacking` -> `error` (exhausted path).
5. Validate: format, analyze, test.
6. Report: changes, tests, residual risk.

## Definition of Done

- The player slice's acceptance criteria are met.
- State transitions are tested and pass.
- No resolver/source plugin code was touched.
- Validation commands pass.
- Fallback behavior is bounded (capped retries, terminal state defined).

## Project Assumptions

- media_kit is the underlying video player library. **Risk: media_kit behavior may vary across Android and Windows platforms.**
- `PlayerSessionOrchestrator` is a single class managing the full session lifecycle. **Risk: as features grow, it may need decomposition into smaller services.**
- Progress storage uses an application-layer contract. The actual Drift implementation is in `kumoriya_storage`. **Risk: storage schema changes could affect resume behavior.**
- The player receives candidates pre-sorted by preference (quality, server priority). The player does not re-sort them.
