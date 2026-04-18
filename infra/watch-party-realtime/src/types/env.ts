/**
 * Environment bindings for the Party Realtime Service Worker
 */
export interface Env {
  // Durable Object bindings
  PARTY_REGISTRY: DurableObjectNamespace;
  PARTY_ROOM: DurableObjectNamespace;

  // Secrets (set via `wrangler secret put`)
  /** Shared bearer token for kumoriya-api -> Worker internal endpoints. */
  PARTY_INTERNAL_TOKEN: string;
  /** Hex-encoded 32-byte raw Ed25519 public key used to verify session tokens. */
  PARTY_SESSION_PUBLIC_KEY_HEX: string;

  // Environment variables (set in wrangler.toml [vars])
  /** Expected `iss` claim of incoming session tokens. */
  PARTY_SESSION_ISSUER: string;
  /** Expected `aud` claim of incoming session tokens. */
  PARTY_WS_AUDIENCE: string;
}
