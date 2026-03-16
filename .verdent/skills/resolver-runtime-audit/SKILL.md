---
name: resolver-runtime-audit
description: >-
  This skill should be used when diagnosing why a Kumoriya resolver fails at
  runtime. Evidence-first investigation workflow covering static code inventory,
  live DOM/JS/network inspection, real payload analysis, host alias discovery,
  root cause isolation by layer (source extraction, host aliasing, resolver
  parser, redirect policy, runtime payload, non-resolver), and production of
  prioritized actionable fix plans. Triggers on mentions of resolver failure,
  broken host, embed not working, stream URL extraction failure, runtime debug,
  network inspection, host alias mismatch, or any "why does this resolver
  fail?" question.
---

# resolver-runtime-audit

## Purpose

Investigate and diagnose why a Kumoriya resolver fails to extract playable stream URLs at runtime. This is an evidence-first audit skill: it does not speculate. It starts from static code analysis, optionally escalates to live browser/network inspection, isolates the root cause by architectural layer, and produces a prioritized fix plan. It exists because resolver failures have many possible causes (source extraction, host aliasing, parser logic, redirect/referer policy, runtime payload changes) and misdiagnosing the layer wastes effort.

## Use When

- A resolver that previously worked now fails to produce stream URLs.
- A resolver works for some episodes but not others from the same source.
- A host works in the browser but fails in resolver code.
- A new host alias or mirror is suspected.
- The error logs show resolver failures but the root cause is unclear.
- Comparing why one resolver/host works and another similar one fails.
- Determining whether a failure is in the source plugin, resolver, or player.

## Do Not Use When

- Implementing a new resolver from scratch (use `resolver-plugin`).
- The resolver needs routine maintenance without a runtime failure (use `resolver-plugin`).
- The problem is purely in the player (use `player-slice`).
- The problem is in matching/AniList (use `anilist-matching`).
- Making architecture decisions (use `kumoriya-architecture`).

## What This Skill Does

1. Builds a static inventory of the affected source plugin, resolver plugin, host allowlist, parser functions, and existing fixtures/tests.
2. Determines whether live runtime inspection is needed based on concrete criteria (JS-dependent tokens, redirect chains, cookie constraints).
3. Captures runtime evidence using browser tools: post-JS DOM, network timeline, redirect chains, required headers, payload fragments.
4. Cross-references runtime evidence against code assumptions: host allowlist vs actual domains, parser regex vs actual payload, referer policy vs actual requirements.
5. Classifies each failure into exactly one primary layer: source-extraction, host-aliasing, resolver-parser, redirect-policy, runtime-payload, or non-resolver.
6. Requires concrete evidence for every root cause classification (not speculation).
7. Produces a prioritized fix plan sorted by user impact and evidence confidence.
8. Validates fixes with both code-level checks and runtime re-verification when runtime behavior was part of the failure.

## Required Inputs

- Description of the failing scenario (which anime, episode, source, resolver/host).
- Access to the source plugin package and resolver plugin package involved.
- Ability to use browser tools for runtime inspection (Playwright MCP or equivalent).
- Access to resolver logs or error output if available.

## Preconditions

- The agent knows which source plugin and resolver plugin are involved in the failure.
- The agent can identify the specific episode/URL that fails.
- If live inspection is needed, browser automation tools are available.

## Procedure

### Step 1: Build static inventory.

Read code before touching a browser.

1. Identify the source plugin entrypoint for the affected flow (which method produces the embed URL).
2. Identify the resolver plugin and its host allowlist/alias normalization.
3. Read the parser/extractor functions in the resolver.
4. Check existing fixtures and tests for coverage of this host/scenario.
5. Read the contract boundary: what does the source output? What does the resolver expect as input?

Produce:
```
Static Inventory
- Source plugin: [package, method]
- Resolver plugin: [package, class]
- Host aliases accepted: [list from code]
- Parser functions: [key functions]
- Existing fixtures: [list or "none"]
- Existing tests: [list or "none"]
- Contract gap: [any mismatch between source output and resolver input]
```

### Step 2: Decide if runtime inspection is needed.

Runtime inspection is mandatory when any of these is true:
- The stream URL or token only appears after JavaScript execution.
- The host uses multiple redirects with referer/cookie constraints.
- The static HTML does not contain the final media manifest.
- The host works in browser but fails in code.
- A domain alias or CDN mismatch is suspected.

If none apply, continue with static + fixture analysis only.

### Step 3: Capture runtime evidence.

Use browser automation to capture real behavior:

1. Navigate to the real episode/embed page.
2. Wait for full JS execution.
3. Capture the network request timeline (filter for media/API requests).
4. Identify the decisive request that produces the stream URL.
5. Record: actual host/domain, required headers, redirect chain, response payload shape.
6. Save reproducible artifacts (HTML/JSON/JS snippets) for fixture updates.

Produce:
```
Runtime Evidence
- Page/step: [URL or description]
- Observed host: [actual domain]
- Decisive request: [URL and method]
- Response type: [HTML/JSON/HLS manifest/etc]
- Required headers: [referer, cookies, tokens]
- Redirect chain: [hops]
- Artifact: [saved snippet location]
```

### Step 4: Compare runtime truth vs code.

For each aspect, compare what the code expects vs what runtime shows:
- Hostnames: code allowlist vs actual domains observed.
- Payload structure: parser regex/selectors vs actual HTML/JS.
- Redirect/referer: code request context vs actual required headers.
- Fixtures: current fixture content vs actual captured content.

Mark each discrepancy as: **proven** (clear evidence), **suspected** (indirect evidence), or **rejected** (evidence contradicts).

### Step 5: Isolate root cause by layer.

Classify into exactly one primary layer:

| Layer | Meaning |
|-------|---------|
| `source-extraction` | Source plugin fails to surface correct embed URL/context |
| `host-aliasing` | Resolver rejects the URL because host/alias is not recognized |
| `resolver-parser` | Parser fails because HTML/JS structure changed |
| `redirect-policy` | Required referer/cookies/headers are lost across redirects |
| `runtime-payload` | Host changed its runtime contract (new token scheme, endpoint, signing) |
| `non-resolver` | Issue is in player/session/orchestration after successful resolution |

Produce:
```
Root Cause Matrix
- Resolver/host: [name]
- Failing step: [specific step]
- Layer: [one of the above]
- Evidence: [concrete reference]
- Confidence: [low/medium/high]
- Blast radius: [how many flows affected]
```

### Step 6: Build prioritized fix plan.

Prioritize by:
- P0: widely used host, currently broken, high-confidence evidence.
- P1: medium impact or partially broken, high-confidence evidence.
- P2: hardening/refactor, no immediate user breakage.

For each fix:
```
Fix Plan Item
- Priority: [P0/P1/P2]
- Resolver/host: [name]
- Change: [specific code change]
- Why now: [user impact]
- Fixtures to add: [what to capture]
- Tests to add: [what to cover]
```

### Step 7: Validate and close.

After implementing fixes:
1. `dart format` on affected paths.
2. `dart analyze` on affected packages.
3. `dart test` on resolver and source tests.
4. Re-run the failing scenario in browser to confirm the fix works.
5. Confirm no layer leakage (player code untouched unless in scope).

```
Validation
- Format: [command + result]
- Analyze: [command + result]
- Tests: [command + result]
- Runtime re-check: [pass/fail + evidence]
- Residual risk: [what remains unresolved]
```

## Required Checks

- [ ] Static inventory was built before runtime inspection.
- [ ] Runtime evidence is concrete (URLs, payloads, headers), not speculative.
- [ ] Root cause is classified into exactly one primary layer with evidence.
- [ ] Fix plan items have concrete code changes, not vague suggestions.
- [ ] Code validation passes (format, analyze, test).
- [ ] Runtime re-verification was performed if runtime behavior was part of the failure.
- [ ] No player code was modified unless explicitly in scope.

## Expected Outputs

- Static inventory of affected plugins and contracts.
- Runtime evidence log (if runtime inspection was performed).
- Root cause matrix with layer classification and confidence.
- Prioritized fix plan.
- Validation evidence (code + runtime).
- Residual risks.

## Anti-Patterns

- **Speculating without evidence.** Never classify a root cause without concrete proof.
- **Skipping static analysis.** Always read the code before opening a browser.
- **Fixing symptoms.** Do not patch around the problem without identifying the root cause layer.
- **Mixing layers in fixes.** If the root cause is in the source plugin, do not hack the resolver to compensate.
- **Massive rewrites before diagnosis.** Do not rewrite a resolver before proving the failure is in the resolver.
- **Assuming static HTML is runtime truth.** Many embed pages build their payload via JavaScript.
- **Ignoring host aliases.** CDN subdomains, mirror domains, and embed domains are different from the main host.
- **Claiming fixed without runtime re-check.** If the failure was observed at runtime, the fix must be verified at runtime.

## Constraints

- Evidence-first: no speculative fixes without proof.
- Layer isolation: source, resolver, and player are separate concerns.
- `Result<T, KumoriyaError>` at all boundaries.
- Prefer no link over fabricated link.
- Keep changes minimal and targeted to the proven root cause.
- Runtime artifacts captured during audit should be sanitized and stored as fixtures for regression testing.

## Minimal Example

Task: "Filemoon resolver returns empty results for episodes from JKAnime."

1. Static inventory: JKAnime `getEpisodeServerLinks()` returns `SourceServerLink` with Filemoon URLs. Filemoon resolver accepts `filemoon.sx`, `filemoon.to`. Parser expects `<script>` tag with packed JS.
2. Runtime: open JKAnime episode page, extract Filemoon embed URL. Navigate to it. Network shows redirect to `filemoon.nl` (new alias not in allowlist).
3. Root cause: `host-aliasing`. Filemoon resolver rejects `filemoon.nl` because it's not in `supports()`.
4. Fix: add `filemoon.nl` to host allowlist. Add test for new alias. Add fixture from captured page.
5. Validate: format, analyze, test, re-run episode in browser.

## Definition of Done

- Root cause is identified with evidence and classified into a specific layer.
- Fix addresses the root cause (not symptoms).
- Code validation passes.
- Runtime re-verification confirms the fix (when applicable).
- Residual risks documented.
- No layer leakage in the fix.

## Project Assumptions

- Browser automation (Playwright MCP) is available for runtime inspection. **Risk: some hosts may block automated browsers or require CAPTCHA solving.**
- Source plugins and resolver plugins are in separate packages under `packages/`. **This boundary is enforced.**
- Resolver logs may not always be available; runtime inspection fills the gap.
- **Risk: video hosting providers change their infrastructure frequently. A fix today may break again next week.**
- **Risk: some failures are intermittent (rate limiting, geo-blocking) and may not reproduce consistently.**
