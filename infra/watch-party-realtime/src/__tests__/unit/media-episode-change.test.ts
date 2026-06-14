/**
 * Unit Tests: Media and Episode Change Logic
 *
 * Tests:
 * - applyMediaChange updates anilistId
 * - applyEpisodeChange updates episodeNumber
 * - resetReadyStates resets all member ready states
 * - HTTP /init stores media correctly
 * - HTTP /join doesn't change media
 *
 * Requirements: 9.1, 9.2, 9.3, 9.4
 */

import { describe, it, expect, vi } from 'vitest';
import {
  PartyRoomDO,
  applyMediaChange,
  applyEpisodeChange,
  resetReadyStates,
} from '@/durable-objects/PartyRoomDO';
import type { Member, MediaState } from '@/types';

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
    PARTY_INTERNAL_TOKEN: 'test-token',
    PARTY_SESSION_PUBLIC_KEY_HEX: "00".repeat(32) as string,
    PARTY_WS_AUDIENCE: "watch-party",
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

function makeMedia(opts: Partial<MediaState> = {}): MediaState {
  return {
    anilistId: 100,
    animeTitle: 'Test Anime',
    episodeNumber: 1,
    ...opts,
  };
}

function makeMember(userId: string, opts: Partial<Member> = {}): Member {
  return {
    userId,
    name: `User ${userId}`,
    presence: 'connected',
    status: 'in_lobby',
    readyPersisted: false,
    effectiveReady: false,
    joinedAtMs: 1000,
    lastHeartbeatMs: 1000,
    ...opts,
  };
}

// ─── applyMediaChange ─────────────────────────────────────────────────────────

describe('applyMediaChange', () => {
  it('updates anilistId to the new value', () => {
    const media = makeMedia({ anilistId: 100 });
    expect(applyMediaChange(media, 999).anilistId).toBe(999);
  });

  it('preserves animeTitle', () => {
    const media = makeMedia({ animeTitle: 'My Anime' });
    expect(applyMediaChange(media, 200).animeTitle).toBe('My Anime');
  });

  it('preserves episodeNumber', () => {
    const media = makeMedia({ episodeNumber: 5 });
    expect(applyMediaChange(media, 200).episodeNumber).toBe(5);
  });

  it('does not mutate the original media state', () => {
    const media = makeMedia({ anilistId: 100 });
    applyMediaChange(media, 200);
    expect(media.anilistId).toBe(100);
  });
});

// ─── applyEpisodeChange ───────────────────────────────────────────────────────

describe('applyEpisodeChange', () => {
  it('updates episodeNumber to the new value', () => {
    const media = makeMedia({ episodeNumber: 1 });
    expect(applyEpisodeChange(media, 12).episodeNumber).toBe(12);
  });

  it('preserves anilistId', () => {
    const media = makeMedia({ anilistId: 42 });
    expect(applyEpisodeChange(media, 2).anilistId).toBe(42);
  });

  it('preserves animeTitle', () => {
    const media = makeMedia({ animeTitle: 'Naruto' });
    expect(applyEpisodeChange(media, 100).animeTitle).toBe('Naruto');
  });

  it('does not mutate the original media state', () => {
    const media = makeMedia({ episodeNumber: 1 });
    applyEpisodeChange(media, 5);
    expect(media.episodeNumber).toBe(1);
  });
});

// ─── resetReadyStates ─────────────────────────────────────────────────────────

describe('resetReadyStates', () => {
  it('sets readyPersisted=false for all members', () => {
    const members = [
      makeMember('u1', { readyPersisted: true, effectiveReady: true }),
      makeMember('u2', { readyPersisted: false, effectiveReady: false }),
      makeMember('u3', { readyPersisted: true, effectiveReady: false }),
    ];
    const reset = resetReadyStates(members);
    expect(reset.every((m) => m.readyPersisted === false)).toBe(true);
  });

  it('sets effectiveReady=false for all members', () => {
    const members = [
      makeMember('u1', { readyPersisted: true, effectiveReady: true }),
      makeMember('u2', { readyPersisted: true, effectiveReady: true }),
    ];
    const reset = resetReadyStates(members);
    expect(reset.every((m) => m.effectiveReady === false)).toBe(true);
  });

  it('returns an empty array for an empty input', () => {
    expect(resetReadyStates([])).toEqual([]);
  });

  it('does not mutate original members', () => {
    const members = [makeMember('u1', { readyPersisted: true, effectiveReady: true })];
    resetReadyStates(members);
    expect(members[0].readyPersisted).toBe(true);
    expect(members[0].effectiveReady).toBe(true);
  });

  it('preserves all other member fields (userId, name, presence, joinedAtMs)', () => {
    const members = [makeMember('u1', { name: 'Alice', presence: 'connected', joinedAtMs: 500 })];
    const reset = resetReadyStates(members);
    expect(reset[0].userId).toBe('u1');
    expect(reset[0].name).toBe('Alice');
    expect(reset[0].presence).toBe('connected');
    expect(reset[0].joinedAtMs).toBe(500);
  });

  it('works for disconnected members too', () => {
    const members = [
      makeMember('u1', { presence: 'disconnected', readyPersisted: true, effectiveReady: false }),
    ];
    const reset = resetReadyStates(members);
    expect(reset[0].readyPersisted).toBe(false);
    expect(reset[0].effectiveReady).toBe(false);
  });
});

// ─── HTTP /init: media stored correctly ──────────────────────────────────────

describe('HTTP /init: media state', () => {
  it('stores anilistId from init payload', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await room.fetch(postJson('/init', {
      roomId: 'room-1',
      inviteCode: 'INV001',
      creatorId: 'user-1',
      creatorName: 'Alice',
      media: { anilistId: 12345, animeTitle: 'One Piece', episodeNumber: 1 },
    }));
    const stored = await (state.storage as any).get('roomState');
    expect(stored.media.anilistId).toBe(12345);
  });

  it('stores animeTitle from init payload', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await room.fetch(postJson('/init', {
      roomId: 'room-1',
      inviteCode: 'INV001',
      creatorId: 'user-1',
      creatorName: 'Alice',
      media: { anilistId: 1, animeTitle: 'One Piece', episodeNumber: 3 },
    }));
    const stored = await (state.storage as any).get('roomState');
    expect(stored.media.animeTitle).toBe('One Piece');
  });

  it('stores episodeNumber from init payload', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await room.fetch(postJson('/init', {
      roomId: 'room-1',
      inviteCode: 'INV001',
      creatorId: 'user-1',
      creatorName: 'Alice',
      media: { anilistId: 1, animeTitle: 'Test', episodeNumber: 7 },
    }));
    const stored = await (state.storage as any).get('roomState');
    expect(stored.media.episodeNumber).toBe(7);
  });
});

// ─── HTTP /join: media is unchanged ──────────────────────────────────────────

describe('HTTP /join: does not change media', () => {
  it('media remains identical after a member joins', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    const media = { anilistId: 42, animeTitle: 'Attack on Titan', episodeNumber: 5 };
    await room.fetch(postJson('/init', {
      roomId: 'room-1',
      inviteCode: 'INV001',
      creatorId: 'user-1',
      creatorName: 'Alice',
      media,
    }));
    await room.fetch(postJson('/join', { userId: 'user-2', name: 'Bob' }));
    const stored = await (state.storage as any).get('roomState');
    expect(stored.media.anilistId).toBe(42);
    expect(stored.media.animeTitle).toBe('Attack on Titan');
    expect(stored.media.episodeNumber).toBe(5);
  });
});
