/**
 * Session Token (JWT-style, Ed25519 signed)
 *
 * Issued by Kumoriya API and validated by Party Realtime Service
 * for WebSocket authentication.
 */
export interface SessionToken {
  // Header
  alg: 'EdDSA';
  typ: 'JWT';

  // Claims
  sub: string; // userId
  name: string; // display name
  roomId: string; // room identifier
  role: 'host' | 'member';
  sessionId: string; // unique session identifier
  iss: string; // issuer (kumoriya-api)
  aud: 'watch-party';
  exp: number; // expiration timestamp (Unix epoch seconds)
  iat: number; // issued at timestamp
}
