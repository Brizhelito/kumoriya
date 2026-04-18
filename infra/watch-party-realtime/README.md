# Party Realtime Service

Dedicated realtime service for watch party state management, built with Cloudflare Workers and Durable Objects.

## Overview

The Party Realtime Service provides server-authoritative state management for watch party rooms, including:

- Room creation and invite code management
- Member presence and heartbeat tracking
- Host authority and transfer logic
- Server-authoritative playback synchronization
- Chat messaging and reactions
- WebRTC signaling preparation (for future voice chat)

## Architecture

- **Worker Entry Point**: Routes HTTP and WebSocket requests
- **PartyRegistryDO**: Singleton Durable Object managing room creation and invite codes
- **PartyRoomDO**: Per-room Durable Object managing authoritative room state

## Prerequisites

- Node.js 18+ and npm
- Cloudflare account with Workers and Durable Objects enabled
- Wrangler CLI (`npm install -g wrangler`)

## Setup

### 1. Install Dependencies

```bash
cd infra/watch-party-realtime
npm install
```

### 2. Configure Environment Variables

Copy the example environment file:

```bash
cp .dev.vars.example .dev.vars
```

Edit `.dev.vars` and set the required values:

- `PARTY_INTERNAL_TOKEN`: Bearer token for Kumoriya API → Party Service authentication
- `PARTY_SESSION_PUBLIC_KEY_HEX`: Ed25519 public key as a 32-byte hex string (matches the public half of `JWT_PRIVATE_KEY_HEX` in kumoriya-api)

### 3. Authenticate with Cloudflare

```bash
wrangler login
```

## Development

### Run Local Development Server

```bash
npm run dev
```

This starts a local Wrangler dev server with hot reloading.

### Type Checking

```bash
npm run type-check
```

### Linting and Formatting

```bash
npm run lint
npm run format
```

### Testing

```bash
# Run tests once
npm test

# Run tests in watch mode
npm run test:watch
```

## Deployment

### Deploy to Production

```bash
npm run deploy
```

Or with Wrangler directly:

```bash
wrangler deploy
```

### Set Production Secrets

Secrets must be set separately from environment variables:

```bash
# Set internal authentication token
wrangler secret put PARTY_INTERNAL_TOKEN

# Set Ed25519 public key for Session Token validation (32-byte hex)
wrangler secret put PARTY_SESSION_PUBLIC_KEY_HEX
```

### Configure DNS

1. In Cloudflare dashboard, navigate to your domain
2. Add a DNS record for `party.kumoriya.online`:
   - Type: CNAME or A record
   - Name: `party`
   - Target: Your Worker route (configured automatically by Wrangler)
   - Proxy status: Proxied (orange cloud)

### Configure Routes

Once DNS is proxied, enable routes by uncommenting the `routes = [...]`
lines in `wrangler.toml` (both `[env.production]` and `[env.development]`
sections, if the dev env should be reachable under a subdomain). Then
run `wrangler deploy --env production`.

Public surface:

- `wss://party.kumoriya.online/ws?token={session_token}` — client WebSocket
- `https://party.kumoriya.online/health` — liveness probe

Internal surface (requires `Authorization: Bearer {PARTY_INTERNAL_TOKEN}`):

- `POST   /internal/v1/rooms`                     — create room
- `GET    /internal/v1/invite/:code`              — resolve invite code
- `POST   /internal/v1/rooms/:roomId/join`        — join
- `POST   /internal/v1/rooms/:roomId/leave`       — leave
- `POST   /internal/v1/rooms/:roomId/member-verify` — check membership

The internal surface is called only from kumoriya-api (never from the
Flutter app). If you run kumoriya-api outside Cloudflare, add a WAF rule
that drops `/internal/*` requests from IPs other than your API.

## API Endpoints

### Public Endpoints

- `GET /ws?token={Session_Token}` - WebSocket connection endpoint
- `GET /health` - Health check endpoint

### Internal Endpoints (Require `PARTY_INTERNAL_TOKEN`)

- `POST /internal/v1/rooms` - Create room
- `GET /internal/v1/invite/:code` - Resolve invite code
- `POST /internal/v1/rooms/:roomId/join` - Join room
- `POST /internal/v1/rooms/:roomId/leave` - Leave room
- `POST /internal/v1/rooms/:roomId/member-verify` - Verify member status

## Environment Variables

### Required Secrets (via `wrangler secret put`)

- `PARTY_INTERNAL_TOKEN`: Bearer token for internal API authentication
- `PARTY_SESSION_PUBLIC_KEY_HEX`: 32-byte hex Ed25519 public key for Session Token validation

### Configuration Variables (in `wrangler.toml`)

- `PARTY_SESSION_ISSUER`: Expected `iss` claim (default: `https://api.kumoriya.online`)
- `PARTY_WS_AUDIENCE`: Expected `aud` claim (default: `watch-party`)

These values must match the ones configured on kumoriya-api:
`JWT_ISSUER`/`BASE_URL` and the `PartyWSAudience` config flag.

## Project Structure

```
infra/watch-party-realtime/
├── src/
│   ├── index.ts              # Worker entry point
│   └── types/
│       └── env.ts            # Environment type definitions
├── wrangler.toml             # Cloudflare Workers configuration
├── tsconfig.json             # TypeScript configuration
├── package.json              # Node.js dependencies and scripts
├── .dev.vars.example         # Example environment variables
└── README.md                 # This file
```

## Monitoring and Observability

The service emits structured logs for:

- Room creation, join, leave, and destruction events
- WebSocket connection and disconnection events
- Host transfer events
- Rate limit violations
- Token validation failures

All logs include:
- `roomId`: Room identifier
- `userId`: User identifier
- `sessionId`: Session identifier
- `eventType`: Event or action type
- `roomVersion`: Room version number

## Security

- **Internal endpoints**: Protected by `PARTY_INTERNAL_TOKEN` Bearer authentication
- **WebSocket connections**: Validated using Ed25519-signed Session Tokens from Kumoriya API
- **Rate limiting**: Enforced per-user for chat, reactions, and playback intents
- **Token expiration**: Session Tokens expire after 60 minutes (configurable)

## Troubleshooting

### WebSocket Connection Fails

- Verify Session Token is valid and not expired
- Check that `PARTY_SESSION_PUBLIC_KEY` matches Kumoriya API's signing key
- Ensure DNS is properly configured for `party.kumoriya.online`

### Internal Endpoints Return 401

- Verify `PARTY_INTERNAL_TOKEN` is set correctly in both services
- Check that `Authorization: Bearer {token}` header is included in requests

### Durable Objects Not Working

- Ensure Durable Objects are enabled in your Cloudflare account
- Verify migrations are applied (check `wrangler.toml` migrations section)
- Check Cloudflare dashboard for Durable Object errors

## Related Documentation

- [Requirements Document](../../.kiro/specs/watch-party-realtime-migration/requirements.md)
- [Design Document](../../.kiro/specs/watch-party-realtime-migration/design.md)
- [Implementation Tasks](../../.kiro/specs/watch-party-realtime-migration/tasks.md)
- [Cloudflare Workers Documentation](https://developers.cloudflare.com/workers/)
- [Durable Objects Documentation](https://developers.cloudflare.com/workers/runtime-apis/durable-objects/)

## License

UNLICENSED - Internal Kumoriya project
