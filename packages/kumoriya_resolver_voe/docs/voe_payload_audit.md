# VOE Payload Audit (2026-03-08)

## Sample analyzed
- URL: `https://voe.sx/e/6gmwdvlyw8la`
- Redirect observed: `voe.sx` -> `lancewhosedifficult.com`

## Observed runtime structure
1. Initial page is a JavaScript redirect page (`window.location.href`).
2. Landing page contains JW Player bootstrap but no direct `.m3u8`/`.mp4` source list.
3. Script content includes guest-mode token flow:
   - `https://voe.sx/api2/session/generate-token`
   - `https://voe.sx/session/sync?...`
4. Exposed `source` variable in this flow points to placeholder media:
   - `https://test-videos.co.uk/...Big_Buck_Bunny...mp4`

## Resolver implications
- Redirect handling is mandatory.
- Payloads may be token-gated and can expose stream hints without playable media URLs.
- Placeholder links must be rejected.
- Parser should support additional shapes (`url`, embedded/encoded URL strings) without inventing streams.
