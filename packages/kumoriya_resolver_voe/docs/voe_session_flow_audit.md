# VOE Session/Token Flow Audit (HTTP-only feasibility)

## Scope
- Target URL: `https://voe.sx/e/6gmwdvlyw8la` (JKAnime real case)
- Date: 2026-03-08
- Goal: verify if media resolution can be replicated from resolver HTTP flow without browser runtime.

## Observed request flow
1. `GET https://voe.sx/e/6gmwdvlyw8la`
   - returns JS redirect shell to `https://lancewhosedifficult.com/e/6gmwdvlyw8la`
2. `GET https://lancewhosedifficult.com/e/6gmwdvlyw8la`
   - includes `guestMode`, `api2/session/generate-token`, `session/sync`
   - includes placeholder `source` (`test-videos.co.uk/...Big_Buck_Bunny...`)
   - loads obfuscated loader script (`/js/loader.<hash>.js`)
3. runtime player flow (after click):
   - `POST https://lancewhosedifficult.com/engine/update`
   - response is a fixed-looking JSON key map (no media URL)
   - then browser requests real media:
     - `https://cdn-*.edgeon-bandwidth.com/engine/hls2-c/.../master.m3u8?...`

## Key evidence
- `engine/update` response body does not contain `.m3u8` or `.mp4`.
- replaying `POST /engine/update` with dummy body still returns key-map JSON.
- playable URL appears after obfuscated loader runtime executes and user-play flow starts.

## Feasibility result
- HTTP-only replication is **not currently feasible** in a clean resolver-only implementation without porting significant obfuscated JS runtime logic.
- Safe resolver behavior should classify this family as session/runtime-gated, not as parse-only failure.
