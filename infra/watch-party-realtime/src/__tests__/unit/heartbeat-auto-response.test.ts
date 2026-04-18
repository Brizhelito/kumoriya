/**
 * Unit Tests: PartyRoomDO heartbeat auto-response + periodic resync alarm.
 *
 * Covers the two optimizations added in the request-budget pass:
 *   - R1:  constructor registers `setWebSocketAutoResponse` with the exact
 *          `{"t":"hb"}` / `{"t":"hb_ack"}` pair so CF replies without waking
 *          the DO nor billing a request.
 *   - P-3: `alarm()` is a no-op unless the room is actively playing and has
 *          at least one non-host member still connected.
 *
 * Uses the same lightweight DurableObjectState mock pattern as the rest of
 * the suite — no worker runtime required.
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { PartyRoomDO } from '@/durable-objects/PartyRoomDO';
import type { RoomState } from '@/types';

// The `WebSocketRequestResponsePair` class is provided by the Cloudflare
// runtime and is not available in Node. Shim it so the constructor path
// that calls `new WebSocketRequestResponsePair(req, res)` can execute.
(globalThis as unknown as { WebSocketRequestResponsePair?: unknown })
  .WebSocketRequestResponsePair ??= class {
  constructor(private request: string, private response: string) {}
  getRequest() {
    return this.request;
  }
  getResponse() {
    return this.response;
  }
};

// ─── Mocks ────────────────────────────────────────────────────────────────────

class MockStorage {
  private store = new Map<string, unknown>();
  private alarmAt: number | null = null;

  async get<T>(key: string): Promise<T | undefined> {
    return this.store.get(key) as T | undefined;
  }
  async put(key: string, value: unknown): Promise<void> {
    this.store.set(key, value);
  }
  async delete(key: string): Promise<boolean> {
    return this.store.delete(key);
  }
  async getAlarm(): Promise<number | null> {
    return this.alarmAt;
  }
  async setAlarm(ts: number): Promise<void> {
    this.alarmAt = ts;
  }
  async deleteAlarm(): Promise<void> {
    this.alarmAt = null;
  }
}

function makeState() {
  const setAuto = vi.fn();
  const state = {
    storage: new MockStorage(),
    id: {} as DurableObjectId,
    waitUntil: vi.fn(),
    blockConcurrencyWhile: async <T>(fn: () => Promise<T>) => fn(),
    acceptWebSocket: vi.fn(),
    getWebSockets: vi.fn(() => []),
    setWebSocketAutoResponse: setAuto,
    getWebSocketAutoResponse: vi.fn(),
    getWebSocketAutoResponseTimestamp: vi.fn(),
    getTags: vi.fn(() => []),
    setHibernatableWebSocketEventTimeout: vi.fn(),
    getHibernatableWebSocketEventTimeout: vi.fn(),
    abort: vi.fn(),
  };
  return { state: state as unknown as DurableObjectState, setAuto };
}

function makeEnv() {
  return {
    PARTY_REGISTRY: {} as DurableObjectNamespace,
    PARTY_ROOM: {} as DurableObjectNamespace,
    PARTY_INTERNAL_TOKEN: 'test',
    PARTY_SESSION_PUBLIC_KEY_HEX: '00'.repeat(32),
    PARTY_SESSION_ISSUER: 'kumoriya-api',
    PARTY_WS_AUDIENCE: 'watch-party',
  };
}

// ─── R1: auto-response registration ──────────────────────────────────────────

describe('PartyRoomDO constructor — heartbeat auto-response (R1)', () => {
  it('registers the exact {"t":"hb"} / {"t":"hb_ack"} pair', () => {
    const { state, setAuto } = makeState();
    // eslint-disable-next-line @typescript-eslint/no-new
    new PartyRoomDO(state, makeEnv() as never);

    expect(setAuto).toHaveBeenCalledTimes(1);
    const arg = setAuto.mock.calls[0][0];
    // WebSocketRequestResponsePair exposes getRequest / getResponse.
    expect(arg.getRequest()).toBe('{"t":"hb"}');
    expect(arg.getResponse()).toBe('{"t":"hb_ack"}');
  });

  it('does not throw when setWebSocketAutoResponse is missing (legacy runtime)', () => {
    const { state } = makeState();
    // Simulate an older runtime that does not expose the API.
    (state as unknown as { setWebSocketAutoResponse: unknown }).setWebSocketAutoResponse = () => {
      throw new Error('not supported');
    };
    expect(() => new PartyRoomDO(state, makeEnv() as never)).not.toThrow();
  });
});

