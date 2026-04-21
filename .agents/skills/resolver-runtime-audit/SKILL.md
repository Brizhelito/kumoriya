---
name: resolver-runtime-audit
description: Diagnose Kumoriya resolver failures with evidence from static code, runtime DOM/JS, and network payloads. Use to decide if fault is in source extraction, host gating, parser, or redirects.
---

# Resolver Runtime Audit

Run resolver audits with real evidence, not assumptions. Start from code inventory, contrast with observed runtime behavior, isolate root cause by layer, and propose minimal high-impact fixes.

Keep source extraction, resolver logic, and player responsibilities strictly separated.

## Non-negotiable audit rules

1. Treat AniList metadata and plugin boundaries from `AGENTS.md` as hard constraints.
2. Prefer no link over fabricated link; never invent URLs, tokens, or headers.
3. Do not assume visible button or anchor equals real media URL.
4. Do not assume initial HTML contains final runtime truth.
5. Avoid massive rewrites before root cause is proven.
6. Keep player behavior out of resolver/source fixes unless task explicitly targets player.
7. Prioritize fixes by observed user impact and confidence of diagnosis.

## Scope lock before investigation

Publish this block before making changes:

```md
Resolver Runtime Audit Scope
- Request:
- Target flows (episode/source/host):
- In scope:
- Out of scope (must mention player if excluded):
- Evidence required to close:
```

If request mixes layers, split findings per layer and implement only the resolver/source slice requested.

## Audit workflow

### Step 1: Build static inventory first

Inspect existing code and contracts before runtime probing.

1. Identify source plugin extractor entrypoints for affected flow.
2. Identify resolver plugin(s) and host allowlist/alias mapping.
3. Trace normalization/parsing functions and typed error paths.
4. Locate fixtures/tests covering this host and failure mode.
5. Record expected contract boundary:
   - source output contract (embed page/url context)
   - resolver input contract
   - resolver output contract
   - player input assumptions (read-only for this audit)

Output:

```md
Static Inventory
- source plugin paths:
- resolver plugin paths:
- host aliases currently accepted:
- parser/extractor functions:
- existing fixtures/tests:
- known contract gaps:
```

### Step 2: Decide whether runtime inspection is mandatory

Use runtime/browser inspection when any of these is true:

1. Link/token appears only after JS execution or XHR/fetch calls.
2. Multiple redirects/referer/cookie constraints exist.
3. Static HTML lacks the final media manifest or signed URL.
4. Host works in browser but fails in resolver code.
5. Alias/domain mismatch is suspected (mirror/cdn/embed domains).

If none apply, continue with static + fixture analysis first.

### Step 3: Capture runtime evidence

Use available browser/runtime tools to capture evidence, not screenshots only.

1. Open the real episode/embed flow.
2. Capture DOM after scripts execute.
3. Collect network timeline (`includeStatic=false` first).
4. Identify decisive requests/responses:
   - embed bootstrap payload
   - API endpoints returning source lists/manifests
   - redirect chain and effective final URL
   - headers needed (referer/origin/cookies/auth tokens)
5. Capture payload fragments that prove extraction conditions.
6. Save reproducible artifacts (HTML/JSON/JS snippets) for fixture updates.

Evidence log format:

```md
Runtime Evidence
- page/step:
- observed host/domain:
- decisive request URL:
- decisive response type:
- required headers/context:
- redirect chain summary:
- proof artifact path:
```

### Step 4: Compare runtime truth vs code/fixtures

Cross-check implementation against observed runtime behavior.

1. Compare actual hostnames with allowlist and alias normalization.
2. Compare payload shape with parser assumptions.
3. Compare redirect/referer/cookie requirements with resolver request policy.
4. Compare current fixtures against captured artifacts.
5. Mark each mismatch as proven, suspected, or rejected.

### Step 5: Isolate root cause by layer

Classify each failure into one primary layer:

1. `source-extraction`: source plugin fails to surface correct embed/context.
2. `host-aliasing`: resolver rejects or misroutes due to missing alias normalization.
3. `resolver-parser`: resolver parser fails for real payload/JS shape.
4. `redirect-policy`: resolver loses required referer/origin/cookies across redirects.
5. `runtime-payload`: host runtime contract changed (token/signature/endpoint schema).
6. `non-resolver`: issue belongs to player/session/orchestration after successful resolution.

Require concrete evidence for each assigned root cause.

Output:

```md
Root Cause Matrix
- resolver/host:
- failing step:
- layer:
- evidence:
- confidence (low/medium/high):
- blast radius:
```

### Step 6: Define minimal, high-impact fix plan

Prioritize fixes that unlock real failing hosts first.

1. Propose smallest change that resolves proven root cause.
2. Keep source/resolver/player boundaries intact.
3. Add or refresh fixtures from captured runtime artifacts.
4. Add targeted tests for aliasing, parser behavior, and reject paths.
5. Defer speculative refactors not tied to evidence.

Prioritization rubric:

- `P0`: Host widely used and currently broken; evidence high.
- `P1`: Medium impact or partially broken flow; evidence high.
- `P2`: Hardening/refactor; no immediate user breakage.

Output:

```md
Prioritized Fix Plan
- priority:
- resolver/host:
- change:
- why now:
- tests/fixtures to add:
```

### Step 7: Validate and close

For implementation tasks, execute validation explicitly:

1. Run format on affected paths.
2. Run static analysis for touched packages.
3. Run relevant tests (resolver + source tests if both changed).
4. Re-run runtime check for at least one broken scenario.
5. Confirm no layer leakage (player code untouched unless in scope).

Validation report:

```md
Validation
- format:
- analyze:
- tests:
- runtime re-check:
- residual risk:
```

## Final deliverable template

Provide this structure in final answer:

```md
Resolver Runtime Audit Report
- Technical diagnosis:
- Host/resolver inventory:
- Root cause per problematic resolver:
- Prioritized fix plan:
- Validation results:
- Residual risks / unknowns:
```

Do not mark issue as fixed without evidence from both code-level checks and runtime verification when runtime behavior is part of the failure.
