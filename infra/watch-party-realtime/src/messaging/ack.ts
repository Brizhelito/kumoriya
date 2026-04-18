/**
 * Message Acknowledgement and Error Response Utilities
 *
 * Implements the WebSocket protocol-level message responses:
 * - ack: Acknowledgement of a client message with messageId correlation
 * - error: Error response with code, message, retryable fields
 *
 * State-modifying messages (set_ready, send_reaction, playback_intent,
 * leave_room) MUST include a messageId.
 * Messages without messageId are rejected with error code=invalid_message.
 *
 * Requirements: Message Semantics (ack, error sections)
 */

import { WSEnvelope, AckPayload } from '../types/messages';
import { ErrorCode, ErrorPayload } from '../types/errors';

/**
 * Message types that modify state and MUST include a messageId
 */
export const STATE_MODIFYING_TYPES = new Set([
  'set_ready',
  'send_reaction',
  'playback_intent',
  'leave_room',
]);

/**
 * Build a success ack envelope for a given messageId and original message type
 */
export function buildAck(messageId: string, originalType: string, roomId?: string): WSEnvelope {
  const payload: AckPayload = {
    messageId,
    type: originalType,
    success: true,
  };

  return {
    type: 'ack',
    roomId,
    eventId: crypto.randomUUID(),
    sentAt: Date.now(),
    payload,
    messageId,
  };
}

/**
 * Build an error envelope
 */
export function buildError(
  code: string,
  message: string,
  retryable: boolean,
  messageId?: string,
  roomId?: string
): WSEnvelope {
  const payload: ErrorPayload = { code, message, retryable };
  return {
    type: 'error',
    roomId,
    eventId: crypto.randomUUID(),
    sentAt: Date.now(),
    payload,
    ...(messageId ? { messageId } : {}),
  };
}

/**
 * Validate that a state-modifying message includes a messageId.
 * Returns an error envelope if validation fails, null if valid.
 */
export function validateMessageId(
  envelope: WSEnvelope,
  roomId?: string
): WSEnvelope | null {
  if (STATE_MODIFYING_TYPES.has(envelope.type) && !envelope.messageId) {
    return buildError(
      ErrorCode.INVALID_MESSAGE,
      `Message of type '${envelope.type}' requires a messageId`,
      false,
      undefined,
      roomId
    );
  }
  return null;
}

/**
 * Serialize a WSEnvelope to a JSON string for WebSocket transmission
 */
export function serializeEnvelope(envelope: WSEnvelope): string {
  return JSON.stringify(envelope);
}

/**
 * Parse and validate an incoming WebSocket message string into a WSEnvelope.
 * Returns the parsed envelope or an error envelope if parsing fails.
 */
export function parseEnvelope(raw: string, _roomId?: string): WSEnvelope | null {
  try {
    const parsed = JSON.parse(raw) as WSEnvelope;

    if (!parsed.type || typeof parsed.type !== 'string') {
      return null; // Can't even build a correlation — drop silently
    }

    return parsed;
  } catch {
    return null;
  }
}

/**
 * Pre-built error factories for common error codes
 */
export const Errors = {
  invalidToken: (messageId?: string, roomId?: string) =>
    buildError(ErrorCode.INVALID_TOKEN, 'Invalid or malformed token', false, messageId, roomId),

  expiredToken: (messageId?: string, roomId?: string) =>
    buildError(ErrorCode.EXPIRED_TOKEN, 'Token has expired', false, messageId, roomId),

  roomNotFound: (messageId?: string, roomId?: string) =>
    buildError(ErrorCode.ROOM_NOT_FOUND, 'Room not found', false, messageId, roomId),

  roomFull: (messageId?: string, roomId?: string) =>
    buildError(ErrorCode.ROOM_FULL, 'Room is full (max 4 members)', false, messageId, roomId),

  invalidInviteCode: (messageId?: string, roomId?: string) =>
    buildError(ErrorCode.INVALID_INVITE_CODE, 'Invalid invite code', false, messageId, roomId),

  rateLimitExceeded: (messageId?: string, roomId?: string) =>
    buildError(
      ErrorCode.RATE_LIMIT_EXCEEDED,
      'Rate limit exceeded. Please slow down.',
      true,
      messageId,
      roomId
    ),

  unauthorized: (reason: string, messageId?: string, roomId?: string) =>
    buildError(ErrorCode.UNAUTHORIZED, reason, false, messageId, roomId),

  userAlreadyInRoom: (messageId?: string, roomId?: string) =>
    buildError(
      ErrorCode.USER_ALREADY_IN_ROOM,
      'User is already in another room',
      false,
      messageId,
      roomId
    ),

  invalidMessage: (reason: string, messageId?: string, roomId?: string) =>
    buildError(ErrorCode.INVALID_MESSAGE, reason, false, messageId, roomId),
};
