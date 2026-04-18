/**
 * Session Token verification unit tests.
 *
 * These tests exercise the Ed25519 JWT verifier against:
 *  - valid, signed tokens with all required claims
 *  - tokens with wrong audience / issuer / algorithm
 *  - expired tokens
 *  - tampered payload / signature
 *  - malformed structure
 *
 * We sign tokens inside the test with a fresh Ed25519 key pair via
 * Node's `crypto` module, exported as raw so the verifier can
 * import it via `crypto.subtle.importKey('raw', ...)`.
 */

import { describe, expect, it } from 'vitest';
import { generateKeyPairSync, sign as nodeSign, KeyObject } from 'node:crypto';

import { verifySessionToken, SessionClaims } from '../../auth/session-token';

// ─── Helpers ─────────────────────────────────────────────────────────────────

function base64UrlEncode(input: string | Uint8Array): string {
  const b = typeof input === 'string' ? Buffer.from(input) : Buffer.from(input);
  return b
    .toString('base64')
    .replace(/=+$/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function generateEd25519KeyPair(): {
  privateKey: KeyObject;
  publicKeyHex: string;
} {
  const { privateKey, publicKey } = generateKeyPairSync('ed25519');
  // Raw 32-byte public key is encoded in an SPKI DER wrapper; extract it by
  // asking for `raw` via `publicKey.export({ format: 'jwk' })` -> `x` and
  // base64url-decoding. Simpler: use der+spki, then slice last 32 bytes.
  const spki = publicKey.export({ type: 'spki', format: 'der' }) as Buffer;
  const rawPub = spki.subarray(spki.length - 32);
  return { privateKey, publicKeyHex: rawPub.toString('hex') };
}

function signEd25519Jwt(
  privateKey: KeyObject,
  header: Record<string, unknown>,
  claims: Record<string, unknown> | SessionClaims,
): string {
  const h = base64UrlEncode(JSON.stringify(header));
  const p = base64UrlEncode(JSON.stringify(claims));
  const signingInput = `${h}.${p}`;
  // Ed25519 signs a message directly without a separate digest.
  const sig = nodeSign(null, Buffer.from(signingInput), privateKey);
  const s = base64UrlEncode(sig);
  return `${h}.${p}.${s}`;
}

function validClaims(overrides: Partial<SessionClaims> = {}): SessionClaims {
  const now = Math.floor(Date.now() / 1000);
  return {
    sub: 'user-1',
    name: 'Alice',
    roomId: 'room-abc',
    role: 'host',
    sessionId: 'sess-xyz',
    iss: 'https://api.kumoriya.online',
    aud: 'watch-party',
    exp: now + 60,
    iat: now,
    ...overrides,
  };
}

const issuer = 'https://api.kumoriya.online';
const audience = 'watch-party';

// ─── Tests ───────────────────────────────────────────────────────────────────

describe('verifySessionToken', () => {
  it('accepts a correctly signed, well-formed token', async () => {
    const { privateKey, publicKeyHex } = generateEd25519KeyPair();
    const token = signEd25519Jwt(
      privateKey,
      { alg: 'EdDSA', typ: 'JWT' },
      validClaims(),
    );

    const result = await verifySessionToken(token, {
      publicKeyHex,
      expectedIssuer: issuer,
      expectedAudience: audience,
    });

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.claims.sub).toBe('user-1');
      expect(result.claims.roomId).toBe('room-abc');
      expect(result.claims.role).toBe('host');
      expect(result.claims.sessionId).toBe('sess-xyz');
    }
  });

  it('rejects token with wrong audience', async () => {
    const { privateKey, publicKeyHex } = generateEd25519KeyPair();
    const token = signEd25519Jwt(
      privateKey,
      { alg: 'EdDSA', typ: 'JWT' },
      validClaims({ aud: 'not-watch-party' }),
    );

    const result = await verifySessionToken(token, {
      publicKeyHex,
      expectedIssuer: issuer,
      expectedAudience: audience,
    });

    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.code).toBe('invalid_token');
  });

  it('rejects token with wrong issuer', async () => {
    const { privateKey, publicKeyHex } = generateEd25519KeyPair();
    const token = signEd25519Jwt(
      privateKey,
      { alg: 'EdDSA', typ: 'JWT' },
      validClaims({ iss: 'https://evil.example' }),
    );

    const result = await verifySessionToken(token, {
      publicKeyHex,
      expectedIssuer: issuer,
      expectedAudience: audience,
    });

    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.code).toBe('invalid_token');
  });

  it('rejects token with unexpected alg', async () => {
    const { privateKey, publicKeyHex } = generateEd25519KeyPair();
    const token = signEd25519Jwt(
      privateKey,
      { alg: 'HS256', typ: 'JWT' },
      validClaims(),
    );

    const result = await verifySessionToken(token, {
      publicKeyHex,
      expectedIssuer: issuer,
      expectedAudience: audience,
    });

    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.code).toBe('invalid_token');
  });

  it('rejects expired token', async () => {
    const { privateKey, publicKeyHex } = generateEd25519KeyPair();
    const token = signEd25519Jwt(
      privateKey,
      { alg: 'EdDSA', typ: 'JWT' },
      validClaims({ exp: Math.floor(Date.now() / 1000) - 120 }),
    );

    const result = await verifySessionToken(token, {
      publicKeyHex,
      expectedIssuer: issuer,
      expectedAudience: audience,
    });

    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.code).toBe('expired_token');
  });

  it('rejects tampered payload', async () => {
    const { privateKey, publicKeyHex } = generateEd25519KeyPair();
    const token = signEd25519Jwt(
      privateKey,
      { alg: 'EdDSA', typ: 'JWT' },
      validClaims(),
    );
    // Tamper with payload while keeping the signature
    const parts = token.split('.');
    const tampered = JSON.stringify({ ...validClaims(), sub: 'evil' });
    const newPayload = Buffer.from(tampered)
      .toString('base64')
      .replace(/=+$/g, '')
      .replace(/\+/g, '-')
      .replace(/\//g, '_');
    const broken = `${parts[0]}.${newPayload}.${parts[2]}`;

    const result = await verifySessionToken(broken, {
      publicKeyHex,
      expectedIssuer: issuer,
      expectedAudience: audience,
    });

    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.code).toBe('invalid_token');
  });

  it('rejects signature signed with a different key', async () => {
    const { privateKey } = generateEd25519KeyPair();
    const { publicKeyHex: otherPub } = generateEd25519KeyPair();
    const token = signEd25519Jwt(
      privateKey,
      { alg: 'EdDSA', typ: 'JWT' },
      validClaims(),
    );

    const result = await verifySessionToken(token, {
      publicKeyHex: otherPub,
      expectedIssuer: issuer,
      expectedAudience: audience,
    });

    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.code).toBe('invalid_token');
  });

  it('rejects malformed tokens', async () => {
    const { publicKeyHex } = generateEd25519KeyPair();
    for (const bad of ['', 'abc', 'only.twoparts', 'a.b.c.d', '...']) {
      const result = await verifySessionToken(bad, {
        publicKeyHex,
        expectedIssuer: issuer,
        expectedAudience: audience,
      });
      expect(result.ok).toBe(false);
    }
  });

  it('rejects token missing required claims', async () => {
    const { privateKey, publicKeyHex } = generateEd25519KeyPair();
    const now = Math.floor(Date.now() / 1000);
    const token = signEd25519Jwt(
      privateKey,
      { alg: 'EdDSA', typ: 'JWT' },
      {
        // roomId intentionally missing
        sub: 'u',
        name: 'n',
        role: 'member',
        sessionId: 's',
        iss: issuer,
        aud: audience,
        exp: now + 60,
        iat: now,
      },
    );

    const result = await verifySessionToken(token, {
      publicKeyHex,
      expectedIssuer: issuer,
      expectedAudience: audience,
    });

    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.code).toBe('invalid_token');
  });
});
