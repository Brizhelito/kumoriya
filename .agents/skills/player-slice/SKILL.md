---
name: player-slice
description: Implement Kumoriya player slices with media_kit, isolated from scraping/resolution. Use for session/orchestrator flows, controls, server/quality switching, progress/resume, and error states.
---

# Player Slice (Kumoriya)

Build player-only slices with media_kit. Consume resolved inputs, do not resolve links.

## Enforce boundaries first

1. Respect `AGENTS.md` architecture guardrails.
2. Keep player separated from source scraping and resolver plugins.
3. Require pre-resolved playback candidates before player orchestration starts.
4. Do not add resolver/scraper logic to player UI/providers/controllers.
5. Keep slices narrow and vertically deliverable.

## Scope lock before coding

Publish this block first:

```md
Player Slice Scope
- Request:
- In scope:
- Out of scope (must include scraping/resolution):
- Preconditions (resolved pipeline input):
- Done when:
```

If preconditions are missing, add a seam/typed error and stop short of fake resolution logic.

## Player session and orchestrator design

Implement player control through explicit session/orchestrator boundaries.

1. Define a `PlayerSession`/orchestrator that owns:
   - active source candidate (already resolved)
   - active server and quality selection
   - playback lifecycle state
2. Keep UI state consumers thin (watch provider/state, dispatch actions).
3. Keep media_kit interaction centralized in orchestrator/service layer.
4. Make state transitions explicit and testable.

Output:

```md
Player Architecture Slice
- orchestrator/session responsibilities:
- media_kit boundary:
- UI boundary:
- external dependencies:
```

## Supported player responsibilities

Implement only player-domain concerns:
1. Reproduction lifecycle: load, play, pause, seek, stop.
2. Controls: transport, duration/progress indicators, mute/volume where applicable.
3. Server switch: move to another pre-resolved server candidate safely.
4. Quality switch: choose another pre-resolved quality variant.
5. Progress/resume: persist and restore playhead position with guardrails.
6. Basic fallback: attempt next candidate/quality/server based on explicit policy.

## Error and fallback policy

Model errors explicitly and avoid silent retries.

1. Distinguish:
   - invalid precondition (no resolved candidates)
   - media load/playback failure
   - server/quality switch failure
   - timeout/stall
2. Define fallback order deterministically (e.g., same server lower quality, then next server).
3. Cap fallback attempts and surface final failure state.
4. Keep user-facing error states minimal and clear.

Output:

```md
Player Error Policy
- error type:
- retry/fallback behavior:
- terminal condition:
- user-visible state:
```

## Progress and history integration

1. Persist progress periodically and on key lifecycle events.
2. Resume only when saved progress passes minimum threshold and is below near-end threshold.
3. Write history/progress through application/storage contracts, not directly in UI widgets.
4. Avoid duplicate writes on frequent position ticks (throttle/debounce or checkpoint policy).

## Minimal UX validation for player

Validate key interactions for slice acceptance:
1. open and start playback with pre-resolved input
2. pause/resume and seek behavior
3. server switch flow
4. quality switch flow
5. error banner/state and fallback feedback
6. resume from stored progress

Do not broaden into full design-system work.

## Testing expectations

Minimum test set:
1. orchestrator state transition tests
2. fallback policy tests (success path + exhausted path)
3. progress/resume logic tests
4. server/quality switching tests
5. widget-level sanity test for critical controls (if package uses widget tests)

Use fakes/mocks for resolver output and media_kit adapters when needed.

## Validation checklist

```md
Validation Checklist
- [ ] dart format <affected paths>
- [ ] dart analyze <affected package or repo rule>
- [ ] dart test <player-related tests>
- [ ] run/build check for player flow when wiring/startup/navigation changed
```

Do not mark slice complete without executed validation.

## Decision and risk reporting

```md
Player Slice Decisions
- decision:
- rationale:
- tradeoff:
```

```md
Player Slice Risks
- risk:
- trigger:
- mitigation:
- fallback:
```

## Final report template

```md
Player Slice Report
- Scope executed:
- Session/orchestrator changes:
- Controls/server/quality changes:
- Progress/history integration changes:
- Error/fallback behavior:
- Tests run:
  - command:
  - result:
- Known risks/limitations:
- Residual risk:
```
