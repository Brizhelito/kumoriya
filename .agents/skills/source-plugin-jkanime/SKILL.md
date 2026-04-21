---
name: source-plugin-jkanime
description: Implement or maintain Kumoriya JKAnime source plugin. Use for JKAnime search, detail, episode listing, defensive HTML parsing, fixtures, and plugin tests. Excludes playback and resolvers.
---

# Source Plugin JKAnime (Kumoriya)

Implement only JKAnime source-plugin behavior. Keep scope tight, parser robust, and tests real.

## Enforce boundaries first

1. Read `AGENTS.md` and respect plugin-first architecture.
2. Keep AniList as canonical metadata source.
3. Limit work to source plugin responsibilities:
   - search
   - minimal detail
   - real episodes
   - source parsing logic
4. Exclude playback and resolvers.
5. Prefer no-match/no-data over weak inferred results.

## Scope lock for each task

Before coding, publish:

```md
JKAnime Slice Scope
- Request:
- In scope:
- Out of scope (must include playback/resolvers):
- Done when:
```

If user asks mixed scope, split and implement only the source-plugin part.

## Review source plugin contracts

Identify and validate contracts before touching scraper code.

1. Locate plugin-facing interfaces and models used by JKAnime source package.
2. Confirm required fields and invariants for:
   - search result item
   - anime detail (minimal)
   - episode entries
3. Keep mapping explicit from JKAnime raw fields to contract model.
4. If JKAnime data is missing/ambiguous, return empty/none with typed error or safe fallback defined by contract.

Output:

```md
Contract Review
- interface/model:
- required fields:
- parser source:
- failure behavior:
```

## Implement robust scraping and defensive parsing

Use maintainable selectors and parser helpers.

1. Prefer semantic anchors (URL patterns, stable attributes, section labels) over fragile nth-child chains.
2. Normalize text before comparisons (trim, whitespace collapse, case folding, punctuation normalization as needed).
3. Parse defensively:
   - guard null/empty nodes
   - validate URL/id extraction
   - avoid throwing on optional blocks
4. Preserve deterministic behavior for partial HTML changes.
5. Keep parser functions small and testable; separate fetch from parse where practical.

## Fixture policy for JKAnime

Create fixtures when parser logic is non-trivial or bug-prone.

1. Capture representative HTML for:
   - search page
   - anime detail page
   - episode listing page
2. Store fixtures in plugin test resources using repo conventions.
3. Keep fixture names descriptive and stable.
4. Add focused fixtures for known edge cases (missing poster, alt title, unusual episode markup).

Output:

```md
Fixture Plan
- fixture file:
- source page type:
- scenario covered:
```

## Testing requirements (plugin-focused)

Run tests that prove contract compliance and parser resilience.

Minimum test set:
1. Search parsing test:
   - valid query returns expected mapped items
   - ambiguous/weak inputs can return empty safely
2. Detail parsing test:
   - minimal required fields parsed
   - missing optional blocks do not crash
3. Episode parsing test:
   - extracts real ordered episodes from fixture
   - malformed nodes are skipped safely
4. Integration-level plugin test (if repo has it):
   - source plugin method outputs contract-valid objects

Validation commands (adapt paths to package):

```md
Validation Checklist
- [ ] dart format <affected paths>
- [ ] dart analyze <affected package>
- [ ] dart test <plugin package or targeted tests>
```

Do not claim completion without executed commands and observed results.

## Limitation logging

Document known JKAnime constraints after each change.

Include:
1. What cannot be guaranteed (selector volatility, missing metadata, anti-bot behavior).
2. Which fallbacks exist.
3. What intentionally returns no-match/no-data.

Output:

```md
Plugin Limitations
- limitation:
- impact:
- mitigation:
```

## Final report template

```md
JKAnime Plugin Report
- Scope executed:
- Contracts touched:
- Files changed:
- Fixtures added/updated:
- Tests run:
  - command:
  - result:
- Limitations documented:
- Residual risk:
```
