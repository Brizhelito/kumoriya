# Download Pipeline Playground Audit - 2026-04-03

## Scope Executed

Executed end-to-end `download_playground.dart` runs for these titles on episode 1 across all enabled sources and resolvers:

- Naruto
- Shingeki no Kyojin / Attack on Titan
- Jujutsu Kaisen
- One Punch Man

Input reports used:

- `tools/resolver_cli/reports/naruto.json`
- `tools/resolver_cli/reports/attack_on_titan.json`
- `tools/resolver_cli/reports/jujutsu_kaisen.json`
- `tools/resolver_cli/dl_one_punch_man.json`

This is a broad pipeline audit, not a literal full-catalog or all-episodes sweep. A true all-episodes run across long series like Naruto would require a long-running batch job and would produce very large output.

## Aggregate Results

- Total server links discovered: 159
- Resolved successfully: 85
- Resolver failures: 30
- Unsupported hosts: 44
- Probe successes: 63
- Probe failures after resolve: 22

Observed matching verdicts:

- `autoMatch`: 9
- `reviewNeeded`: 2
- `fallback`: 1

## Selection / Matching Findings

1. Matching integration fixed the previous hard failure mode where the playground was taking `matches.first`.
2. Naruto now resolves correctly on AnimeFlv as `Naruto` instead of drifting to other franchise entries.
3. Shingeki no Kyojin still shows a weak case on AnimeNexus: `fallback` with score `28.1`. The selected title is correct, but the resolver confidence is low because the canonical query and source title diverge (`Shingeki no Kyojin` vs `Attack on Titan`) and no strong alias was injected into that run.
4. Jujutsu Kaisen on JKAnime and AnimeFlv lands in `reviewNeeded` instead of `autoMatch`. This is acceptable for the playground, but it indicates the current thresholds are conservative when only the base TV title variant is present.
5. AnimeNexus episode inventory for Naruto is only `50`, while the other sources expose `220`. That is not a matcher problem; it is a source catalog coverage issue.

## Most Frequent Pipeline Problems

### 1. Unsupported hosts

Repeated unsupported hosts across runs:

- `mega.nz` (4 runs)
- `mediafire.com` (4 runs)
- `embedsito.com` (4 runs)
- `my.mail.ru` (3 runs)
- `terabox.com` (2 runs)
- `ryderjet.com` (1 run)

Impact:

- Large share of links are dead-on-arrival because no resolver exists.
- This alone accounts for `44` failures.

Probable fixes:

- Add resolver plugins for `mega.nz`, `mediafire.com`, `my.mail.ru` / `ok video mail`, `terabox.com`.
- Audit whether `embedsito.com` and `ryderjet.com` are aliases/fronts for already supported hosts. If yes, extend host allowlists instead of building new resolvers.
- If some of these hosts are intentionally unsupported, filter them out earlier in source plugins to avoid polluting server lists.

### 2. Mp4Upload TLS failure

Frequency:

- `11` occurrences

Observed error:

- `CERTIFICATE_VERIFY_FAILED`

Impact:

- Resolver extracts a candidate URL, but probe/download fails at transport time.

Probable fixes:

- Reproduce with a custom `HttpClient` and inspect certificate chain.
- If the CDN chain is consistently broken, use a narrowly-scoped certificate bypass only for the exact Mp4Upload CDN hosts and only in the resolver transport layer.
- Prefer host-specific TLS workaround over global bad certificate acceptance.

### 3. Streamtape instability

Frequency:

- `9` transport failures

Observed error:

- `resolver.streamtape.transport` with HTTP 404 in multiple AnimeFlv / JKAnime links.

Impact:

- Some Streamtape links work, others are stale or malformed.

Probable fixes:

- Validate whether source plugins are surfacing expired/stale Streamtape URLs.
- Tighten the resolver to discard malformed alternatives like typo-derived secondary URLs.
- Capture raw HTML fixtures from failing pages and compare against successful pages to determine whether the issue is source-side extraction or resolver-side parsing.

### 4. HQQ / Netu challenge wall

Frequency:

- `6` occurrences

Observed error:

- `resolver.hqq.challenge_required`

Impact:

- Static extraction is insufficient; these links are not directly usable in current resolver mode.

Probable fixes:

- Treat HQQ as runtime-gated and de-prioritize it in UI/server ordering.
- Only invest in this resolver if browser-assisted challenge solving is acceptable for product goals.
- Otherwise mark as unsupported-at-runtime and avoid presenting it as a first-tier server.

### 5. OK.ru inconsistency

Frequency:

- `5` parse failures plus at least one transport/probe failure after successful extraction

Observed errors:

- `resolver.okru.parse`
- One probe `HTTP 400` even after stream extraction

Impact:

- Parser is inconsistent across payload variants.
- Even when parsed, some generated media URLs are not probe-safe with current headers.

Probable fixes:

- Capture failing OK.ru payload variants as fixtures.
- Compare payload schema between successful Naruto run and failed runs.
- Revisit header policy for direct OK media URLs, especially `Referer`/`Origin` and signed URL parameter preservation.

### 6. Doodstream alias drift

Frequency:

- `3` occurrences

Observed error:

- `resolver.doodstream.transport` on `d-s.io`

Impact:

- Resolver works for some Doodstream aliases (`dsvplay.com` succeeded), but some aliases are dead or no longer resolvable.

Probable fixes:

- Maintain an allowlist/denylist of known live Doodstream aliases.
- Reject dead aliases early and surface a clearer host-deprecated failure.
- Normalize viable aliases to canonical Doodstream entrypoints before extraction.

### 7. VOE instability

Frequency:

- `2` session-gated failures
- `2` transport failures

Impact:

- VOE behavior is inconsistent between links; some pages now require runtime session material, others simply 404.

Probable fixes:

- Separate VOE failures into `stale_link` vs `session_required` in diagnostics.
- If runtime session flow becomes common, decide whether VOE remains worth supporting without browser automation.

### 8. Probe-layer timeouts and empty responses

Observed issues:

- `TimeoutException after 10s` and `15s`
- `Invalid argument(s): 0` when content-length is zero on one YourUpload case
- `HTTP 502` on some HLS endpoints that did resolve correctly

Impact:

- Some failures are not resolver bugs; they are probe robustness issues.

Probable fixes:

- Harden probe logic for zero-byte / zero-length bodies before attempting range math.
- Distinguish `resolved_but_probe_unstable` from actual resolver failure in summaries.
- Consider retry-once for `502` and timeout on HLS playlist GETs.
- For `JKPlayer JK` specifically, filter non-media assets before probe; current resolver emits CSS/JS/document URLs as playable candidates.

## Source-Level Findings

### JKAnime

- Strong source coverage.
- `JKPlayer UM` is consistently healthy.
- `JKPlayer JK` is not probe-safe in current shape because it returns non-media assets in at least one run.

Recommended actions:

- Tighten `JKPlayer JK` stream candidate extraction to only media/HLS URLs.

### AnimeFlv

- Good link volume.
- Strong improvement after matcher integration.
- Still exposes many unsupported and low-value hosts (`MEGA`, `Maru`, `Fembed`, `Netu`).

Recommended actions:

- Add host capability filtering or lower unsupported host priority in UI.

### AnimeAV1

- Best overall probe success rate in this sample.
- High number of usable `Pixeldrain`, `UPNShare`, `Zilla`, `YourUpload`, `StreamTape` links.
- Also exposes unsupported `MEGA`, `TeraBox`, some `VidHide` alias drift.

Recommended actions:

- Extend alias support for `VidHide` front domains.
- Add or suppress unsupported hosts.

### AnimeNexus

- Resolver path is healthy when a match exists.
- Coverage is sparse by design: usually one link per episode.
- Naruto catalog incompleteness stands out (`50` episodes only).

Recommended actions:

- Audit Naruto ingestion/catalog completeness in AnimeNexus source.
- For multilingual title cases, pass more aliases into the canonical query to reduce fallback selection.

## Priority Fix Order

1. Add or suppress unsupported hosts to eliminate the `44` guaranteed failures.
2. Fix Mp4Upload transport handling because it is a high-frequency post-resolution failure.
3. Tighten `JKPlayer JK` and other resolvers that emit non-playable candidates.
4. Audit Streamtape stale-link generation from sources.
5. Harden probe logic around timeouts, zero-byte responses, and transient 502s.
6. Revisit OK.ru parsing and transport headers with fixtures from successful and failing variants.
7. Audit AnimeNexus catalog completeness for long-running series.

## Recommended Next Batch

If the next goal is a deeper validation rather than a broad smoke test, the most useful follow-up is:

1. Run first/middle/last episode audit for Naruto, Jujutsu Kaisen, and Attack on Titan.
2. Store a compact per-resolver scorecard by episode bucket.
3. Capture raw failing payload fixtures for `Mp4Upload`, `OK.ru`, `Streamtape`, `JKPlayer JK`, and `Doodstream` dead aliases.
