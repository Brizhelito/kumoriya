---
name: source-plugin-jkanime
description: >-
  This skill should be used when implementing or maintaining the JKAnime source
  plugin for Kumoriya. Covers search parsing, anime detail extraction, episode
  listing, defensive HTML parsing, fixture-driven parser hardening, SourcePlugin
  contract compliance, and limitation reporting. Triggers on mentions of
  JKAnime, jkanime.net, kumoriya_source_jkanime, source plugin search, episode
  scraping, anime catalog extraction, or HTML parser hardening for JKAnime.
---

# source-plugin-jkanime

## Purpose

Implement and maintain the JKAnime source plugin (`packages/kumoriya_source_jkanime/`) as a compliant `SourcePlugin` implementation. This skill covers search, anime detail, episode listing, and server link extraction from jkanime.net. It enforces defensive parsing, fixture-driven testing, honest limitation reporting, and strict independence from resolvers and playback. The guiding principle is: prefer returning no data over returning ambiguous or incorrect data.

## Use When

- Implementing new scraping capabilities for JKAnime (search, detail, episodes, server links).
- Fixing broken JKAnime parsing due to site HTML changes.
- Adding or updating HTML fixtures for JKAnime parser tests.
- Hardening JKAnime parsers against edge cases (missing poster, unusual episode markup, alt titles).
- Reviewing compliance of JKAnime plugin against the `SourcePlugin` contract.
- Adding new test cases for JKAnime parsing logic.

## Do Not Use When

- Implementing resolver plugins for hosts found in JKAnime links (use `resolver-plugin`).
- Debugging resolver failures for JKAnime server links (use `resolver-runtime-audit`).
- Working on a different source plugin (AnimeFLV, AnimeNexus, etc.).
- Working on matching logic (use `anilist-matching`).
- Working on player features (use `player-slice`).
- Making architecture decisions (use `kumoriya-architecture`).

## What This Skill Does

1. Validates compliance with the `SourcePlugin` interface: `search()`, `getAnimeDetail()`, `getEpisodes()`, `getEpisodeServerLinks()` all return `Result<T, KumoriyaError>`.
2. Maps JKAnime raw HTML fields to contract models: `SourceAnimeMatch`, `SourceAnimeDetail`, `SourceEpisode`, `SourceServerLink`.
3. Enforces defensive parsing: null/empty guards on every extracted node, URL/ID validation, no throwing on optional blocks.
4. Prefers semantic anchors (URL patterns, stable attributes, section labels) over fragile nth-child selectors.
5. Normalizes extracted text before use: trim, whitespace collapse, case folding.
6. Creates and maintains HTML fixtures for every non-trivial parsing scenario.
7. Requires tests that prove both successful extraction and safe failure on malformed input.
8. Returns `KumoriyaError` (not exceptions) when data is missing or unparseable.
9. Documents known JKAnime limitations (selector volatility, missing metadata, AJAX pagination behavior).
10. Keeps JKAnime plugin completely independent from resolver and player code.

## Required Inputs

- Access to `packages/kumoriya_source_jkanime/`.
- Knowledge of `SourcePlugin` contract from `packages/kumoriya_plugins/lib/src/contracts/source_plugin.dart`.
- Knowledge of contract models: `SourceAnimeMatch` (sourceId, title, thumbnailUrl, releaseYear, format, aliases, totalEpisodes), `SourceAnimeDetail` (adds synopsis), `SourceEpisode` (sourceEpisodeId, number, title, episodeUrl), `SourceServerLink` (serverId, serverName, initialUrl, language, linkType, detectedHost, externalSubtitles).
- Representative HTML from jkanime.net pages (or existing fixtures in `test/fixtures/`).
- Knowledge that JKAnime uses AJAX-based paginated episode listing.

## Preconditions

- `packages/kumoriya_source_jkanime/` compiles.
- Existing JKAnime tests pass.
- The agent has inspected at least one real JKAnime page (or existing fixture) for the parsing task at hand.

## Procedure

1. **Publish scope lock.**
   ```
   JKAnime Slice Scope
   - Request: [what to implement/fix]
   - In scope: [specific parsing/scraping work]
   - Out of scope: resolvers, playback, other source plugins
   - Done when: [acceptance criteria]
   ```

2. **Review source plugin contract.** Read `source_plugin.dart`. Confirm required fields and return types for the method being implemented.
   ```
   Contract Review
   - Method: [search/getAnimeDetail/getEpisodes/getEpisodeServerLinks]
   - Required output fields: [list]
   - Failure behavior: Result.failure(KumoriyaError)
   - Parser source: [HTML page type]
   ```

3. **Inspect real page or existing fixture.** Before writing any parser, examine the actual HTML structure. Identify:
   - Stable anchors (IDs, data attributes, URL patterns, section headers).
   - Data location (which DOM element contains each required field).
   - Optional vs required blocks.
   - AJAX endpoints if episode listing uses pagination.

4. **Implement parsing.** Follow these rules:
   - Separate HTTP fetch from HTML parse (fetch returns raw HTML, parser extracts structured data).
   - Use stable selectors (prefer `[data-*]`, class+tag combos, URL patterns over positional selectors).
   - Guard every extraction: check node exists, text is non-empty, URL is valid.
   - Normalize extracted text (trim, collapse whitespace, case fold for comparisons).
   - Return typed error on parse failure, not exception.
   - Keep parser functions small and focused (one function per extraction task).

5. **Create or update fixtures.**
   - Save representative HTML for the page type being parsed.
   - Add edge-case fixtures: missing poster, alt title format, unusual episode markup, empty search results.
   - Store in `test/fixtures/` with descriptive names: `jkanime_search_naruto.html`, `jkanime_detail_missing_poster.html`.
   ```
   Fixture Plan
   - Fixture: [filename]
   - Page type: [search/detail/episodes/serverlinks]
   - Scenario: [what it covers]
   ```

6. **Write tests.**
   - Search parsing: valid query returns mapped `SourceAnimeMatch` items with correct fields; empty/ambiguous query returns empty list safely.
   - Detail parsing: all required fields extracted; missing optional blocks do not crash.
   - Episode parsing: ordered episodes extracted from fixture; malformed episode nodes skipped safely.
   - Server links: `SourceServerLink` items have valid `initialUrl` and `detectedHost` when available.
   - Integration test (if applicable): plugin method returns contract-valid objects.

7. **Run validation.**
   ```
   dart format packages/kumoriya_source_jkanime/
   dart analyze packages/kumoriya_source_jkanime/
   dart test packages/kumoriya_source_jkanime/
   ```

8. **Document limitations.**
   ```
   Plugin Limitations
   - Limitation: [what cannot be guaranteed]
   - Impact: [effect on users]
   - Mitigation: [fallback or workaround]
   ```

9. **Report.**
   ```
   JKAnime Plugin Report
   - Scope executed: [recap]
   - Contracts: [methods touched]
   - Files changed: [list]
   - Fixtures: [added/updated]
   - Tests: [commands + results]
   - Limitations: [documented]
   - Residual risk: [honest assessment]
   ```

## Required Checks

- [ ] `dart format` passes on JKAnime package.
- [ ] `dart analyze` reports no issues.
- [ ] All JKAnime tests pass.
- [ ] Every non-trivial parser has at least one fixture.
- [ ] Every parsing function handles null/empty input without throwing.
- [ ] No import of resolver, player, or UI code in the source plugin.
- [ ] `SourceServerLink.initialUrl` is validated as a real URI, not a relative path.
- [ ] `SourceEpisode.number` is a real episode number, not a page index.

## Expected Outputs

- JKAnime plugin code compliant with `SourcePlugin` contract.
- HTML fixtures for parsed page types.
- Tests covering success and failure paths.
- Validation evidence.
- Limitation documentation.

## Anti-Patterns

- **Parsing without inspection.** Never write a parser without looking at the actual HTML structure first.
- **Fragile selectors.** Avoid `nth-child(3) > div > a` when a stable class or attribute exists.
- **Throwing on missing data.** Return `Result.failure()` or skip the item, never throw.
- **Returning ambiguous data.** If the title or episode number cannot be reliably extracted, return nothing.
- **Coupling to resolvers.** The source plugin extracts `initialUrl` for server links; it does not resolve them.
- **Coupling to playback.** The source plugin has no knowledge of media_kit or player state.
- **Hardcoding page structure assumptions.** JKAnime may change its HTML at any time; parsing must be defensive.
- **Mixing source logic with matching logic.** The source plugin provides data; matching decisions happen in `kumoriya_matching`.

## Constraints

- `SourcePlugin` interface from `kumoriya_plugins` is the contract.
- `Result<T, KumoriyaError>` at all public method boundaries.
- JKAnime package is independent: `packages/kumoriya_source_jkanime/`.
- No dependency on resolver packages, player, or app UI.
- AniList is the canonical metadata source; JKAnime provides supplementary source data.
- Prefer no-data over ambiguous data.

## Minimal Example

Task: "JKAnime episode list parsing breaks when an anime has OVA episodes with non-integer numbers."

1. Scope: fix episode parser to handle decimal episode numbers (e.g., 0.5 for OVAs). In scope: episode parsing. Out of scope: resolvers, player.
2. Inspect existing fixture and a real JKAnime page with OVA episodes.
3. Fix parser: `SourceEpisode.number` is `double`, parse the text as double instead of int.
4. Add fixture: `jkanime_episodes_with_ova.html` containing OVA episode markup.
5. Add test: parse fixture, verify OVA episode has number `0.5`, regular episodes have integer values.
6. Validate: format, analyze, test.
7. Report: change, fixture, test, limitation (some OVAs may have no number at all -- handle as skip).

## Definition of Done

- The parsing task works correctly against fixtures.
- No existing test broken.
- Defensive guards are in place for the touched parser.
- Fixtures cover the scenario.
- Validation passes.
- Limitations documented.

## Project Assumptions

- JKAnime uses server-rendered HTML with AJAX for episode pagination. **Risk: JKAnime may add anti-bot protections that break HTTP-only scraping.**
- The JKAnime domain is `jkanime.net`. **Risk: domain may change or add mirrors.**
- The source plugin uses an injectable HTTP client for testing. **This enables fixture-based tests without live network.**
- `SourceServerLink.detectedHost` is optionally populated by the source plugin to hint which resolver may handle the link. **Risk: detection may be wrong if JKAnime wraps embed URLs in redirects.**
