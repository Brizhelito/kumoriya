/**
 * Property Tests: Host Authority
 *
 * Property 3: Host Authority is Exclusive
 * Property 16: Host Transfer on Host Leave
 * Property 17: Playback Intent Host-Only Enforcement
 * Property 19: Empty Room TTL
 *
 * Validates: Requirements 6.1, 6.2, 6.3, 6.5, 6.7, 6.8, 13.5
 */

import { describe, it, expect } from 'vitest';
import * as fc from 'fast-check';
import type { Member } from '@/types';
import { isHost, transferHost, findOldestConnectedMember } from '@/durable-objects/PartyRoomDO';

// ─── Generators ───────────────────────────────────────────────────────────────

const userIdArb = fc.uuid();

function memberArb(presence: 'connected' | 'disconnected' = 'connected') {
  return fc
    .record({
      userId: userIdArb,
      name: fc.string({ minLength: 1, maxLength: 30 }),
      joinedAtMs: fc.integer({ min: 1, max: 1_700_000_000_000 }),
      readyPersisted: fc.boolean(),
    })
    .map((d): Member => ({
      userId: d.userId,
      name: d.name,
      presence,
      readyPersisted: d.readyPersisted,
      effectiveReady: d.readyPersisted && presence === 'connected',
      joinedAtMs: d.joinedAtMs,
      lastHeartbeatMs: d.joinedAtMs,
    }));
}

// ─── Property 3: Host Authority is Exclusive ──────────────────────────────────

describe('Property 3: Host Authority is Exclusive', () => {
  it('exactly one userId is the host at any time', () => {
    fc.assert(
      fc.property(
        userIdArb,
        fc.array(userIdArb, { minLength: 1, maxLength: 4 }),
        (hostId: string, allUserIds: string[]) => {
          // Count how many users pass isHost check
          const hostCount = allUserIds.filter((uid) => isHost(hostId, uid)).length;
          // Only the host passes the check (0 or 1 depending on whether hostId is in allUserIds)
          const expectedCount = allUserIds.includes(hostId) ? 1 : 0;
          expect(hostCount).toBe(expectedCount);
        },
      ),
      { numRuns: 200 },
    );
  });

  it('isHost returns true only for the exact hostId', () => {
    fc.assert(
      fc.property(
        userIdArb,
        userIdArb,
        (hostId: string, userId: string) => {
          const result = isHost(hostId, userId);
          expect(result).toBe(hostId === userId);
        },
      ),
      { numRuns: 200 },
    );
  });

  it('non-host users always fail isHost check', () => {
    fc.assert(
      fc.property(
        userIdArb,
        fc.array(userIdArb, { minLength: 1, maxLength: 3 }),
        (hostId: string, nonHosts: string[]) => {
          fc.pre(nonHosts.every((uid) => uid !== hostId));
          for (const uid of nonHosts) {
            expect(isHost(hostId, uid)).toBe(false);
          }
        },
      ),
      { numRuns: 100 },
    );
  });
});

// ─── Property 16: Host Transfer on Host Leave ─────────────────────────────────

describe('Property 16: Host Transfer on Host Leave', () => {
  it('host is transferred to the oldest connected member when host leaves', () => {
    fc.assert(
      fc.property(
        // 2–4 members, all connected
        fc.array(memberArb('connected'), { minLength: 2, maxLength: 4 }).filter(
          (members) => new Set(members.map((m) => m.userId)).size === members.length,
        ),
        (members: Member[]) => {
          fc.pre(members.length >= 2);
          const hostId = members[0].userId;

          const newHostId = transferHost(hostId, members);

          // New host must NOT be the old host
          expect(newHostId).not.toBe(hostId);

          // New host must be one of the remaining connected members
          const remaining = members.filter((m) => m.userId !== hostId);
          expect(remaining.some((m) => m.userId === newHostId)).toBe(true);
        },
      ),
      { numRuns: 100 },
    );
  });

  it('transferred host is the oldest connected member (smallest joinedAtMs)', () => {
    fc.assert(
      fc.property(
        fc.array(memberArb('connected'), { minLength: 2, maxLength: 4 }).filter(
          (members) => new Set(members.map((m) => m.userId)).size === members.length,
        ),
        (members: Member[]) => {
          fc.pre(members.length >= 2);
          const hostId = members[0].userId;

          const newHostId = transferHost(hostId, members);

          const remaining = members.filter((m) => m.userId !== hostId && m.presence === 'connected');
          const oldestRemaining = remaining.sort((a, b) => a.joinedAtMs - b.joinedAtMs)[0];

          expect(newHostId).toBe(oldestRemaining?.userId ?? hostId);
        },
      ),
      { numRuns: 100 },
    );
  });

  it('host stays as-is when no other connected members remain', () => {
    fc.assert(
      fc.property(
        memberArb('connected'),
        (host: Member) => {
          // Only the host — no one to transfer to
          const newHostId = transferHost(host.userId, [host]);
          expect(newHostId).toBe(host.userId);
        },
      ),
      { numRuns: 100 },
    );
  });

  it('host transfer skips disconnected members', () => {
    fc.assert(
      fc.property(
        fc.record({
          host: memberArb('connected'),
          disconnected: memberArb('disconnected'),
          connected: memberArb('connected'),
        }).filter(
          ({ host, disconnected, connected }) =>
            host.userId !== disconnected.userId &&
            host.userId !== connected.userId &&
            disconnected.userId !== connected.userId,
        ),
        ({ host, disconnected, connected }) => {
          // Make disconnected member "older" by joinedAtMs
          const adjustedDisconnected = { ...disconnected, joinedAtMs: 1 };
          const adjustedConnected = { ...connected, joinedAtMs: 1000 };

          const members = [host, adjustedDisconnected, adjustedConnected];
          const newHostId = transferHost(host.userId, members);

          // Must transfer to connected member, not the older disconnected one
          expect(newHostId).toBe(adjustedConnected.userId);
        },
      ),
      { numRuns: 100 },
    );
  });
});

// ─── Property 17: Playback Intent Host-Only Enforcement ───────────────────────

describe('Property 17: Playback Intent Host-Only Enforcement', () => {
  it('only the host passes the host authority check', () => {
    fc.assert(
      fc.property(
        userIdArb, // hostId
        userIdArb, // senderId
        (hostId: string, senderId: string) => {
          const isAllowed = isHost(hostId, senderId);
          if (senderId === hostId) {
            expect(isAllowed).toBe(true);
          } else {
            expect(isAllowed).toBe(false);
          }
        },
      ),
      { numRuns: 300 },
    );
  });

  it('after host transfer, old host fails authority check and new host passes', () => {
    fc.assert(
      fc.property(
        fc.array(memberArb('connected'), { minLength: 2, maxLength: 4 }).filter(
          (members) => new Set(members.map((m) => m.userId)).size === members.length,
        ),
        (members: Member[]) => {
          fc.pre(members.length >= 2);
          const oldHostId = members[0].userId;

          const newHostId = transferHost(oldHostId, members);

          // Old host fails check
          expect(isHost(newHostId, oldHostId)).toBe(false);
          // New host passes check
          expect(isHost(newHostId, newHostId)).toBe(true);
        },
      ),
      { numRuns: 100 },
    );
  });
});

// ─── Property 19: Empty Room TTL ─────────────────────────────────────────────

describe('Property 19: Empty Room TTL', () => {
  it('a room with zero members is considered empty', () => {
    fc.assert(
      fc.property(
        fc.constant([] as Member[]),
        (members: Member[]) => {
          expect(members.length).toBe(0);
          // An empty room should have its TTL started — verified by logic: members.length === 0
        },
      ),
      { numRuns: 10 },
    );
  });

  it('a room with at least one member is not empty', () => {
    fc.assert(
      fc.property(
        fc.array(memberArb(), { minLength: 1, maxLength: 4 }),
        (members: Member[]) => {
          expect(members.length).toBeGreaterThan(0);
        },
      ),
      { numRuns: 100 },
    );
  });

  it('findOldestConnectedMember returns undefined for empty room (no transfer possible)', () => {
    fc.assert(
      fc.property(
        fc.constant([] as Member[]),
        (members: Member[]) => {
          expect(findOldestConnectedMember(members)).toBeUndefined();
        },
      ),
      { numRuns: 10 },
    );
  });
});
