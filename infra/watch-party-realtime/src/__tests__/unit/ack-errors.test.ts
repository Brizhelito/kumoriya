/**
 * Unit Tests: Message Acknowledgement and Error Handling
 *
 * Tests ack generation, error generation, messageId validation, and
 * all error code paths.
 *
 * Requirements: Message Semantics
 */

import { describe, it, expect } from 'vitest';
import {
  buildAck,
  buildError,
  validateMessageId,
  parseEnvelope,
  serializeEnvelope,
  Errors,
  STATE_MODIFYING_TYPES,
} from '@/messaging/ack';
import { ErrorCode } from '@/types/errors';
import type { WSEnvelope } from '@/types/messages';

describe('buildAck', () => {
  it('should include the original messageId', () => {
    const ack = buildAck('msg-123', 'set_ready', 'room-abc');
    const payload = ack.payload as { messageId: string; type: string; success: boolean };
    expect(payload.messageId).toBe('msg-123');
    expect(ack.messageId).toBe('msg-123');
  });

  it('should have type "ack"', () => {
    const ack = buildAck('msg-1', 'send_reaction');
    expect(ack.type).toBe('ack');
  });

  it('should set success=true', () => {
    const ack = buildAck('msg-1', 'playback_intent');
    expect((ack.payload as { success: boolean }).success).toBe(true);
  });

  it('should include the original message type in payload', () => {
    const ack = buildAck('msg-1', 'send_reaction', 'room-1');
    expect((ack.payload as { type: string }).type).toBe('send_reaction');
  });

  it('should include a sentAt timestamp', () => {
    const before = Date.now();
    const ack = buildAck('msg-1', 'leave_room');
    const after = Date.now();
    expect(ack.sentAt).toBeGreaterThanOrEqual(before);
    expect(ack.sentAt).toBeLessThanOrEqual(after);
  });

  it('should include roomId when provided', () => {
    const ack = buildAck('msg-1', 'set_ready', 'room-xyz');
    expect(ack.roomId).toBe('room-xyz');
  });

  it('should include an eventId', () => {
    const ack = buildAck('msg-1', 'set_ready');
    expect(ack.eventId).toBeDefined();
    expect(typeof ack.eventId).toBe('string');
  });
});

describe('buildError', () => {
  it('should include code, message, retryable in payload', () => {
    const err = buildError('rate_limit_exceeded', 'Slow down', true);
    const payload = err.payload as { code: string; message: string; retryable: boolean };
    expect(payload.code).toBe('rate_limit_exceeded');
    expect(payload.message).toBe('Slow down');
    expect(payload.retryable).toBe(true);
  });

  it('should have type "error"', () => {
    const err = buildError('room_not_found', 'Room not found', false);
    expect(err.type).toBe('error');
  });

  it('should include messageId when provided', () => {
    const err = buildError('invalid_message', 'Missing messageId', false, 'msg-42');
    expect(err.messageId).toBe('msg-42');
  });

  it('should not include messageId field when not provided', () => {
    const err = buildError('room_not_found', 'Not found', false);
    expect(err.messageId).toBeUndefined();
  });

  it('should include roomId when provided', () => {
    const err = buildError('unauthorized', 'Not allowed', false, undefined, 'room-1');
    expect(err.roomId).toBe('room-1');
  });

  it('should have retryable=false for non-retriable errors', () => {
    const err = buildError(ErrorCode.INVALID_TOKEN, 'Bad token', false);
    expect((err.payload as { retryable: boolean }).retryable).toBe(false);
  });

  it('should have retryable=true for rate limit errors', () => {
    const err = buildError(ErrorCode.RATE_LIMIT_EXCEEDED, 'Too fast', true);
    expect((err.payload as { retryable: boolean }).retryable).toBe(true);
  });
});

describe('validateMessageId', () => {
  it('should return null when a state-modifying message includes a messageId', () => {
    for (const type of STATE_MODIFYING_TYPES) {
      const envelope: WSEnvelope = { type, sentAt: Date.now(), payload: {}, messageId: 'msg-1' };
      expect(validateMessageId(envelope, 'room-1')).toBeNull();
    }
  });

  it('should return an error envelope when a state-modifying message lacks messageId', () => {
    for (const type of STATE_MODIFYING_TYPES) {
      const envelope: WSEnvelope = { type, sentAt: Date.now(), payload: {} };
      const result = validateMessageId(envelope, 'room-1');
      expect(result).not.toBeNull();
      expect(result!.type).toBe('error');
      expect((result!.payload as { code: string }).code).toBe(ErrorCode.INVALID_MESSAGE);
    }
  });

  it('should return null for non-state-modifying messages even without messageId', () => {
    const types = ['heartbeat', 'hello', 'request_snapshot', 'webrtc_signal'];
    for (const type of types) {
      const envelope: WSEnvelope = { type, sentAt: Date.now(), payload: {} };
      expect(validateMessageId(envelope)).toBeNull();
    }
  });

  it('state-modifying types should be the correct set', () => {
    expect(STATE_MODIFYING_TYPES.has('set_ready')).toBe(true);
    expect(STATE_MODIFYING_TYPES.has('send_reaction')).toBe(true);
    expect(STATE_MODIFYING_TYPES.has('send_chat')).toBe(false);
    expect(STATE_MODIFYING_TYPES.has('playback_intent')).toBe(true);
    expect(STATE_MODIFYING_TYPES.has('leave_room')).toBe(true);
    expect(STATE_MODIFYING_TYPES.has('heartbeat')).toBe(false);
    expect(STATE_MODIFYING_TYPES.has('hello')).toBe(false);
  });
});

describe('parseEnvelope', () => {
  it('should parse a valid JSON envelope', () => {
    const raw = JSON.stringify({ type: 'heartbeat', sentAt: Date.now(), payload: {} });
    const result = parseEnvelope(raw);
    expect(result).not.toBeNull();
    expect(result!.type).toBe('heartbeat');
  });

  it('should return null for malformed JSON', () => {
    expect(parseEnvelope('{not valid json')).toBeNull();
  });

  it('should return null when type is missing', () => {
    const raw = JSON.stringify({ sentAt: Date.now(), payload: {} });
    expect(parseEnvelope(raw)).toBeNull();
  });

  it('should return null when type is not a string', () => {
    const raw = JSON.stringify({ type: 42, sentAt: Date.now(), payload: {} });
    expect(parseEnvelope(raw)).toBeNull();
  });

  it('should preserve messageId if present', () => {
    const raw = JSON.stringify({
      type: 'set_ready',
      sentAt: Date.now(),
      payload: { ready: true },
      messageId: 'abc-123',
    });
    const result = parseEnvelope(raw);
    expect(result!.messageId).toBe('abc-123');
  });
});

describe('serializeEnvelope', () => {
  it('should produce valid JSON', () => {
    const env: WSEnvelope = { type: 'ack', sentAt: Date.now(), payload: { success: true } };
    const json = serializeEnvelope(env);
    expect(() => JSON.parse(json)).not.toThrow();
  });

  it('should round-trip parse correctly', () => {
    const env: WSEnvelope = {
      type: 'error',
      sentAt: 1234567890,
      payload: { code: 'unauthorized', message: 'No', retryable: false },
      messageId: 'mid-1',
      roomId: 'room-1',
    };
    const parsed = JSON.parse(serializeEnvelope(env)) as WSEnvelope;
    expect(parsed.type).toBe(env.type);
    expect(parsed.messageId).toBe(env.messageId);
    expect(parsed.roomId).toBe(env.roomId);
  });
});

describe('Errors factory', () => {
  it('invalidToken should have correct code and retryable=false', () => {
    const err = Errors.invalidToken();
    expect((err.payload as { code: string; retryable: boolean }).code).toBe(ErrorCode.INVALID_TOKEN);
    expect((err.payload as { retryable: boolean }).retryable).toBe(false);
  });

  it('expiredToken should have correct code and retryable=false', () => {
    const err = Errors.expiredToken();
    expect((err.payload as { code: string }).code).toBe(ErrorCode.EXPIRED_TOKEN);
    expect((err.payload as { retryable: boolean }).retryable).toBe(false);
  });

  it('roomNotFound should have correct code and retryable=false', () => {
    const err = Errors.roomNotFound();
    expect((err.payload as { code: string }).code).toBe(ErrorCode.ROOM_NOT_FOUND);
  });

  it('roomFull should have correct code and retryable=false', () => {
    const err = Errors.roomFull();
    expect((err.payload as { code: string }).code).toBe(ErrorCode.ROOM_FULL);
    expect((err.payload as { retryable: boolean }).retryable).toBe(false);
  });

  it('invalidInviteCode should have correct code', () => {
    const err = Errors.invalidInviteCode();
    expect((err.payload as { code: string }).code).toBe(ErrorCode.INVALID_INVITE_CODE);
  });

  it('rateLimitExceeded should have correct code and retryable=true', () => {
    const err = Errors.rateLimitExceeded();
    expect((err.payload as { code: string }).code).toBe(ErrorCode.RATE_LIMIT_EXCEEDED);
    expect((err.payload as { retryable: boolean }).retryable).toBe(true);
  });

  it('unauthorized should include a reason', () => {
    const err = Errors.unauthorized('Not the host');
    expect((err.payload as { message: string }).message).toBe('Not the host');
    expect((err.payload as { code: string }).code).toBe(ErrorCode.UNAUTHORIZED);
  });

  it('userAlreadyInRoom should have correct code', () => {
    const err = Errors.userAlreadyInRoom();
    expect((err.payload as { code: string }).code).toBe(ErrorCode.USER_ALREADY_IN_ROOM);
  });

  it('invalidMessage should include a reason', () => {
    const err = Errors.invalidMessage('Missing messageId');
    expect((err.payload as { message: string }).message).toBe('Missing messageId');
    expect((err.payload as { code: string }).code).toBe(ErrorCode.INVALID_MESSAGE);
  });
});
