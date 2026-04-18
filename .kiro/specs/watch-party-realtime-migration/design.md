# Design Document: Watch Party Realtime Migration

## Overview

This document specifies the design for migrating the watch party system from an in-memory implementation to a dedicated realtime service hosted at `party.kumoriya.online`. The new architecture uses Cloudflare Workers with Durable Objects as the authoritative source for room state, member presence, playback synchronization, and signaling.

### Goals

1. Deploy a dedicated realtime service at `party.kumoriya.online` using Cloudflare Workers
2. Use Durable Objects for authoritative state management with persistence
3. Implement server-authoritative playback synchronization
4. Provide reliable reconnection with grace periods
5. Enable future WebRTC voice chat through prepared signaling infrastructure

### Scope

- Party Realtime Service (Cloudflare Workers + Durable Objects)
- Kumoriya API integration (broker client, token signing)
- Flutter client migration (PartyRealtimeClient, PartySessionNotifier)
- Internal HTTP endpoints for Kumoriya API communication
- WebSocket endpoint for client connections

---

## Architecture

### High-Level Topology

```
┌─────────────────┐     REST      ┌──────────────────┐    Internal HTTP    ┌─────────────────────────────┐
│  Flutter App    │──────────────▶│   Kumoriya API   │─────────────────────▶│  Party Realtime Service     │
│                 │               │   (Go backend)   │                      │  (Cloudflare Workers)       │
│                 │◀──────────────│                  │◀─────────────────────│                             │
│                 │   JSON        │                  │    JSON              │  ┌───────────────────────┐  │
└────────┬────────┘               └──────────────────┘                      │  │  Worker Entry Point   │  │
         │                                                                   │  │  (HTTP + WS routing)  │  │
         │                                                                   │  └──────────┬────────────┘  │
         │                                                                   └─────────────┼───────────────┘
         │                                                                                 │
         │                                                          ┌──────────────────────┼──────────────────────┐
         │                                                          │                      │                      │
         │                                                  ┌───────▼──────────┐   ┌───────▼──────────┐   ┌──────▼───────────┐
         │                                                  │ PartyRegistryDO  │   │  PartyRoomDO     │   │  PartyRoomDO     │
         │                                                  │   (singleton)    │   │   (per-room)     │   │   (per-room)     │
         │                                                  └──────────────────┘   └──────────────────┘   └──────────────────┘
         │                                                                                 ▲
         │                                                                                 │
         │                                                                      WebSocket  │
         └─────────────────────────────────────────────────────────────────────────────────┘
```

**Note**: WebSocket connections are validated at the Worker entry point, then routed directly to the appropriate PartyRoomDO based on the roomId claim in the token.

### Trust Model

1. **Kumoriya API** is the trust root for authentication
2. Kumoriya API signs Session Tokens using Ed25519 (via `jwt_service.go`)
3. Party Realtime Service validates tokens using the public key from config
4. Party Realtime Service never issues tokens, only validates them

### State Authority

- **PartyRegistryDO**: Singleton Durable Object managing:
  - Room creation and registration
  - Invite code resolution
  - User-to-room mapping
  - Cleanup of expired rooms

- **PartyRoomDO**: Per-room Durable Object managing:
  - Membership and presence
  - Ready states (readyPersisted/effectiveReady)
  - Playback state (basePositionMs/effectiveAtMs/generation)
  - Host authority
  - Grace periods
  - Rate limiting

### Communication Patterns

| Pattern | Protocol | Purpose |
|---------|----------|---------|
| Client → Service | WebSocket (wss://party.kumoriya.online/ws) | Realtime messaging |
| Service → Client | WebSocket | Broadcasts, state updates |
| Kumoriya API → Service | REST (internal HTTP) | Room operations |
| DO → DO | DurableObjectStub | PartyRegistryDO ↔ PartyRoomDO communication |

---

## Components and Interfaces

### 1. Party Realtime Service (Cloudflare Workers)

#### Worker Entry Point

The Worker handles two types of requests:

**Public WebSocket Endpoint**
```
GET /ws?token={Session_Token}
```

**Internal HTTP Endpoints** (authenticated with `PARTY_INTERNAL_TOKEN`)
```
POST   /internal/v1/rooms              - Create room
GET    /internal/v1/invite/:code       - Resolve invite code
POST   /internal/v1/rooms/:roomId/join - Join room
POST   /internal/v1/rooms/:roomId/leave - Leave room
POST   /internal/v1/rooms/:roomId/member-verify - Verify member status (active OR within reconnect grace)
```

#### PartyRegistryDO (Singleton)

**Responsibilities:**
- Generate unique roomId (UUID v4)
- Generate unique inviteCode (6-char alphanumeric)
- Instantiate PartyRoomDO for each room
- Map userId to roomId
- Resolve invite codes to roomIds
- Cleanup when rooms are destroyed

**Room Creation Coordination:**
When creating a room, PartyRegistryDO:
1. Generates roomId and inviteCode
2. Instantiates PartyRoomDO via DurableObjectStub
3. Calls PartyRoomDO to initialize room state with creator as first member and host
4. Maps creator userId to roomId
5. Returns roomId and inviteCode to Kumoriya API

**Storage:**
- `rooms`: Map<roomId, RoomMetadata>
- `inviteCodes`: Map<inviteCode, roomId>
- `userRooms`: Map<userId, roomId>

#### PartyRoomDO (Per-Room)

**Responsibilities:**
- Manage room membership
- Track member presence and heartbeats
- Handle ready states (dual-layer: readyPersisted/effectiveReady)
- Authoritative playback state management
- Host authority and transfer
- Rate limiting
- Grace period management
- WebSocket message routing and broadcasting

**In-Memory State:**
- Active WebSocket connections
- Heartbeat timestamps
- Grace period timers
- Rate limiters

**Persistent Storage:**
- Room state (members, ready states, playback, media, roomVersion)

#### Token Validation

The Worker validates Ed25519-signed Session Tokens:
1. Extract token from query parameter
2. Verify signature using `PARTY_SESSION_PUBLIC_KEY`
3. Check expiration
4. Extract roomId, userId, sessionId claims

### 2. Kumoriya API (Go)

#### Public REST Endpoints

| Endpoint | Description |
|----------|-------------|
| `POST /api/v1/party` | Create watch party room |
| `POST /api/v1/party/join` | Join room via invite code |
| `POST /api/v1/party/leave` | Leave current room |
| `GET /api/v1/party/me` | Get current party info |
| `GET /api/v1/party/invite/:code` | Get room info by invite code |
| `POST /api/v1/party/session/refresh` | Refresh session token |

#### PartyRealtimeBrokerClient

Internal HTTP client for communicating with Party Realtime Service:
- Base URL: `https://party.kumoriya.online`
- Authentication: Bearer token (`PARTY_INTERNAL_TOKEN`)
- Timeout: 10 seconds
- Retry: 2 attempts with exponential backoff

#### Token Signing

Uses existing `jwt_service.go` with Ed25519:
- Algorithm: EdDSA
- Issuer: `kumoriya-api`
- Audience: `watch-party`
- Expiration: 60 minutes (configurable, range 30-120 min)

### 3. Flutter Client

#### PartyRealtimeClient

WebSocket client with:
- Automatic reconnection with exponential backoff (up to 5 attempts)
- Heartbeat every 25 seconds
- Event handlers for all message types

#### PartySessionNotifier

Server-authoritative state management:
- Derives all state from server messages
- No local state synchronization needed
- Handles: members, presence, ready states, host, media, playback

#### Migration from SignalingClient

- Replace P2P-based signaling with server-authoritative model
- Remove dependency on connectedPeerIds
- Use server-provided room_snapshot for initial state

---

## Data Models

### 1. Session Token (JWT-style, Ed25519 signed)

```typescript
interface SessionToken {
  // Header
  alg: 'EdDSA';
  typ: 'JWT';

  // Claims
  sub: string;      // userId
  name: string;     // display name
  roomId: string;   // room identifier
  role: 'host' | 'member';
  sessionId: string; // unique session identifier
  iss: string;      // issuer (kumoriya-api)
  aud: 'watch-party';
  exp: number;      // expiration timestamp (Unix epoch seconds)
  iat: number;      // issued at timestamp
}
```

### 2. Room State (PartyRoomDO Persistent Storage)

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
```

**Note**: `lastActivityAt` is persisted to support TTL enforcement after hibernation/restart.

### 3. Member State

```typescript
interface Member {
  userId: string;
  name: string;
  presence: 'connected' | 'disconnected';
  readyPersisted: boolean;    // Persisted during grace period
  effectiveReady: boolean;    // readyPersisted AND connected
  joinedAtMs: number;
  lastHeartbeatMs: number;
}
```

### 4. Ready State

```typescript
interface ReadyState {
  readyPersisted: boolean;
  effectiveReady: boolean;
}
```

### 5. Media State

```typescript
interface MediaState {
  anilistId: number;
  animeTitle: string;
  episodeNumber: number;
}
```

### 6. Playback State

```typescript
interface PlaybackState {
  status: 'playing' | 'paused';
  basePositionMs: number;
  effectiveAtMs: number;
  generation: number;
}
```

### 7. WebSocket Envelope

```typescript
interface WSEnvelope {
  type: string;           // Message type (event name)
  roomId?: string;        // Room identifier
  eventId?: string;       // Unique event identifier
  roomVersion?: number;   // Room version for optimistic updates
  sentAt: number;         // Server timestamp
  sender?: string;        // userId of sender
  payload: unknown;       // Message-specific payload
  messageId?: string;     // Client-provided for correlation
}
```

### 8. Canonical Message Payloads

#### Client → Server Messages

**hello**
```typescript
interface HelloPayload {
  // Empty - token already validated via WebSocket query parameter
}
```

**heartbeat**
```typescript
interface HeartbeatPayload {
  // Empty - presence tracked by connection
}
```

**request_snapshot**
```typescript
interface RequestSnapshotPayload {
  // Empty - triggers room_snapshot response
}
```

**set_ready**
```typescript
interface SetReadyPayload {
  ready: boolean;
}
```

**send_chat**
```typescript
interface SendChatPayload {
  message: string;
}
```

**send_reaction**
```typescript
interface SendReactionPayload {
  reaction: 'like' | 'love' | 'laugh' | 'surprise' | 'sad' | 'angry';
}
```

**playback_intent**
```typescript
interface PlaybackIntentPayload {
  action: 'play' | 'pause' | 'seek' | 'media_change' | 'episode_change' | 'resync_request';
  positionMs?: number;      // For seek
  anilistId?: number;       // For media_change
  episodeNumber?: number;   // For episode_change
}
```

**leave_room**
```typescript
interface LeaveRoomPayload {
  // Empty - triggers leave process
}
```

**webrtc_signal**
```typescript
interface WebRTCSignalPayload {
  targetUserId: string;
  type: 'offer' | 'answer' | 'ice-candidate';
  signal: unknown;
}
```

#### Server → Client Messages

**room_snapshot**
```typescript
interface RoomSnapshotPayload {
  roomId: string;
  inviteCode?: string;
  hostId: string;
  members: Member[];
  media: MediaState;
  playback: PlaybackState;
  roomVersion: number;
  serverTimeMs: number;
}
```

**member_joined**
```typescript
interface MemberJoinedPayload {
  member: Member;
}
```

**member_left**
```typescript
interface MemberLeftPayload {
  userId: string;
  newHostId?: string;
}
```

**member_presence_changed**
```typescript
interface MemberPresenceChangedPayload {
  userId: string;
  presence: 'connected' | 'disconnected';
}
```

**member_ready_changed**
```typescript
interface MemberReadyChangedPayload {
  userId: string;
  effectiveReady: boolean;
}
```

**chat_message**
```typescript
interface ChatMessagePayload {
  messageId: string;
  senderId: string;
  senderName: string;
  message: string;
  sentAt: number;
}
```

**reaction_broadcast**
```typescript
interface ReactionBroadcastPayload {
  reactionId: string;
  senderId: string;
  senderName: string;
  reaction: string;
  sentAt: number;
}
```

**playback_state_changed**
```typescript
interface PlaybackStateChangedPayload {
  status: 'playing' | 'paused';
  basePositionMs: number;
  effectiveAtMs: number;
  generation: number;
}
```

**media_changed**
```typescript
interface MediaChangedPayload {
  media: MediaState;
  resetPosition: boolean;
  resetReady: boolean;
}
```

**episode_changed**
```typescript
interface EpisodeChangedPayload {
  episodeNumber: number;
  resetPosition: boolean;
  resetReady: boolean;
}
```

**host_transferred**
```typescript
interface HostTransferredPayload {
  oldHostId: string;
  newHostId: string;
}
```

**room_closed**
```typescript
interface RoomClosedPayload {
  reason: 'host_left' | 'empty_timeout' | 'room_destroyed';
}
```

**ack**
```typescript
interface AckPayload {
  messageId: string;
  type: string;
  success: boolean;
}
```

**error**
```typescript
interface ErrorPayload {
  code: string;
  message: string;
  retryable: boolean;
}
```

**webrtc_signal**
```typescript
interface WebRTCSignalPayload {
  senderId: string;
  type: 'offer' | 'answer' | 'ice-candidate';
  signal: unknown;
}
```

---

## State Management

### Persistent State (PartyRoomDO Storage)

The following state is persisted to Durable Object storage:
- Room metadata (roomId, inviteCode, hostId)
- Member list with ready states
- Media state (anilistId, animeTitle, episodeNumber)
- Playback state (status, basePositionMs, effectiveAtMs, generation)
- Room version (monotonic counter)

### In-Memory State

The following state is kept in memory only:
- Active WebSocket connections
- Heartbeat timestamps (lastHeartbeatMs)
- Grace period timers
- Rate limiters (chat, reactions, playback_intent)

### State Recovery

1. **On Connect**: PartyRoomDO sends full `room_snapshot`
2. **On Reconnect**: PartyRoomDO sends updated `room_snapshot`
3. **Grace Period**: Disconnected members retain their slot for 120s (60s for host)
4. **Snapshot-based Recovery**: Client replaces local state with server snapshot

### Ready State Dual-Layer

```
readyPersisted    effectiveReady    Meaning
─────────────────────────────────────────────────────
false             false             Not ready
true              false             Ready but disconnected (grace period)
true              true              Ready and connected
false             true              Never happens (effectiveReady = readyPersisted && connected)
```

---

## Key Flows

### 1. Room Creation Flow

```
Flutter App                    Kumoriya API              PartyRegistryDO           PartyRoomDO
    │                              │                         │                         │
    │ POST /api/v1/party          │                         │                         │
    │────────────────────────────▶│                         │                         │
    │                              │ POST /internal/v1/rooms │                         │
    │                              │────────────────────────▶│                         │
    │                              │                         │ Generate roomId         │
    │                              │                         │ Generate inviteCode    │
    │                              │                         │ Create PartyRoomDO     │
    │                              │                         │ Add creator as first   │
    │                              │                         │ member, set as host    │
    │                              │                         │◀────────────────────────│
    │                              │                         │                         │
    │                              │    {roomId, inviteCode} │                         │
    │                              │◀────────────────────────│                         │
    │                              │                         │                         │
    │                              │ Sign Session_Token      │                         │
    │                              │ (Ed25519)               │                         │
    │                              │                         │                         │
    │ {roomId, inviteCode,        │                         │                         │
    │  websocketUrl, token}       │                         │                         │
    │◀────────────────────────────│                         │                         │
    │                              │                         │                         │
    │ Connect to WebSocket        │                         │                         │
    │ wss://party.kumoriya.online │                         │                         │
    │ /ws?token={Session_Token}   │                         │                         │
    │───────────────────────────────────────────────────────▶│                         │
    │                              │                         │ Validate token          │
    │                              │                         │ Route to PartyRoomDO   │
    │                              │                         │◀────────────────────────│
    │                              │                         │                         │
    │                              │                         │ Add socket              │
    │                              │                         │ Send room_snapshot     │
    │ room_snapshot               │                         │                         │
    │◀────────────────────────────│                         │                         │
```

### 2. Join by Invite Code Flow

```
Flutter App                    Kumoriya API              PartyRegistryDO           PartyRoomDO
    │                              │                         │                         │
    │ POST /api/v1/party/join     │                         │                         │
    │ {inviteCode}                │                         │                         │
    │────────────────────────────▶│                         │                         │
    │                              │ GET /internal/v1/invite/:code                   │
    │                              │────────────────────────▶│                         │
    │                              │                         │ Resolve to roomId      │
    │                              │    {roomId}             │                         │
    │                              │◀────────────────────────│                         │
    │                              │                         │                         │
    │                              │ POST /internal/v1/rooms/:roomId/join            │
    │                              │ {userId, name}          │                         │
    │                              │────────────────────────▶│                         │
    │                              │                         │ Verify room not full   │
    │                              │                         │ Add member             │
    │                              │                         │ Broadcast member_joined│
    │                              │                         │◀────────────────────────│
    │                              │    {success}            │                         │
    │                              │◀────────────────────────│                         │
    │                              │                         │                         │
    │                              │ Sign Session_Token      │                         │
    │                              │ (Ed25519)               │                         │
    │                              │                         │                         │
    │ {roomId, websocketUrl,      │                         │                         │
    │  token}                     │                         │                         │
    │◀────────────────────────────│                         │                         │
    │                              │                         │                         │
    │ Connect to WebSocket        │                         │                         │
    │───────────────────────────────────────────────────────▶│                         │
    │                              │                         │ Validate token          │
    │                              │                         │ Add socket              │
    │                              │                         │ Send room_snapshot     │
    │ room_snapshot               │                         │                         │
    │◀────────────────────────────│                         │                         │
```

### 3. WebSocket Connection Flow

```
Flutter App                              Party Realtime Service
    │                                            │
    │ GET /ws?token={Session_Token}             │
    │───────────────────────────────────────────▶│
    │                                            │ Validate Ed25519 signature
    │                                            │ Check expiration
    │                                            │ Extract roomId, userId
    │                                            │ Route to PartyRoomDO
    │                                            │
    │                 WebSocket Upgrade          │
    │<───────────────────────────────────────────│
    │                                            │
    │              room_snapshot                 │
    │<───────────────────────────────────────────│
    │                                            │
    │              hello {}                      │
    │───────────────────────────────────────────>│
    │                                            │ Confirm connection ready
    │                                            │ (no auth - already validated)
    │              ack                           │
    │<───────────────────────────────────────────│
```

**Note**: The `hello` message does not perform authentication (token already validated during WebSocket upgrade). It serves as a client-initiated handshake to confirm session readiness.

### 4. Playback Intent Flow (Host-only)

```
Flutter App                              PartyRoomDO
    │                                            │
    │ playback_intent {action: "play"}          │
    │───────────────────────────────────────────▶│
    │                                            │ Validate sender is host
    │                                            │ Update playback state
    │                                            │ Increment generation
    │                                            │ Set effectiveAtMs
    │                                            │ Broadcast playback_state_changed
    │                                            │
    │              ack                           │
    │◀───────────────────────────────────────────│
    │                                            │
    │         [All members receive]             │
    │              playback_state_changed        │
    │◀───────────────────────────────────────────│
```

### 5. Reconnection Flow

```
Flutter App                              PartyRoomDO
    │                                            │
    │ [Connection drops]                         │
    │                                            │
    │ [Start exponential backoff]                │
    │                                            │
    │ [Attempt 1] GET /ws?token={token}         │
    │───────────────────────────────────────────▶│
    │              [Fails - token expired]       │
    │◀───────────────────────────────────────────│
    │                                            │
    │ POST /api/v1/party/session/refresh         │
    │───────────────────────────────────────────▶│
    │         [Kumoriya API validates]           │
    │         [Verifies member via DO]           │
    │         [Signs new token]                  │
    │         {newToken}                         │
    │◀───────────────────────────────────────────│
    │                                            │
    │ [Attempt 2] GET /ws?token={newToken}      │
    │───────────────────────────────────────────▶│
    │                                            │ Validate token
    │                                            │ Check within grace period
    │                                            │ Restore member state
    │                                            │ Send room_snapshot
    │              room_snapshot                 │
    │◀───────────────────────────────────────────│
```

### 6. Session Token Refresh Flow

```
Flutter App                    Kumoriya API              PartyRoomDO
    │                              │                         │
    │ POST /api/v1/party/         │                         │
    │ session/refresh             │                         │
    │────────────────────────────▶│                         │
    │                              │ Validate auth           │
    │                              │                         │
    │                              │ POST /internal/v1/rooms │
    │                              │ /:roomId/member-verify  │
    │                              │ {userId}                │
    │                              │────────────────────────▶│
    │                              │                         │ Verify member exists
    │                              │    {isMember: true}     │
    │                              │◀────────────────────────│
    │                              │                         │
    │                              │ Sign new Session_Token │
    │                              │                         │
    │ {newToken, websocketUrl}    │                         │
    │◀────────────────────────────│                         │
```

---

## Security

### Authentication

1. **Internal Endpoints**: Authenticated with `PARTY_INTERNAL_TOKEN` (Bearer token)
2. **WebSocket**: Session Token validated via Ed25519 public key

### Authorization

1. **Playback Control**: Only host can send `playback_intent` messages
2. **Room Operations**: Only Kumoriya API can call internal endpoints

### Rate Limiting

| Action | Limit | Window |
|--------|-------|--------|
| Chat messages | 10 | 10 seconds |
| Reactions | 5 | 5 seconds |
| Playback intents | 10 | 10 seconds |

### WebSocket Close Codes

| Code | Reason | Description |
|------|--------|-------------|
| 4001 | invalid_token | Token signature invalid or malformed |
| 4002 | expired_token | Token past expiration time |
| 4003 | room_not_found | roomId in token does not exist |

---

## Deployment

### Infrastructure

- **Worker Project**: `infra/watch-party-realtime`
- **Domain**: `party.kumoriya.online` proxied through Cloudflare
- **Runtime**: Cloudflare Workers with Durable Objects

### Wrangler Configuration

```toml
name = "watch-party-realtime"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[[durable_objects.bindings]]
name = "PARTY_REGISTRY"
class_name = "PartyRegistryDO"

[[durable_objects.bindings]]
name = "PARTY_ROOM"
class_name = "PartyRoomDO"

[vars]
PARTY_SESSION_ISSUER = "kumoriya-api"
```

### Environment Variables / Secrets

| Variable | Description |
|----------|-------------|
| `PARTY_INTERNAL_TOKEN` | Bearer token for internal API authentication |
| `PARTY_SESSION_PUBLIC_KEY` | Ed25519 public key for token validation |
| `PARTY_SESSION_ISSUER` | Expected token issuer (kumoriya-api) |

---

## Migration Strategy

### Feature Flag

- **Flag**: `WATCH_PARTY_REALTIME_V2`
- **Default**: `false` (use existing system)
- **Rollout**: Gradual enablement per-user or per-room

### Parallel Deployment

1. Deploy new Party Realtime Service alongside existing system
2. New rooms created with flag enabled use new flow
3. Old rooms continue using existing implementation
4. No mixing of old/new room implementations

### Migration Phases

1. **Phase 1**: Deploy Party Realtime Service, keep flag off
2. **Phase 2**: Enable flag for testing, validate end-to-end
3. **Phase 3**: Gradual rollout to users
4. **Phase 4**: Deprecate old PartyService, SignalRelay, PartySignalHandler

---

## Observability

### Structured Logging

All logs include:
- `roomId`: Room identifier
- `userId`: User identifier
- `sessionId`: Session identifier
- `eventType`: Event or action type
- `roomVersion`: Room version number

### Events to Log

- Room creation, join, leave, destruction
- WebSocket connection and disconnection
- Host transfer
- Rate limit violations
- Token validation failures

### Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `active_rooms` | gauge | Number of active rooms |
| `active_connections` | gauge | Number of WebSocket connections |
| `room_joins_total` | counter | Total join events |
| `room_leaves_total` | counter | Total leave events |
| `host_transfers_total` | counter | Total host transfers |
| `room_closures_total` | counter | Total room closures |
| `ws_errors_total` | counter | WebSocket errors |
| `reconnects_total` | counter | Reconnection attempts |
| `resync_requests_total` | counter | Playback resync requests |

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Room Creation Generates Unique Identifiers

*For any* room creation request, the PartyRegistryDO SHALL generate a unique roomId and inviteCode that do not conflict with existing rooms

**Validates: Requirements 2.2, 2.3**

### Property 2: Invite Code Resolution is Deterministic

*For any* valid inviteCode, resolving it multiple times SHALL always return the same roomId

**Validates: Requirements 3.2**

### Property 3: Host Authority is Exclusive

*For any* room, at any given time, exactly one member SHALL be designated as the host

**Validates: Requirements 6.1**

### Property 4: Playback State Monotonicity

*For any* playback state update, the generation counter SHALL strictly increase

**Validates: Requirements 8.5**

### Property 5: Room Version Monotonicity

*For any* room state change, the roomVersion counter SHALL strictly increase

**Validates: Requirements 2, 3, 5, 6, 7, 9, 13 (state mutations that increment roomVersion)**

### Property 6: Ready State Dual-Layer Consistency

*For any* member, effectiveReady SHALL equal (readyPersisted AND presence equals connected)

**Validates: Requirements 7.1, 7.3, 7.4**

### Property 7: Grace Period State Preservation

*For any* member that disconnects within the grace period, their readyPersisted value SHALL be preserved upon reconnection

**Validates: Requirements 5.4, 5.6, 7.4**

### Property 8: Media Change Resets Position

*For any* media_change or episode_change action, the playback position SHALL be reset to 0

**Validates: Requirements 9.3**

### Property 9: Media Change Resets Ready States

*For any* media_change or episode_change action, all members' readyPersisted SHALL be reset to false

**Validates: Requirements 9.4**

### Property 10: Token Claims Preservation

*For any* session token refresh, the new token SHALL contain the same roomId, userId, and sessionId claims

**Validates: Requirements 21.5**

### Property 11: Token Validation Accepts Valid Tokens

*For any* valid Session_Token signed by Kumoriya_API with correct signature, expiration, and claims, the Party_Realtime_Service SHALL accept the token and allow WebSocket connection

**Validates: Requirements 4.2, 4.4**

### Property 12: Token Validation Rejects Invalid Tokens

*For any* Session_Token with invalid signature, expired timestamp, or malformed claims, the Party_Realtime_Service SHALL reject the token and close the connection

**Validates: Requirements 4.3**

### Property 13: Rate Limiting Enforces Chat Limit

*For any* user, when they send more than 10 chat messages within a 10-second window, the PartyRoomDO SHALL reject the excess messages

**Validates: Requirements 10.2, 10.3, 18.1**

### Property 14: Rate Limiting Enforces Reaction Limit

*For any* user, when they send more than 5 reactions within a 5-second window, the PartyRoomDO SHALL reject the excess reactions

**Validates: Requirements 11.2, 11.3, 18.2**

### Property 15: Reconnection State Restoration

*For any* member that reconnects within the grace period, the PartyRoomDO SHALL restore their membership including presence, readyPersisted, and effectiveReady

**Validates: Requirements 5.6, 17.3**

### Property 16: Host Transfer on Host Leave

*For any* room where the host leaves and other members remain, the PartyRoomDO SHALL transfer host authority to the oldest remaining member

**Validates: Requirements 6.5, 13.5**

### Property 17: Playback Intent Host-Only Enforcement

*For any* playback_intent message received from a non-host member, the PartyRoomDO SHALL reject the message

**Validates: Requirements 6.2, 6.3**

### Property 18: Room Snapshot Completeness

*For any* room_snapshot message sent to a client, it SHALL include roomId, hostId, members with presence and ready states, media, playback, and roomVersion

**Validates: Requirements 12.2, 12.3, 12.4, 12.5, 12.6**

### Property 19: Empty Room TTL

*For any* room that remains empty for 15 minutes, the PartyRoomDO SHALL destroy the room

**Validates: Requirements 6.7, 6.8**

### Property 20: Member Count Limit

*For any* join request for a room that already has 4 members, the PartyRoomDO SHALL reject the request

**Validates: Requirements 3.7, 3.8**

---

## Error Handling

### Error Codes

| Code | Description | Retryable |
|------|-------------|-----------|
| `invalid_token` | Token signature invalid or malformed | No |
| `expired_token` | Token past expiration time | Yes (refresh) |
| `room_not_found` | roomId in token does not exist | No |
| `room_full` | Room has reached 4-member limit | No |
| `invalid_invite_code` | Invite code does not exist | No |
| `rate_limit_exceeded` | Action exceeds rate limit | Yes |
| `unauthorized` | User not permitted to perform action | No |
| `user_already_in_room` | User is already in another room | No |
| `invalid_message` | Client message missing required fields (e.g., messageId) | No |

### Error Response Format

```typescript
interface ErrorPayload {
  code: string;
  message: string;
  retryable: boolean;
}
```

### WebSocket Close Codes

| Code | Reason | Description |
|------|--------|-------------|
| 4001 | invalid_token | Token signature invalid or malformed |
| 4002 | expired_token | Token past expiration time |
| 4003 | room_not_found | roomId in token does not exist |
| 4004 | room_full | Room has reached member limit |
| 4005 | server_error | Internal server error |

---

## Testing Strategy

### Dual Testing Approach

- **Unit tests**: Verify specific examples, edge cases, and error conditions
- **Property tests**: Verify universal properties across all inputs (when applicable)
- Both are complementary and necessary for comprehensive coverage

### Property-Based Testing

This feature is suitable for property-based testing because:
- Room state management has clear input/output behavior
- There are universal properties that should hold across all room operations
- The input space is large (various room states, member configurations, playback actions)

**Property Test Configuration:**
- Minimum 100 iterations per property test
- Use Cloudflare's built-in testing infrastructure or Vitest with fast-check

### Unit Testing Focus Areas

1. **Message parsing and validation**: Ensure all message types are correctly parsed
2. **Rate limiting logic**: Test boundary conditions for rate limits
3. **Error handling**: Test all error code paths
4. **State transitions**: Test member join/leave/presence transitions
5. **Host transfer logic**: Test all host transfer scenarios

### Integration Testing

1. **End-to-end room flow**: Create room → join → connect → interact → leave
2. **Reconnection flow**: Disconnect → reconnect → verify state restoration
3. **Token refresh flow**: Expire token → refresh → reconnect
4. **Grace period flow**: Disconnect → wait → reconnect within/outside grace period

### Test Tag Format

```typescript
// Property-based test tag
// Feature: watch-party-realtime-migration, Property 1: Room creation uniqueness

// Unit test tag
// Feature: watch-party-realtime-migration, Test: Rate limiting
```

### Test Type Classification Summary

Based on the prework analysis:

| Classification | Count | Examples |
|----------------|-------|----------|
| PROPERTY | 20 | Unique identifiers, monotonic counters, state consistency |
| INTEGRATION | 5 | API broker flow, end-to-end room creation, host transfer |
| SMOKE | 12 | Infrastructure deployment, DNS configuration, Worker setup |
| EDGE_CASE | 0 | Covered by property tests |
| EXAMPLE | 0 | Covered by integration tests |

---

## Requirements Traceability

| Requirement | Design Section | Properties |
|-------------|----------------|------------|
| 1. Dedicated Realtime Service | Architecture, Deployment | - |
| 2. Room Creation | Components, Key Flows | Property 1 |
| 3. Room Joining | Components, Key Flows | Properties 2, 20 |
| 4. WebSocket Connection | Components, Key Flows | Properties 11, 12 |
| 5. Member Presence | Components, Data Models | Properties 7, 15 |
| 6. Host Authority | Components, Data Models | Properties 3, 16, 17 |
| 7. Ready State | Data Models, State Management | Property 6 |
| 8. Playback Sync | Components, Key Flows | Property 4 |
| 9. Media/Episode Change | Components | Properties 8, 9 |
| 10. Chat Messaging | Components | Property 13 |
| 11. Reactions | Components | Property 14 |
| 12. Room Snapshot | Components, Data Models | Properties 5, 18 |
| 13. Room Leave | Components, Key Flows | Property 16 |
| 14. WebRTC Signaling | Components | - |
| 15. API Broker Migration | Components | - |
| 16. Flutter Client Migration | Components | - |
| 17. Reconnection | Components, Key Flows | Properties 7, 15 |
| 18. Rate Limiting | Security, Error Handling | Properties 13, 14, 20 |
| 19. Observability | Observability | - |
| 20. Deployment | Deployment | - |
| 21. Session Refresh | Components, Key Flows | Property 10 |