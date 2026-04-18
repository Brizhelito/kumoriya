/**
 * Unit Tests: Ready State Management
 *
 * Tests the dual-layer ready state logic:
 * - applySetReady updates readyPersisted and effectiveReady
 * - Disconnect/reconnect cycle preserves readyPersisted via existing helpers
 * - HTTP /init and /join create members with correct initial ready state
 *
 * Requirements: 7.1, 7.2, 7.3, 7.4
 */

import { describe, it, expect, vi } from 'vitest';
import {
  PartyRoomDO,
  applySetReady,
  applyDisconnect,
  applyReconnect,
  resetReadyStates,
} from '@/durable-objects/PartyRoomDO';
import type { Member } from '@/types';

// ─── Shared helpers ───────────────────────────────────────────────────────────

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
    PARTY_SESSION_PUBLIC_KEY_HEX: '00'.repeat(32) as string,
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

function makeMember(userId: string, opts: Partial<Member> = {}): Member {
  return {
    userId,
    name: `User ${userId}`,
    presence: 'connected',
    readyPersisted: false,
    effectiveReady: false,
    joinedAtMs: 1000,
    lastHeartbeatMs: 1000,
    ...opts,
  };
}

// ─── applySetReady ────────────────────────────────────────────────────────────

describe('applySetReady', () => {
  it('sets readyPersisted=true and effectiveReady=true when member is connected', () => {
    const member = makeMember('u1', {
      presence: 'connected',
      readyPersisted: false,
      effectiveReady: false,
    });
    const updated = applySetReady(member, true);
    expect(updated.readyPersisted).toBe(true);
    expect(updated.effectiveReady).toBe(true);
  });

  it('sets readyPersisted=false and effectiveReady=false when calling set_ready(false) while connected', () => {
    const member = makeMember('u1', {
      presence: 'connected',
      readyPersisted: true,
      effectiveReady: true,
    });
    const updated = applySetReady(member, false);
    expect(updated.readyPersisted).toBe(false);
    expect(updated.effectiveReady).toBe(false);
  });

  it('sets readyPersisted=true but effectiveReady=false when member is disconnected', () => {
    const member = makeMember('u1', {
      presence: 'disconnected',
      readyPersisted: false,
      effectiveReady: false,
    });
    const updated = applySetReady(member, true);
    expect(updated.readyPersisted).toBe(true);
    expect(updated.effectiveReady).toBe(false);
  });

  it('does not mutate the original member', () => {
    const member = makeMember('u1', {
      presence: 'connected',
      readyPersisted: false,
      effectiveReady: false,
    });
    applySetReady(member, true);
    expect(member.readyPersisted).toBe(false);
    expect(member.effectiveReady).toBe(false);
  });

  it('preserves all other fields', () => {
    const member = makeMember('u1', { name: 'Alice', joinedAtMs: 500, lastHeartbeatMs: 600 });
    const updated = applySetReady(member, true);
    expect(updated.userId).toBe('u1');
    expect(updated.name).toBe('Alice');
    expect(updated.joinedAtMs).toBe(500);
    expect(updated.lastHeartbeatMs).toBe(600);
  });
});

// ─── Ready state across disconnect / reconnect ────────────────────────────────

describe('Ready state: disconnect preserves readyPersisted, effectiveReady becomes false', () => {
  it('after applyDisconnect: effectiveReady=false, readyPersisted preserved (was true)', () => {
    const member = makeMember('u1', {
      presence: 'connected',
      readyPersisted: true,
      effectiveReady: true,
    });
    const disconnected = applyDisconnect(member);
    expect(disconnected.effectiveReady).toBe(false);
    expect(disconnected.readyPersisted).toBe(true);
  });

  it('after applyDisconnect: effectiveReady=false, readyPersisted preserved (was false)', () => {
    const member = makeMember('u1', {
      presence: 'connected',
      readyPersisted: false,
      effectiveReady: false,
    });
    const disconnected = applyDisconnect(member);
    expect(disconnected.effectiveReady).toBe(false);
    expect(disconnected.readyPersisted).toBe(false);
  });

  it('after applyReconnect: effectiveReady restored from readyPersisted=true', () => {
    const member = makeMember('u1', {
      presence: 'disconnected',
      readyPersisted: true,
      effectiveReady: false,
    });
    const reconnected = applyReconnect(member);
    expect(reconnected.effectiveReady).toBe(true);
    expect(reconnected.readyPersisted).toBe(true);
  });

  it('after applyReconnect: effectiveReady restored from readyPersisted=false', () => {
    const member = makeMember('u1', {
      presence: 'disconnected',
      readyPersisted: false,
      effectiveReady: false,
    });
    const reconnected = applyReconnect(member);
    expect(reconnected.effectiveReady).toBe(false);
    expect(reconnected.readyPersisted).toBe(false);
  });

  it('full cycle: set_ready(true) → disconnect → reconnect restores effectiveReady=true', () => {
    const initial = makeMember('u1', {
      presence: 'connected',
      readyPersisted: false,
      effectiveReady: false,
    });
    const ready = applySetReady(initial, true);
    const disconnected = applyDisconnect(ready);
    const reconnected = applyReconnect(disconnected);
    expect(reconnected.readyPersisted).toBe(true);
    expect(reconnected.effectiveReady).toBe(true);
  });

  it('full cycle: set_ready(false) → disconnect → reconnect keeps effectiveReady=false', () => {
    const initial = makeMember('u1', {
      presence: 'connected',
      readyPersisted: true,
      effectiveReady: true,
    });
    const notReady = applySetReady(initial, false);
    const disconnected = applyDisconnect(notReady);
    const reconnected = applyReconnect(disconnected);
    expect(reconnected.readyPersisted).toBe(false);
    expect(reconnected.effectiveReady).toBe(false);
  });
});

describe('resetReadyStates', () => {
  it('clears all persisted/effective ready flags for player loading transitions', () => {
    const members = [
      makeMember('u1', { readyPersisted: true, effectiveReady: true }),
      makeMember('u2', { readyPersisted: true, effectiveReady: true }),
    ];

    const reset = resetReadyStates(members);
    expect(reset.map((member) => member.readyPersisted)).toEqual([false, false]);
    expect(reset.map((member) => member.effectiveReady)).toEqual([false, false]);
  });
});

// ─── HTTP /init: initial ready state ─────────────────────────────────────────

describe('HTTP /init: creator member initial ready state', () => {
  it('creator is created with effectiveReady=false', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await room.fetch(
      postJson('/init', {
        roomId: 'room-1',
        inviteCode: 'INV001',
        creatorId: 'user-1',
        creatorName: 'Alice',
        media: defaultMedia,
      })
    );
    const stored = await (state.storage as any).get('roomState');
    expect(stored.members[0].effectiveReady).toBe(false);
  });

  it('creator is created with readyPersisted=false', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await room.fetch(
      postJson('/init', {
        roomId: 'room-1',
        inviteCode: 'INV001',
        creatorId: 'user-1',
        creatorName: 'Alice',
        media: defaultMedia,
      })
    );
    const stored = await (state.storage as any).get('roomState');
    expect(stored.members[0].readyPersisted).toBe(false);
  });

  it('readyStates entry for creator has readyPersisted=false and effectiveReady=false', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await room.fetch(
      postJson('/init', {
        roomId: 'room-1',
        inviteCode: 'INV001',
        creatorId: 'user-1',
        creatorName: 'Alice',
        media: defaultMedia,
      })
    );
    const stored = await (state.storage as any).get('roomState');
    expect(stored.readyStates['user-1'].readyPersisted).toBe(false);
    expect(stored.readyStates['user-1'].effectiveReady).toBe(false);
  });
});

// ─── HTTP /join: initial ready state ─────────────────────────────────────────

describe('HTTP /join: new member initial ready state', () => {
  it('joining member is created with effectiveReady=false', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await room.fetch(
      postJson('/init', {
        roomId: 'room-1',
        inviteCode: 'INV001',
        creatorId: 'user-1',
        creatorName: 'Alice',
        media: defaultMedia,
      })
    );
    await room.fetch(postJson('/join', { userId: 'user-2', name: 'Bob' }));
    const stored = await (state.storage as any).get('roomState');
    const bob = stored.members.find((m: Member) => m.userId === 'user-2');
    expect(bob.effectiveReady).toBe(false);
  });

  it('joining member is created with readyPersisted=false', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await room.fetch(
      postJson('/init', {
        roomId: 'room-1',
        inviteCode: 'INV001',
        creatorId: 'user-1',
        creatorName: 'Alice',
        media: defaultMedia,
      })
    );
    await room.fetch(postJson('/join', { userId: 'user-2', name: 'Bob' }));
    const stored = await (state.storage as any).get('roomState');
    const bob = stored.members.find((m: Member) => m.userId === 'user-2');
    expect(bob.readyPersisted).toBe(false);
  });

  it('readyStates entry for joining member has readyPersisted=false and effectiveReady=false', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await room.fetch(
      postJson('/init', {
        roomId: 'room-1',
        inviteCode: 'INV001',
        creatorId: 'user-1',
        creatorName: 'Alice',
        media: defaultMedia,
      })
    );
    await room.fetch(postJson('/join', { userId: 'user-2', name: 'Bob' }));
    const stored = await (state.storage as any).get('roomState');
    expect(stored.readyStates['user-2'].readyPersisted).toBe(false);
    expect(stored.readyStates['user-2'].effectiveReady).toBe(false);
  });
});
