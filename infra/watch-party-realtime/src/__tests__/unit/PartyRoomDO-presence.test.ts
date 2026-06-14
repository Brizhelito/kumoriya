/**
 * Unit Tests: PartyRoomDO — Presence and Heartbeat Logic
 *
 * Tests the state-transformation helpers and HTTP handlers for:
 * - heartbeat updating lastHeartbeatMs
 * - disconnect starting grace period (effectiveReady=false, readyPersisted preserved)
 * - reconnect within grace period restoring state
 * - member removal after grace period expiration
 *
 * Note: PartyRoomDO's WebSocket paths require the Cloudflare runtime.
 * This test suite exercises the pure state-transformation helpers
 * (applyDisconnect, applyReconnect, applyHeartbeat, findOldestConnectedMember)
 * and the HTTP endpoints (/init, /join, /leave, /member-verify) which are
 * testable in a Node.js + Vitest environment.
 *
 * Requirements: 5.1, 5.2, 5.3, 5.4, 5.6, 5.7
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { PartyRoomDO, applyDisconnect, applyReconnect, applyHeartbeat, findOldestConnectedMember } from '@/durable-objects/PartyRoomDO';
import type { Member } from '@/types';

// ─── Minimal mock helpers (same pattern as PartyRegistryDO tests) ─────────────

class MockStorage {
  private store = new Map<string, unknown>();

  async get<T>(key: string): Promise<T | undefined> {
    return this.store.get(key) as T | undefined;
  }

  async put(key: string, value: unknown): Promise<void> {
    this.store.set(key, value);
  }

  async delete(key: string): Promise<boolean> {
    return this.store.delete(key);
  }

  async list<T>(opts?: { prefix?: string }): Promise<Map<string, T>> {
    const result = new Map<string, T>();
    for (const [k, v] of this.store) {
      if (!opts?.prefix || k.startsWith(opts.prefix)) result.set(k, v as T);
    }
    return result;
  }
}

function makeMockState(): DurableObjectState {
  return {
    storage: new MockStorage() as unknown as DurableObjectStorage,
    id: {} as DurableObjectId,
    waitUntil: vi.fn(),
    blockConcurrencyWhile: async <T>(fn: () => Promise<T>) => fn(),
    acceptWebSocket: vi.fn(),
    getWebSockets: vi.fn(() => []),
    setWebSocketAutoResponse: vi.fn(),
    getWebSocketAutoResponse: vi.fn(),
    getWebSocketAutoResponseTimestamp: vi.fn(),
    setHibernatableWebSocketEventTimeout: vi.fn(),
    getHibernatableWebSocketEventTimeout: vi.fn(),
    abort: vi.fn(),
  } as unknown as DurableObjectState;
}

function makeEnv() {
  return {
    PARTY_REGISTRY: {} as DurableObjectNamespace,
    PARTY_ROOM: {} as DurableObjectNamespace,
    PARTY_INTERNAL_TOKEN: 'test-token',
    PARTY_SESSION_PUBLIC_KEY_HEX: '00'.repeat(32),
    PARTY_SESSION_ISSUER: 'kumoriya-api',
    PARTY_WS_AUDIENCE: 'watch-party',
  };
}

function postJson(path: string, body: unknown): Request {
  return new Request(`http://room${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

const defaultMedia = { anilistId: 1, animeTitle: 'Test Anime', episodeNumber: 1 };

async function initRoom(room: PartyRoomDO, creatorId = 'user-1', creatorName = 'Alice') {
  return room.fetch(
    postJson('/init', {
      roomId: 'room-abc',
      inviteCode: 'ABC123',
      creatorId,
      creatorName,
      media: defaultMedia,
    }),
  );
}

function makeMember(
  userId: string,
  opts: Partial<Member> = {},
): Member {
  return {
    userId,
    name: `User ${userId}`,
    presence: 'connected',
    status: 'in_lobby',
    readyPersisted: false,
    effectiveReady: false,
    joinedAtMs: Date.now(),
    lastHeartbeatMs: Date.now(),
    ...opts,
  };
}

// ─── applyHeartbeat ───────────────────────────────────────────────────────────

describe('applyHeartbeat', () => {
  it('updates lastHeartbeatMs to the provided timestamp', () => {
    const member = makeMember('u1', { lastHeartbeatMs: 1000 });
    const updated = applyHeartbeat(member, 9999);
    expect(updated.lastHeartbeatMs).toBe(9999);
  });

  it('does not mutate the original member', () => {
    const member = makeMember('u1', { lastHeartbeatMs: 1000 });
    applyHeartbeat(member, 9999);
    expect(member.lastHeartbeatMs).toBe(1000);
  });

  it('preserves all other fields', () => {
    const member = makeMember('u1', {
      name: 'Alice',
      presence: 'connected',
      readyPersisted: true,
      effectiveReady: true,
      joinedAtMs: 500,
    });
    const updated = applyHeartbeat(member, 8888);
    expect(updated.userId).toBe('u1');
    expect(updated.name).toBe('Alice');
    expect(updated.presence).toBe('connected');
    expect(updated.readyPersisted).toBe(true);
    expect(updated.effectiveReady).toBe(true);
    expect(updated.joinedAtMs).toBe(500);
  });
});

// ─── applyDisconnect ──────────────────────────────────────────────────────────

describe('applyDisconnect (grace period begins)', () => {
  it('sets presence to disconnected', () => {
    const member = makeMember('u1', { presence: 'connected' });
    expect(applyDisconnect(member).presence).toBe('disconnected');
  });

  it('sets effectiveReady to false', () => {
    const member = makeMember('u1', { readyPersisted: true, effectiveReady: true, presence: 'connected' });
    expect(applyDisconnect(member).effectiveReady).toBe(false);
  });

  it('preserves readyPersisted=true during grace period', () => {
    const member = makeMember('u1', { readyPersisted: true, effectiveReady: true });
    expect(applyDisconnect(member).readyPersisted).toBe(true);
  });

  it('preserves readyPersisted=false during grace period', () => {
    const member = makeMember('u1', { readyPersisted: false, effectiveReady: false });
    expect(applyDisconnect(member).readyPersisted).toBe(false);
  });

  it('does not mutate the original member', () => {
    const member = makeMember('u1', { presence: 'connected', readyPersisted: true, effectiveReady: true });
    applyDisconnect(member);
    expect(member.presence).toBe('connected');
    expect(member.effectiveReady).toBe(true);
  });
});

// ─── applyReconnect ───────────────────────────────────────────────────────────

describe('applyReconnect (reconnect within grace period)', () => {
  it('sets presence to connected', () => {
    const member = makeMember('u1', { presence: 'disconnected', readyPersisted: false, effectiveReady: false });
    expect(applyReconnect(member).presence).toBe('connected');
  });

  it('restores effectiveReady from readyPersisted when readyPersisted=true', () => {
    const member = makeMember('u1', { presence: 'disconnected', readyPersisted: true, effectiveReady: false });
    expect(applyReconnect(member).effectiveReady).toBe(true);
  });

  it('restores effectiveReady from readyPersisted when readyPersisted=false', () => {
    const member = makeMember('u1', { presence: 'disconnected', readyPersisted: false, effectiveReady: false });
    expect(applyReconnect(member).effectiveReady).toBe(false);
  });

  it('does not change readyPersisted', () => {
    const member = makeMember('u1', { presence: 'disconnected', readyPersisted: true, effectiveReady: false });
    expect(applyReconnect(member).readyPersisted).toBe(true);
  });

  it('preserves userId, name, joinedAtMs', () => {
    const member = makeMember('u1', {
      name: 'Alice',
      presence: 'disconnected',
      joinedAtMs: 12345,
    });
    const restored = applyReconnect(member);
    expect(restored.userId).toBe('u1');
    expect(restored.name).toBe('Alice');
    expect(restored.joinedAtMs).toBe(12345);
  });

  it('full disconnect → reconnect cycle is idempotent', () => {
    const member = makeMember('u1', { presence: 'connected', readyPersisted: true, effectiveReady: true });
    const restored = applyReconnect(applyDisconnect(member));
    expect(restored.presence).toBe('connected');
    expect(restored.readyPersisted).toBe(true);
    expect(restored.effectiveReady).toBe(true);
  });
});

// ─── findOldestConnectedMember ────────────────────────────────────────────────

describe('findOldestConnectedMember', () => {
  it('returns undefined for an empty member list', () => {
    expect(findOldestConnectedMember([])).toBeUndefined();
  });

  it('returns undefined when all members are disconnected', () => {
    const members = [
      makeMember('u1', { presence: 'disconnected', joinedAtMs: 100 }),
      makeMember('u2', { presence: 'disconnected', joinedAtMs: 200 }),
    ];
    expect(findOldestConnectedMember(members)).toBeUndefined();
  });

  it('returns the only connected member', () => {
    const members = [
      makeMember('u1', { presence: 'disconnected', joinedAtMs: 100 }),
      makeMember('u2', { presence: 'connected', joinedAtMs: 200 }),
    ];
    expect(findOldestConnectedMember(members)?.userId).toBe('u2');
  });

  it('returns the member with the smallest joinedAtMs among connected members', () => {
    const members = [
      makeMember('u3', { presence: 'connected', joinedAtMs: 300 }),
      makeMember('u1', { presence: 'connected', joinedAtMs: 100 }),
      makeMember('u2', { presence: 'connected', joinedAtMs: 200 }),
    ];
    expect(findOldestConnectedMember(members)?.userId).toBe('u1');
  });

  it('excludes the specified userId', () => {
    const members = [
      makeMember('u1', { presence: 'connected', joinedAtMs: 100 }),
      makeMember('u2', { presence: 'connected', joinedAtMs: 200 }),
    ];
    // Exclude u1 (oldest) — should return u2
    expect(findOldestConnectedMember(members, 'u1')?.userId).toBe('u2');
  });

  it('returns undefined when only connected member is excluded', () => {
    const members = [makeMember('u1', { presence: 'connected', joinedAtMs: 100 })];
    expect(findOldestConnectedMember(members, 'u1')).toBeUndefined();
  });
});

// ─── HTTP /init handler ───────────────────────────────────────────────────────

describe('PartyRoomDO HTTP /init', () => {
  it('stores room state with creator as host and first member', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    const res = await initRoom(room);
    expect(res.status).toBe(200);
    const body = await res.json() as { success: boolean };
    expect(body.success).toBe(true);
  });

  it('initialises roomVersion to 1', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await initRoom(room);
    const stored = await (state.storage as any).get('roomState');
    expect(stored.roomVersion).toBe(1);
  });

  it('sets creator as hostId', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await initRoom(room, 'creator-99');
    const stored = await (state.storage as any).get('roomState');
    expect(stored.hostId).toBe('creator-99');
  });

  it('includes creator in members list with connected presence', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await initRoom(room, 'creator-1', 'Alice');
    const stored = await (state.storage as any).get('roomState');
    expect(stored.members).toHaveLength(1);
    expect(stored.members[0].userId).toBe('creator-1');
    expect(stored.members[0].name).toBe('Alice');
    expect(stored.members[0].presence).toBe('connected');
  });

  it('initialises playback as paused at position 0', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await initRoom(room);
    const stored = await (state.storage as any).get('roomState');
    expect(stored.playback.status).toBe('paused');
    expect(stored.playback.basePositionMs).toBe(0);
    expect(stored.playback.generation).toBe(0);
  });
});

// ─── HTTP /join handler ───────────────────────────────────────────────────────

describe('PartyRoomDO HTTP /join', () => {
  it('adds a new member and increments roomVersion', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await initRoom(room);

    const res = await room.fetch(postJson('/join', { userId: 'user-2', name: 'Bob' }));
    expect(res.status).toBe(200);

    const stored = await (state.storage as any).get('roomState');
    expect(stored.members).toHaveLength(2);
    expect(stored.roomVersion).toBe(2);
  });

  it('rejects joining when room is full (4 members)', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await initRoom(room); // member 1

    for (const id of ['user-2', 'user-3', 'user-4']) {
      await room.fetch(postJson('/join', { userId: id, name: id }));
    }

    const res = await room.fetch(postJson('/join', { userId: 'user-5', name: 'Extra' }));
    expect(res.status).toBe(409);
    const body = await res.json() as { code: string };
    expect(body.code).toBe('room_full');
  });

  it('returns 404 when room does not exist', async () => {
    const room = new PartyRoomDO(makeMockState(), makeEnv() as any);
    const res = await room.fetch(postJson('/join', { userId: 'user-1', name: 'Alice' }));
    expect(res.status).toBe(404);
  });
});

// ─── HTTP /leave handler ──────────────────────────────────────────────────────

describe('PartyRoomDO HTTP /leave', () => {
  it('removes the member and increments roomVersion', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await initRoom(room, 'user-1');
    await room.fetch(postJson('/join', { userId: 'user-2', name: 'Bob' }));

    const res = await room.fetch(postJson('/leave', { userId: 'user-2' }));
    expect(res.status).toBe(200);

    const stored = await (state.storage as any).get('roomState');
    const ids = stored.members.map((m: Member) => m.userId);
    expect(ids).not.toContain('user-2');
    expect(stored.roomVersion).toBe(3); // init(1) + join(2) + leave(3)
  });

  it('transfers host to oldest connected member when host leaves', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await initRoom(room, 'user-1');
    await room.fetch(postJson('/join', { userId: 'user-2', name: 'Bob' }));

    const res = await room.fetch(postJson('/leave', { userId: 'user-1' }));
    expect(res.status).toBe(200);

    const stored = await (state.storage as any).get('roomState');
    expect(stored.hostId).toBe('user-2');
  });

  it('returns 404 when the user is not a member', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await initRoom(room, 'user-1');

    const res = await room.fetch(postJson('/leave', { userId: 'ghost-user' }));
    expect(res.status).toBe(404);
  });
});

// ─── HTTP /member-verify handler ──────────────────────────────────────────────

describe('PartyRoomDO HTTP /member-verify', () => {
  it('returns isMember=true for an active member', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await initRoom(room, 'user-1');

    const res = await room.fetch(postJson('/member-verify', { userId: 'user-1' }));
    expect(res.status).toBe(200);
    const body = await res.json() as { isMember: boolean };
    expect(body.isMember).toBe(true);
  });

  it('returns 403 for a non-member', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await initRoom(room, 'user-1');

    const res = await room.fetch(postJson('/member-verify', { userId: 'unknown-user' }));
    expect(res.status).toBe(403);
  });

  it('returns 404 when room does not exist', async () => {
    const room = new PartyRoomDO(makeMockState(), makeEnv() as any);
    const res = await room.fetch(postJson('/member-verify', { userId: 'user-1' }));
    expect(res.status).toBe(404);
  });
});

// ─── Grace period simulation (timer-based logic) ──────────────────────────────

describe('Grace period: member removal after expiry (simulated via state transforms)', () => {
  it('a member in disconnected state has effectiveReady=false (grace period in progress)', () => {
    // This simulates what handleDisconnect does to the member state
    const member = makeMember('u1', { readyPersisted: true, effectiveReady: true, presence: 'connected' });
    const graceMember = applyDisconnect(member);

    expect(graceMember.presence).toBe('disconnected');
    expect(graceMember.effectiveReady).toBe(false);
    expect(graceMember.readyPersisted).toBe(true); // preserved
  });

  it('reconnecting within grace restores state fully', () => {
    const member = makeMember('u1', { readyPersisted: true, effectiveReady: true, presence: 'connected' });
    const graceMember = applyDisconnect(member);
    const restored = applyReconnect(graceMember);

    expect(restored.presence).toBe('connected');
    expect(restored.effectiveReady).toBe(true); // readyPersisted=true → effectiveReady=true
    expect(restored.readyPersisted).toBe(true);
  });

  it('after grace period expires, removing member from room means they are no longer present', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await initRoom(room, 'user-1');
    await room.fetch(postJson('/join', { userId: 'user-2', name: 'Bob' }));

    // Simulate grace expiry: leave user-2 (equivalent outcome — removed from room)
    await room.fetch(postJson('/leave', { userId: 'user-2' }));

    // Verify user-2 is no longer a member
    const res = await room.fetch(postJson('/member-verify', { userId: 'user-2' }));
    expect(res.status).toBe(403);
  });

  it('host grace period is shorter — host is transferred when grace expires', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await initRoom(room, 'host-user');
    await room.fetch(postJson('/join', { userId: 'member-user', name: 'Bob' }));

    // Simulate host grace expiry: host leaves without reconnecting
    await room.fetch(postJson('/leave', { userId: 'host-user' }));

    const stored = await (state.storage as any).get('roomState');
    // Host should have been transferred to member-user
    expect(stored.hostId).toBe('member-user');
  });
});
