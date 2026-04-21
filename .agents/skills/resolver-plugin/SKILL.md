---
name: resolver-plugin
description: Create or harden Kumoriya video resolver plugins (independent from source plugins, playback, UI). Use for resolver contracts, URL/host gating, headers/cookies, fixtures, and resolver tests.
---

# Resolver Plugin (Kumoriya)

Implement resolver plugins as isolated, testable modules. Keep resolver logic independent from source plugins, playback pipeline, and UI.

## Hard boundaries first

1. Respect `AGENTS.md` architecture guardrails.
2. Treat resolvers as separate plugins from sources.
3. Do not add playback or UI behavior in resolver tasks.
4. Use WebView only as explicit last resort and document why.
5. Prefer rejection over unsafe host handling.

## Scope lock before coding

Publish this block first:

```md
Resolver Scope
- Request:
- Resolver target (new or existing):
- In scope:
- Out of scope (must include playback/UI):
- Done when:
```

If request mixes concerns, implement only resolver slice.

## Contract-first implementation

1. Locate resolver plugin contracts and required result/error models.
2. Validate input expectations:
   - accepted host(s)
   - accepted URL shapes
   - required request context
3. Validate output expectations:
   - resolved stream/link payload
   - metadata needed by downstream layers
   - typed failure reasons
4. Keep contract mapping explicit and deterministic.

Output:

```md
Resolver Contract Review
- interface/model:
- required inputs:
- required outputs:
- failure types:
```

## Host acceptance and rejection policy

Implement strict host gating.

1. Define allowlist of hostnames for resolver.
2. Normalize and validate host before any network work.
3. Reject if:
   - host not allowlisted
   - URL shape unsupported
   - required tokens/context missing
4. Return explicit unsupported-host/invalid-url style errors.

Do not attempt cross-host guessing.

## URL normalization and request context

Normalize URL inputs and request metadata consistently.

1. Canonicalize scheme/host/path safely.
2. Preserve relevant query params required by host.
3. Strip tracking noise only if proven irrelevant.
4. Build request context explicitly:
   - headers
   - referer/origin
   - cookies
   - user-agent or extra headers when required
5. Keep host-specific request policy localized in resolver module.

## Parsing and extraction hardening

1. Separate fetch/decode/parse steps.
2. Use defensive parsing for HTML/JS responses:
   - null/empty guards
   - regex boundaries with fail-safe behavior
   - multiple extraction strategies only when deterministic
3. Avoid brittle one-selector logic when safer alternatives exist.
4. Emit typed parse failures instead of unhandled exceptions.

## Errors, retries, and timeouts

1. Configure explicit timeout budgets per request stage.
2. Distinguish timeout, network, parse, and unsupported errors.
3. Retry only idempotent safe calls and keep retry count bounded.
4. On repeated failure, return typed error with minimal diagnostics.

## Fixtures and tests per resolver

Add fixtures when parser or script extraction is non-trivial.

Fixture guidance:
1. Store representative HTML/JS payloads per host scenario.
2. Include edge fixtures:
   - token missing
   - obfuscated/changed script shape
   - access denied/captcha page
3. Keep fixture naming stable and scenario-specific.

Minimum tests:
1. Host acceptance success.
2. Host rejection for unsupported domain.
3. URL normalization behavior.
4. Parsing success on standard fixture.
5. Parsing failure on changed/invalid fixture.
6. Timeout/error-path behavior.

## Validation checklist

```md
Validation Checklist
- [ ] dart format <affected paths>
- [ ] dart analyze <resolver package>
- [ ] dart test <resolver tests>
```

Do not claim resolver stability without executed tests.

## Risk documentation

Always document resolver/host risks:

```md
Resolver Risks
- host/resolver:
- risk:
- trigger:
- mitigation:
- fallback behavior:
```

Examples:
- anti-bot challenges
- rotating tokens
- unstable inline scripts
- mandatory referer/cookie dependencies

## Final report template

```md
Resolver Plugin Report
- Scope executed:
- Contracts touched:
- Host policy (accept/reject):
- URL/context handling changes:
- Fixtures added/updated:
- Tests run:
  - command:
  - result:
- Risks documented:
- Residual risk:
```
