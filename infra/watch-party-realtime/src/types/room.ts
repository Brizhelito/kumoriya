/**
 * Room State (PartyRoomDO Persistent Storage)
 *
 * The authoritative state persisted to Durable Object storage.
 */
export interface RoomState {
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

/**
 * Member State
 *
 * Represents a member in the watch party room.
 */
export interface Member {
  userId: string;
  name: string;
  presence: 'connected' | 'disconnected';
  readyPersisted: boolean; // Persisted during grace period
  effectiveReady: boolean; // readyPersisted AND connected
  joinedAtMs: number;
  lastHeartbeatMs: number;
}

/**
 * Ready State
 *
 * Dual-layer ready state tracking for grace period support.
 */
export interface ReadyState {
  readyPersisted: boolean;
  effectiveReady: boolean;
}

/**
 * Media State
 *
 * Current media identifier for the watch party.
 */
export interface MediaState {
  anilistId: number;
  animeTitle: string;
  episodeNumber: number;
}

/**
 * Playback State
 *
 * Server-authoritative playback synchronization state.
 */
export interface PlaybackState {
  status: 'playing' | 'paused';
  basePositionMs: number;
  effectiveAtMs: number;
  generation: number;
}
