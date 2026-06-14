/**
 * Property Test: Grace Period State Preservation
 *
 * **Validates: Requirements 5.4, 5.6, 7.4**
 *
 * Property 7: For any member that disconnects (starting the grace period),
 * their `readyPersisted` value MUST be preserved. `effectiveReady` MUST be
 * set to false. If they reconnect within the grace period, `effectiveReady`
 * MUST be restored from `readyPersisted`.
 */

import { describe, it, expect } from 'vitest';
import * as fc from 'fast-check';
import type { Member } from '@/types';
import { applyDisconnect, applyReconnect } from '@/durable-objects/PartyRoomDO';

// ─── Generators ───────────────────────────────────────────────────────────────

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
      status: 'in_lobby',
      readyPersisted: data.readyPersisted,
      effectiveReady: data.readyPersisted, // invariant: effectiveReady = readyPersisted when connected
      joinedAtMs: data.joinedAtMs,
      lastHeartbeatMs: data.lastHeartbeatMs,
    }),
  );

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
      status: 'in_lobby',
      readyPersisted: data.readyPersisted,
      effectiveReady: false, // invariant: effectiveReady = false when disconnected
      joinedAtMs: data.joinedAtMs,
      lastHeartbeatMs: data.lastHeartbeatMs,
    }),
  );

// ─── Tests ────────────────────────────────────────────────────────────────────

describe('Property 7: Grace Period State Preservation', () => {
  it('disconnecting a connected member MUST set presence=disconnected and effectiveReady=false', () => {
    fc.assert(
      fc.property(connectedMemberArb, (member: Member) => {
        const disconnected = applyDisconnect(member);

        expect(disconnected.presence).toBe('disconnected');
        expect(disconnected.effectiveReady).toBe(false);
      }),
      { numRuns: 200 },
    );
  });

  it('disconnecting MUST preserve readyPersisted regardless of its value', () => {
    fc.assert(
      fc.property(connectedMemberArb, (member: Member) => {
        const originalReadyPersisted = member.readyPersisted;
        const disconnected = applyDisconnect(member);

        expect(disconnected.readyPersisted).toBe(originalReadyPersisted);
      }),
      { numRuns: 200 },
    );
  });

  it('reconnecting within grace MUST restore effectiveReady from readyPersisted', () => {
    fc.assert(
      fc.property(disconnectedMemberArb, (member: Member) => {
        const reconnected = applyReconnect(member);

        expect(reconnected.presence).toBe('connected');
        expect(reconnected.effectiveReady).toBe(member.readyPersisted);
      }),
      { numRuns: 200 },
    );
  });

  it('full disconnect → reconnect cycle MUST restore the original effectiveReady', () => {
    fc.assert(
      fc.property(connectedMemberArb, (member: Member) => {
        const originalEffectiveReady = member.effectiveReady;
        const originalReadyPersisted = member.readyPersisted;

        const afterDisconnect = applyDisconnect(member);

        // During grace: readyPersisted is preserved, effectiveReady is false
        expect(afterDisconnect.readyPersisted).toBe(originalReadyPersisted);
        expect(afterDisconnect.effectiveReady).toBe(false);

        const afterReconnect = applyReconnect(afterDisconnect);

        // After reconnect: full restoration
        expect(afterReconnect.presence).toBe('connected');
        expect(afterReconnect.readyPersisted).toBe(originalReadyPersisted);
        expect(afterReconnect.effectiveReady).toBe(originalEffectiveReady);
      }),
      { numRuns: 200 },
    );
  });

  it('readyPersisted=true members MUST have effectiveReady=true after reconnect', () => {
    fc.assert(
      fc.property(
        connectedMemberArb.filter((m) => m.readyPersisted === true),
        (member: Member) => {
          const reconnected = applyReconnect(applyDisconnect(member));
          expect(reconnected.effectiveReady).toBe(true);
        },
      ),
      { numRuns: 200 },
    );
  });

  it('readyPersisted=false members MUST have effectiveReady=false after reconnect', () => {
    fc.assert(
      fc.property(
        connectedMemberArb.filter((m) => m.readyPersisted === false),
        (member: Member) => {
          const reconnected = applyReconnect(applyDisconnect(member));
          expect(reconnected.effectiveReady).toBe(false);
        },
      ),
      { numRuns: 200 },
    );
  });

  it('multiple disconnect/reconnect cycles MUST be idempotent with respect to readyPersisted', () => {
    fc.assert(
      fc.property(
        connectedMemberArb,
        fc.integer({ min: 1, max: 10 }),
        (member: Member, cycles: number) => {
          const originalReadyPersisted = member.readyPersisted;
          let current = member;

          for (let i = 0; i < cycles; i++) {
            current = applyDisconnect(current);
            expect(current.readyPersisted).toBe(originalReadyPersisted);
            expect(current.effectiveReady).toBe(false);

            current = applyReconnect(current);
            expect(current.readyPersisted).toBe(originalReadyPersisted);
            expect(current.effectiveReady).toBe(originalReadyPersisted);
          }
        },
      ),
      { numRuns: 100 },
    );
  });
});
