/**
 * Property Test: Reconnection State Restoration
 *
 * **Validates: Requirements 5.6, 17.3**
 *
 * Property 15: For any disconnected member with a grace period timer active,
 * reconnecting within the grace period SHALL result in the member's state being
 * fully restored:
 *   - presence = 'connected'
 *   - effectiveReady = readyPersisted
 *   - membership preserved (userId, name, joinedAtMs unchanged)
 */

import { describe, it, expect } from 'vitest';
import * as fc from 'fast-check';
import type { Member } from '@/types';
import { applyReconnect, applyDisconnect } from '@/durable-objects/PartyRoomDO';

// ─── Generators ───────────────────────────────────────────────────────────────

/** A member in a disconnected state (as it would be during the grace period). */
const disconnectedMemberArb = fc
  .record({
    userId: fc.uuid(),
    name: fc.string({ minLength: 1, maxLength: 50 }),
    readyPersisted: fc.boolean(),
    joinedAtMs: fc.integer({ min: 0, max: 1_700_000_000_000 }),
    lastHeartbeatMs: fc.integer({ min: 0, max: 1_700_000_000_000 }),
  })
  .map(
    (data): Member => ({
      userId: data.userId,
      name: data.name,
      presence: 'disconnected',
      readyPersisted: data.readyPersisted,
      effectiveReady: false, // invariant while disconnected
      joinedAtMs: data.joinedAtMs,
      lastHeartbeatMs: data.lastHeartbeatMs,
    }),
  );

/** A member in a connected state — will be disconnected first then reconnected. */
const connectedMemberArb = fc
  .record({
    userId: fc.uuid(),
    name: fc.string({ minLength: 1, maxLength: 50 }),
    readyPersisted: fc.boolean(),
    joinedAtMs: fc.integer({ min: 0, max: 1_700_000_000_000 }),
    lastHeartbeatMs: fc.integer({ min: 0, max: 1_700_000_000_000 }),
  })
  .map(
    (data): Member => ({
      userId: data.userId,
      name: data.name,
      presence: 'connected',
      readyPersisted: data.readyPersisted,
      effectiveReady: data.readyPersisted,
      joinedAtMs: data.joinedAtMs,
      lastHeartbeatMs: data.lastHeartbeatMs,
    }),
  );

// ─── Tests ────────────────────────────────────────────────────────────────────

describe('Property 15: Reconnection State Restoration', () => {
  it('reconnecting a disconnected member MUST set presence=connected', () => {
    fc.assert(
      fc.property(disconnectedMemberArb, (member: Member) => {
        const restored = applyReconnect(member);
        expect(restored.presence).toBe('connected');
      }),
      { numRuns: 200 },
    );
  });

  it('reconnecting MUST restore effectiveReady = readyPersisted', () => {
    fc.assert(
      fc.property(disconnectedMemberArb, (member: Member) => {
        const restored = applyReconnect(member);
        expect(restored.effectiveReady).toBe(member.readyPersisted);
      }),
      { numRuns: 200 },
    );
  });

  it('reconnecting MUST NOT alter membership identity (userId, name, joinedAtMs)', () => {
    fc.assert(
      fc.property(disconnectedMemberArb, (member: Member) => {
        const restored = applyReconnect(member);
        expect(restored.userId).toBe(member.userId);
        expect(restored.name).toBe(member.name);
        expect(restored.joinedAtMs).toBe(member.joinedAtMs);
      }),
      { numRuns: 200 },
    );
  });

  it('reconnecting MUST NOT alter readyPersisted', () => {
    fc.assert(
      fc.property(disconnectedMemberArb, (member: Member) => {
        const originalReadyPersisted = member.readyPersisted;
        const restored = applyReconnect(member);
        expect(restored.readyPersisted).toBe(originalReadyPersisted);
      }),
      { numRuns: 200 },
    );
  });

  it('grace period invariant: disconnect preserves readyPersisted, reconnect restores effectiveReady', () => {
    fc.assert(
      fc.property(connectedMemberArb, (member: Member) => {
        const snapshot = {
          userId: member.userId,
          name: member.name,
          readyPersisted: member.readyPersisted,
          joinedAtMs: member.joinedAtMs,
        };

        // Step 1: disconnect (grace period begins)
        const disconnected = applyDisconnect(member);
        expect(disconnected.presence).toBe('disconnected');
        expect(disconnected.effectiveReady).toBe(false);
        expect(disconnected.readyPersisted).toBe(snapshot.readyPersisted); // preserved

        // Step 2: reconnect within grace period
        const restored = applyReconnect(disconnected);
        expect(restored.presence).toBe('connected');
        expect(restored.effectiveReady).toBe(snapshot.readyPersisted); // restored
        expect(restored.readyPersisted).toBe(snapshot.readyPersisted); // unchanged
        expect(restored.userId).toBe(snapshot.userId);
        expect(restored.name).toBe(snapshot.name);
        expect(restored.joinedAtMs).toBe(snapshot.joinedAtMs);
      }),
      { numRuns: 200 },
    );
  });

  it('a member with readyPersisted=true SHALL have effectiveReady=true after reconnect', () => {
    fc.assert(
      fc.property(
        disconnectedMemberArb.filter((m) => m.readyPersisted === true),
        (member: Member) => {
          const restored = applyReconnect(member);
          expect(restored.effectiveReady).toBe(true);
        },
      ),
      { numRuns: 200 },
    );
  });

  it('a member with readyPersisted=false SHALL have effectiveReady=false after reconnect', () => {
    fc.assert(
      fc.property(
        disconnectedMemberArb.filter((m) => m.readyPersisted === false),
        (member: Member) => {
          const restored = applyReconnect(member);
          expect(restored.effectiveReady).toBe(false);
        },
      ),
      { numRuns: 200 },
    );
  });

  it('reconnect is idempotent — applying it twice does not change the result', () => {
    fc.assert(
      fc.property(disconnectedMemberArb, (member: Member) => {
        const once = applyReconnect(member);
        const twice = applyReconnect(once); // already connected — reconnect again
        expect(twice.presence).toBe('connected');
        expect(twice.effectiveReady).toBe(member.readyPersisted);
        expect(twice.readyPersisted).toBe(member.readyPersisted);
      }),
      { numRuns: 200 },
    );
  });
});
