/**
 * Token-bucket rate-limit unit tests.
 *
 * Exercises the pure `consumeFromBucket` helper that backs the
 * in-memory per-user rate limiter on PartyRoomDO.
 */

import { describe, it, expect } from 'vitest';
import {
  consumeFromBucket,
  DEFAULT_RATE_LIMITS,
} from '../../durable-objects/PartyRoomDO';

describe('consumeFromBucket', () => {
  // `chat` was removed; reactions keep the same 8/10s spec so we exercise the
  // bucket helper through the reaction spec instead.
  const reactionSpec = DEFAULT_RATE_LIMITS.reaction;

  it('starts with a full bucket and allows `capacity` consecutive requests', () => {
    let bucket = undefined as ReturnType<typeof consumeFromBucket>['bucket'] | undefined;
    let allowedCount = 0;
    for (let i = 0; i < reactionSpec.capacity; i++) {
      const r = consumeFromBucket(bucket, reactionSpec, 1_000);
      bucket = r.bucket;
      if (r.allowed) allowedCount += 1;
    }
    expect(allowedCount).toBe(reactionSpec.capacity);
  });

  it('rejects the next request after the bucket is empty', () => {
    let bucket = undefined as ReturnType<typeof consumeFromBucket>['bucket'] | undefined;
    for (let i = 0; i < reactionSpec.capacity; i++) {
      bucket = consumeFromBucket(bucket, reactionSpec, 1_000).bucket;
    }
    const extra = consumeFromBucket(bucket, reactionSpec, 1_000);
    expect(extra.allowed).toBe(false);
  });

  it('refills over time proportionally to refillPerSec', () => {
    let bucket = undefined as ReturnType<typeof consumeFromBucket>['bucket'] | undefined;
    // Drain the bucket at t=0.
    for (let i = 0; i < reactionSpec.capacity; i++) {
      bucket = consumeFromBucket(bucket, reactionSpec, 0).bucket;
    }
    // After 2 seconds, we should have >= 1 token again for a 0.8/s refill.
    const after2s = consumeFromBucket(bucket, reactionSpec, 2_000);
    expect(after2s.allowed).toBe(true);
  });

  it('never exceeds capacity when idle for a long time', () => {
    let bucket = undefined as ReturnType<typeof consumeFromBucket>['bucket'] | undefined;
    // Drain first.
    for (let i = 0; i < reactionSpec.capacity; i++) {
      bucket = consumeFromBucket(bucket, reactionSpec, 0).bucket;
    }
    // Sleep 1 hour.
    const r = consumeFromBucket(bucket, reactionSpec, 3_600_000);
    expect(r.bucket.tokens).toBeLessThanOrEqual(reactionSpec.capacity);
  });

  it('handles zero elapsed time without producing NaN or negative tokens', () => {
    const r = consumeFromBucket(
      { tokens: 3, updatedMs: 1_000 },
      reactionSpec,
      1_000,
    );
    expect(Number.isFinite(r.bucket.tokens)).toBe(true);
    expect(r.bucket.tokens).toBeGreaterThanOrEqual(0);
  });

  it('each rate-limited resource has independent buckets', () => {
    // Drain reaction completely, playback_intent should still allow through.
    let reactionBucket = undefined as ReturnType<typeof consumeFromBucket>['bucket'] | undefined;
    for (let i = 0; i < DEFAULT_RATE_LIMITS.reaction.capacity; i++) {
      reactionBucket = consumeFromBucket(reactionBucket, DEFAULT_RATE_LIMITS.reaction, 0).bucket;
    }
    const intentR = consumeFromBucket(undefined, DEFAULT_RATE_LIMITS.playback_intent, 0);
    expect(intentR.allowed).toBe(true);
  });

  it('correctly configures and verifies voice_state rate limit', () => {
    const spec = DEFAULT_RATE_LIMITS.voice_state;
    expect(spec).toBeDefined();
    expect(spec.capacity).toBe(10);
    expect(spec.refillPerSec).toBe(1);

    let bucket = undefined as ReturnType<typeof consumeFromBucket>['bucket'] | undefined;
    for (let i = 0; i < spec.capacity; i++) {
      bucket = consumeFromBucket(bucket, spec, 0).bucket;
    }
    const extra = consumeFromBucket(bucket, spec, 0);
    expect(extra.allowed).toBe(false);

    // After 1 second, we should have 1 token for a 1/s refill.
    const after1s = consumeFromBucket(bucket, spec, 1000);
    expect(after1s.allowed).toBe(true);
  });
});
