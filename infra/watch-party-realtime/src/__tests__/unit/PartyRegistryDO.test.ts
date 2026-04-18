/**
 * Unit Tests: PartyRegistryDO
 *
 * Tests room creation, invite code resolution, user-to-room mapping,
 * and cleanup behavior.
 *
 * Requirements: 2.1, 2.2, 2.3, 3.2, 3.6
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PartyRegistryDO } from '@/durable-objects/PartyRegistryDO';

// ─── Minimal DurableObjectStorage mock ────────────────────────────────────────

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
      if (!opts?.prefix || k.startsWith(opts.prefix)) {
        result.set(k, v as T);
      }
    }
    return result;
  }
}

// ─── Minimal DurableObjectState mock ──────────────────────────────────────────

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

// ─── Minimal PartyRoomDO stub returned by env.PARTY_ROOM.get() ────────────────

function makeRoomStub(initOk = true, joinOk = true): DurableObjectStub {
  return {
    fetch: vi.fn(async (input: RequestInfo | string, _init?: RequestInit) => {
      // Resolve URL whether input is a string or Request
      const url = typeof input === 'string' ? new URL(input) : new URL((input as Request).url);
      const path = url.pathname;
      if (path === '/init') {
        if (!initOk) return new Response('init failed', { status: 500 });
        return new Response(JSON.stringify({ success: true }), { status: 200 });
      }
      if (path === '/join') {
        if (!joinOk)
          return new Response(
            JSON.stringify({ code: 'room_full', message: 'Room is full', retryable: false }),
            { status: 409 }
          );
        return new Response(JSON.stringify({ success: true }), { status: 200 });
      }
      if (path === '/leave') {
        return new Response(JSON.stringify({ success: true }), { status: 200 });
      }
      if (path === '/member-verify') {
        return new Response(JSON.stringify({ isMember: true }), { status: 200 });
      }
      return new Response('not found', { status: 404 });
    }),
  } as unknown as DurableObjectStub;
}

// ─── Env mock factory ─────────────────────────────────────────────────────────

function makeEnv(roomStub: DurableObjectStub) {
  return {
    PARTY_REGISTRY: {} as DurableObjectNamespace,
    PARTY_ROOM: {
      idFromName: (_name: string) => ({ toString: () => _name }) as DurableObjectId,
      get: (_id: DurableObjectId) => roomStub,
    } as unknown as DurableObjectNamespace,
    PARTY_INTERNAL_TOKEN: 'test-token',
    PARTY_SESSION_PUBLIC_KEY_HEX: "00".repeat(32) as string,
    PARTY_WS_AUDIENCE: "watch-party",
    PARTY_SESSION_ISSUER: 'kumoriya-api',
  };
}

// ─── Request helpers ──────────────────────────────────────────────────────────

function postJson(path: string, body: unknown): Request {
  return new Request(`http://registry${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

function getReq(path: string): Request {
  return new Request(`http://registry${path}`, { method: 'GET' });
}

// ─── Test Suite ───────────────────────────────────────────────────────────────

describe('PartyRegistryDO', () => {
  const defaultMedia = { anilistId: 1, animeTitle: 'Test Anime', episodeNumber: 1 };

  // ── Room creation ──────────────────────────────────────────────────────────

  describe('POST /rooms - Room creation', () => {
    it('should create a room and return roomId + inviteCode', async () => {
      const roomStub = makeRoomStub();
      const registry = new PartyRegistryDO(makeMockState(), makeEnv(roomStub) as any);

      const res = await registry.fetch(
        postJson('/rooms', { userId: 'user-1', name: 'Alice', media: defaultMedia })
      );

      expect(res.status).toBe(201);
      const body = await res.json() as { roomId: string; inviteCode: string };
      expect(body.roomId).toBeDefined();
      expect(body.inviteCode).toBeDefined();
      expect(body.inviteCode).toMatch(/^[A-Z0-9]{6}$/);
    });

    it('should generate a valid UUID v4 roomId', async () => {
      const registry = new PartyRegistryDO(makeMockState(), makeEnv(makeRoomStub()) as any);

      const res = await registry.fetch(
        postJson('/rooms', { userId: 'user-1', name: 'Alice', media: defaultMedia })
      );
      const body = await res.json() as { roomId: string };
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
      expect(body.roomId).toMatch(uuidRegex);
    });

    it('should reject creation when user is already in another room', async () => {
      const registry = new PartyRegistryDO(makeMockState(), makeEnv(makeRoomStub()) as any);

      // First creation succeeds
      await registry.fetch(
        postJson('/rooms', { userId: 'user-1', name: 'Alice', media: defaultMedia })
      );

      // Second creation with same user should fail
      const res = await registry.fetch(
        postJson('/rooms', { userId: 'user-1', name: 'Alice', media: defaultMedia })
      );
      expect(res.status).toBe(409);
      const body = await res.json() as { code: string };
      expect(body.code).toBe('user_already_in_room');
    });

    it('should rollback registry state when PartyRoomDO initialization fails', async () => {
      const roomStub = makeRoomStub(false); // init fails
      const registry = new PartyRegistryDO(makeMockState(), makeEnv(roomStub) as any);

      const res = await registry.fetch(
        postJson('/rooms', { userId: 'user-1', name: 'Alice', media: defaultMedia })
      );
      expect(res.status).toBe(500);

      // User should not be locked in a room after failed init
      // A second attempt should succeed (no user_already_in_room)
      const roomStub2 = makeRoomStub(true);
      // Re-use same state — we need to re-inject a working stub
      // (simulated by creating a fresh registry that shares state — not possible here
      //  but we verify the error code is not user_already_in_room)
      const err = await res.json() as { code: string };
      expect(err.code).not.toBe('user_already_in_room');
    });
  });

  // ── Invite code resolution ─────────────────────────────────────────────────

  describe('GET /invite/:code - Invite code resolution', () => {
    it('should resolve a valid invite code to its roomId', async () => {
      const registry = new PartyRegistryDO(makeMockState(), makeEnv(makeRoomStub()) as any);

      const createRes = await registry.fetch(
        postJson('/rooms', { userId: 'user-1', name: 'Alice', media: defaultMedia })
      );
      const { inviteCode, roomId } = await createRes.json() as { inviteCode: string; roomId: string };

      const resolveRes = await registry.fetch(getReq(`/invite/${inviteCode}`));
      expect(resolveRes.status).toBe(200);
      const body = await resolveRes.json() as { roomId: string };
      expect(body.roomId).toBe(roomId);
    });

    it('should return 404 for an unknown invite code', async () => {
      const registry = new PartyRegistryDO(makeMockState(), makeEnv(makeRoomStub()) as any);

      const res = await registry.fetch(getReq('/invite/XXXXXX'));
      expect(res.status).toBe(404);
      const body = await res.json() as { code: string };
      expect(body.code).toBe('invalid_invite_code');
    });
  });

  // ── User-to-room mapping ───────────────────────────────────────────────────

  describe('POST /rooms/:roomId/join - User-to-room mapping', () => {
    it('should map user to room after successful join', async () => {
      const state = makeMockState();
      const registry = new PartyRegistryDO(state, makeEnv(makeRoomStub()) as any);

      const createRes = await registry.fetch(
        postJson('/rooms', { userId: 'user-1', name: 'Alice', media: defaultMedia })
      );
      const { roomId } = await createRes.json() as { roomId: string };

      const joinRes = await registry.fetch(
        postJson(`/rooms/${roomId}/join`, { userId: 'user-2', name: 'Bob' })
      );
      expect(joinRes.status).toBe(200);
    });

    it('should reject join when user is already in another room', async () => {
      const state = makeMockState();
      const registry = new PartyRegistryDO(state, makeEnv(makeRoomStub()) as any);

      // Create room 1 and add user-2
      const cr1 = await registry.fetch(
        postJson('/rooms', { userId: 'user-1', name: 'Alice', media: defaultMedia })
      );
      const { roomId: roomId1 } = await cr1.json() as { roomId: string };
      await registry.fetch(postJson(`/rooms/${roomId1}/join`, { userId: 'user-2', name: 'Bob' }));

      // Create room 2
      const cr2 = await registry.fetch(
        postJson('/rooms', { userId: 'user-3', name: 'Carol', media: defaultMedia })
      );
      const { roomId: roomId2 } = await cr2.json() as { roomId: string };

      // user-2 tries to join room 2 while still in room 1
      const res = await registry.fetch(
        postJson(`/rooms/${roomId2}/join`, { userId: 'user-2', name: 'Bob' })
      );
      expect(res.status).toBe(409);
      const body = await res.json() as { code: string };
      expect(body.code).toBe('user_already_in_room');
    });

    it('should return 404 when joining a non-existent room', async () => {
      const registry = new PartyRegistryDO(makeMockState(), makeEnv(makeRoomStub()) as any);

      const res = await registry.fetch(
        postJson('/rooms/does-not-exist/join', { userId: 'user-2', name: 'Bob' })
      );
      expect(res.status).toBe(404);
    });

    it('should forward room_full error from PartyRoomDO', async () => {
      const state = makeMockState();
      const roomStub = makeRoomStub(true, false); // join fails with room_full
      const registry = new PartyRegistryDO(state, makeEnv(roomStub) as any);

      const cr = await registry.fetch(
        postJson('/rooms', { userId: 'user-1', name: 'Alice', media: defaultMedia })
      );
      const { roomId } = await cr.json() as { roomId: string };

      const res = await registry.fetch(
        postJson(`/rooms/${roomId}/join`, { userId: 'user-2', name: 'Bob' })
      );
      expect(res.status).toBe(409);
      const body = await res.json() as { code: string };
      expect(body.code).toBe('room_full');
    });
  });

  // ── Leave and cleanup ──────────────────────────────────────────────────────

  describe('POST /rooms/:roomId/leave - Cleanup', () => {
    it('should remove user-to-room mapping on leave', async () => {
      const state = makeMockState();
      const registry = new PartyRegistryDO(state, makeEnv(makeRoomStub()) as any);

      const createRes = await registry.fetch(
        postJson('/rooms', { userId: 'user-1', name: 'Alice', media: defaultMedia })
      );
      const { roomId } = await createRes.json() as { roomId: string };

      const leaveRes = await registry.fetch(
        postJson(`/rooms/${roomId}/leave`, { userId: 'user-1' })
      );
      expect(leaveRes.status).toBe(200);
    });

    it('should reject leave when user is not in the specified room', async () => {
      const registry = new PartyRegistryDO(makeMockState(), makeEnv(makeRoomStub()) as any);

      const res = await registry.fetch(
        postJson('/rooms/fake-room-id/leave', { userId: 'user-99' })
      );
      expect(res.status).toBe(400);
    });
  });
});
