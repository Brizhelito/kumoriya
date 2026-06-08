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
  hostUserId: string;
  members: Map<string, Member>;
  playback: PlaybackState;
  media: MediaState;
  createdAt: number;
}

interface Member {
  userId: string;
  name: string;
  role: 'host' | 'member';
  joinedAt: number;
  lastHeartbeat: number;
  readyPersisted: boolean;    // User explicitly marked ready
  effectiveReady: boolean;    // Computed: readyPersisted && present
  wsConnection: WebSocket;
}

interface PlaybackState {
  isPlaying: boolean;
  position: number;           // Seconds
  updatedAt: number;          // Timestamp
  updatedBy: string;          // userId
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

### Rate Limiting

Token-bucket rate limiting per user per message type:

| Message Type | Capacity | Refill Rate | Window |
|:---|:---|:---|:---|
| Reactions | 8 | 0.8/sec | ~10 seconds |
| Playback Intents | 3 | 0.3/sec | ~10 seconds |

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
  type: string;       // Message type discriminator
  id?: string;        // Optional message ID for ACK tracking
  payload?: unknown;  // Type-specific payload
  timestamp?: number; // Client timestamp
}
```

### Message Types

| Type | Direction | Purpose |
|:---|:---|:---|
| `playback_intent` | Client → Server | User wants to play/pause/seek |
| `playback_state` | Server → Client | Authoritative playback state broadcast |
| `media_change` | Host → Server | Host changes anime/episode |
| `media_state` | Server → Client | Current media info broadcast |
| `ready` | Client → Server | User marks ready to start |
| `ready_state` | Server → Client | Ready state broadcast |
| `reaction` | Client → Server | User sends reaction emoji |
| `reaction_broadcast` | Server → Client | Reaction forwarded to room |
| `member_join` | Server → Client | New member joined |
| `member_leave` | Server → Client | Member left |
| `host_change` | Server → Client | Host transferred |
| `hb` | Client → Server | Heartbeat (auto-responded) |
| `hb_ack` | Server → Client | Heartbeat acknowledgment |
| `error` | Server → Client | Error response |

### ACK/Error Handling

Messages with `id` fields expect acknowledgment:

```
Client sends: {type: "playback_intent", id: "msg_42", payload: {...}}
Server responds: {type: "ack", id: "msg_42"} or {type: "error", id: "msg_42", payload: {code: "...", message: "..."}}
```

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
3. **Deep Linking:**
   - Custom scheme: `kumoriya://party/join?code={code}`
   - Android intent: `intent://party/join?code={code}#Intent;scheme=kumoriya;package=dev.kumoriya.app;end`
4. **Fallback:** Redirects to download page if app not installed
5. **Auto-open:** JavaScript attempts to open app on page load (mobile only)
6. **Digital Asset Links:** Serves `/.well-known/assetlinks.json` for Android passkey association

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
