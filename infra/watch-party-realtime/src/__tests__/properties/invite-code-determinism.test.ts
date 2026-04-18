/**
 * Property Test: Invite Code Resolution is Deterministic
 *
 * Property 2: Invite Code Resolution is Deterministic
 * **Validates: Requirements 3.2**
 *
 * For any stored (inviteCode → roomId) mapping, resolving the same inviteCode
 * SHALL always return the same roomId, and resolving an unknown inviteCode
 * SHALL always return an error.
 */

import { describe, it, expect } from 'vitest';
import * as fc from 'fast-check';

/**
 * Minimal in-memory invite code store to model PartyRegistryDO storage
 */
class InviteCodeStore {
  private inviteCodes = new Map<string, string>();

  register(inviteCode: string, roomId: string): void {
    this.inviteCodes.set(inviteCode, roomId);
  }

  resolve(inviteCode: string): { roomId: string } | null {
    const roomId = this.inviteCodes.get(inviteCode);
    return roomId != null ? { roomId } : null;
  }

  remove(inviteCode: string): void {
    this.inviteCodes.delete(inviteCode);
  }
}

/** Arbitrary for a valid 6-char alphanumeric invite code */
const inviteCodeArbitrary = fc
  .array(fc.constantFrom(...'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.split('')), {
    minLength: 6,
    maxLength: 6,
  })
  .map((chars) => chars.join(''));

/** Arbitrary for a UUID-like roomId */
const roomIdArbitrary = fc.uuid();

describe('Property 2: Invite Code Resolution is Deterministic', () => {
  it('should always return the same roomId for the same registered inviteCode', () => {
    fc.assert(
      fc.property(
        inviteCodeArbitrary,
        roomIdArbitrary,
        fc.integer({ min: 1, max: 5 }), // Number of resolution attempts
        (inviteCode: string, roomId: string, attempts: number) => {
          const store = new InviteCodeStore();
          store.register(inviteCode, roomId);

          // Resolve the same code multiple times — must always return same roomId
          for (let i = 0; i < attempts; i++) {
            const result = store.resolve(inviteCode);
            expect(result).not.toBeNull();
            expect(result!.roomId).toBe(roomId);
          }
        }
      ),
      { numRuns: 100 }
    );
  });

  it('should return null (not found) for any unregistered inviteCode', () => {
    fc.assert(
      fc.property(
        inviteCodeArbitrary,
        inviteCodeArbitrary,
        roomIdArbitrary,
        (registered: string, unknown: string, roomId: string) => {
          fc.pre(registered !== unknown); // ensure they're different codes

          const store = new InviteCodeStore();
          store.register(registered, roomId);

          // Resolving a different code must return null
          const result = store.resolve(unknown);
          expect(result).toBeNull();
        }
      ),
      { numRuns: 100 }
    );
  });

  it('should return null for any code after that code is removed', () => {
    fc.assert(
      fc.property(
        inviteCodeArbitrary,
        roomIdArbitrary,
        (inviteCode: string, roomId: string) => {
          const store = new InviteCodeStore();
          store.register(inviteCode, roomId);

          // Registered: must resolve
          expect(store.resolve(inviteCode)).not.toBeNull();

          // After removal (room destroyed): must return null
          store.remove(inviteCode);
          expect(store.resolve(inviteCode)).toBeNull();
        }
      ),
      { numRuns: 100 }
    );
  });

  it('should not confuse roomIds across different invite codes', () => {
    fc.assert(
      fc.property(
        fc.array(
          fc.record({ inviteCode: inviteCodeArbitrary, roomId: roomIdArbitrary }),
          { minLength: 2, maxLength: 10 }
        ),
        (entries: Array<{ inviteCode: string; roomId: string }>) => {
          // Deduplicate invite codes for a clean test
          const unique = new Map<string, string>();
          for (const { inviteCode, roomId } of entries) {
            if (!unique.has(inviteCode)) {
              unique.set(inviteCode, roomId);
            }
          }

          const store = new InviteCodeStore();
          for (const [code, id] of unique) {
            store.register(code, id);
          }

          // Each registered code must resolve to its own roomId
          for (const [code, id] of unique) {
            const result = store.resolve(code);
            expect(result).not.toBeNull();
            expect(result!.roomId).toBe(id);
          }
        }
      ),
      { numRuns: 50 }
    );
  });

  it('should handle empty store — any code resolves to null', () => {
    fc.assert(
      fc.property(
        inviteCodeArbitrary,
        (inviteCode: string) => {
          const store = new InviteCodeStore();
          expect(store.resolve(inviteCode)).toBeNull();
        }
      ),
      { numRuns: 100 }
    );
  });
});
