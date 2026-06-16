import type { Member, MediaState, PlaybackState } from './room';

/**
 * WebSocket Envelope
 *
 * Standard envelope structure for all WebSocket messages.
 */
export interface WSEnvelope {
  type: string; // Message type (event name)
  roomId?: string; // Room identifier
  eventId?: string; // Unique event identifier
  roomVersion?: number; // Room version for optimistic updates
  sentAt: number; // Server timestamp
  sender?: string; // userId of sender
  payload: unknown; // Message-specific payload
  messageId?: string; // Client-provided for correlation
}

// ============================================================================
// Client → Server Message Payloads
// ============================================================================

/**
 * hello
 *
 * Initial handshake message sent after WebSocket connection is established.
 * Token already validated via WebSocket query parameter.
 */
export interface HelloPayload {
  // Empty - token already validated via WebSocket query parameter
}

/**
 * heartbeat
 *
 * Periodic keep-alive sent every 25 seconds.
 */
export interface HeartbeatPayload {
  // Empty - presence tracked by connection
}

/**
 * request_snapshot
 *
 * Request the current room snapshot.
 */
export interface RequestSnapshotPayload {
  // Empty - triggers room_snapshot response
}

/**
 * set_ready
 *
 * Set the sender's ready state.
 */
export interface SetReadyPayload {
  ready: boolean;
}

/**
 * set_status
 *
 * Set the sender's current activity status.
 */
export interface SetStatusPayload {
  status: 'in_lobby' | 'loading' | 'in_player' | 'watching' | 'paused';
}

/**
 * send_reaction
 *
 * Send a reaction emote to the room.
 */
export interface SendReactionPayload {
  reaction: 'like' | 'love' | 'laugh' | 'surprise' | 'sad' | 'angry';
}

/**
 * playback_intent
 *
 * Host-only playback command.
 *
 * `start_watching` is a notification-only action: it does not mutate room
 * state, it just asks the Worker to broadcast the current media + playback
 * so every client (including the host) navigates to the player. This is
 * how a party transitions out of the lobby when everyone is ready.
 */
export interface PlaybackIntentPayload {
  action:
    | 'play'
    | 'pause'
    | 'seek'
    | 'media_change'
    | 'episode_change'
    | 'resync_request'
    | 'start_watching'
    | 'source_selected';
  positionMs?: number; // For seek, or optional anchor for play/pause
  anilistId?: number; // For media_change
  animeTitle?: string; // For media_change / episode_change
  episodeNumber?: number; // For episode_change, media_change and source_selected
  sourcePluginId?: string; // For source_selected
  serverName?: string; // For source_selected
  resolverPluginId?: string; // For source_selected (optional hint)
}

/**
 * source_selected (server → client)
 *
 * Broadcast when the host picks a specific server for the current
 * episode. Other clients can use these identifiers to auto-resolve the
 * same source locally — the actual stream URL is NEVER shared, each
 * client resolves on its own because resolvers depend on region,
 * plugins installed, and auth.
 *
 * When the host's source is unavailable on a member's device, the
 * member's client falls back to the normal manual picker.
 */
export interface SourceSelectedPayload {
  sourcePluginId: string;
  serverName: string;
  resolverPluginId?: string;
  episodeNumber: number;
  selectedAtMs: number;
}

/**
 * start_watching (server → client)
 *
 * Broadcast when the host taps "Start Watching" in the lobby. Carries the
 * current media + playback snapshot so every client can navigate straight
 * to the player without touching ready/position state.
 */
export interface StartWatchingPayload {
  media: MediaState;
  playback: PlaybackState;
}

/**
 * leave_room
 *
 * Explicit leave notification before disconnecting.
 */
export interface LeaveRoomPayload {
  // Empty - triggers leave process
}

/**
 * kick_member
 *
 * Host-only. Forcibly removes `targetUserId` from the room. The target
 * receives a `kicked` event just before their WebSocket is closed.
 */
export interface KickMemberPayload {
  targetUserId: string;
  reason?: string; // Optional human-readable reason (<=200 chars)
}

/**
 * transfer_host
 *
 * Host-only. Transfers host authority to `targetUserId` without the
 * current host leaving the room. The Worker broadcasts the existing
 * `host_transferred` event so every client (including the old host)
 * picks up the new `hostId`.
 */
export interface TransferHostPayload {
  targetUserId: string;
}

/**
 * kicked (server → client, target only)
 *
 * Delivered to the member being removed right before their sockets are
 * closed, so the client can show a user-facing message instead of a
 * generic "connection lost".
 */
export interface KickedPayload {
  byUserId: string;
  reason?: string;
}

/**
 * webrtc_signal
 *
 * WebRTC signaling payload (offer, answer, ICE candidate).
 */
export interface WebRTCSignalPayload {
  targetUserId: string;
  type: 'offer' | 'answer' | 'ice-candidate';
  signal: unknown;
}

// ============================================================================
// Server → Client Message Payloads
// ============================================================================

/**
 * room_snapshot
 *
 * Full room state snapshot sent on connect/reconnect.
 */
export interface RoomSnapshotPayload {
  roomId: string;
  inviteCode?: string;
  hostId: string;
  members: Member[];
  media: MediaState;
  playback: PlaybackState;
  roomVersion: number;
  serverTimeMs: number;
}

/**
 * member_joined
 *
 * A new member has joined the room.
 */
export interface MemberJoinedPayload {
  member: Member;
}

/**
 * member_left
 *
 * A member has left the room.
 */
export interface MemberLeftPayload {
  userId: string;
  newHostId?: string;
}

/**
 * member_presence_changed
 *
 * A member's connection presence has changed.
 */
export interface MemberPresenceChangedPayload {
  userId: string;
  presence: 'connected' | 'disconnected';
}

/**
 * member_ready_changed
 *
 * A member's ready state (effectiveReady) has changed.
 */
export interface MemberReadyChangedPayload {
  userId: string;
  effectiveReady: boolean;
}

/**
 * member_status_changed
 *
 * A member's activity status has changed.
 */
export interface MemberStatusChangedPayload {
  userId: string;
  status: 'in_lobby' | 'loading' | 'in_player' | 'watching' | 'paused';
}

/**
 * reaction_broadcast
 *
 * A reaction emote broadcast to all members.
 */
export interface ReactionBroadcastPayload {
  reactionId: string;
  senderId: string;
  senderName: string;
  reaction: string;
  sentAt: number;
}

/**
 * playback_state_changed
 *
 * Authoritative playback state update.
 */
export interface PlaybackStateChangedPayload {
  status: 'playing' | 'paused';
  basePositionMs: number;
  effectiveAtMs: number;
  generation: number;
}

/**
 * media_changed
 *
 * The current media identifier has been changed by the host.
 */
export interface MediaChangedPayload {
  media: MediaState;
  resetPosition: boolean;
  resetReady: boolean;
}

/**
 * episode_changed
 *
 * The current episode identifier has been changed by the host.
 */
export interface EpisodeChangedPayload {
  episodeNumber: number;
  resetPosition: boolean;
  resetReady: boolean;
}

/**
 * host_transferred
 *
 * Host authority has been transferred to a new member.
 */
export interface HostTransferredPayload {
  oldHostId: string;
  newHostId: string;
}

/**
 * room_closed
 *
 * The room has been destroyed.
 */
export interface RoomClosedPayload {
  reason: 'host_left' | 'empty_timeout' | 'room_destroyed';
}

/**
 * ack
 *
 * Acknowledgement of a client message.
 */
export interface AckPayload {
  messageId: string;
  type: string;
  success: boolean;
}

/**
 * error
 *
 * Error response (includes reason code and message).
 */
export interface ErrorPayload {
  code: string;
  message: string;
  retryable: boolean;
}

/**
 * webrtc_signal (server → client)
 *
 * WebRTC signaling payload routed to target peer.
 */
export interface WebRTCSignalServerPayload {
  senderId: string;
  type: 'offer' | 'answer' | 'ice-candidate';
  signal: unknown;
}

/**
 * voice_state (client → server)
 *
 * Client notifies room of their local PTT speaking state.
 */
export interface VoiceStatePayload {
  speaking: boolean;
}

/**
 * voice_state_changed (server → client)
 *
 * Broadcast to other room members when a member's PTT state changes.
 */
export interface VoiceStateChangedPayload {
  userId: string;
  speaking: boolean;
}
