/**
 * Property Test: Playback State Monotonicity
 *
 * **Validates: Requirements 8.5**
 *
 * Property 4: For any sequence of play/pause/seek actions, the generation counter
 * MUST strictly increase. The generation MUST never decrease. effectiveAtMs MUST
 * be non-decreasing across calls using simulated monotonic timestamps.
 */

import { describe, it } from 'vitest';
import * as fc from 'fast-check';
import { applyPlaybackPlay, applyPlaybackPause, applyPlaybackSeek } from '@/durable-objects/PartyRoomDO';
import type { PlaybackState } from '@/types';

// ─── Generators ───────────────────────────────────────────────────────────────

type PlaybackAction =
  | { type: 'play' }
  | { type: 'pause' }
  | { type: 'seek'; positionMs: number };

const playbackActionArb: fc.Arbitrary<PlaybackAction> = fc.oneof(
  fc.constant({ type: 'play' as const }),
  fc.constant({ type: 'pause' as const }),
  fc.record({ type: fc.constant('seek' as const), positionMs: fc.integer({ min: 0, max: 10_000_000 }) }),
);

function makeInitialPlayback(generation = 0): PlaybackState {
  return {
    status: 'paused',
    basePositionMs: 0,
    effectiveAtMs: 0,
    generation,
  };
}

/**
 * Apply a list of actions to a playback state with strictly increasing timestamps.
 * Returns the sequence of (generation, effectiveAtMs) after each action.
 */
function applyActions(
  initial: PlaybackState,
  actions: PlaybackAction[],
): Array<{ generation: number; effectiveAtMs: number }> {
  const results: Array<{ generation: number; effectiveAtMs: number }> = [];
  let state = initial;
  let nowMs = initial.effectiveAtMs;

  for (const action of actions) {
    // Monotonically increasing timestamp — each action gets a later timestamp
    nowMs += 1;

    switch (action.type) {
      case 'play':
        state = applyPlaybackPlay(state, nowMs);
        break;
      case 'pause':
        state = applyPlaybackPause(state, nowMs);
        break;
      case 'seek':
        state = applyPlaybackSeek(state, action.positionMs, nowMs);
        break;
    }

    results.push({ generation: state.generation, effectiveAtMs: state.effectiveAtMs });
  }

  return results;
}

// ─── Property 4: Playback State Monotonicity ─────────────────────────────────

describe('Property 4: Playback State Monotonicity', () => {
  it('generation strictly increases with every play/pause/seek action', () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 0, max: 100 }), // initial generation
        fc.array(playbackActionArb, { minLength: 1, maxLength: 20 }),
        (initialGeneration: number, actions: PlaybackAction[]) => {
          const initial = makeInitialPlayback(initialGeneration);
          const results = applyActions(initial, actions);

          let prevGeneration = initialGeneration;
          for (const { generation } of results) {
            // Each action must strictly increase generation
            if (generation <= prevGeneration) return false;
            prevGeneration = generation;
          }
          return true;
        },
      ),
      { numRuns: 200 },
    );
  });

  it('generation never decreases across any sequence of actions', () => {
    fc.assert(
      fc.property(
        fc.array(playbackActionArb, { minLength: 2, maxLength: 30 }),
        (actions: PlaybackAction[]) => {
          const initial = makeInitialPlayback(0);
          const results = applyActions(initial, actions);

          for (let i = 1; i < results.length; i++) {
            // generation[i] must be strictly greater than generation[i-1]
            if (results[i].generation <= results[i - 1].generation) return false;
          }
          return true;
        },
      ),
      { numRuns: 200 },
    );
  });

  it('effectiveAtMs is non-decreasing across monotonically increasing timestamps', () => {
    fc.assert(
      fc.property(
        fc.array(playbackActionArb, { minLength: 1, maxLength: 20 }),
        (actions: PlaybackAction[]) => {
          const initial = makeInitialPlayback(0);
          const results = applyActions(initial, actions);

          let prevEffectiveAtMs = initial.effectiveAtMs;
          for (const { effectiveAtMs } of results) {
            // Each action gets a later timestamp → effectiveAtMs must be >= previous
            if (effectiveAtMs < prevEffectiveAtMs) return false;
            prevEffectiveAtMs = effectiveAtMs;
          }
          return true;
        },
      ),
      { numRuns: 200 },
    );
  });

  it('generation increases by exactly 1 for each action', () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 0, max: 1000 }), // initial generation
        playbackActionArb, // single action
        (initialGeneration: number, action: PlaybackAction) => {
          const initial = makeInitialPlayback(initialGeneration);
          const [result] = applyActions(initial, [action]);
          return result.generation === initialGeneration + 1;
        },
      ),
      { numRuns: 200 },
    );
  });

  it('after N actions from generation 0, generation equals N', () => {
    fc.assert(
      fc.property(
        fc.array(playbackActionArb, { minLength: 1, maxLength: 50 }),
        (actions: PlaybackAction[]) => {
          const initial = makeInitialPlayback(0);
          const results = applyActions(initial, actions);
          const finalGeneration = results[results.length - 1].generation;
          return finalGeneration === actions.length;
        },
      ),
      { numRuns: 200 },
    );
  });
});
