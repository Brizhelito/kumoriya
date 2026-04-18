/**
 * Error Codes
 *
 * Canonical error codes for watch party operations.
 */
export enum ErrorCode {
  INVALID_TOKEN = 'invalid_token',
  EXPIRED_TOKEN = 'expired_token',
  ROOM_NOT_FOUND = 'room_not_found',
  ROOM_FULL = 'room_full',
  INVALID_INVITE_CODE = 'invalid_invite_code',
  RATE_LIMIT_EXCEEDED = 'rate_limit_exceeded',
  UNAUTHORIZED = 'unauthorized',
  USER_ALREADY_IN_ROOM = 'user_already_in_room',
  INVALID_MESSAGE = 'invalid_message',
}

/**
 * Error Payload
 *
 * Structure for error messages sent to clients.
 */
export interface ErrorPayload {
  code: string;
  message: string;
  retryable: boolean;
}
