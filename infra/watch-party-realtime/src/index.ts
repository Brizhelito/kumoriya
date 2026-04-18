/**
 * Party Realtime Service - Worker Entry Point
 *
 * Routes:
 * - Public:
 *     GET /health                                              plain health probe
 *     GET /ws?token={session_token}                            WebSocket upgrade
 * - Internal (require `Authorization: Bearer PARTY_INTERNAL_TOKEN`):
 *     POST /internal/v1/rooms                                  create room
 *     GET  /internal/v1/invite/:code                           resolve invite code
 *     POST /internal/v1/rooms/:roomId/join                     add member
 *     POST /internal/v1/rooms/:roomId/leave                    remove member
 *     POST /internal/v1/rooms/:roomId/member-verify            verify membership
 *     POST /internal/v1/users/:userId/force-leave              recovery: force user out of their current room
 *
 * Auth:
 * - Internal endpoints: `PARTY_INTERNAL_TOKEN` shared bearer.
 * - WebSocket: Ed25519 session token signed by kumoriya-api with:
 *     iss = PARTY_SESSION_ISSUER, aud = PARTY_WS_AUDIENCE,
 *     roomId/sub/name/role/sessionId claims.
 */

import { Env } from './types/env';
import { PartyRegistryDO as RegistryImpl } from './durable-objects/PartyRegistryDO';
import { PartyRoomDO as RoomImpl } from './durable-objects/PartyRoomDO';
import { verifySessionToken } from './auth/session-token';

export { RegistryImpl as PartyRegistryDO, RoomImpl as PartyRoomDO };

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    try {
      if (path === '/health') {
        return new Response(
          JSON.stringify({
            status: 'ok',
            service: 'watch-party-realtime',
            timestamp: Date.now(),
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        );
      }

      if (path === '/ws' && request.headers.get('Upgrade') === 'websocket') {
        return handleWebSocketUpgrade(request, env, ctx);
      }

      if (path.startsWith('/internal/v1/')) {
        return handleInternalEndpoint(request, env);
      }

      return new Response('Not Found', { status: 404 });
    } catch (error) {
      console.error('worker_error', { error: String(error) });
      return new Response('Internal Server Error', { status: 500 });
    }
  },
};

/** Validate the session token and upgrade the WebSocket against the target PartyRoomDO. */
async function handleWebSocketUpgrade(
  request: Request,
  env: Env,
  _ctx: ExecutionContext,
): Promise<Response> {
  const url = new URL(request.url);
  const token = url.searchParams.get('token');
  if (!token) {
    // WebSocket upgrades must return a 101; if auth fails, we close on the server side
    // using a 4xxx code so browsers see `onclose` with a useful reason.
    return new Response('Missing token', { status: 401 });
  }

  const verify = await verifySessionToken(token, {
    publicKeyHex: env.PARTY_SESSION_PUBLIC_KEY_HEX,
    expectedIssuer: env.PARTY_SESSION_ISSUER,
    expectedAudience: env.PARTY_WS_AUDIENCE,
  });

  if (!verify.ok) {
    const status = verify.code === 'expired_token' ? 401 : 401;
    return new Response(verify.reason, {
      status,
      headers: { 'X-Party-Error-Code': verify.code },
    });
  }

  const { claims } = verify;

  // Route to the PartyRoomDO for the claim's room, attaching identity metadata.
  const roomDOId = env.PARTY_ROOM.idFromName(claims.roomId);
  const roomDOStub = env.PARTY_ROOM.get(roomDOId);

  const forwardUrl = new URL('http://room/ws');
  forwardUrl.searchParams.set('userId', claims.sub);
  forwardUrl.searchParams.set('name', claims.name);
  forwardUrl.searchParams.set('sessionId', claims.sessionId);
  forwardUrl.searchParams.set('role', claims.role);
  forwardUrl.searchParams.set('roomId', claims.roomId);

  // Forward the upgrade request so the DO can accept the WebSocket.
  return roomDOStub.fetch(
    new Request(forwardUrl.toString(), {
      method: request.method,
      headers: request.headers,
    }),
  );
}

function getRegistryStub(env: Env): DurableObjectStub {
  const id = env.PARTY_REGISTRY.idFromName('global-registry');
  return env.PARTY_REGISTRY.get(id);
}

async function handleInternalEndpoint(request: Request, env: Env): Promise<Response> {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return new Response('Unauthorized', { status: 401 });
  }
  const token = authHeader.slice('Bearer '.length);
  if (token !== env.PARTY_INTERNAL_TOKEN) {
    return new Response('Unauthorized', { status: 401 });
  }

  const url = new URL(request.url);
  const registryPath = url.pathname.replace(/^\/internal\/v1/, '');

  const stub = getRegistryStub(env);

  // POST /rooms
  if (registryPath === '/rooms' && request.method === 'POST') {
    return stub.fetch(new Request('http://registry/rooms', request));
  }

  // GET /invite/:code
  if (registryPath.startsWith('/invite/') && request.method === 'GET') {
    return stub.fetch(new Request(`http://registry${registryPath}`, request));
  }

  // POST /rooms/:roomId/join|leave|member-verify
  if (
    request.method === 'POST' &&
    (registryPath.match(/^\/rooms\/[^/]+\/(join|leave|member-verify)$/) !== null)
  ) {
    return stub.fetch(new Request(`http://registry${registryPath}`, request));
  }

  // POST /users/:userId/force-leave
  if (
    request.method === 'POST' &&
    registryPath.match(/^\/users\/[^/]+\/force-leave$/) !== null
  ) {
    return stub.fetch(new Request(`http://registry${registryPath}`, request));
  }

  return new Response('Not Found', { status: 404 });
}
