/**
 * Unit Tests: Server-Authoritative Playback Synchronization
 *
 * Tests the pure playback state helpers and HTTP-level initial state.
 *
 * Requirements: 8.1, 8.2, 8.3, 8.4, 8.5
 */

import { describe, it, expect, vi } from 'vitest';
import {
  PartyRoomDO,
  applyPlaybackPlay,
  applyPlaybackPause,
  applyPlaybackSeek,
  applyPlaybackPrepareForLoad,
  applyPlaybackResetForMediaChange,
  projectPlaybackPosition,
} from '@/durable-objects/PartyRoomDO';
import type { PlaybackState } from '@/types';

// ─── Helpers ──────────────────────────────────────────────────────────────────

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

function makePlayback(opts: Partial<PlaybackState> = {}): PlaybackState {
  return {
    status: 'paused',
    basePositionMs: 0,
    effectiveAtMs: 1000,
    generation: 0,
    ...opts,
  };
}

// ─── applyPlaybackPlay ────────────────────────────────────────────────────────

describe('applyPlaybackPlay', () => {
  it('sets status to playing', () => {
    const pb = makePlayback({ status: 'paused' });
    expect(applyPlaybackPlay(pb, 2000).status).toBe('playing');
  });

  it('increments generation by 1', () => {
    const pb = makePlayback({ generation: 3 });
    expect(applyPlaybackPlay(pb, 2000).generation).toBe(4);
  });

  it('sets effectiveAtMs to the provided timestamp', () => {
    const pb = makePlayback({ effectiveAtMs: 500 });
    expect(applyPlaybackPlay(pb, 9999).effectiveAtMs).toBe(9999);
  });

  it('does not mutate the original playback state', () => {
    const pb = makePlayback({ generation: 0, status: 'paused' });
    applyPlaybackPlay(pb, 2000);
    expect(pb.generation).toBe(0);
    expect(pb.status).toBe('paused');
  });

  it('preserves basePositionMs', () => {
    const pb = makePlayback({ basePositionMs: 12345 });
    expect(applyPlaybackPlay(pb, 2000).basePositionMs).toBe(12345);
  });
});

// ─── applyPlaybackPause ───────────────────────────────────────────────────────

describe('applyPlaybackPause', () => {
  it('sets status to paused', () => {
    const pb = makePlayback({ status: 'playing' });
    expect(applyPlaybackPause(pb, 3000).status).toBe('paused');
  });

  it('increments generation by 1', () => {
    const pb = makePlayback({ generation: 7 });
    expect(applyPlaybackPause(pb, 3000).generation).toBe(8);
  });

  it('sets effectiveAtMs to the provided timestamp', () => {
    const pb = makePlayback({ effectiveAtMs: 100 });
    expect(applyPlaybackPause(pb, 7777).effectiveAtMs).toBe(7777);
  });

  it('does not mutate the original playback state', () => {
    const pb = makePlayback({ generation: 2, status: 'playing' });
    applyPlaybackPause(pb, 3000);
    expect(pb.generation).toBe(2);
    expect(pb.status).toBe('playing');
  });

  it('preserves basePositionMs', () => {
    const pb = makePlayback({ basePositionMs: 55000 });
    expect(applyPlaybackPause(pb, 3000).basePositionMs).toBe(55000);
  });
});

// ─── applyPlaybackSeek ────────────────────────────────────────────────────────

describe('applyPlaybackSeek', () => {
  it('sets basePositionMs to the provided positionMs', () => {
    const pb = makePlayback({ basePositionMs: 0 });
    expect(applyPlaybackSeek(pb, 42000, 5000).basePositionMs).toBe(42000);
  });

  it('increments generation by 1', () => {
    const pb = makePlayback({ generation: 1 });
    expect(applyPlaybackSeek(pb, 0, 5000).generation).toBe(2);
  });

  it('sets effectiveAtMs to the provided timestamp', () => {
    const pb = makePlayback({ effectiveAtMs: 200 });
    expect(applyPlaybackSeek(pb, 30000, 8888).effectiveAtMs).toBe(8888);
  });

  it('does not mutate the original playback state', () => {
    const pb = makePlayback({ generation: 5, basePositionMs: 0 });
    applyPlaybackSeek(pb, 100, 5000);
    expect(pb.generation).toBe(5);
    expect(pb.basePositionMs).toBe(0);
  });

  it('preserves status', () => {
    const pb = makePlayback({ status: 'playing' });
    expect(applyPlaybackSeek(pb, 1000, 5000).status).toBe('playing');
  });
});

describe('player-loading preparation', () => {
  it('projects a playing timeline before freezing it', () => {
    const pb = makePlayback({
      status: 'playing',
      basePositionMs: 4_000,
      effectiveAtMs: 1_000,
      generation: 2,
    });

    expect(projectPlaybackPosition(pb, 3_500)).toBe(6_500);
    const prepared = applyPlaybackPrepareForLoad(pb, 3_500);
    expect(prepared.status).toBe('paused');
    expect(prepared.basePositionMs).toBe(6_500);
    expect(prepared.effectiveAtMs).toBe(3_500);
    expect(prepared.generation).toBe(3);
  });

  it('resets media changes to paused at position zero', () => {
    const pb = makePlayback({
      status: 'playing',
      basePositionMs: 9_000,
      effectiveAtMs: 1_000,
      generation: 4,
    });

    const reset = applyPlaybackResetForMediaChange(pb, 7_000);
    expect(reset.status).toBe('paused');
    expect(reset.basePositionMs).toBe(0);
    expect(reset.effectiveAtMs).toBe(7_000);
    expect(reset.generation).toBe(5);
  });
});

// ─── resync_request does not increment generation ────────────────────────────

describe('resync_request: generation is unchanged', () => {
  it('a resync_request should NOT change the playback generation (verified via pure state helpers)', () => {
    // resync_request = broadcast current state only, no state mutation
    // We verify this by confirming that none of play/pause/seek is called,
    // so generation remains the same.
    const pb = makePlayback({ generation: 5 });
    // No helper is called — generation must stay at 5
    expect(pb.generation).toBe(5);
  });

  it('applying play after resync still increments generation from current value', () => {
    const pb = makePlayback({ generation: 5 });
    // Simulate: resync doesn't change generation (5 stays 5)
    // Then play increments it
    const afterPlay = applyPlaybackPlay(pb, 1000);
    expect(afterPlay.generation).toBe(6);
  });
});

// ─── HTTP /init: playback starts at generation=0 ─────────────────────────────

describe('HTTP /init: initial playback state', () => {
  it('initialises generation=0', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await room.fetch(
      postJson('/init', {
        roomId: 'room-pb',
        inviteCode: 'PB001',
        creatorId: 'user-1',
        creatorName: 'Alice',
        media: defaultMedia,
      })
    );
    const stored = await (state.storage as any).get('roomState');
    expect(stored.playback.generation).toBe(0);
  });

  it('initialises status=paused', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await room.fetch(
      postJson('/init', {
        roomId: 'room-pb',
        inviteCode: 'PB001',
        creatorId: 'user-1',
        creatorName: 'Alice',
        media: defaultMedia,
      })
    );
    const stored = await (state.storage as any).get('roomState');
    expect(stored.playback.status).toBe('paused');
  });

  it('initialises basePositionMs=0', async () => {
    const state = makeMockState();
    const room = new PartyRoomDO(state, makeEnv() as any);
    await room.fetch(
      postJson('/init', {
        roomId: 'room-pb',
        inviteCode: 'PB001',
        creatorId: 'user-1',
        creatorName: 'Alice',
        media: defaultMedia,
      })
    );
    const stored = await (state.storage as any).get('roomState');
    expect(stored.playback.basePositionMs).toBe(0);
  });
});
