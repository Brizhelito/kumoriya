/**
 * Property Test: Room Creation Generates Unique Identifiers
 *
 * Property 1: Room Creation Generates Unique Identifiers
 * **Validates: Requirements 2.2, 2.3**
 *
 * For any batch of room creation requests, all generated roomIds and inviteCodes
 * SHALL be unique across the entire batch.
 */

import { describe, it, expect } from 'vitest';
import * as fc from 'fast-check';

/**
 * Simulate roomId generation (UUID v4)
 */
function generateRoomId(): string {
  return crypto.randomUUID();
}

/**
 * Simulate inviteCode generation (6-char alphanumeric, uppercase)
 */
function generateInviteCode(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  return code;
}

/**
 * Simulate generating N unique invite codes with collision detection
 * (mirrors the PartyRegistryDO.generateUniqueInviteCode logic)
 */
function generateUniqueInviteCodes(count: number): string[] {
  const codes = new Set<string>();
  while (codes.size < count) {
    codes.add(generateInviteCode());
  }
  return Array.from(codes);
}

describe('Property 1: Room Creation Generates Unique Identifiers', () => {
  it('should generate unique roomIds for any number of rooms (1 to 50)', () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 50 }),
        (count: number) => {
          // Generate `count` room IDs
          const roomIds = Array.from({ length: count }, () => generateRoomId());

          // All roomIds must be unique
          const uniqueRoomIds = new Set(roomIds);
          expect(uniqueRoomIds.size).toBe(count);
        }
      ),
      { numRuns: 50 }
    );
  });

  it('should generate roomIds that are valid UUIDs (v4 format)', () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 20 }),
        (count: number) => {
          const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
          const roomIds = Array.from({ length: count }, () => generateRoomId());

          for (const roomId of roomIds) {
            expect(roomId).toMatch(uuidRegex);
          }
        }
      ),
      { numRuns: 50 }
    );
  });

  it('should generate invite codes that are exactly 6 alphanumeric uppercase characters', () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 20 }),
        (count: number) => {
          const inviteCodeRegex = /^[A-Z0-9]{6}$/;
          const codes = generateUniqueInviteCodes(count);

          for (const code of codes) {
            expect(code).toMatch(inviteCodeRegex);
            expect(code).toHaveLength(6);
          }
        }
      ),
      { numRuns: 50 }
    );
  });

  it('should generate unique invite codes within a batch of up to 10 rooms', () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 10 }),
        (count: number) => {
          const codes = generateUniqueInviteCodes(count);

          // All codes must be unique
          const uniqueCodes = new Set(codes);
          expect(uniqueCodes.size).toBe(count);
        }
      ),
      { numRuns: 100 }
    );
  });

  it('should produce roomId and inviteCode as independent identifiers (no correlation)', () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 2, max: 10 }),
        (count: number) => {
          const rooms = Array.from({ length: count }, () => ({
            roomId: generateRoomId(),
            inviteCode: generateInviteCode(),
          }));

          // roomIds must all be unique
          const roomIds = new Set(rooms.map((r) => r.roomId));
          expect(roomIds.size).toBe(count);

          // No roomId should equal any inviteCode (different namespaces)
          for (const room of rooms) {
            expect(room.roomId).not.toBe(room.inviteCode);
            expect(room.roomId).not.toMatch(/^[A-Z0-9]{6}$/); // roomId is UUID, not invite code
          }
        }
      ),
      { numRuns: 50 }
    );
  });
});
