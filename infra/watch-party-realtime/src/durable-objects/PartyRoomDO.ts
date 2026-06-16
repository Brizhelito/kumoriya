/**
 * PartyRoomDO - Per-Room Durable Object
 *
 * Manages authoritative state for a single watch party room:
 * - Membership and presence
 * - Ready states (dual-layer: readyPersisted / effectiveReady)
 * - Playback state (server-authoritative)
 * - Host authority and transfer
 * - Rate limiting
 * - Grace period management
 * - WebSocket message routing and broadcasting
 *
 * Tasks 6.1 + 6.2
 */

import { Env } from '../types/env';
import type { RoomState, Member, MemberStatus, PlaybackState, MediaState } from '../types/room';
import { buildAck, buildError, parseEnvelope, validateMessageId } from '../messaging/ack';
import type { WSEnvelope, PlaybackIntentPayload } from '../types/messages';

// ─── Grace period constants ───────────────────────────────────────────────────

const MEMBER_GRACE_PERIOD_MS = 120_000; // 120 seconds for non-host members
const HOST_GRACE_PERIOD_MS = 60_000; // 60 seconds for host
const EMPTY_ROOM_TTL_MS = 900_000; // 15 minutes

// ─── Heartbeat auto-response (R1) ─────────────────────────────────────────────
//
// The Cloudflare Durable Object runtime can reply to a fixed request string
// with a fixed response string WITHOUT waking the DO from hibernation and
// WITHOUT incurring a billable request. This is the single biggest cost
// reduction lever available for a long-lived WebSocket: our clients heartbeat
// once every 45s per session, so skipping those round-trips trims the DO
// request rate by ~95% for an active party.
//
// Kept short to stay well under the 2,048-char cap and to minimise the bytes
// flowing on every session. The companion client change sends this exact
// literal — any drift (whitespace, extra keys, etc.) would bypass the
// auto-response and fall back to the billable `handleHeartbeat` path.
const HEARTBEAT_AUTO_REQUEST = '{"t":"hb"}';
const HEARTBEAT_AUTO_RESPONSE = '{"t":"hb_ack"}';

// ─── Rate limiting constants ──────────────────────────────────────────────────

/** Token-bucket refill rates per user. */
const RATE_LIMITS: Record<string, { capacity: number; refillPerSec: number }> = {
  // Reactions bucket: 8 events / 10s window. Text chat was removed in favour
  // of (future) voice chat, so the former `chat` bucket no longer exists.
  reaction: { capacity: 8, refillPerSec: 0.8 },
  // Playback intents are slower to avoid thrash.
  playback_intent: { capacity: 6, refillPerSec: 0.6 },
  // WebRTC signaling can be chatty during ICE negotiation.
  webrtc_signal: { capacity: 30, refillPerSec: 5 },
};

interface TokenBucket {
  tokens: number;
  updatedMs: number;
}

/**
 * Pure token-bucket helper. Exported for unit testing the rate-limit math
 * without needing to spin up the Durable Object.
 *
 * Mutates the provided bucket in place. Returns true when the request
 * was allowed, false when rate-limited.
 */
export function consumeFromBucket(
  bucket: TokenBucket | undefined,
  spec: { capacity: number; refillPerSec: number },
  nowMs: number
): { allowed: boolean; bucket: TokenBucket } {
  const b: TokenBucket = bucket ?? { tokens: spec.capacity, updatedMs: nowMs };
  const elapsedSec = Math.max(0, (nowMs - b.updatedMs) / 1000);
  b.tokens = Math.min(spec.capacity, b.tokens + elapsedSec * spec.refillPerSec);
  b.updatedMs = nowMs;
  if (b.tokens < 1) return { allowed: false, bucket: b };
  b.tokens -= 1;
  return { allowed: true, bucket: b };
}

/** Default rate-limit specs used by PartyRoomDO. Exported for tests. */
export const DEFAULT_RATE_LIMITS: Record<string, { capacity: number; refillPerSec: number }> = {
  reaction: { capacity: 8, refillPerSec: 0.8 },
  playback_intent: { capacity: 6, refillPerSec: 0.6 },
  webrtc_signal: { capacity: 30, refillPerSec: 5 },
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function buildEnvelope(
  type: string,
  payload: unknown,
  roomId?: string,
  roomVersion?: number
): WSEnvelope {
  return {
    type,
    roomId,
    eventId: crypto.randomUUID(),
    sentAt: Date.now(),
    payload,
    ...(roomVersion !== undefined ? { roomVersion } : {}),
  };
}

// ─── Public helper types (exported for unit tests) ────────────────────────────

/** Apply a disconnect to a member: set presence=disconnected, effectiveReady=false */
export function applyDisconnect(member: Member): Member {
  return { ...member, presence: 'disconnected', effectiveReady: false };
}

/** Apply a reconnect to a member: set presence=connected, restore effectiveReady from readyPersisted */
export function applyReconnect(member: Member): Member {
  return { ...member, presence: 'connected', effectiveReady: member.readyPersisted };
}

/** Update lastHeartbeatMs */
export function applyHeartbeat(member: Member, nowMs: number): Member {
  return { ...member, lastHeartbeatMs: nowMs };
}

/** Find the oldest connected member by joinedAtMs, excluding a specific userId */
export function findOldestConnectedMember(
  members: Member[],
  excludeUserId?: string
): Member | undefined {
  return members
    .filter((m) => m.presence === 'connected' && m.userId !== excludeUserId)
    .sort((a, b) => a.joinedAtMs - b.joinedAtMs)[0];
}

/** Check if a userId is the current host */
export function isHost(hostId: string, userId: string): boolean {
  return hostId === userId;
}

/**
 * Transfer host to the oldest connected member (excluding oldHostId).
 * Returns the updated hostId, or the existing hostId if no transfer possible.
 */
export function transferHost(hostId: string, members: Member[]): string {
  const newHost = findOldestConnectedMember(members, hostId);
  return newHost ? newHost.userId : hostId;
}

/** Apply set_ready to a member: update readyPersisted and derive effectiveReady */
export function applySetReady(member: Member, ready: boolean): Member {
  const effectiveReady = ready && member.presence === 'connected';
  return { ...member, readyPersisted: ready, effectiveReady };
}

/** Apply set_status to a member: update the member's activity status */
export function applySetStatus(member: Member, status: MemberStatus): Member {
  return { ...member, status };
}

/** Apply play action to playback state */
export function applyPlaybackPlay(playback: PlaybackState, nowMs: number): PlaybackState {
  return {
    ...playback,
    status: 'playing',
    effectiveAtMs: nowMs,
    generation: playback.generation + 1,
  };
}

/** Apply pause action to playback state */
export function applyPlaybackPause(playback: PlaybackState, nowMs: number): PlaybackState {
  return {
    ...playback,
    status: 'paused',
    effectiveAtMs: nowMs,
    generation: playback.generation + 1,
  };
}

/** Apply seek action to playback state */
export function applyPlaybackSeek(
  playback: PlaybackState,
  positionMs: number,
  nowMs: number
): PlaybackState {
  return {
    ...playback,
    basePositionMs: positionMs,
    effectiveAtMs: nowMs,
    generation: playback.generation + 1,
  };
}

/** Project the effective playback position to a specific wall-clock time. */
export function projectPlaybackPosition(playback: PlaybackState, nowMs: number): number {
  if (playback.status !== 'playing') {
    return playback.basePositionMs;
  }
  return playback.basePositionMs + Math.max(0, nowMs - playback.effectiveAtMs);
}

/** Freeze playback in paused state for a synchronized player-loading phase. */
export function applyPlaybackPrepareForLoad(playback: PlaybackState, nowMs: number): PlaybackState {
  return {
    ...playback,
    status: 'paused',
    basePositionMs: projectPlaybackPosition(playback, nowMs),
    effectiveAtMs: nowMs,
    generation: playback.generation + 1,
  };
}

/** Reset playback to the start of the current media and keep it paused. */
export function applyPlaybackResetForMediaChange(
  playback: PlaybackState,
  nowMs: number
): PlaybackState {
  return {
    ...playback,
    status: 'paused',
    basePositionMs: 0,
    effectiveAtMs: nowMs,
    generation: playback.generation + 1,
  };
}

/** Apply media_change: update anilistId */
export function applyMediaChange(media: MediaState, anilistId: number): MediaState {
  return { ...media, anilistId };
}

/** Apply episode_change: update episodeNumber */
export function applyEpisodeChange(media: MediaState, episodeNumber: number): MediaState {
  return { ...media, episodeNumber };
}

/** Reset all members' ready states to false */
export function resetReadyStates(members: Member[]): Member[] {
  return members.map((m) => ({ ...m, readyPersisted: false, effectiveReady: false }));
}

// ─── PartyRoomDO ─────────────────────────────────────────────────────────────

export class PartyRoomDO {
  private state: DurableObjectState;
  private env: Env;

  // ── In-memory state ────────────────────────────────────────────────────────

  /** Active WebSocket connections keyed by userId (multiple per user for reconnect) */
  private activeConnections: Map<string, WebSocket[]> = new Map();

  /** Grace period timers keyed by userId */
  private gracePeriodTimers: Map<string, ReturnType<typeof setTimeout>> = new Map();

  /** Empty-room TTL timer */
  private emptyRoomTimer: ReturnType<typeof setTimeout> | null = null;

  /** Rate-limit buckets: userId -> bucketName -> TokenBucket */
  private rateBuckets: Map<string, Map<string, TokenBucket>> = new Map();

  constructor(state: DurableObjectState, env: Env) {
    this.state = state;
    this.env = env;

    // Register the heartbeat auto-response as early as possible so that
    // any WebSockets already attached from a previous DO lifetime (i.e.
    // sockets that survived hibernation) benefit on their next message.
    // This call is idempotent and cheap; doing it once per construction
    // is sufficient since CF persists the auto-response config for the
    // lifetime of the DO.
    try {
      this.state.setWebSocketAutoResponse(
        new WebSocketRequestResponsePair(HEARTBEAT_AUTO_REQUEST, HEARTBEAT_AUTO_RESPONSE)
      );
    } catch {
      // Older runtimes / test mocks may not expose this API. Failing
      // here would break every deploy path that mocks DurableObjectState
      // in unit tests, so we swallow the error — the only downside is
      // that legacy heartbeats keep hitting `handleHeartbeat`.
    }

    // Rehydrate the per-user connection cache from any WebSockets that
    // CF preserved across DO hibernation. Without this rebuild, the
    // first broadcast after a wake-up would treat the room as empty.
    this.rehydrateConnectionsFromState();
  }

  /**
   * Rebuild the in-memory `activeConnections` map from sockets the CF
   * runtime has re-attached to this DO instance. Safe to call multiple
   * times; runs in O(n) over the current socket count.
   */
  private rehydrateConnectionsFromState(): void {
    let sockets: WebSocket[];
    try {
      sockets = this.state.getWebSockets();
    } catch {
      return;
    }
    for (const ws of sockets) {
      let attachment: unknown;
      try {
        attachment = (ws as any).deserializeAttachment?.();
      } catch {
        continue;
      }
      const userId =
        attachment && typeof (attachment as any).userId === 'string'
          ? ((attachment as any).userId as string)
          : undefined;
      if (!userId) continue;
      const bucket = this.activeConnections.get(userId) ?? [];
      bucket.push(ws);
      this.activeConnections.set(userId, bucket);
    }
  }

  // ─── Fetch handler ─────────────────────────────────────────────────────────

  async fetch(request: Request): Promise<Response> {
    if (request.headers.get('Upgrade') === 'websocket') {
      return this.handleWebSocket(request);
    }

    const url = new URL(request.url);
    const path = url.pathname;

    if (path === '/init' && request.method === 'POST') {
      return this.handleInit(request);
    }
    if (path === '/join' && request.method === 'POST') {
      return this.handleJoin(request);
    }
    if (path === '/leave' && request.method === 'POST') {
      return this.handleLeave(request);
    }
    if (path === '/member-verify' && request.method === 'POST') {
      return this.handleMemberVerify(request);
    }

    return new Response('Not Found', { status: 404 });
  }

  // ─── HTTP handlers ─────────────────────────────────────────────────────────

  private async handleInit(request: Request): Promise<Response> {
    const body = (await request.json()) as {
      roomId: string;
      inviteCode: string;
      creatorId: string;
      creatorName: string;
      media: { anilistId: number; animeTitle: string; episodeNumber: number };
    };

    const now = Date.now();
    const roomState: RoomState = {
      roomId: body.roomId,
      inviteCode: body.inviteCode,
      hostId: body.creatorId,
      members: [
        {
          userId: body.creatorId,
          name: body.creatorName,
          presence: 'connected',
          readyPersisted: false,
          effectiveReady: false,
          status: 'in_lobby',
          joinedAtMs: now,
          lastHeartbeatMs: now,
        },
      ],
      readyStates: {
        [body.creatorId]: { readyPersisted: false, effectiveReady: false },
      },
      media: body.media,
      playback: {
        status: 'paused',
        basePositionMs: 0,
        effectiveAtMs: now,
        generation: 0,
      },
      roomVersion: 1,
      createdAt: now,
      lastActivityAt: now,
    };

    await this.state.storage.put('roomState', roomState);
    return json({ success: true });
  }

  private async handleJoin(request: Request): Promise<Response> {
    const body = (await request.json()) as { userId: string; name: string };
    const roomState = await this.getRoomState();

    if (!roomState) {
      return json({ code: 'room_not_found', message: 'Room not found', retryable: false }, 404);
    }

    if (roomState.members.length >= 4) {
      return json(
        { code: 'room_full', message: 'Room is full (max 4 members)', retryable: false },
        409
      );
    }

    const now = Date.now();
    const newMember: Member = {
      userId: body.userId,
      name: body.name,
      presence: 'connected',
      readyPersisted: false,
      effectiveReady: false,
      status: 'in_lobby',
      joinedAtMs: now,
      lastHeartbeatMs: now,
    };

    roomState.members.push(newMember);
    roomState.readyStates[body.userId] = { readyPersisted: false, effectiveReady: false };
    roomState.roomVersion += 1;
    roomState.lastActivityAt = now;

    await this.state.storage.put('roomState', roomState);

    this.broadcast(
      buildEnvelope(
        'member_joined',
        { member: newMember },
        roomState.roomId,
        roomState.roomVersion
      ),
      body.userId
    );

    return json({ success: true });
  }

  private async handleLeave(request: Request): Promise<Response> {
    const body = (await request.json()) as { userId: string };
    const roomState = await this.getRoomState();

    if (!roomState) {
      return json({ code: 'room_not_found', message: 'Room not found', retryable: false }, 404);
    }

    const leavingMember = roomState.members.find((m) => m.userId === body.userId);
    if (!leavingMember) {
      return json(
        { code: 'not_found', message: 'User is not a member of this room', retryable: false },
        404
      );
    }

    // Cancel grace period timer if any
    this.clearGracePeriodTimer(body.userId);

    // Close the user's WebSocket connections
    const sockets = this.activeConnections.get(body.userId) ?? [];
    for (const ws of sockets) {
      try {
        ws.close(1000, 'left_room');
      } catch {
        /* ignore */
      }
    }
    this.activeConnections.delete(body.userId);

    roomState.members = roomState.members.filter((m) => m.userId !== body.userId);
    delete roomState.readyStates[body.userId];

    let newHostId: string | undefined;
    if (roomState.hostId === body.userId && roomState.members.length > 0) {
      const newHost = findOldestConnectedMember(roomState.members);
      if (newHost) {
        roomState.hostId = newHost.userId;
        newHostId = newHost.userId;
      }
    }

    roomState.roomVersion += 1;
    roomState.lastActivityAt = Date.now();

    await this.state.storage.put('roomState', roomState);

    this.broadcast(
      buildEnvelope(
        'member_left',
        { userId: body.userId, newHostId },
        roomState.roomId,
        roomState.roomVersion
      )
    );

    if (newHostId) {
      this.broadcast(
        buildEnvelope(
          'host_transferred',
          { oldHostId: body.userId, newHostId },
          roomState.roomId,
          roomState.roomVersion
        )
      );
    }

    this.startEmptyRoomTimerIfNeeded(roomState);

    return json({ success: true });
  }

  private async handleMemberVerify(request: Request): Promise<Response> {
    const body = (await request.json()) as { userId: string };
    const roomState = await this.getRoomState();

    if (!roomState) {
      return json({ code: 'room_not_found', message: 'Room not found', retryable: false }, 404);
    }

    const member = roomState.members.find((m) => m.userId === body.userId);
    const inGrace = this.gracePeriodTimers.has(body.userId);

    if (!member && !inGrace) {
      return json(
        { code: 'unauthorized', message: 'User is not a member of this room', retryable: false },
        403
      );
    }

    return json({ isMember: true });
  }

  // ─── WebSocket handler ─────────────────────────────────────────────────────

  private async handleWebSocket(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const userId = url.searchParams.get('userId') ?? '';
    const displayName = url.searchParams.get('name') ?? '';
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair) as [WebSocket, WebSocket];

    const roomState = await this.getRoomState();
    if (!roomState) {
      // Accept + close synchronously so the 101 response still includes a
      // client socket. Using `server.accept()` here is fine because we
      // never intend to keep this WS alive.
      server.accept();
      server.close(4003, 'room_not_found');
      return new Response(null, { status: 101, webSocket: client } as any);
    }

    const existingMember = roomState.members.find((m) => m.userId === userId);
    if (!existingMember) {
      server.accept();
      server.close(4003, 'not_a_member');
      return new Response(null, { status: 101, webSocket: client } as any);
    }

    // ── Hibernation API handshake (R1) ─────────────────────────────────
    //
    // `acceptWebSocket` attaches `server` to the DO lifecycle and allows
    // the DO to hibernate between bursts of activity. Messages are then
    // delivered via the class-level `webSocketMessage` method (not via
    // `addEventListener`). The `tags` array is used later by
    // `getWebSockets(tag)` to find all sockets for a given user without
    // relying on our in-memory `activeConnections` map, which is lost on
    // hibernation.
    this.state.acceptWebSocket(server, [userId]);
    // Persist per-connection identity so `webSocketMessage` can recover
    // the userId without hitting storage.
    try {
      (server as any).serializeAttachment?.({ userId });
    } catch {
      // Older runtimes may not expose this — fall back silently. The
      // rehydration path will still map userIds via tags in getWebSockets.
    }

    // Refresh display name from the token if it changed.
    if (displayName && existingMember.name !== displayName) {
      existingMember.name = displayName;
    }

    // Register connection in the in-memory cache. The cache accelerates
    // broadcasts while the DO is warm; hibernation-safety is covered by
    // `rehydrateConnectionsFromState` in the constructor.
    const sockets = this.activeConnections.get(userId) ?? [];
    sockets.push(server);
    this.activeConnections.set(userId, sockets);

    // Handle reconnect within grace period
    if (existingMember.presence === 'disconnected') {
      this.clearGracePeriodTimer(userId);
      existingMember.presence = 'connected';
      existingMember.effectiveReady = existingMember.readyPersisted;
      roomState.readyStates[userId] = {
        readyPersisted: existingMember.readyPersisted,
        effectiveReady: existingMember.effectiveReady,
      };
      roomState.lastActivityAt = Date.now();
      await this.state.storage.put('roomState', roomState);

      this.broadcast(
        buildEnvelope(
          'member_presence_changed',
          { userId, presence: 'connected' },
          roomState.roomId,
          roomState.roomVersion
        ),
        userId
      );
    } else if (displayName && existingMember.name !== displayName) {
      // Only persist if we actually changed a field. Previously this
      // branch unconditionally wrote roomState for every reconnect, which
      // added one DO storage op per WS upgrade.
      await this.state.storage.put('roomState', roomState);
    }

    // Send room snapshot
    this.sendSnapshot(server, roomState);

    return new Response(null, { status: 101, webSocket: client } as any);
  }

  // ─── Hibernation-API event entrypoints ──────────────────────────────────
  //
  // These class-level methods replace the `addEventListener('message'|
  // 'close'|'error')` handlers. They are invoked by the CF runtime even
  // if the DO was hibernated and had to be re-instantiated. The current
  // DurableObjectState attaches the WebSocket before any of these fire,
  // so `deserializeAttachment` reliably returns whatever we set in
  // `handleWebSocket`.

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    // Auto-response heartbeats never reach this method, so `message`
    // here is always non-trivial. Binary frames are not part of our
    // protocol — drop them silently.
    if (typeof message !== 'string') return;

    const userId = this.getAttachedUserId(ws);
    if (!userId) return;
    await this.handleMessage(ws, userId, message).catch(() => {});
  }

  async webSocketClose(
    ws: WebSocket,
    _code: number,
    _reason: string,
    _wasClean: boolean
  ): Promise<void> {
    const userId = this.getAttachedUserId(ws);
    if (!userId) return;
    await this.handleDisconnect(userId).catch(() => {});
  }

  async webSocketError(ws: WebSocket, _error: unknown): Promise<void> {
    const userId = this.getAttachedUserId(ws);
    if (!userId) return;
    await this.handleDisconnect(userId).catch(() => {});
  }

  private getAttachedUserId(ws: WebSocket): string | undefined {
    try {
      const att = (ws as any).deserializeAttachment?.();
      if (att && typeof att.userId === 'string') return att.userId as string;
    } catch {
      // ignore
    }
    // Fall back to CF's per-tag bookkeeping. `acceptWebSocket(ws, [userId])`
    // marks the socket with that tag; the runtime exposes the list of
    // tags via `getTags(ws)` on the state.
    try {
      const tags = this.state.getTags(ws);
      return tags.length > 0 ? tags[0] : undefined;
    } catch {
      return undefined;
    }
  }

  // ─── WebSocket message dispatch ────────────────────────────────────────────

  private async handleMessage(ws: WebSocket, userId: string, raw: string): Promise<void> {
    const roomState = await this.getRoomState();
    if (!roomState) return;

    const envelope = parseEnvelope(raw, roomState.roomId);
    if (!envelope) {
      ws.send(
        JSON.stringify(
          buildError('invalid_message', 'Malformed message', false, undefined, roomState.roomId)
        )
      );
      return;
    }

    const idError = validateMessageId(envelope, roomState.roomId);
    if (idError) {
      ws.send(JSON.stringify(idError));
      return;
    }

    switch (envelope.type) {
      case 'heartbeat':
        await this.handleHeartbeat(ws, userId, roomState, envelope);
        break;
      case 'hello':
        ws.send(
          JSON.stringify(
            buildAck(envelope.messageId ?? crypto.randomUUID(), 'hello', roomState.roomId)
          )
        );
        break;
      case 'request_snapshot':
        this.sendSnapshot(ws, roomState);
        break;
      case 'playback_intent':
        await this.handlePlaybackIntent(ws, userId, roomState, envelope);
        break;
      case 'set_ready':
        await this.handleSetReady(ws, userId, roomState, envelope);
        break;
      case 'set_status':
        await this.handleSetStatus(ws, userId, roomState, envelope);
        break;
      case 'send_reaction':
        await this.handleSendReaction(ws, userId, roomState, envelope);
        break;
      case 'webrtc_signal':
        this.handleWebRtcSignal(ws, userId, roomState, envelope);
        break;
      case 'leave_room':
        await this.handleLeaveFromSocket(ws, userId, roomState, envelope);
        break;
      case 'kick_member':
        await this.handleKickMember(ws, userId, roomState, envelope);
        break;
      case 'transfer_host':
        await this.handleTransferHost(ws, userId, roomState, envelope);
        break;
      default:
        ws.send(
          JSON.stringify(
            buildError(
              'invalid_message',
              `Unknown message type '${envelope.type}'`,
              false,
              envelope.messageId,
              roomState.roomId
            )
          )
        );
        break;
    }
  }

  /** Consume one token from the named bucket for a user. Returns true if allowed. */
  private consumeToken(userId: string, bucketName: string): boolean {
    const spec = RATE_LIMITS[bucketName];
    if (!spec) return true; // Unmetered
    let userBuckets = this.rateBuckets.get(userId);
    if (!userBuckets) {
      userBuckets = new Map();
      this.rateBuckets.set(userId, userBuckets);
    }
    const result = consumeFromBucket(userBuckets.get(bucketName), spec, Date.now());
    userBuckets.set(bucketName, result.bucket);
    return result.allowed;
  }

  private rejectRateLimited(ws: WebSocket, envelope: WSEnvelope, roomId: string): void {
    ws.send(
      JSON.stringify(
        buildError(
          'rate_limit_exceeded',
          'Rate limit exceeded. Please slow down.',
          true,
          envelope.messageId,
          roomId
        )
      )
    );
  }

  private async handleHeartbeat(
    ws: WebSocket,
    userId: string,
    roomState: RoomState,
    envelope: WSEnvelope
  ): Promise<void> {
    // Fallback path for legacy clients that still wrap heartbeats in a full
    // envelope. New clients send the raw `HEARTBEAT_AUTO_REQUEST` string
    // which the CF runtime replies to without billing a DO request.
    //
    // R3: we used to `storage.put('roomState', ...)` here — one DO storage
    // write every 25-45s per connected client. That single write dominated
    // the cost of a long-running party. The in-memory update is kept so
    // that stale-peer detection heuristics keep working while the DO is
    // warm; if the DO hibernates and restarts, `lastHeartbeatMs` is lost,
    // but the very next auto-response or state-modifying message will
    // refresh the liveness signal anyway.
    const member = roomState.members.find((m) => m.userId === userId);
    if (member) {
      member.lastHeartbeatMs = Date.now();
    }
    // Legacy clients may set a messageId; acknowledge only in that case so
    // the reconnect correlation logic on the client still works.
    if (envelope.messageId) {
      ws.send(JSON.stringify(buildAck(envelope.messageId, 'heartbeat', roomState.roomId)));
    }
  }

  /**
   * Handle set_ready — dual-layer ready state update
   */
  private async handleSetReady(
    ws: WebSocket,
    userId: string,
    roomState: RoomState,
    envelope: WSEnvelope
  ): Promise<void> {
    const payload = envelope.payload as { ready: boolean };
    const ready = payload.ready;

    const member = roomState.members.find((m) => m.userId === userId);
    if (!member) return;

    member.readyPersisted = ready;
    member.effectiveReady = ready && member.presence === 'connected';
    roomState.readyStates[userId] = {
      readyPersisted: member.readyPersisted,
      effectiveReady: member.effectiveReady,
    };
    roomState.roomVersion += 1;
    roomState.lastActivityAt = Date.now();
    await this.state.storage.put('roomState', roomState);

    this.broadcast(
      buildEnvelope(
        'member_ready_changed',
        { userId, effectiveReady: member.effectiveReady },
        roomState.roomId,
        roomState.roomVersion
      )
    );

    if (envelope.messageId) {
      ws.send(JSON.stringify(buildAck(envelope.messageId, 'set_ready', roomState.roomId)));
    }

    // Auto-resume if waiting on a ready barrier and everyone is now ready
    if (roomState.playback.awaitReady) {
      const allReady = roomState.members
        .filter((m) => m.presence === 'connected')
        .every((m) => m.effectiveReady);
      if (allReady) {
        roomState.playback.status = 'playing';
        roomState.playback.awaitReady = false;
        roomState.playback.effectiveAtMs = Date.now();
        roomState.playback.generation += 1;
        roomState.roomVersion += 1;
        roomState.lastActivityAt = Date.now();
        await this.state.storage.put('roomState', roomState);
        this.broadcast(this.buildPlaybackStateChangedEnvelope(roomState));
      }
    }
  }

  /**
   * Handle set_status — member activity status update (any member can set their own status)
   */
  private async handleSetStatus(
    ws: WebSocket,
    userId: string,
    roomState: RoomState,
    envelope: WSEnvelope
  ): Promise<void> {
    const payload = envelope.payload as { status: MemberStatus };
    const status = payload.status;

    const member = roomState.members.find((m) => m.userId === userId);
    if (!member) return;

    const wasWatching = member.status === 'watching';
    member.status = status;
    roomState.roomVersion += 1;
    roomState.lastActivityAt = Date.now();
    await this.state.storage.put('roomState', roomState);

    this.broadcast(
      buildEnvelope(
        'member_status_changed',
        { userId, status },
        roomState.roomId,
        roomState.roomVersion
      )
    );

    if (wasWatching && (status === 'in_lobby' || status === 'buffering')) {
      await this._applyAutoPause(roomState);
    }

    if (envelope.messageId) {
      ws.send(JSON.stringify(buildAck(envelope.messageId, 'set_status', roomState.roomId)));
    }
  }

  /**
   * Handle playback_intent — host-only, server-authoritative playback control
   */
  private async handlePlaybackIntent(
    ws: WebSocket,
    userId: string,
    roomState: RoomState,
    envelope: WSEnvelope
  ): Promise<void> {
    if (roomState.hostId !== userId) {
      ws.send(
        JSON.stringify(
          buildError(
            'unauthorized',
            'Only the host can send playback_intent',
            false,
            envelope.messageId,
            roomState.roomId
          )
        )
      );
      return;
    }

    const payload = envelope.payload as PlaybackIntentPayload;
    const now = Date.now();

    switch (payload.action) {
      case 'play':
      case 'pause': {
        // An optional `positionMs` on play/pause is treated as an implicit
        // seek so members do not rewind to a stale `basePositionMs=0` when
        // the host toggles playback away from the start of the episode.
        if (typeof payload.positionMs === 'number') {
          roomState.playback.basePositionMs = payload.positionMs;
        }
        roomState.playback.status = payload.action === 'play' ? 'playing' : 'paused';
        roomState.playback.effectiveAtMs = now;
        roomState.playback.generation += 1;
        break;
      }
      case 'seek':
        if (payload.positionMs !== undefined) {
          roomState.playback.basePositionMs = payload.positionMs;
          roomState.playback.status = 'paused';
          roomState.playback.awaitReady = true;
          roomState.playback.effectiveAtMs = now;
          roomState.playback.generation += 1;
          const resetIds = this.resetAllReadyStates(roomState);
          
          // Persist state before broadcasting
          roomState.roomVersion += 1;
          roomState.lastActivityAt = now;
          await this.state.storage.put('roomState', roomState);

          this.broadcast(this.buildPlaybackStateChangedEnvelope(roomState));
          
          for (const resetUserId of resetIds) {
            this.broadcast(
              buildEnvelope(
                'member_ready_changed',
                { userId: resetUserId, effectiveReady: false },
                roomState.roomId,
                roomState.roomVersion
              )
            );
          }
          if (envelope.messageId) {
            ws.send(
              JSON.stringify(buildAck(envelope.messageId, 'playback_intent', roomState.roomId))
            );
          }
          return;
        }
        break;
      case 'media_change':
        if (payload.anilistId !== undefined) {
          roomState.media.anilistId = payload.anilistId;
          if (payload.animeTitle !== undefined) {
            roomState.media.animeTitle = payload.animeTitle;
          }
          if (payload.episodeNumber !== undefined) {
            roomState.media.episodeNumber = payload.episodeNumber;
          }
          roomState.playback = applyPlaybackResetForMediaChange(roomState.playback, now);
          // Exempt the host (origin of the intent): their next PlayerPage
          // will re-mark ready immediately and the round-trip flicker is
          // user-visible as a spurious "waiting for everyone" toast.
          const mediaResetIds = this.resetAllReadyStates(roomState, userId);
          roomState.roomVersion += 1;
          roomState.lastActivityAt = now;
          await this.state.storage.put('roomState', roomState);
          this.broadcast(
            buildEnvelope(
              'media_changed',
              { media: roomState.media, resetPosition: true, resetReady: true },
              roomState.roomId,
              roomState.roomVersion
            )
          );
          for (const resetUserId of mediaResetIds) {
            this.broadcast(
              buildEnvelope(
                'member_ready_changed',
                { userId: resetUserId, effectiveReady: false },
                roomState.roomId,
                roomState.roomVersion
              )
            );
          }
          if (envelope.messageId) {
            ws.send(
              JSON.stringify(buildAck(envelope.messageId, 'playback_intent', roomState.roomId))
            );
          }
          return;
        }
        break;
      case 'episode_change':
        if (payload.episodeNumber !== undefined) {
          roomState.media.episodeNumber = payload.episodeNumber;
          if (payload.animeTitle !== undefined) {
            roomState.media.animeTitle = payload.animeTitle;
          }
          roomState.playback = applyPlaybackResetForMediaChange(roomState.playback, now);
          const episodeResetIds = this.resetAllReadyStates(roomState, userId);
          roomState.roomVersion += 1;
          roomState.lastActivityAt = now;
          await this.state.storage.put('roomState', roomState);
          this.broadcast(
            buildEnvelope(
              'episode_changed',
              { episodeNumber: payload.episodeNumber, resetPosition: true, resetReady: true },
              roomState.roomId,
              roomState.roomVersion
            )
          );
          for (const resetUserId of episodeResetIds) {
            this.broadcast(
              buildEnvelope(
                'member_ready_changed',
                { userId: resetUserId, effectiveReady: false },
                roomState.roomId,
                roomState.roomVersion
              )
            );
          }
          if (envelope.messageId) {
            ws.send(
              JSON.stringify(buildAck(envelope.messageId, 'playback_intent', roomState.roomId))
            );
          }
          return;
        }
        break;
      case 'resync_request':
        // Broadcast current state without incrementing generation
        this.broadcast(this.buildPlaybackStateChangedEnvelope(roomState));
        if (envelope.messageId) {
          ws.send(
            JSON.stringify(buildAck(envelope.messageId, 'playback_intent', roomState.roomId))
          );
        }
        return;
      case 'start_watching':
        // Transition the room from "lobby ready" into "player loading".
        // Everybody must re-ack readiness once their player is actually open,
        // and playback is frozen in paused state so no device runs ahead.
        roomState.playback = applyPlaybackPrepareForLoad(roomState.playback, now);
        this.resetAllReadyStates(roomState);
        roomState.roomVersion += 1;
        roomState.lastActivityAt = now;
        await this.state.storage.put('roomState', roomState);
        this.broadcast(
          buildEnvelope(
            'start_watching',
            { media: roomState.media, playback: roomState.playback },
            roomState.roomId,
            roomState.roomVersion
          )
        );
        for (const member of roomState.members) {
          this.broadcast(
            buildEnvelope(
              'member_ready_changed',
              { userId: member.userId, effectiveReady: false },
              roomState.roomId,
              roomState.roomVersion
            )
          );
        }
        if (envelope.messageId) {
          ws.send(
            JSON.stringify(buildAck(envelope.messageId, 'playback_intent', roomState.roomId))
          );
        }
        return;
      case 'source_selected':
        // Notification-only: tells every client which source/server the
        // host just selected, so members can auto-resolve the same
        // provider. Does not touch timeline state — the server stays
        // authoritative on play/pause/seek.
        if (
          typeof payload.sourcePluginId !== 'string' ||
          typeof payload.serverName !== 'string' ||
          typeof payload.episodeNumber !== 'number'
        ) {
          ws.send(
            JSON.stringify(
              buildError(
                'invalid_message',
                'source_selected requires sourcePluginId, serverName and episodeNumber',
                false,
                envelope.messageId,
                roomState.roomId
              )
            )
          );
          return;
        }
        this.broadcast(
          buildEnvelope(
            'source_selected',
            {
              sourcePluginId: payload.sourcePluginId,
              serverName: payload.serverName,
              resolverPluginId: payload.resolverPluginId,
              episodeNumber: payload.episodeNumber,
              selectedAtMs: now,
            },
            roomState.roomId,
            roomState.roomVersion
          )
        );
        if (envelope.messageId) {
          ws.send(
            JSON.stringify(buildAck(envelope.messageId, 'playback_intent', roomState.roomId))
          );
        }
        return;
    }

    // Persist and broadcast for state-changing actions
    roomState.roomVersion += 1;
    roomState.lastActivityAt = now;
    await this.state.storage.put('roomState', roomState);

    this.broadcast(this.buildPlaybackStateChangedEnvelope(roomState));

    if (envelope.messageId) {
      ws.send(JSON.stringify(buildAck(envelope.messageId, 'playback_intent', roomState.roomId)));
    }
  }

  /**
   * Auto-pause the room when a member who was watching leaves the player
   * or disconnects. This is server-initiated and bypasses the host check.
   */
  private async _applyAutoPause(roomState: RoomState): Promise<void> {
    const now = Date.now();
    roomState.playback.status = 'paused';
    roomState.playback.effectiveAtMs = now;
    roomState.playback.generation += 1;
    roomState.roomVersion += 1;
    roomState.lastActivityAt = now;
    await this.state.storage.put('roomState', roomState);

    this.broadcast(this.buildPlaybackStateChangedEnvelope(roomState));
  }

  // ─── Playback-state envelope helper ───────────────────────────────
  //
  // Every `playback_state_changed` broadcast carries `serverTimeMs` so the
  // member-side EWMA (`_applyPlayback` in realtime_state.dart) can keep the
  // client↔server clock offset fresh without any explicit ping/pong.
  //
  // We intentionally removed the periodic `alarm()`-driven resync: modern
  // NTP-synced devices drift well under 100 ms/hour, which is invisible for
  // 24 fps anime playback. Drift correction is now client-driven — the
  // player compares actual vs. projected position every ~30 s and issues a
  // `resync_request` only when the gap exceeds the tolerance band. That
  // saves ~360 DO requests/hour per active party while keeping sync tight.

  /** Build an envelope carrying the current playback plus server wall-clock. */
  private buildPlaybackStateChangedEnvelope(roomState: RoomState): WSEnvelope {
    return buildEnvelope(
      'playback_state_changed',
      { ...roomState.playback, serverTimeMs: Date.now() },
      roomState.roomId,
      roomState.roomVersion
    );
  }

  /**
   * Reset ready states to false (in-place mutation of roomState).
   *
   * When `exemptUserId` is provided, that member keeps their current ready
   * state and is excluded from the returned list. This is used when the
   * host originates a media/episode change — the host will remain on the
   * driver seat across the transition, so clearing their ready only to
   * have the new PlayerPage re-emit `toggleReady(true)` a moment later
   * flickers the host's UI into a spurious "waiting for everyone" state.
   *
   * Returns the list of userIds whose ready state was actually cleared, so
   * callers can broadcast `member_ready_changed` only for them.
   */
  private resetAllReadyStates(roomState: RoomState, exemptUserId?: string): string[] {
    const resetIds: string[] = [];
    for (const member of roomState.members) {
      if (exemptUserId !== undefined && member.userId === exemptUserId) {
        continue;
      }
      member.readyPersisted = false;
      member.effectiveReady = false;
      roomState.readyStates[member.userId] = { readyPersisted: false, effectiveReady: false };
      resetIds.push(member.userId);
    }
    return resetIds;
  }

  // ─── Reactions / signaling relay ──────────────────────────────────────────
  //
  // NOTE: text chat was intentionally removed — voice chat (future) is a
  // better fit for watch parties and does not transit the DO, so we skip
  // the request + moderation cost entirely.

  private async handleSendReaction(
    ws: WebSocket,
    userId: string,
    roomState: RoomState,
    envelope: WSEnvelope
  ): Promise<void> {
    const member = roomState.members.find((m) => m.userId === userId);
    if (!member) {
      ws.send(
        JSON.stringify(
          buildError(
            'unauthorized',
            'Not a member of this room',
            false,
            envelope.messageId,
            roomState.roomId
          )
        )
      );
      return;
    }
    if (!this.consumeToken(userId, 'reaction')) {
      this.rejectRateLimited(ws, envelope, roomState.roomId);
      return;
    }
    const payload = envelope.payload as { reaction?: unknown } | null | undefined;
    const reaction = payload && typeof payload.reaction === 'string' ? payload.reaction : '';
    if (!reaction || reaction.length > 16) {
      ws.send(
        JSON.stringify(
          buildError(
            'invalid_message',
            'Reaction must be 1..16 chars',
            false,
            envelope.messageId,
            roomState.roomId
          )
        )
      );
      return;
    }

    const now = Date.now();
    const reactionEnvelope: WSEnvelope = {
      ...buildEnvelope(
        'reaction_broadcast',
        {
          reactionId: crypto.randomUUID(),
          senderId: userId,
          senderName: member.name,
          reaction,
          sentAt: now,
        },
        roomState.roomId,
        roomState.roomVersion
      ),
      sender: userId,
    };
    this.broadcast(reactionEnvelope);

    if (envelope.messageId) {
      ws.send(JSON.stringify(buildAck(envelope.messageId, 'send_reaction', roomState.roomId)));
    }
  }

  /**
   * Relay a WebRTC signaling message (offer/answer/ICE candidate) to a target
   * peer in the same room. Reserved for future voice chat; does not touch
   * playback/lobby state.
   */
  private handleWebRtcSignal(
    ws: WebSocket,
    userId: string,
    roomState: RoomState,
    envelope: WSEnvelope
  ): void {
    if (!this.consumeToken(userId, 'webrtc_signal')) {
      this.rejectRateLimited(ws, envelope, roomState.roomId);
      return;
    }
    const payload = envelope.payload as
      | { targetUserId?: string; type?: string; signal?: unknown }
      | null
      | undefined;
    if (
      !payload ||
      typeof payload.targetUserId !== 'string' ||
      typeof payload.type !== 'string' ||
      payload.signal === undefined
    ) {
      ws.send(
        JSON.stringify(
          buildError(
            'invalid_message',
            'webrtc_signal requires targetUserId, type, signal',
            false,
            envelope.messageId,
            roomState.roomId
          )
        )
      );
      return;
    }
    if (payload.targetUserId === userId) {
      // self-loop makes no sense
      return;
    }
    const targetSockets = this.activeConnections.get(payload.targetUserId) ?? [];
    if (targetSockets.length === 0) {
      // Target not connected. Do not error noisily — voice-chat layer retries.
      return;
    }
    const relayEnvelope: WSEnvelope = {
      ...buildEnvelope(
        'webrtc_signal',
        { senderId: userId, type: payload.type, signal: payload.signal },
        roomState.roomId,
        roomState.roomVersion
      ),
      sender: userId,
    };
    const serialized = JSON.stringify(relayEnvelope);
    for (const target of targetSockets) {
      try {
        target.send(serialized);
      } catch {
        /* ignore dead socket */
      }
    }
    if (envelope.messageId) {
      ws.send(JSON.stringify(buildAck(envelope.messageId, 'webrtc_signal', roomState.roomId)));
    }
  }

  private async handleLeaveFromSocket(
    ws: WebSocket,
    userId: string,
    roomState: RoomState,
    envelope: WSEnvelope
  ): Promise<void> {
    const member = roomState.members.find((m) => m.userId === userId);
    if (!member) return;

    // Cancel grace period timer if any, then proceed with a full member removal.
    this.clearGracePeriodTimer(userId);

    // Close all sockets for this user so the client sees a clean shutdown.
    const sockets = this.activeConnections.get(userId) ?? [];
    for (const socket of sockets) {
      try {
        socket.close(1000, 'left_room');
      } catch {
        /* ignore */
      }
    }
    this.activeConnections.delete(userId);
    this.rateBuckets.delete(userId);

    roomState.members = roomState.members.filter((m) => m.userId !== userId);
    delete roomState.readyStates[userId];

    let newHostId: string | undefined;
    if (roomState.hostId === userId && roomState.members.length > 0) {
      const newHost = findOldestConnectedMember(roomState.members);
      if (newHost) {
        roomState.hostId = newHost.userId;
        newHostId = newHost.userId;
      }
    }

    roomState.roomVersion += 1;
    roomState.lastActivityAt = Date.now();
    await this.state.storage.put('roomState', roomState);

    this.broadcast(
      buildEnvelope('member_left', { userId, newHostId }, roomState.roomId, roomState.roomVersion)
    );
    if (newHostId) {
      this.broadcast(
        buildEnvelope(
          'host_transferred',
          { oldHostId: userId, newHostId },
          roomState.roomId,
          roomState.roomVersion
        )
      );
    }

    if (envelope.messageId) {
      ws.send(JSON.stringify(buildAck(envelope.messageId, 'leave_room', roomState.roomId)));
    }

    this.startEmptyRoomTimerIfNeeded(roomState);
  }

  /**
   * Handle kick_member — host-only eviction of another member.
   *
   * Sends a targeted `kicked` event to the victim before closing their
   * sockets so the client can show a proper "you were removed" message
   * rather than a generic disconnect. The Registry's `userRoom:*` entry
   * for the victim is intentionally NOT force-cleaned here: the
   * self-heal path in `handleCreateRoom`/`handleJoinRoom` drops the
   * stale mapping the next time the victim acts, and doing the cleanup
   * synchronously would require an additional Registry round-trip on
   * every kick for a case that is already idempotent.
   */
  private async handleKickMember(
    ws: WebSocket,
    userId: string,
    roomState: RoomState,
    envelope: WSEnvelope
  ): Promise<void> {
    if (roomState.hostId !== userId) {
      ws.send(
        JSON.stringify(
          buildError(
            'unauthorized',
            'Only the host can kick members',
            false,
            envelope.messageId,
            roomState.roomId
          )
        )
      );
      return;
    }
    const payload = envelope.payload as
      | { targetUserId?: unknown; reason?: unknown }
      | null
      | undefined;
    const targetUserId =
      payload && typeof payload.targetUserId === 'string' ? payload.targetUserId : '';
    const rawReason = payload && typeof payload.reason === 'string' ? payload.reason : undefined;
    const reason = rawReason ? rawReason.slice(0, 200) : undefined;
    if (!targetUserId) {
      ws.send(
        JSON.stringify(
          buildError(
            'invalid_message',
            'kick_member requires targetUserId',
            false,
            envelope.messageId,
            roomState.roomId
          )
        )
      );
      return;
    }
    if (targetUserId === userId) {
      ws.send(
        JSON.stringify(
          buildError(
            'invalid_message',
            'Host cannot kick themselves; leave the room instead',
            false,
            envelope.messageId,
            roomState.roomId
          )
        )
      );
      return;
    }

    const targetMember = roomState.members.find((m) => m.userId === targetUserId);
    if (!targetMember) {
      ws.send(
        JSON.stringify(
          buildError(
            'not_found',
            'Target user is not a member of this room',
            false,
            envelope.messageId,
            roomState.roomId
          )
        )
      );
      return;
    }

    // Send a targeted `kicked` event to every live socket of the victim
    // BEFORE closing them, so their client can distinguish a kick from a
    // network drop.
    const targetSockets = this.activeConnections.get(targetUserId) ?? [];
    const kickedEnvelope = buildEnvelope(
      'kicked',
      { byUserId: userId, reason },
      roomState.roomId,
      roomState.roomVersion
    );
    const kickedSerialized = JSON.stringify(kickedEnvelope);
    for (const socket of targetSockets) {
      try {
        socket.send(kickedSerialized);
      } catch {
        /* ignore */
      }
    }

    // Now perform the standard eviction.
    this.clearGracePeriodTimer(targetUserId);
    for (const socket of targetSockets) {
      try {
        socket.close(4003, 'kicked');
      } catch {
        /* ignore */
      }
    }
    this.activeConnections.delete(targetUserId);
    this.rateBuckets.delete(targetUserId);

    roomState.members = roomState.members.filter((m) => m.userId !== targetUserId);
    delete roomState.readyStates[targetUserId];
    roomState.roomVersion += 1;
    roomState.lastActivityAt = Date.now();
    await this.state.storage.put('roomState', roomState);

    this.broadcast(
      buildEnvelope(
        'member_left',
        { userId: targetUserId, reason: 'kicked' },
        roomState.roomId,
        roomState.roomVersion
      )
    );

    if (envelope.messageId) {
      ws.send(JSON.stringify(buildAck(envelope.messageId, 'kick_member', roomState.roomId)));
    }

    this.startEmptyRoomTimerIfNeeded(roomState);
  }

  /**
   * Handle transfer_host — current host hands authority to another
   * connected member without leaving. The existing `host_transferred`
   * event carries the new `hostId` so every client rewrites their local
   * projection uniformly.
   */
  private async handleTransferHost(
    ws: WebSocket,
    userId: string,
    roomState: RoomState,
    envelope: WSEnvelope
  ): Promise<void> {
    if (roomState.hostId !== userId) {
      ws.send(
        JSON.stringify(
          buildError(
            'unauthorized',
            'Only the host can transfer host authority',
            false,
            envelope.messageId,
            roomState.roomId
          )
        )
      );
      return;
    }
    const payload = envelope.payload as { targetUserId?: unknown } | null | undefined;
    const targetUserId =
      payload && typeof payload.targetUserId === 'string' ? payload.targetUserId : '';
    if (!targetUserId) {
      ws.send(
        JSON.stringify(
          buildError(
            'invalid_message',
            'transfer_host requires targetUserId',
            false,
            envelope.messageId,
            roomState.roomId
          )
        )
      );
      return;
    }
    if (targetUserId === userId) {
      // Same host, no-op but ack for symmetry.
      if (envelope.messageId) {
        ws.send(JSON.stringify(buildAck(envelope.messageId, 'transfer_host', roomState.roomId)));
      }
      return;
    }
    const targetMember = roomState.members.find((m) => m.userId === targetUserId);
    if (!targetMember) {
      ws.send(
        JSON.stringify(
          buildError(
            'not_found',
            'Target user is not a member of this room',
            false,
            envelope.messageId,
            roomState.roomId
          )
        )
      );
      return;
    }
    // Refuse to hand over to a disconnected member — the new host would
    // immediately enter grace period, leaving the party without an
    // active host.
    if (targetMember.presence !== 'connected') {
      ws.send(
        JSON.stringify(
          buildError(
            'invalid_state',
            'Target user is not currently connected',
            true,
            envelope.messageId,
            roomState.roomId
          )
        )
      );
      return;
    }

    const oldHostId = roomState.hostId;
    roomState.hostId = targetUserId;
    roomState.roomVersion += 1;
    roomState.lastActivityAt = Date.now();
    await this.state.storage.put('roomState', roomState);

    this.broadcast(
      buildEnvelope(
        'host_transferred',
        { oldHostId, newHostId: targetUserId },
        roomState.roomId,
        roomState.roomVersion
      )
    );

    if (envelope.messageId) {
      ws.send(JSON.stringify(buildAck(envelope.messageId, 'transfer_host', roomState.roomId)));
    }
  }

  // ─── Disconnect / grace period logic ──────────────────────────────────────

  private async handleDisconnect(userId: string): Promise<void> {
    const roomState = await this.getRoomState();
    if (!roomState) return;

    // Remove this socket from active connections
    const sockets = this.activeConnections.get(userId) ?? [];
    const aliveSockets = sockets.filter((ws) => {
      try {
        // readyState 3 = CLOSED, 2 = CLOSING — both mean dead
        return (ws as any).readyState < 2;
      } catch {
        return false;
      }
    });

    if (aliveSockets.length > 0) {
      this.activeConnections.set(userId, aliveSockets);
      // User still has another live socket — no grace period
      return;
    }

    this.activeConnections.delete(userId);

    const member = roomState.members.find((m) => m.userId === userId);
    if (!member) return;

    // Update presence and effectiveReady
    const wasWatching = member.status === 'watching';
    member.presence = 'disconnected';
    member.effectiveReady = false;
    roomState.readyStates[userId] = {
      readyPersisted: member.readyPersisted,
      effectiveReady: false,
    };
    roomState.lastActivityAt = Date.now();
    await this.state.storage.put('roomState', roomState);

    this.broadcast(
      buildEnvelope(
        'member_presence_changed',
        { userId, presence: 'disconnected' },
        roomState.roomId,
        roomState.roomVersion
      )
    );

    if (wasWatching) {
      await this._applyAutoPause(roomState);
    }

    // Determine grace period length
    const graceMs = roomState.hostId === userId ? HOST_GRACE_PERIOD_MS : MEMBER_GRACE_PERIOD_MS;

    // Clear any existing timer for this user
    this.clearGracePeriodTimer(userId);

    const timer = setTimeout(() => {
      this.onGracePeriodExpired(userId).catch(() => {});
    }, graceMs);

    this.gracePeriodTimers.set(userId, timer);
  }

  private async onGracePeriodExpired(userId: string): Promise<void> {
    this.gracePeriodTimers.delete(userId);

    const roomState = await this.getRoomState();
    if (!roomState) return;

    const memberIndex = roomState.members.findIndex((m) => m.userId === userId);
    if (memberIndex === -1) return; // Already removed

    roomState.members.splice(memberIndex, 1);
    delete roomState.readyStates[userId];
    this.rateBuckets.delete(userId);

    let newHostId: string | undefined;
    if (roomState.hostId === userId && roomState.members.length > 0) {
      const newHost = findOldestConnectedMember(roomState.members);
      if (newHost) {
        roomState.hostId = newHost.userId;
        newHostId = newHost.userId;
      }
    }

    roomState.roomVersion += 1;
    roomState.lastActivityAt = Date.now();
    await this.state.storage.put('roomState', roomState);

    this.broadcast(
      buildEnvelope('member_left', { userId, newHostId }, roomState.roomId, roomState.roomVersion)
    );

    if (newHostId) {
      this.broadcast(
        buildEnvelope(
          'host_transferred',
          { oldHostId: userId, newHostId },
          roomState.roomId,
          roomState.roomVersion
        )
      );
    }

    this.startEmptyRoomTimerIfNeeded(roomState);
  }

  // ─── Empty room TTL ────────────────────────────────────────────────────────

  private startEmptyRoomTimerIfNeeded(roomState: RoomState): void {
    if (roomState.members.length > 0) {
      // Room not empty — cancel any existing timer
      if (this.emptyRoomTimer !== null) {
        clearTimeout(this.emptyRoomTimer);
        this.emptyRoomTimer = null;
      }
      return;
    }
    if (this.emptyRoomTimer !== null) return; // Already scheduled

    this.emptyRoomTimer = setTimeout(() => {
      this.destroyRoom().catch(() => {});
    }, EMPTY_ROOM_TTL_MS);
  }

  private async destroyRoom(): Promise<void> {
    this.emptyRoomTimer = null;
    const roomState = await this.getRoomState();
    if (!roomState) return;

    // Close all remaining connections
    for (const sockets of this.activeConnections.values()) {
      for (const ws of sockets) {
        try {
          ws.close(1000, 'room_destroyed');
        } catch {
          /* ignore */
        }
      }
    }
    this.activeConnections.clear();

    // Broadcast room_closed before clearing
    this.broadcast(buildEnvelope('room_closed', { reason: 'empty_timeout' }, roomState.roomId));

    await this.state.storage.delete('roomState');
  }

  // ─── Broadcast / send helpers ──────────────────────────────────────────────

  /** Send an envelope to all connected sockets, optionally excluding one user */
  private broadcast(envelope: WSEnvelope, excludeUserId?: string): void {
    const payload = JSON.stringify(envelope);
    for (const [userId, sockets] of this.activeConnections) {
      if (userId === excludeUserId) continue;
      for (const ws of sockets) {
        try {
          ws.send(payload);
        } catch {
          /* ignore dead socket */
        }
      }
    }
  }

  /** Send an envelope to a specific user's sockets */
  private sendToUser(userId: string, envelope: WSEnvelope): void {
    const payload = JSON.stringify(envelope);
    const sockets = this.activeConnections.get(userId) ?? [];
    for (const ws of sockets) {
      try {
        ws.send(payload);
      } catch {
        /* ignore */
      }
    }
  }

  /** Send the current room snapshot to a specific WebSocket */
  private sendSnapshot(ws: WebSocket, roomState: RoomState): void {
    const snapshot = buildEnvelope(
      'room_snapshot',
      {
        roomId: roomState.roomId,
        inviteCode: roomState.inviteCode,
        hostId: roomState.hostId,
        members: roomState.members,
        media: roomState.media,
        playback: roomState.playback,
        roomVersion: roomState.roomVersion,
        serverTimeMs: Date.now(),
      },
      roomState.roomId,
      roomState.roomVersion
    );
    try {
      ws.send(JSON.stringify(snapshot));
    } catch {
      /* ignore */
    }
  }

  // ─── Storage helper ────────────────────────────────────────────────────────

  private async getRoomState(): Promise<RoomState | undefined> {
    return this.state.storage.get<RoomState>('roomState');
  }

  private clearGracePeriodTimer(userId: string): void {
    const existing = this.gracePeriodTimers.get(userId);
    if (existing !== undefined) {
      clearTimeout(existing);
      this.gracePeriodTimers.delete(userId);
    }
  }
}
