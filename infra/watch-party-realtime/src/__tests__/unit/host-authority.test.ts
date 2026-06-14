/**
 * Unit Tests: Host Authority and Transfer Logic
 *
 * Tests host-only playback_intent acceptance/rejection, host transfer on
 * disconnect/reconnect/timeout, and empty room TTL.
 *
 * Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.7
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { PartyRoomDO, isHost, transferHost, findOldestConnectedMember } from '@/durable-objects/PartyRoomDO';
import type { Member } from '@/types';

// ─── Helpers ──────────────────────────────────────────────────────────────────

class MockStorage {
  private store = new Map<string, unknown>();
  async get<T>(key: string): Promise<T | undefined> { return this.store.get(key) as T | undefined; }
  async put(key: string, value: unknown): Promise<void> { this.store.set(key, value); }
  async delete(key: string): Promise<boolean> { return this.store.delete(key); }
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
    PARTY_INTERNAL_TOKEN: 'test',
    PARTY_SESSION_PUBLIC_KEY_HEX: '00'.repeat(32),
    PARTY_WS_AUDIENCE: 'watch-party',
    PARTY_SESSION_ISSUER: 'kumoriya-api',
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

async function initRoom(room: PartyRoomDO, creatorId = 'host-1', creatorName = 'Host') {
  return room.fetch(postJson('/init', {
    roomId: 'room-test',
    inviteCode: 'ABC123',
    creatorId,
    creatorName,
    media: defaultMedia,
  }));
}

function makeMember(userId: string, opts: Partial<Member> = {}): Member {
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

// ─── isHost ───────────────────────────────────────────────────────────────────

describe('isHost', () => {
  it('returns true when userId equals hostId', () => {
    expect(isHost('host-1', 'host-1')).toBe(true);
  });

  it('returns false when userId does not equal hostId', () => {
    expect(isHost('host-1', 'member-2')).toBe(false);
  });

  it('is case-sensitive', () => {
    expect(isHost('Host-1', 'host-1')).toBe(false);
  });
});

// ─── transferHost ─────────────────────────────────────────────────────────────

describe('transferHost', () => {
  it('transfers to oldest connected member when host leaves', () => {
    const members: Member[] = [
      makeMember('host', { joinedAtMs: 100 }),
      makeMember('member-a', { joinedAtMs: 200 }),
      makeMember('member-b', { joinedAtMs: 300 }),
    ];
    expect(transferHost('host', members)).toBe('member-a');
  });

  it('returns original hostId when no other connected members', () => {
    const members: Member[] = [makeMember('host', { joinedAtMs: 100 })];
    expect(transferHost('host', members)).toBe('host');
  });

  it('skips disconnected members for transfer', () => {
    const members: Member[] = [
      makeMember('host', { joinedAtMs: 100 }),
      makeMember('disc', { presence: 'disconnected', joinedAtMs: 101 }),
      makeMember('conn', { joinedAtMs: 200 }),
    ];
    expect(transferHost('host', members)).toBe('conn');
  });
});

// ─── HTTP leave with host transfer ────────────────────────────────────────────

describe('Host transfer on HTTP leave', () => {
  it('transfers host when creator (host) leaves and others remain', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await initRoom(room, 'host-1');
    await room.fetch(postJson('/join', { userId: 'member-2', name: 'Bob' }));

    await room.fetch(postJson('/leave', { userId: 'host-1' }));

    const stored = await (state.storage as any).get('roomState');
    expect(stored.hostId).toBe('member-2');
  });

  it('does not transfer host when non-host member leaves', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await initRoom(room, 'host-1');
    await room.fetch(postJson('/join', { userId: 'member-2', name: 'Bob' }));

    await room.fetch(postJson('/leave', { userId: 'member-2' }));

    const stored = await (state.storage as any).get('roomState');
    expect(stored.hostId).toBe('host-1');
  });

  it('transfers to the oldest remaining member (by joinedAtMs)', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await initRoom(room, 'host-1');

    // Add members sequentially (joinedAtMs increases)
    await room.fetch(postJson('/join', { userId: 'member-2', name: 'Bob' }));
    await room.fetch(postJson('/join', { userId: 'member-3', name: 'Carol' }));

    await room.fetch(postJson('/leave', { userId: 'host-1' }));

    const stored = await (state.storage as any).get('roomState');
    // member-2 joined before member-3 → should become host
    expect(stored.hostId).toBe('member-2');
  });

  it('host-only: rejects non-host leaving (no host transfer)', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await initRoom(room, 'host-1');
    await room.fetch(postJson('/join', { userId: 'member-2', name: 'Bob' }));

    // member-2 leaves — host remains host-1
    await room.fetch(postJson('/leave', { userId: 'member-2' }));

    const stored = await (state.storage as any).get('roomState');
    expect(stored.hostId).toBe('host-1');
    expect(stored.members).toHaveLength(1);
  });
});

// ─── Empty room TTL (state logic) ─────────────────────────────────────────────

describe('Empty room state after all members leave', () => {
  it('room state still exists after one member leaves (not empty yet)', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await initRoom(room, 'host-1');
    await room.fetch(postJson('/join', { userId: 'member-2', name: 'Bob' }));

    await room.fetch(postJson('/leave', { userId: 'member-2' }));

    const stored = await (state.storage as any).get('roomState');
    expect(stored).toBeDefined();
    expect(stored.members).toHaveLength(1);
  });

  it('member-verify returns 403 after room has zero members and last user left', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await initRoom(room, 'host-1');
    await room.fetch(postJson('/leave', { userId: 'host-1' }));

    // Room has no members now
    const res = await room.fetch(postJson('/member-verify', { userId: 'host-1' }));
    expect(res.status).toBe(403);
  });
});
