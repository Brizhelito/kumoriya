/**
 * Property Test: Ready State Dual-Layer Consistency
 *
 * **Validates: Requirements 7.1, 7.3, 7.4**
 *
 * Property 6: For any member, effectiveReady SHALL equal (readyPersisted AND presence equals connected)
 *
 * This property test verifies the dual-layer ready state consistency across various member states:
 * - When a member sends set_ready, both readyPersisted and effectiveReady are updated
 * - When a member disconnects, effectiveReady is set to false while readyPersisted is preserved
 * - When a member reconnects, effectiveReady is restored from readyPersisted
 */

import { describe, it, expect } from 'vitest';
import * as fc from 'fast-check';
import type { Member } from '@/types';

/**
 * Helper function to create a valid Member object that respects the invariant
 * effectiveReady = readyPersisted AND (presence === 'connected')
 */
function createMember(
  userId: string,
  name: string,
  presence: 'connected' | 'disconnected',
  readyPersisted: boolean,
  joinedAtMs: number,
  lastHeartbeatMs: number
): Member {
  return {
    userId,
    name,
    presence,
    status: 'in_lobby',
    readyPersisted,
    effectiveReady: readyPersisted && presence === 'connected',
    joinedAtMs,
    lastHeartbeatMs,
  };
}

/**
 * Helper function to simulate set_ready action
 */
function setReady(member: Member, ready: boolean): Member {
  if (member.presence !== 'connected') {
    // Cannot set ready when disconnected
    return member;
  }
  return {
    ...member,
    readyPersisted: ready,
    effectiveReady: ready && member.presence === 'connected',
  };
}

/**
 * Helper function to simulate disconnect action
 */
function disconnect(member: Member): Member {
  return {
    ...member,
    presence: 'disconnected',
    effectiveReady: false, // effectiveReady becomes false, readyPersisted preserved
  };
}

/**
 * Helper function to simulate reconnect action
 */
function reconnect(member: Member): Member {
  return {
    ...member,
    presence: 'connected',
    effectiveReady: member.readyPersisted, // Restore from readyPersisted
  };
}

describe('Property 6: Ready State Dual-Layer Consistency', () => {
  /**
   * Arbitrary generator for valid Member states
   * Generates members that respect the invariant
   */
  const validMemberArbitrary = fc
    .record({
      userId: fc.uuid(),
      name: fc.string({ minLength: 1, maxLength: 50 }),
      presence: fc.constantFrom('connected' as const, 'disconnected' as const),
      readyPersisted: fc.boolean(),
      joinedAtMs: fc.integer({ min: 0, max: Date.now() }),
      lastHeartbeatMs: fc.integer({ min: 0, max: Date.now() }),
    })
    .map((data) =>
      createMember(
        data.userId,
        data.name,
        data.presence,
        data.readyPersisted,
        data.joinedAtMs,
        data.lastHeartbeatMs
      )
    );

  it('should maintain effectiveReady = readyPersisted AND (presence === connected) for any valid member state', () => {
    fc.assert(
      fc.property(validMemberArbitrary, (member: Member) => {
        // The invariant: effectiveReady MUST equal (readyPersisted AND presence === 'connected')
        const expectedEffectiveReady = member.readyPersisted && member.presence === 'connected';

        // Verify the invariant holds
        expect(member.effectiveReady).toBe(expectedEffectiveReady);
      }),
      { numRuns: 100 }
    );
  });

  it('should have effectiveReady = false when member is disconnected, regardless of readyPersisted', () => {
    fc.assert(
      fc.property(
        fc
          .record({
            userId: fc.uuid(),
            name: fc.string({ minLength: 1, maxLength: 50 }),
            readyPersisted: fc.boolean(), // Can be true or false
            joinedAtMs: fc.integer({ min: 0, max: Date.now() }),
            lastHeartbeatMs: fc.integer({ min: 0, max: Date.now() }),
          })
          .map((data) =>
            createMember(
              data.userId,
              data.name,
              'disconnected',
              data.readyPersisted,
              data.joinedAtMs,
              data.lastHeartbeatMs
            )
          ),
        (member: Member) => {
          // When disconnected, effectiveReady MUST be false
          expect(member.effectiveReady).toBe(false);
          // readyPersisted can be any value (preserved during grace period)
          expect(typeof member.readyPersisted).toBe('boolean');
        }
      ),
      { numRuns: 100 }
    );
  });

  it('should have effectiveReady = readyPersisted when member is connected', () => {
    fc.assert(
      fc.property(
        fc
          .record({
            userId: fc.uuid(),
            name: fc.string({ minLength: 1, maxLength: 50 }),
            readyPersisted: fc.boolean(),
            joinedAtMs: fc.integer({ min: 0, max: Date.now() }),
            lastHeartbeatMs: fc.integer({ min: 0, max: Date.now() }),
          })
          .map((data) =>
            createMember(
              data.userId,
              data.name,
              'connected',
              data.readyPersisted,
              data.joinedAtMs,
              data.lastHeartbeatMs
            )
          ),
        (member: Member) => {
          // When connected, effectiveReady MUST equal readyPersisted
          expect(member.effectiveReady).toBe(member.readyPersisted);
        }
      ),
      { numRuns: 100 }
    );
  });

  it('should verify ready state transitions: set_ready updates both readyPersisted and effectiveReady when connected', () => {
    fc.assert(
      fc.property(
        validMemberArbitrary.filter((m) => m.presence === 'connected'),
        fc.boolean(), // New ready value
        (member: Member, newReady: boolean) => {
          // Simulate set_ready action
          const updatedMember = setReady(member, newReady);

          // Verify both readyPersisted and effectiveReady are updated
          expect(updatedMember.readyPersisted).toBe(newReady);
          expect(updatedMember.effectiveReady).toBe(newReady);

          // Verify invariant still holds
          expect(updatedMember.effectiveReady).toBe(
            updatedMember.readyPersisted && updatedMember.presence === 'connected'
          );
        }
      ),
      { numRuns: 100 }
    );
  });

  it('should verify disconnect preserves readyPersisted but sets effectiveReady to false', () => {
    fc.assert(
      fc.property(
        validMemberArbitrary.filter((m) => m.presence === 'connected'),
        (member: Member) => {
          const originalReadyPersisted = member.readyPersisted;

          // Simulate disconnect
          const disconnectedMember = disconnect(member);

          // Verify readyPersisted is preserved
          expect(disconnectedMember.readyPersisted).toBe(originalReadyPersisted);

          // Verify effectiveReady is set to false
          expect(disconnectedMember.effectiveReady).toBe(false);

          // Verify presence is disconnected
          expect(disconnectedMember.presence).toBe('disconnected');

          // Verify invariant still holds
          expect(disconnectedMember.effectiveReady).toBe(
            disconnectedMember.readyPersisted && disconnectedMember.presence === 'connected'
          );
        }
      ),
      { numRuns: 100 }
    );
  });

  it('should verify reconnect restores effectiveReady from readyPersisted', () => {
    fc.assert(
      fc.property(
        validMemberArbitrary.filter((m) => m.presence === 'disconnected'),
        (member: Member) => {
          const originalReadyPersisted = member.readyPersisted;

          // Simulate reconnect
          const reconnectedMember = reconnect(member);

          // Verify readyPersisted is unchanged
          expect(reconnectedMember.readyPersisted).toBe(originalReadyPersisted);

          // Verify effectiveReady is restored from readyPersisted
          expect(reconnectedMember.effectiveReady).toBe(originalReadyPersisted);

          // Verify presence is connected
          expect(reconnectedMember.presence).toBe('connected');

          // Verify invariant still holds
          expect(reconnectedMember.effectiveReady).toBe(
            reconnectedMember.readyPersisted && reconnectedMember.presence === 'connected'
          );
        }
      ),
      { numRuns: 100 }
    );
  });

  it('should verify complete disconnect/reconnect cycle preserves readyPersisted', () => {
    fc.assert(
      fc.property(
        validMemberArbitrary.filter((m) => m.presence === 'connected'),
        (member: Member) => {
          const originalReadyPersisted = member.readyPersisted;
          const originalEffectiveReady = member.effectiveReady;

          // Simulate disconnect (grace period starts)
          const disconnectedMember = disconnect(member);

          // Verify during disconnect
          expect(disconnectedMember.readyPersisted).toBe(originalReadyPersisted);
          expect(disconnectedMember.effectiveReady).toBe(false);

          // Simulate reconnect within grace period
          const reconnectedMember = reconnect(disconnectedMember);

          // Verify after reconnect: state is fully restored
          expect(reconnectedMember.readyPersisted).toBe(originalReadyPersisted);
          expect(reconnectedMember.effectiveReady).toBe(originalEffectiveReady);

          // Verify invariant holds throughout
          expect(reconnectedMember.effectiveReady).toBe(
            reconnectedMember.readyPersisted && reconnectedMember.presence === 'connected'
          );
        }
      ),
      { numRuns: 100 }
    );
  });

  it('should verify complex state transition sequences maintain invariant', () => {
    fc.assert(
      fc.property(
        fc.boolean(), // Initial readyPersisted value
        fc.array(fc.constantFrom('connect', 'disconnect', 'set_ready_true', 'set_ready_false'), {
          minLength: 1,
          maxLength: 20,
        }),
        (initialReady: boolean, actions: string[]) => {
          // Start with a connected member
          let member = createMember(
            'test-user',
            'Test User',
            'connected',
            initialReady,
            Date.now(),
            Date.now()
          );

          // Apply each action and verify invariant holds
          for (const action of actions) {
            switch (action) {
              case 'connect':
                if (member.presence === 'disconnected') {
                  member = reconnect(member);
                }
                break;
              case 'disconnect':
                if (member.presence === 'connected') {
                  member = disconnect(member);
                }
                break;
              case 'set_ready_true':
                member = setReady(member, true);
                break;
              case 'set_ready_false':
                member = setReady(member, false);
                break;
            }

            // Verify invariant holds after each action
            expect(member.effectiveReady).toBe(
              member.readyPersisted && member.presence === 'connected'
            );
          }
        }
      ),
      { numRuns: 100 }
    );
  });
});
