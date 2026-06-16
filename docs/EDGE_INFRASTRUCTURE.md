# Edge Infrastructure

> **Cloudflare Workers and Durable Objects powering real-time features at the edge.**

---

## Table of Contents

1. [Overview](#overview)
2. [watch-party-realtime Worker](#watch-party-realtime-worker)
3. [PartyRoomDO — Room State Machine](#partyroomdo--room-state-machine)
4. [PartyRegistryDO — Global Registry](#partyregistrydo--global-registry)
5. [WebSocket Protocol](#websocket-protocol)
6. [Session Token Authentication](#session-token-authentication)
7. [Cost Optimization](#cost-optimization)
8. [join-worker](#join-worker)
9. [Testing Strategy](#testing-strategy)
10. [Deployment](#deployment)

---

## Overview

Kumoriya's edge tier consists of two Cloudflare Workers:

| Worker | Host | Purpose |
|:---|:---|:---|
| `watch-party-realtime` | `party.kumoriya.online` | Real-time WebSocket rooms, room lifecycle |
| `join-worker` | `join.kumoriya.online` | Invite link landing page, deep linking |

Both leverage **Cloudflare Durable Objects** for stateful, strongly-consistent computation at the edge.

---

## watch-party-realtime Worker

### Entry Point (`index.ts`)

Routes incoming requests to three surfaces:

```
Request → index.ts
  │
  ├── GET /health
  │     → JSON health probe (public)
  │
  ├── GET /ws?token={session_token}
  │     → WebSocket upgrade (public, authenticated)
  │
  └── /internal/v1/*
        → Internal API (Bearer PARTY_INTERNAL_TOKEN)
          ├── POST /rooms              → Create room
          ├── GET  /invite/:code       → Resolve invite
          ├── POST /rooms/:id/join     → Add member
          ├── POST /rooms/:id/leave    → Remove member
          ├── POST /rooms/:id/member-verify → Check membership
          └── POST /users/:id/force-leave   → Recovery endpoint
```

### WebSocket Upgrade Flow

```
1. Client requests GET /ws?token={ed25519_jwt}
2. Worker verifies Ed25519 signature against public key
3. Worker extracts claims: roomId, userId, name, role, sessionId
4. Worker routes to PartyRoomDO.idFromName(roomId)
5. Worker forwards upgrade request to PartyRoomDO
6. PartyRoomDO accepts WebSocket, registers member
```

---

## PartyRoomDO — Room State Machine

### Architecture

Each room is a **single-threaded Durable Object** instance that is the **authoritative source of truth** for:

- Membership and presence
- Playback state (current time, playing/paused)
- Media state (which anime/episode)
- Host authority
- Ready states (pre-playback synchronization)

### State Model

```typescript
interface RoomState {
  roomId: string;
  inviteCode: string;
  hostId: string;
  members: Member[];
  readyStates: Record<string, ReadyState>;
  media: MediaState;
  playback: PlaybackState;
  roomVersion: number;
  createdAt: number;
  lastActivityAt: number;
}

interface Member {
  userId: string;
  name: string;
  presence: 'connected' | 'disconnected';
  readyPersisted: boolean;     // Persisted during grace period
  effectiveReady: boolean;     // readyPersisted AND connected
  status: MemberStatus;        // Current member activity (watching, buffering, lobby, etc.)
  joinedAtMs: number;
  lastHeartbeatMs: number;
}

type MemberStatus = 'in_lobby' | 'loading' | 'in_player' | 'watching' | 'paused' | 'buffering';

interface ReadyState {
  readyPersisted: boolean;
  effectiveReady: boolean;
}

interface PlaybackState {
  status: 'playing' | 'paused';
  basePositionMs: number;
  effectiveAtMs: number;
  generation: number;
  awaitReady?: boolean;        // When true, clients wait until everyone is ready before auto-resuming
}

interface MediaState {
  anilistId: number;
  animeTitle: string;
  episodeNumber: number;
}
```

### Grace Period System

When a member disconnects, they enter a **grace period** instead of being immediately removed:

| Role | Grace Period | Rationale |
|:---|:---|:---|
| Host | 60 seconds | Shorter to enable faster host transfer |
| Member | 120 seconds | Allows reconnection without re-joining |

**Host Transfer:** If the host disconnects and doesn't return within the grace period, the longest-tenured active member is promoted to host.

**Empty Room Cleanup:** If all members leave (including grace expiration), the room is destroyed after 15 minutes.

### Auto-Pause on Member Disconnect

When a member whose status was `watching` disconnects (or changes status to `in_lobby` / `buffering`), the server **automatically pauses playback**. This is a server-initiated action that bypasses the host check, ensuring no device runs ahead while a member is disconnected.

### Synchronized Seek Barrier

When the host issues a `seek` playback intent, the server:
1. Pauses playback and resets all members' ready states
2. Sets `awaitReady = true` on the playback state
3. Clients must re-toggle ready once their player has seeked
4. When all connected members are ready again, the server auto-resumes playback

### Rate Limiting

Token-bucket rate limiting per user per message type:

| Message Type | Capacity | Refill Rate | Description / Window |
|:---|:---|:---|:---|
| Reactions | 8 | 0.8/sec | ~10 seconds (emotes) |
| Playback Intents | 6 | 0.6/sec | ~10 seconds (throttled to prevent thrashing) |
| WebRTC Signals | 30 | 5.0/sec | ~6 seconds (chatty during ICE negotiation) |
| Voice State | 10 | 1.0/sec | ~10 seconds (PTT state changes) |

### Heartbeat Auto-Response

The most significant cost optimization:

```
Normal flow:
  Client → "hb" → DO wakes up → "hb_ack" → Client
  (Cost: 1 billable request)

Optimized flow:
  Client → '{"t":"hb"}' → DO hibernation bypass → '{"t":"hb_ack"}' → Client
  (Cost: 0 billable requests)
```

The Cloudflare runtime can respond to a fixed request/response pair **without waking the DO from hibernation**. This eliminates ~95% of billable requests for an active party.

---

## PartyRegistryDO — Global Registry

### Purpose

A singleton Durable Object (`idFromName('global-registry')`) that maintains:

- **Invite code → Room ID mapping**
- **User → Current Room mapping** (enforces one-room-per-user constraint)
- **Room creation uniqueness** (prevents duplicate invite codes)

### Operations

| Operation | Description |
|:---|:---|
| `createRoom(userId, name, media)` | Creates room, generates invite code, sets creator as host |
| `resolveInvite(code)` | Looks up room ID from invite code |
| `joinRoom(roomId, userId, name)` | Adds user to room (validates not already in another room) |
| `leaveRoom(roomId, userId)` | Removes user from room |
| `verifyMember(roomId, userId)` | Checks if user is active member (or within grace) |
| `forceLeave(userId)` | Recovery: removes user from any room they're in |

### Invite Code Generation

- **Format:** `[A-Z0-9]{4,12}` (uppercase alphanumeric)
- **Deterministic:** Derived from room ID for consistency
- **Collision-resistant:** Registry validates uniqueness on creation

---

## WebSocket Protocol

### Message Format

All messages are JSON with a `type` discriminator:

```typescript
interface WSEnvelope {
  type: string;          // Message type (event name)
  roomId?: string;       // Room identifier
  eventId?: string;      // Unique event identifier
  roomVersion?: number;  // Room version for optimistic updates
  sentAt: number;        // Server timestamp
  sender?: string;       // userId of sender
  payload: unknown;      // Message-specific payload
  messageId?: string;    // Client-provided for correlation
}
```

### Message Types

#### Client → Server Messages

| Type | Payload Type | Purpose |
|:---|:---|:---|
| `hello` | (none) | Initial handshake after WebSocket connection is established |
| `heartbeat` | (none) | Periodic keep-alive sent every 25 seconds (presence tracking) |
| `request_snapshot` | (none) | Request the current room snapshot |
| `set_ready` | `SetReadyPayload` | Toggle the member's ready state |
| `set_status` | `SetStatusPayload` | Update the member's current activity status (lobby, watching, buffering, etc.) |
| `send_reaction` | `SendReactionPayload` | Send a reaction emote to the room |
| `playback_intent` | `PlaybackIntentPayload` | Host-only commands to control playback (play, pause, seek, media_change, episode_change, resync_request, start_watching, source_selected) |
| `leave_room` | (none) | Explicit notification before disconnecting |
| `kick_member` | `KickMemberPayload` | Host-only command to forcibly remove a user |
| `transfer_host` | `TransferHostPayload` | Host-only command to transfer host authority |
| `webrtc_signal` | `WebRTCSignalPayload` | Send ICE/SDP signals to a target peer |
| `voice_state` | `VoiceStatePayload` | Notify local Push-to-Talk (PTT) speaking state |

#### Server → Client Messages / Events

| Type | Payload Type | Purpose |
|:---|:---|:---|
| `room_snapshot` | `RoomSnapshotPayload` | Complete room state sent on connect or reconnect |
| `member_joined` | `MemberJoinedPayload` | Broadcast when a new member joins |
| `member_left` | `MemberLeftPayload` | Broadcast when a member leaves |
| `member_presence_changed` | `MemberPresenceChangedPayload` | Broadcast when a member's network presence changes (connected/disconnected) |
| `member_ready_changed` | `MemberReadyChangedPayload` | Broadcast when a member's effective ready state changes |
| `member_status_changed` | `MemberStatusChangedPayload` | Broadcast when a member's activity status changes (watching, buffering, etc.) |
| `reaction_broadcast` | `ReactionBroadcastPayload` | Broadcast a reaction emote to all members |
| `playback_state_changed` | `PlaybackStateChangedPayload` | Broadcast authoritative playback state update |
| `media_changed` | `MediaChangedPayload` | Broadcast when the host changes the current media |
| `episode_changed` | `EpisodeChangedPayload` | Broadcast when the host changes the current episode |
| `host_transferred` | `HostTransferredPayload` | Broadcast when host authority is transferred |
| `room_closed` | `RoomClosedPayload` | Broadcast when the room is destroyed |
| `ack` | `AckPayload` | Acknowledge a client message via `messageId` correlation |
| `webrtc_signal` | `WebRTCSignalServerPayload` | Relayed WebRTC signaling from a peer |
| `voice_state_changed` | `VoiceStateChangedPayload` | Broadcast when a peer starts or stops speaking (PTT toggle) |
| `source_selected` | `SourceSelectedPayload` | Broadcast when the host picks a source/server for the current episode (notification-only, no timeline mutation) |
| `start_watching` | `StartWatchingPayload` | Broadcast when the host taps "Start Watching" in the lobby — carries media + playback snapshot so all clients navigate to the player |
| `kicked` | `KickedPayload` | Targeted notification sent to a member being kicked, right before their WebSocket is closed |
| `error` | `ErrorPayload` | Error response |

### ACK/Error Handling

Messages with `messageId` fields expect acknowledgment:

```
Client sends: {type: "playback_intent", messageId: "msg_42", payload: {...}}
Server responds: {type: "ack", payload: {messageId: "msg_42", type: "playback_intent", success: true}} or {type: "error", payload: {code: "...", message: "...", retryable: true}}
```

The `PlaybackIntentPayload` supports the following actions:

| Action | Description |
|:---|:---|
| `play` | Resume playback (optional `positionMs` for implicit seek) |
| `pause` | Pause playback (optional `positionMs` for implicit seek) |
| `seek` | Seek to position, pause, reset ready states, set `awaitReady` barrier |
| `media_change` | Change anime (resets playback, resets ready states, exempts host) |
| `episode_change` | Change episode within same anime (resets playback and ready states) |
| `resync_request` | Broadcast current playback state without incrementing generation |
| `start_watching` | Transition from lobby to player — freezes playback paused, resets ready |
| `source_selected` | Notification-only — broadcast which source/server host picked (no timeline mutation) |

### Source Selection Protocol

When the host selects a specific server for the current episode, a `source_selected` playback intent is sent. The server broadcasts a `source_selected` event to all members carrying `sourcePluginId`, `serverName`, `resolverPluginId`, and `episodeNumber`. Each member's client can then **auto-resolve the same source locally** — the actual stream URL is never shared, because resolvers depend on region, installed plugins, and auth.

If the host's source is unavailable on a member's device, the member's client falls back to the normal manual server picker.

---

## Session Token Authentication

### Token Format

Ed25519-signed JWT issued by the Go API:

```json
{
  "iss": "https://api.kumoriya.online",
  "aud": "watch-party",
  "roomId": "abc123",
  "sub": "user-uuid-here",
  "name": "DisplayName",
  "role": "host",
  "sessionId": "session-uuid",
  "iat": 1715000000,
  "exp": 1715000045
}
```

### Verification Flow

```
1. Worker receives token from ?token= query parameter
2. Worker decodes JWT without verification (read header)
3. Worker verifies Ed25519 signature against PARTY_SESSION_PUBLIC_KEY_HEX
4. Worker validates:
   - iss === expectedIssuer
   - aud === expectedAudience
   - exp > now
5. If valid: extract claims, proceed with WebSocket upgrade
6. If invalid: return 401 with error code (expired_token, invalid_signature, etc.)
```

### Security Properties

- **Short-lived:** 45-second token lifetime
- **Asymmetric:** Worker only needs public key (private key stays in Go API)
- **Scoped:** Token is bound to a specific room and session
- **Refreshable:** Client can request new token before expiry

---

## Cost Optimization

### Hibernation Bypass

The heartbeat auto-response mechanism is the primary cost optimization:

- **Without bypass:** Every 45s heartbeat = ~1,920 billable requests/day/room
- **With bypass:** Heartbeats cost $0; only actual state changes are billable
- **Savings:** ~95% reduction in billable DO requests

### Implementation

```typescript
// These exact strings must match client ↔ server
const HEARTBEAT_AUTO_REQUEST = '{"t":"hb"}';
const HEARTBEAT_AUTO_RESPONSE = '{"t":"hb_ack"}';

// DO configuration in wrangler.toml
[[durable_objects.bindings]]
name = "PARTY_ROOM"
class_name = "PartyRoomDO"

[[durable_objects.auto_response]]
request = '{"t":"hb"}'
response = '{"t":"hb_ack"}'
```

---

## join-worker

### Purpose

Handles Watch Party invite links at `join.kumoriya.online/{code}`.

### Features

1. **Invite Code Validation:** Regex `^[A-Z0-9]{4,12}$`
2. **Branded Landing Page:** Dark-themed, responsive HTML with invite code display
3. Deep Linking:
   - Custom scheme: `kumoriya://party/join?code={code}`
   - Android intent: `intent://party/join?code={code}#Intent;scheme=kumoriya;package=dev.kumoriya.app;end`
   - Windows integration: Registers the `kumoriya://` custom protocol scheme to the app executable on installation via Inno Setup registry keys (HKCU/HKLM `SOFTWARE\Classes\kumoriya`).
4. Windows Single Instance Forwarding:
   - Activates when deep links are clicked while the app is already running (warm-start).
   - The Windows native runner (`main.cpp`) uses a lock/find-window mechanism and forwards the deep link URI via `WM_COPYDATA` (using the `app_links` plugin C API) to the running instance, then immediately exits.
5. Fallback: Redirects to download page if app not installed.
6. Auto-open: JavaScript attempts to open app on page load (mobile and desktop supporting custom protocol handlers).
7. Digital Asset Links: Serves `/.well-known/assetlinks.json` for Android passkey association.

### Security

- **No caching:** `Cache-Control: no-store` headers prevent invite code leakage
- **Input validation:** Strict regex on invite code format
- **No server-side state:** Worker is purely a rendering proxy

---

## Testing Strategy

### Unit Tests (Vitest)

Located in `src/__tests__/unit/`:

| Test File | Coverage |
|:---|:---|
| `session-token.test.ts` | Token creation, verification, expiry, invalid signatures |
| `PartyRegistryDO.test.ts` | Room creation, invite resolution, duplicate prevention |
| `PartyRoomDO-presence.test.ts` | Join, leave, heartbeat, grace periods |
| `playback-sync.test.ts` | Play/pause/seek state synchronization |
| `host-authority.test.ts` | Host transfer, host-only operations |
| `ready-state.test.ts` | Ready persistence, effective ready computation |
| `media-episode-change.test.ts` | Media state transitions |
| `rate-limit.test.ts` | Token bucket behavior, rate limit enforcement |
| `ack-errors.test.ts` | Message ACK, error responses |
| `heartbeat-auto-response.test.ts` | Hibernation bypass verification |

### Property-Based Tests

Located in `src/__tests__/properties/`:

| Test File | Property Verified |
|:---|:---|
| `room-creation-uniqueness.test.ts` | No two rooms share an invite code |
| `invite-code-determinism.test.ts` | Same room ID → same invite code |
| `playback-monotonicity.test.ts` | Playback position never goes backward |
| `ready-state-consistency.test.ts` | effectiveReady implies readyPersisted |
| `host-authority.test.ts` | Exactly one host exists at all times |
| `grace-period-preservation.test.ts` | Grace period expires exactly on schedule |
| `media-change-resets.test.ts` | Media change resets ready states |
| `reconnection-state-restoration.test.ts` | Reconnecting member receives full state |

---

## Deployment

### Configuration (`wrangler.toml`)

```toml
name = "watch-party-realtime"
main = "src/index.ts"

[[durable_objects.bindings]]
name = "PARTY_ROOM"
class_name = "PartyRoomDO"

[[durable_objects.bindings]]
name = "PARTY_REGISTRY"
class_name = "PartyRegistryDO"

[[durable_objects.auto_response]]
request = '{"t":"hb"}'
response = '{"t":"hb_ack"}'

[vars]
PARTY_SESSION_PUBLIC_KEY_HEX = "..."  # Ed25519 public key
PARTY_SESSION_ISSUER = "https://api.kumoriya.online"
PARTY_WS_AUDIENCE = "watch-party"
PARTY_INTERNAL_TOKEN = "..."  # Shared secret for internal API
```

### Deploy Command

```bash
cd infra/watch-party-realtime
npm install
npx wrangler deploy
```
