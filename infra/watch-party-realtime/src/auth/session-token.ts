/**
 * Session Token verification (Ed25519 JWT)
 *
 * Short-lived ticket issued by kumoriya-api and validated by the
 * Party Realtime Service before upgrading a WebSocket.
 *
 * Format: JWT compact serialization with alg=EdDSA.
 * Public key is provided as a hex-encoded 32-byte raw Ed25519 key
 * via `PARTY_SESSION_PUBLIC_KEY_HEX`.
 *
 * Expected claims (after audience/issuer check):
 *   sub       userId
 *   name      display name
 *   roomId    room identifier
 *   role      'host' | 'member'
 *   sessionId unique session identifier
 *   iss       issuer (must match PARTY_SESSION_ISSUER)
 *   aud       must equal PARTY_WS_AUDIENCE (default 'watch-party')
 *   exp       expiration (unix seconds)
 *   iat       issued-at (unix seconds)
 */

export interface SessionClaims {
  sub: string;
  name: string;
  roomId: string;
  role: 'host' | 'member';
  sessionId: string;
  iss: string;
  /**
   * RFC 7519 allows `aud` to be either a single StringOrURI or an array.
   * jwt-go (v5) serializes single-element audiences as an array by default,
   * so callers MUST treat both forms as equivalent.
   */
  aud: string | string[];
  exp: number;
  iat: number;
}

export type SessionVerifyError =
  | { ok: false; code: 'invalid_token'; reason: string }
  | { ok: false; code: 'expired_token'; reason: string };

export type SessionVerifyResult =
  | { ok: true; claims: SessionClaims }
  | SessionVerifyError;

function base64UrlDecode(input: string): Uint8Array {
  const padded = input
    .replace(/-/g, '+')
    .replace(/_/g, '/')
    .padEnd(input.length + ((4 - (input.length % 4)) % 4), '=');
  const bin = atob(padded);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

function bytesToString(bytes: Uint8Array): string {
  return new TextDecoder().decode(bytes);
}

function hexToBytes(hex: string): Uint8Array {
  const clean = hex.trim().toLowerCase();
  if (clean.length % 2 !== 0 || !/^[0-9a-f]+$/.test(clean)) {
    throw new Error('invalid hex');
  }
  const out = new Uint8Array(clean.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(clean.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

/**
 * Import an Ed25519 public key provided as raw 32-byte hex.
 * The result is cached via a WeakMap-less module map keyed by hex string.
 */
const keyCache = new Map<string, Promise<CryptoKey>>();

function importPublicKey(publicKeyHex: string): Promise<CryptoKey> {
  const cached = keyCache.get(publicKeyHex);
  if (cached) return cached;
  const bytes = hexToBytes(publicKeyHex);
  if (bytes.length !== 32) {
    throw new Error(`invalid ed25519 public key length: ${bytes.length}`);
  }
  const promise = crypto.subtle.importKey(
    'raw',
    bytes,
    // Workers types don't yet expose Ed25519 as a known Algorithm; cast is safe.
    { name: 'Ed25519' } as unknown as { name: string },
    false,
    ['verify'],
  );
  keyCache.set(publicKeyHex, promise);
  return promise;
}

export interface VerifyOptions {
  publicKeyHex: string;
  expectedIssuer: string;
  expectedAudience: string;
  clockToleranceSec?: number;
  nowSec?: number;
}

/**
 * Parse and verify a session token.
 *
 * Returns `{ ok: true, claims }` on success, or a structured error that
 * can be mapped to `invalid_token` / `expired_token` codes.
 */
export async function verifySessionToken(
  token: string,
  opts: VerifyOptions,
): Promise<SessionVerifyResult> {
  if (typeof token !== 'string' || token.length === 0) {
    return { ok: false, code: 'invalid_token', reason: 'missing token' };
  }

  const parts = token.split('.');
  if (parts.length !== 3) {
    return { ok: false, code: 'invalid_token', reason: 'malformed token' };
  }
  const [headerB64, payloadB64, sigB64] = parts;

  let header: { alg?: string; typ?: string };
  let claims: Partial<SessionClaims> & Record<string, unknown>;
  try {
    header = JSON.parse(bytesToString(base64UrlDecode(headerB64)));
    claims = JSON.parse(bytesToString(base64UrlDecode(payloadB64)));
  } catch {
    return { ok: false, code: 'invalid_token', reason: 'malformed json' };
  }

  if (header.alg !== 'EdDSA') {
    return { ok: false, code: 'invalid_token', reason: 'unexpected alg' };
  }

  if (typeof claims.exp !== 'number') {
    return { ok: false, code: 'invalid_token', reason: 'missing exp' };
  }
  const nowSec = opts.nowSec ?? Math.floor(Date.now() / 1000);
  const tolerance = opts.clockToleranceSec ?? 30;
  if (claims.exp + tolerance < nowSec) {
    return { ok: false, code: 'expired_token', reason: 'token expired' };
  }

  if (claims.iss !== opts.expectedIssuer) {
    return { ok: false, code: 'invalid_token', reason: 'issuer mismatch' };
  }
  // `aud` may be a string or string[] per RFC 7519 §4.1.3. jwt-go v5 emits
  // single-element audiences as arrays, so accept both forms.
  const audMatches = Array.isArray(claims.aud)
    ? claims.aud.includes(opts.expectedAudience)
    : claims.aud === opts.expectedAudience;
  if (!audMatches) {
    return { ok: false, code: 'invalid_token', reason: 'audience mismatch' };
  }
  if (
    typeof claims.sub !== 'string' ||
    typeof claims.roomId !== 'string' ||
    typeof claims.sessionId !== 'string' ||
    typeof claims.name !== 'string' ||
    (claims.role !== 'host' && claims.role !== 'member')
  ) {
    return { ok: false, code: 'invalid_token', reason: 'missing required claims' };
  }

  let key: CryptoKey;
  try {
    key = await importPublicKey(opts.publicKeyHex);
  } catch {
    return { ok: false, code: 'invalid_token', reason: 'invalid signing key' };
  }

  let signature: Uint8Array;
  try {
    signature = base64UrlDecode(sigB64);
  } catch {
    return { ok: false, code: 'invalid_token', reason: 'malformed signature' };
  }

  const signingInput = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const verified = await crypto.subtle.verify(
    { name: 'Ed25519' } as unknown as { name: string },
    key,
    signature,
    signingInput,
  );
  if (!verified) {
    return { ok: false, code: 'invalid_token', reason: 'signature verification failed' };
  }

  return { ok: true, claims: claims as SessionClaims };
}

/** Test-only helpers exported for unit tests. */
export const __test = { base64UrlDecode, hexToBytes };
