/**
 * Watch Party Realtime Types
 *
 * Core data model interfaces and types for the watch party realtime service.
 */

// Session types
export type { SessionToken } from './session';

// Room state types
export type { RoomState, Member, ReadyState, MediaState, PlaybackState } from './room';

// Error types
export { ErrorCode } from './errors';
export type { ErrorPayload } from './errors';

// Message types
export type {
  WSEnvelope,
  // Client → Server
  HelloPayload,
  HeartbeatPayload,
  RequestSnapshotPayload,
  SetReadyPayload,
  SendReactionPayload,
  PlaybackIntentPayload,
  LeaveRoomPayload,
  WebRTCSignalPayload,
  // Server → Client
  RoomSnapshotPayload,
  MemberJoinedPayload,
  MemberLeftPayload,
  MemberPresenceChangedPayload,
  MemberReadyChangedPayload,
  ReactionBroadcastPayload,
  PlaybackStateChangedPayload,
  MediaChangedPayload,
  EpisodeChangedPayload,
  HostTransferredPayload,
  RoomClosedPayload,
  AckPayload,
  WebRTCSignalServerPayload,
} from './messages';
