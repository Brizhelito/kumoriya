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
/**
 * Member Status
 *
 * What the member is currently doing in the watch party.
 * - in_lobby:   browsing / waiting in the lobby
 * - loading:    episode is loading (buffer / resolve)
 * - in_player:  player open but not actively watching (e.g. paused by user)
 * - watching:   actively playing (media is running)
 * - paused:     playback paused by user
 */
export type MemberStatus = 'in_lobby' | 'loading' | 'in_player' | 'watching' | 'paused';

export interface Member {
  userId: string;
  name: string;
  presence: 'connected' | 'disconnected';
  readyPersisted: boolean; // Persisted during grace period
  effectiveReady: boolean; // readyPersisted AND connected
  status: MemberStatus;    // current member activity
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
