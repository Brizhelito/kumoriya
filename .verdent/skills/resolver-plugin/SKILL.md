---
name: resolver-plugin
description: >-
  This skill should be used when implementing, maintaining, or hardening
  Kumoriya resolver plugins. Covers host gating, URL normalization,
  headers/referer/cookies/timeout management, HTML/JS payload parsing,
  redirect handling, fixture creation, contract tests, smoke tests, and
  conservative accept/reject policies for video link resolution. Triggers on
  mentions of resolver plugin, ResolverPlugin, ResolvedStream, host gating,
  video extraction, embed parsing, stream URL, HLS resolution, doodstream,
  filemoon, streamtape, mp4upload, okru, voe, streamwish, vidhide, or any
  resolver-specific host in the Kumoriya context.
---

# resolver-plugin

## Purpose

Implement and maintain Kumoriya resolver plugins as independent, testable modules that extract playable stream URLs from embed/video hosting pages. Each resolver handles specific hosts, validates URLs, manages HTTP context (headers, cookies, referer), parses HTML/JS payloads, and returns `ResolvedStream` objects. Resolvers are strictly separated from source plugins, playback, and UI. The guiding principle is: prefer failing to resolve over returning a wrong or broken stream URL.

## Use When

- Implementing a new resolver plugin for a video hosting provider.
- Fixing or hardening an existing resolver that fails to extract stream URLs.
- Updating a resolver to handle changed host HTML/JS structure.
- Adding host aliases or URL normalization for a resolver.
- Creating or updating fixtures for resolver parser testing.
- Writing contract tests or smoke tests for resolvers.
- Reviewing a resolver-related PR.

## Do Not Use When

- Debugging a resolver failure at runtime with DOM/network inspection (use `resolver-runtime-audit`).
- Implementing source plugin scraping (use `source-plugin-jkanime` or equivalent).
- Working on player features (use `player-slice`).
- Making architecture decisions (use `kumoriya-architecture`).
- The task is about matching or AniList (use `anilist-matching`).

## What This Skill Does

1. Enforces `ResolverPlugin` contract compliance: `manifest`, `priority`, `supports(Uri)`, `resolve(Uri) -> Result<List<ResolvedStream>, KumoriyaError>`.
2. Implements strict host gating: each resolver declares which hostnames it handles and rejects everything else.
3. Normalizes URLs before processing: canonicalize scheme/host/path, preserve required query params, strip tracking noise.
4. Manages HTTP request context per host: required headers, referer, origin, cookies, user-agent.
5. Parses HTML/JS payloads defensively: null guards, regex boundaries with fail-safe, typed parse failures.
6. Handles redirects explicitly: track redirect chains, preserve required context (referer, cookies) across hops.
7. Configures explicit timeout budgets per request stage.
8. Creates fixtures for non-trivial parsing scenarios.
9. Writes contract tests (interface compliance) and smoke tests (real or fixture-based extraction).
10. Returns typed errors with diagnostic information, never throws unhandled exceptions.

## Required Inputs

- Access to the target resolver package: `packages/kumoriya_resolver_<host>/`.
- Knowledge of `ResolverPlugin` contract from `packages/kumoriya_plugins/lib/src/contracts/resolver_plugin.dart`.
- Knowledge of `ResolvedStream` model (url, qualityLabel, mimeType, isHls, headers).
- Knowledge of `PluginManifest` model from `packages/kumoriya_plugins/`.
- Representative embed page HTML/JS for the target host (either live capture or fixture).
- Knowledge of HTTP requirements for the target host (referer policy, cookie dependencies, CDN patterns).

## Preconditions

- The resolver package compiles.
- The `ResolverPlugin` contract interface is stable (or the change to it is part of the scope).
- The agent has inspected at least one real embed page for the target host before implementing parsing logic.

## Procedure

1. **Publish scope lock.**
   ```
   Resolver Scope
   - Request: [new resolver / fix / hardening]
   - Resolver target: [host name and package]
   - In scope: [resolver logic, fixtures, tests]
   - Out of scope: playback, UI, source plugins
   - Done when: [acceptance criteria]
   ```

2. **Review the resolver contract.** Read `resolver_plugin.dart`. Confirm:
   - `supports(Uri)` must return true only for declared hostnames.
   - `resolve(Uri)` must return `Result<List<ResolvedStream>, KumoriyaError>`.
   - `manifest` must declare correct `supportedHosts`.
   ```
   Resolver Contract Review
   - Interface: ResolverPlugin
   - Required inputs: Uri (validated by supports())
   - Required outputs: List<ResolvedStream> with url, qualityLabel, isHls, headers
   - Failure types: KumoriyaError (typed: unsupported host, parse failure, timeout, network error)
   ```

3. **Implement host gating.**
   - Define allowlist of hostnames (including known aliases/mirrors).
   - Normalize host before checking (lowercase, strip www prefix if applicable).
   - Return explicit unsupported-host error for non-matching URLs.

4. **Implement URL normalization.**
   - Canonicalize scheme to https when applicable.
   - Normalize path separators.
   - Preserve query params required by the host (e.g., video ID, token).
   - Strip tracking params only when proven irrelevant.

5. **Implement request context.**
   - Set required headers (referer, origin, user-agent) per host documentation or observation.
   - Manage cookies if the host requires session state.
   - Configure timeout budgets per request stage (initial page fetch, API call, stream URL fetch).

6. **Implement parsing.**
   - Separate fetch from parse: fetch returns raw response, parser extracts stream URLs.
   - Parse defensively: check for null/empty response, validate expected DOM/JS structure, use bounded regex with named groups.
   - Handle multiple quality variants if the host provides them.
   - Emit typed parse failure on unexpected structure (not generic exception).

7. **Handle redirects.**
   - Follow redirects explicitly when needed.
   - Preserve required context (referer, cookies) across redirect hops.
   - Cap redirect depth to prevent infinite loops.

8. **Create fixtures.** For non-trivial parsing:
   - Standard success fixture (representative HTML/JS).
   - Edge fixtures: missing token, changed script structure, access denied page.
   - Store in `test/fixtures/` within the resolver package.
   - Name fixtures descriptively: `<host>_success.html`, `<host>_captcha.html`.

9. **Write tests.**
   - Host acceptance: `supports()` returns true for valid hosts.
   - Host rejection: `supports()` returns false for invalid hosts.
   - URL normalization: input/output pairs.
   - Parse success: extract stream URLs from standard fixture.
   - Parse failure: return typed error on changed/invalid fixture.
   - Timeout path: verify timeout error is returned (mock).

10. **Run validation.**
    ```
    dart format packages/kumoriya_resolver_<host>/
    dart analyze packages/kumoriya_resolver_<host>/
    dart test packages/kumoriya_resolver_<host>/
    ```

11. **Report.**
    ```
    Resolver Plugin Report
    - Scope executed: [recap]
    - Host policy: [accepted hosts, rejected patterns]
    - URL/context handling: [normalization, headers, cookies]
    - Parsing approach: [technique, fallbacks]
    - Fixtures: [added/updated]
    - Tests: [commands + results]
    - Risks: [host volatility, anti-bot, token rotation]
    - Residual risk: [honest assessment]
    ```

## Required Checks

- [ ] `dart format` passes on resolver package.
- [ ] `dart analyze` reports no issues.
- [ ] All resolver tests pass.
- [ ] `supports()` has both acceptance and rejection tests.
- [ ] `resolve()` has success and failure path tests.
- [ ] No import of source plugin, player, or UI code exists in the resolver.
- [ ] Timeouts are configured (no unbounded waits).
- [ ] Fixtures exist for non-trivial parsing.

## Expected Outputs

- Resolver plugin implementation compliant with `ResolverPlugin` contract.
- Host gating with explicit allowlist.
- Fixtures for parser testing.
- Contract tests and smoke tests.
- Validation evidence.
- Risk documentation for host-specific fragility.

## Anti-Patterns

- **Cross-host guessing.** Never attempt to resolve a URL for a host not in the allowlist.
- **Silent failure.** Never swallow errors or return empty list without typed error.
- **Parsing without fixtures.** Never ship complex HTML/JS parsing without a test fixture.
- **Unbounded timeouts.** Never make HTTP requests without explicit timeout.
- **Hardcoded tokens.** Never embed API keys, tokens, or secrets in resolver code.
- **Coupling to source plugins.** Resolvers do not know which source produced the URL.
- **Coupling to player.** Resolvers return `ResolvedStream`, they do not control playback.
- **Returning broken URLs.** If the extracted URL cannot be validated as plausible (scheme, host, path), return an error instead.
- **Using WebView as first resort.** WebView is last-resort infrastructure; use HTTP parsing first.

## Constraints

- `ResolverPlugin` interface from `kumoriya_plugins` is the contract. Do not modify it without `kumoriya-architecture` review.
- `Result<T, KumoriyaError>` is the error handling pattern.
- Each resolver is an independent package: `packages/kumoriya_resolver_<host>/`.
- Resolvers are individually testable without the app or other plugins.
- Prefer no resolution over wrong resolution.
- WebView is last-resort; if used, document why HTTP-only approach is impossible.

## Minimal Example

Task: "Implement a resolver for streamtape.com."

1. Scope: new resolver for streamtape, package `kumoriya_resolver_streamtape`. In scope: host gating, URL normalization, HTML parsing, fixture, tests. Out of scope: player, source plugins.
2. Create package scaffold with `mcp_kumoriya-mcp_create_resolver_plugin_package`.
3. Implement `supports()`: accept `streamtape.com`, `streamtape.net`, `streamtape.to`.
4. Implement `resolve()`: fetch embed page, parse JavaScript to extract stream URL, build `ResolvedStream` with headers.
5. Fixture: save representative embed HTML as `test/fixtures/streamtape_success.html`.
6. Tests: acceptance/rejection for `supports()`, parse success from fixture, parse failure from empty fixture.
7. Validate: format, analyze, test.
8. Report with risks (streamtape rotates subdomains, anti-bot tokens change).

## Definition of Done

- Resolver passes all contract and smoke tests.
- Host gating is strict (only declared hosts accepted).
- Parsing handles at least one success and one failure fixture.
- No coupling to source plugins, player, or UI.
- Validation passes.
- Risks documented.

## Project Assumptions

- Each resolver lives in its own package under `packages/kumoriya_resolver_<host>/`.
- The `kumoriya_plugins` package provides the `ResolverPlugin` interface and `ResolvedStream` model.
- HTTP clients are injectable for testing (resolvers use a client parameter or DI).
- **Risk: video hosting providers frequently change their embed structure, requiring ongoing maintenance.**
- **Risk: some hosts use sophisticated anti-bot measures that may require WebView fallback.**
- Current resolver packages: anime_nexus, doodstream, filemoon, hqq, jkplayer, mixdrop, mp4upload, okru, pixeldrain, streamtape, streamwish, upnshare, vidhide, voe, yourupload, zilla.
