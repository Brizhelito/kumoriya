/**
 * PartyRegistryDO - Singleton Durable Object
 *
 * Manages:
 * - Room creation and registration
 * - Invite code resolution
 * - User-to-room mapping
 * - Cleanup when rooms are destroyed
 *
 * Storage Schema:
 * - rooms: Map<roomId, RoomMetadata>
 * - inviteCodes: Map<inviteCode, roomId>
 * - userRooms: Map<userId, roomId>
 */

import { Env } from '../types/env';
import { ErrorCode } from '../types/errors';

/**
 * Room metadata stored in PartyRegistryDO
 */
interface RoomMetadata {
  roomId: string;
  inviteCode: string;
  creatorId: string;
  createdAt: number;
}

/**
 * Request/Response types for internal endpoints
 */
interface CreateRoomRequest {
  userId: string;
  name: string;
  media: {
    anilistId: number;
    animeTitle: string;
    episodeNumber: number;
  };
}

interface CreateRoomResponse {
  roomId: string;
  inviteCode: string;
}

interface ResolveInviteCodeResponse {
  roomId: string;
}

interface JoinRoomRequest {
  userId: string;
  name: string;
}

interface JoinRoomResponse {
  success: boolean;
}

interface LeaveRoomRequest {
  userId: string;
}

interface LeaveRoomResponse {
  success: boolean;
}

interface MemberVerifyRequest {
  userId: string;
}

interface MemberVerifyResponse {
  isMember: boolean;
}

/**
 * PartyRegistryDO implementation
 */
export class PartyRegistryDO {
  private state: DurableObjectState;
  private env: Env;

  constructor(state: DurableObjectState, env: Env) {
    this.state = state;
    this.env = env;
  }

  /**
   * Fetch handler for internal HTTP endpoints
   */
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    try {
      // POST /rooms - Create room
      if (path === '/rooms' && request.method === 'POST') {
        return await this.handleCreateRoom(request);
      }

      // GET /invite/:code - Resolve invite code
      if (path.startsWith('/invite/') && request.method === 'GET') {
        const code = path.substring('/invite/'.length);
        return await this.handleResolveInviteCode(code);
      }

      // POST /rooms/:roomId/join - Join room
      const joinMatch = path.match(/^\/rooms\/([^/]+)\/join$/);
      if (joinMatch && request.method === 'POST') {
        const roomId = joinMatch[1];
        return await this.handleJoinRoom(roomId, request);
      }

      // POST /rooms/:roomId/leave - Leave room
      const leaveMatch = path.match(/^\/rooms\/([^/]+)\/leave$/);
      if (leaveMatch && request.method === 'POST') {
        const roomId = leaveMatch[1];
        return await this.handleLeaveRoom(roomId, request);
      }

      // POST /rooms/:roomId/member-verify - Verify member status
      const verifyMatch = path.match(/^\/rooms\/([^/]+)\/member-verify$/);
      if (verifyMatch && request.method === 'POST') {
        const roomId = verifyMatch[1];
        return await this.handleMemberVerify(roomId, request);
      }

      // POST /rooms/:roomId/cleanup - Cleanup room (called by PartyRoomDO)
      const cleanupMatch = path.match(/^\/rooms\/([^/]+)\/cleanup$/);
      if (cleanupMatch && request.method === 'POST') {
        const roomId = cleanupMatch[1];
        await this.cleanupRoom(roomId);
        return new Response(JSON.stringify({ success: true }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      // POST /users/:userId/force-leave - Recovery: force the user out of
      // whatever room they are registered in. Used when the client lost its
      // session (app crash, cleared storage) and cannot call the normal
      // leave flow because it no longer knows the roomId.
      const forceLeaveMatch = path.match(/^\/users\/([^/]+)\/force-leave$/);
      if (forceLeaveMatch && request.method === 'POST') {
        const userId = forceLeaveMatch[1];
        return await this.handleForceLeave(userId);
      }

      return new Response('Not Found', { status: 404 });
    } catch (error) {
      console.error('PartyRegistryDO error:', error);
      return new Response(
        JSON.stringify({
          code: 'server_error',
          message: 'Internal server error',
          retryable: true,
        }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }
  }

  /**
   * Probe whether `userId` is still a live member of `roomId` from the
   * PartyRoomDO's perspective (active WS connection or within grace
   * period). Returns true when the user is alive, false when the
   * registration is orphan and safe to drop.
   *
   * A failure to reach the room DO is treated as "alive" to stay on the
   * safe side — we do not want a transient issue to evict a valid
   * session. Orphan cleanup only happens on explicit 403/404 responses
   * from the room DO.
   */
  private async isUserAliveInRoom(
    userId: string,
    roomId: string,
  ): Promise<boolean> {
    try {
      const roomDOId = this.env.PARTY_ROOM.idFromName(roomId);
      const roomDOStub = this.env.PARTY_ROOM.get(roomDOId);
      const response = await roomDOStub.fetch(
        'http://internal/member-verify',
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ userId }),
        },
      );
      if (response.status === 200) return true;
      if (response.status === 403 || response.status === 404) return false;
      // Anything else — assume alive, avoid false evictions.
      return true;
    } catch (error) {
      console.warn('isUserAliveInRoom: probe failed, assuming alive', {
        userId,
        roomId,
        error: String(error),
      });
      return true;
    }
  }

  /**
   * Drop an orphan `userRoom:*` mapping whose target room has no record
   * of the user. Logs the event so we can track how often the self-heal
   * path fires — frequent occurrences suggest a client-side leak to fix.
   */
  private async cleanupOrphanUserRoom(
    userId: string,
    roomId: string,
  ): Promise<void> {
    console.warn('cleanupOrphanUserRoom: dropping stale registration', {
      userId,
      roomId,
    });
    await this.state.storage.delete(`userRoom:${userId}`);
  }

  /**
   * Handle room creation
   * Generates unique roomId and inviteCode, instantiates PartyRoomDO
   */
  private async handleCreateRoom(request: Request): Promise<Response> {
    const body = (await request.json()) as CreateRoomRequest;
    const { userId, name, media } = body;

    // Check if user is already in a room.
    //
    // If we find an existing `userRoom:*` mapping, probe the target room
    // first: if the user is no longer a live member there (app crash,
    // lost WS, expired grace), silently clear the orphan mapping and
    // continue. Only genuinely-alive sessions return 409.
    const existingRoomId = await this.state.storage.get<string>(`userRoom:${userId}`);
    if (existingRoomId) {
      const alive = await this.isUserAliveInRoom(userId, existingRoomId);
      if (alive) {
        return new Response(
          JSON.stringify({
            code: ErrorCode.USER_ALREADY_IN_ROOM,
            message: 'User is already in another room',
            retryable: false,
          }),
          {
            status: 409,
            headers: { 'Content-Type': 'application/json' },
          }
        );
      }
      await this.cleanupOrphanUserRoom(userId, existingRoomId);
    }

    // Generate unique roomId (UUID v4)
    const roomId = crypto.randomUUID();

    // Generate unique inviteCode (6-char alphanumeric)
    const inviteCode = await this.generateUniqueInviteCode();

    // Store room metadata
    const roomMetadata: RoomMetadata = {
      roomId,
      inviteCode,
      creatorId: userId,
      createdAt: Date.now(),
    };

    await this.state.storage.put(`room:${roomId}`, roomMetadata);
    await this.state.storage.put(`inviteCode:${inviteCode}`, roomId);
    await this.state.storage.put(`userRoom:${userId}`, roomId);

    // Instantiate PartyRoomDO and initialize room state
    const roomDOId = this.env.PARTY_ROOM.idFromName(roomId);
    const roomDOStub = this.env.PARTY_ROOM.get(roomDOId);

    // Call PartyRoomDO to initialize room with creator as first member and host
    const initResponse = await roomDOStub.fetch('http://internal/init', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        roomId,
        inviteCode,
        creatorId: userId,
        creatorName: name,
        media,
      }),
    });

    if (!initResponse.ok) {
      // Rollback registry state if room initialization fails
      await this.state.storage.delete(`room:${roomId}`);
      await this.state.storage.delete(`inviteCode:${inviteCode}`);
      await this.state.storage.delete(`userRoom:${userId}`);

      return new Response(
        JSON.stringify({
          code: 'room_init_failed',
          message: 'Failed to initialize room',
          retryable: true,
        }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    const response: CreateRoomResponse = {
      roomId,
      inviteCode,
    };

    return new Response(JSON.stringify(response), {
      status: 201,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  /**
   * Handle invite code resolution
   */
  private async handleResolveInviteCode(code: string): Promise<Response> {
    const roomId = await this.state.storage.get<string>(`inviteCode:${code}`);

    if (!roomId) {
      return new Response(
        JSON.stringify({
          code: ErrorCode.INVALID_INVITE_CODE,
          message: 'Invite code does not exist',
          retryable: false,
        }),
        {
          status: 404,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    const response: ResolveInviteCodeResponse = {
      roomId,
    };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  /**
   * Handle room join
   */
  private async handleJoinRoom(roomId: string, request: Request): Promise<Response> {
    const body = (await request.json()) as JoinRoomRequest;
    const { userId, name } = body;

    // Check if user is already in a room.
    //
    // As with `handleCreateRoom`, we probe the target of a stale mapping
    // and self-heal orphan entries. Rejoining the SAME room short-circuits
    // the probe because the happy path (page refresh, reconnect) should
    // never pay a round-trip.
    const existingRoomId = await this.state.storage.get<string>(`userRoom:${userId}`);
    if (existingRoomId && existingRoomId !== roomId) {
      const alive = await this.isUserAliveInRoom(userId, existingRoomId);
      if (alive) {
        return new Response(
          JSON.stringify({
            code: ErrorCode.USER_ALREADY_IN_ROOM,
            message: 'User is already in another room',
            retryable: false,
          }),
          {
            status: 409,
            headers: { 'Content-Type': 'application/json' },
          }
        );
      }
      await this.cleanupOrphanUserRoom(userId, existingRoomId);
    }

    // Verify room exists
    const roomMetadata = await this.state.storage.get<RoomMetadata>(`room:${roomId}`);
    if (!roomMetadata) {
      return new Response(
        JSON.stringify({
          code: ErrorCode.ROOM_NOT_FOUND,
          message: 'Room does not exist',
          retryable: false,
        }),
        {
          status: 404,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Forward join request to PartyRoomDO
    const roomDOId = this.env.PARTY_ROOM.idFromName(roomId);
    const roomDOStub = this.env.PARTY_ROOM.get(roomDOId);

    const joinResponse = await roomDOStub.fetch('http://internal/join', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId,
        name,
      }),
    });

    if (!joinResponse.ok) {
      // Forward error from PartyRoomDO
      const errorBody = await joinResponse.json();
      return new Response(JSON.stringify(errorBody), {
        status: joinResponse.status,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Map user to room
    await this.state.storage.put(`userRoom:${userId}`, roomId);

    const response: JoinRoomResponse = {
      success: true,
    };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  /**
   * Handle room leave
   */
  private async handleLeaveRoom(roomId: string, request: Request): Promise<Response> {
    const body = (await request.json()) as LeaveRoomRequest;
    const { userId } = body;

    // Verify user is in this room
    const userRoomId = await this.state.storage.get<string>(`userRoom:${userId}`);
    if (userRoomId !== roomId) {
      return new Response(
        JSON.stringify({
          code: 'not_in_room',
          message: 'User is not in this room',
          retryable: false,
        }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Forward leave request to PartyRoomDO
    const roomDOId = this.env.PARTY_ROOM.idFromName(roomId);
    const roomDOStub = this.env.PARTY_ROOM.get(roomDOId);

    const leaveResponse = await roomDOStub.fetch('http://internal/leave', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId,
      }),
    });

    if (!leaveResponse.ok) {
      // Forward error from PartyRoomDO
      const errorBody = await leaveResponse.json();
      return new Response(JSON.stringify(errorBody), {
        status: leaveResponse.status,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Remove user-to-room mapping
    await this.state.storage.delete(`userRoom:${userId}`);

    const response: LeaveRoomResponse = {
      success: true,
    };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  /**
   * Handle member verification
   * Verifies user is still an active member (or within reconnect grace) of the room
   */
  private async handleMemberVerify(roomId: string, request: Request): Promise<Response> {
    const body = (await request.json()) as MemberVerifyRequest;
    const { userId } = body;

    // Verify room exists
    const roomMetadata = await this.state.storage.get<RoomMetadata>(`room:${roomId}`);
    if (!roomMetadata) {
      return new Response(
        JSON.stringify({
          code: ErrorCode.ROOM_NOT_FOUND,
          message: 'Room does not exist',
          retryable: false,
        }),
        {
          status: 404,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Forward verify request to PartyRoomDO
    const roomDOId = this.env.PARTY_ROOM.idFromName(roomId);
    const roomDOStub = this.env.PARTY_ROOM.get(roomDOId);

    const verifyResponse = await roomDOStub.fetch('http://internal/member-verify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ userId }),
    });

    if (!verifyResponse.ok) {
      const errorBody = await verifyResponse.json();
      return new Response(JSON.stringify(errorBody), {
        status: verifyResponse.status,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const response: MemberVerifyResponse = {
      isMember: true,
    };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  /**
   * Handle force-leave by userId (recovery path).
   *
   * Idempotent: returns success even if the user has no room registered,
   * so the API can always call this as a safety net before create/join.
   * When a room is found, it forwards a leave to the PartyRoomDO, then
   * removes the user→room mapping from the registry regardless of whether
   * the room leave succeeded (the room may already be gone).
   */
  private async handleForceLeave(userId: string): Promise<Response> {
    const roomId = await this.state.storage.get<string>(`userRoom:${userId}`);
    if (!roomId) {
      return new Response(JSON.stringify({ success: true, roomId: null }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    try {
      const roomDOId = this.env.PARTY_ROOM.idFromName(roomId);
      const roomDOStub = this.env.PARTY_ROOM.get(roomDOId);
      await roomDOStub.fetch('http://internal/leave', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId }),
      });
    } catch (error) {
      console.warn('force-leave: room leave failed, clearing registry anyway', {
        userId,
        roomId,
        error: String(error),
      });
    }

    await this.state.storage.delete(`userRoom:${userId}`);

    return new Response(JSON.stringify({ success: true, roomId }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  /**
   * Generate a unique 6-character alphanumeric invite code
   */
  private async generateUniqueInviteCode(): Promise<string> {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    const maxAttempts = 10;

    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      let code = '';
      for (let i = 0; i < 6; i++) {
        const randomIndex = Math.floor(Math.random() * chars.length);
        code += chars[randomIndex];
      }

      // Check if code already exists
      const existingRoomId = await this.state.storage.get<string>(`inviteCode:${code}`);
      if (!existingRoomId) {
        return code;
      }
    }

    // Fallback: use crypto.randomUUID and take first 6 chars (very unlikely to reach here)
    return crypto.randomUUID().substring(0, 6).toUpperCase().replace(/[^A-Z0-9]/g, 'X');
  }

  /**
   * Cleanup room when destroyed
   * Called by PartyRoomDO when room is destroyed
   */
  async cleanupRoom(roomId: string): Promise<void> {
    const roomMetadata = await this.state.storage.get<RoomMetadata>(`room:${roomId}`);
    if (!roomMetadata) {
      return;
    }

    // Remove room metadata
    await this.state.storage.delete(`room:${roomId}`);

    // Remove invite code mapping
    await this.state.storage.delete(`inviteCode:${roomMetadata.inviteCode}`);

    // Remove all user-to-room mappings for this room
    // Note: This requires iterating through all userRoom entries
    // In a production system, we might maintain a reverse index
    const allKeys = await this.state.storage.list<string>({ prefix: 'userRoom:' });
    for (const [key, value] of allKeys) {
      if (value === roomId) {
        await this.state.storage.delete(key);
      }
    }
  }
}
