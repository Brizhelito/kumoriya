# Watch Party Realtime — Rollout Runbook

This document tracks the moving parts that must be deployed **together** to
enable the brokered realtime flow (`WATCH_PARTY_REALTIME_V2`).

## 1. Cloudflare Worker (`infra/watch-party-realtime`)

1. Authenticate Wrangler once:
   ```bash
   wrangler login
   ```
2. Ensure DNS: add a **proxied** `CNAME party → kumoriya.online` (or whatever
   zone you own) in Cloudflare.
3. Set secrets (per environment):
   ```bash
   wrangler secret put PARTY_INTERNAL_TOKEN        # shared with kumoriya-api
   wrangler secret put PARTY_SESSION_PUBLIC_KEY_HEX # 32-byte hex pub key
   ```
   The public key must be the hex-encoded 32 bytes corresponding to the
   Ed25519 private key kumoriya-api signs access tokens with
   (`JWT_PRIVATE_KEY_HEX`). They must come from the same keypair or token
   verification fails with `signature verification failed`.
4. Once DNS is propagated, uncomment the `routes = [...]` entries in
   `wrangler.toml` and redeploy:
   ```bash
   wrangler deploy --env production
   ```
5. Verify:
   ```bash
   curl https://party.kumoriya.online/health
   # {"status":"ok","service":"watch-party-realtime"}
   ```

## 2. kumoriya-api

The API gates the new behaviour behind `WATCH_PARTY_REALTIME_V2`. When set to
any non-empty value the REST handlers call the Worker instead of the
in-memory `PartyService`.

Required env:

| Variable                        | Example                                |
| ------------------------------- | -------------------------------------- |
| `WATCH_PARTY_REALTIME_V2`       | `true`                                 |
| `PARTY_INTERNAL_TOKEN`          | same secret as the Worker              |
| `PARTY_REALTIME_BASE_URL`       | `https://party.kumoriya.online`        |
| `PARTY_REALTIME_WS_BASE_URL`    | `wss://party.kumoriya.online`          |
| `PARTY_WS_AUDIENCE`             | `watch-party` (default)                |
| `JWT_ISSUER` / `BASE_URL`       | must match `PARTY_SESSION_ISSUER`      |

The issuer in the session token (`iss`) is `JWT_ISSUER` falling back to
`BASE_URL`; keep it in sync with the Worker's `PARTY_SESSION_ISSUER`
(`wrangler.toml [vars]`).

Restart the API and hit:

```bash
curl -H "Authorization: Bearer $TOKEN" \
     -H 'Content-Type: application/json' \
     -d '{"anilistId":1,"animeTitle":"t","episodeNumber":1}' \
     https://api.kumoriya.online/api/v1/party
```

The response now carries a `realtimeSession` object; the legacy shape
remains available by turning the flag off.

## 3. Flutter app

The client picks up the realtime session via the new fields on
`/api/v1/party` and `/api/v1/party/join`. Opt-in build-time flag:

```
flutter build apk --dart-define=WATCH_PARTY_REALTIME_V2=true
```

When the flag is off the client continues to use the legacy P2P path
(`WebRtcPeerManager` + `PartySyncEngine`). When the flag is on, the client
opens a WebSocket against `realtimeSession.websocketUrl` and applies server
events through `reducePartyRealtimeEvent`.

## 4. Rollback

- `WATCH_PARTY_REALTIME_V2=` (empty) on the API **and** the Flutter build
  immediately reverts to the legacy flow. No redeploy of the Worker is
  required; it will simply idle.
- For the Worker, `wrangler rollback` to the previous version is the fastest
  path when a regression lands.

## 5. Smoke checklist after rollout

- Create room from client A → invite code appears, WS connects,
  `room_snapshot` arrives.
- Client B joins via invite → A receives `member_joined`.
- Both `set_ready` → `member_ready_changed` echoes back.
- A disconnects (airplane mode) → B sees `member_presence_changed`
  within ~30 s; grace period applies.
- A reconnects within grace → state restored without resetting ready.
- Host leaves → `host_transferred` is broadcast to B.
- Close last member → room cleans up after the empty-room timer.

## 6. Voice Chat (PTT)

1. **Worker Routing**: Handles the `webrtc_signal` relay to route ICE/SDP messages, and broadcasts `voice_state_changed` whenever a member starts or stops speaking (PTT toggle).
2. **Android Runtime Permission**: The client asks for `RECORD_AUDIO` permission when initializing the voice session. It requires both `RECORD_AUDIO` and `MODIFY_AUDIO_SETTINGS` to be present in `AndroidManifest.xml`.
3. **PTT Button**: In both the Lobby and the Player overlay. Desktop clients can hold the `V` key to speak, while mobile clients long-press the PTT button. The button becomes translucent after 4 seconds of inactivity.
4. **Validation Checklist**:
   - Verify that microphone permission is requested successfully.
   - Test peer connection establishing automatically when members join a room.
   - Verify that the speaking mic indicator 🎤 appears on avatars in the lobby and next to names in the player overlay when speaking.
