---
name: anilist-matching
description: >-
  This skill should be used when building, refining, debugging, or reviewing
  AniList-to-source matching logic in Kumoriya. Covers conservative title
  matching, string normalization pipelines, alias handling, year/format
  conflict detection, confidence scoring, match/no-match decision policies,
  explainability of verdicts, table-driven acceptance/rejection tests, and
  false-positive prevention. Triggers on mentions of matching heuristics,
  entity resolution, title similarity, AniList linking, SeriesEntityResolver,
  HybridSeriesScorer, SeriesFingerprint, MatchingConfig, or candidate scoring.
---

# anilist-matching

## Purpose

Implement and maintain conservative matching between AniList canonical metadata and noisy scraped source catalogs. The goal is to link an AniList anime entry to the correct source catalog entry with high confidence, or explicitly reject the match. This skill covers the entire matching pipeline: normalization, blocking, scoring, decision, and explainability. It exists because false matches cause users to watch the wrong anime, which is worse than showing no match at all.

## Use When

- Implementing new matching heuristics or scoring logic in `kumoriya_matching`.
- Modifying `SeriesEntityResolver`, `HybridSeriesScorer`, `SeriesFingerprint`, or `MatchingConfig`.
- Adding or changing normalization steps in `SeriesFingerprintBuilder`.
- Adjusting match/reject thresholds or ambiguity detection.
- Writing or updating matching tests (acceptance and rejection cases).
- Debugging why a specific anime fails to match or matches incorrectly.
- Reviewing a PR that touches `packages/kumoriya_matching/`.
- Integrating a new source plugin that needs matching calibration.
- Working on `AnilistSourceMatcher` in `apps/kumoriya_app/lib/src/features/anime_catalog/application/matching/`.

## Do Not Use When

- Implementing source plugin scraping logic (use `source-plugin-jkanime` or equivalent).
- Working on resolver plugins (use `resolver-plugin`).
- Making architecture decisions about package boundaries (use `kumoriya-architecture`).
- Implementing player features (use `player-slice`).
- Doing UI/UX work (use `uiux-review`).
- The task is purely about AniList API integration without matching logic.

## What This Skill Does

1. Enforces AniList as the canonical metadata source for all matching decisions.
2. Requires string normalization before any comparison: Unicode NFC, lowercase, whitespace collapse, safe punctuation removal, separator normalization.
3. Requires that only trustworthy aliases participate in matching (AniList native/romaji/english titles and synonyms from AniList metadata, not invented aliases).
4. Implements a weighted scoring model with explicit signal categories: strong (high title similarity), supporting (alias alignment, year agreement, format agreement), and rejection (year conflict, format conflict, ambiguous ties).
5. Enforces the decision policy: accept only when strong lexical signal exists and no material conflict; otherwise reject.
6. Requires explainability: every match decision must produce a structured record with AniList ID/title, candidate source ID/title, signals for acceptance, signals for rejection, confidence band, verdict, and reason.
7. Requires that confidence is categorical (`high`, `medium`, `low`) and conservative: `high` = clear unique alignment with no conflicts; `medium` = partial alignment, usually reject; `low` = weak/noisy, always reject.
8. Requires table-driven tests covering: exact true positive, alias-based true positive, title-similar false positive prevention, year/type conflict rejection, ambiguous multi-candidate tie rejection, empty/partial metadata safety.
9. Documents current matching limitations (missing year in source, alias sparsity, generic franchise titles) and their impact on verdicts.
10. Prevents silent auto-linking: if confidence is not `high` with `autoMatch` verdict, no link is created without explicit user review.

## Required Inputs

- Access to `packages/kumoriya_matching/` source code.
- Access to `apps/kumoriya_app/lib/src/features/anime_catalog/application/matching/anilist_source_matcher.dart`.
- Knowledge of the `SeriesEntityResolver<T>` generic pipeline: `SeriesCandidateIndex` for blocking, `HybridSeriesScorer` for scoring, `MatchingConfig` for thresholds.
- Knowledge of `SeriesFingerprint` structure (normalized titles, aliases, year, format).
- Knowledge of `SeriesMatchDecision` output (verdict: `autoMatch`/`reviewNeeded`/`reject`, `bestScore`, `reasons`, `topCandidates`).
- Knowledge of `MatchReasonCode` enum values and their semantic meaning.
- Representative AniList entries and source catalog entries for the anime being matched (or fixtures simulating them).

## Preconditions

- `packages/kumoriya_matching/` compiles without errors.
- Existing matching tests pass before modifications begin.
- The agent has read the current `MatchingConfig` default thresholds (autoMatch, reviewNeeded, ambiguityDelta).

## Procedure

1. **Read current matching implementation.** Open `series_entity_resolver.dart`, `hybrid_series_scorer.dart`, `series_fingerprint_builder.dart`, and `matching_config.dart`. Understand current thresholds, scoring weights, and decision logic.

2. **Identify the matching change needed.** State precisely: what signal is missing, what false positive occurs, what threshold needs adjustment, or what normalization step is needed.

3. **Publish scope lock.**
   ```
   Matching Scope
   - Target flow: [specific matching scenario]
   - In scope: [specific files/logic to change]
   - Out of scope: [everything else]
   - Acceptance rule: [what makes this change correct]
   ```

4. **Implement normalization changes (if needed).** Modify `SeriesFingerprintBuilder`. Each normalization step must be documented and testable independently. Do not apply destructive transformations that erase semantic meaning (e.g., removing all numbers, stripping season indicators).

5. **Implement scoring/decision changes (if needed).** Modify scorer or resolver. Keep scoring deterministic. Every reason code must map to a concrete signal. Do not add opaque weighted bonuses without a named reason code.

6. **Add or update table-driven tests.** Each test case must specify: AniList input fingerprint, source candidates, expected verdict, expected confidence band, expected rejection reason (when no-match). Include at minimum:
   - One exact match true positive.
   - One alias-based true positive with supporting signals.
   - One near-miss false positive that must be rejected.
   - One year/format conflict that must be rejected.
   - One ambiguous tie that must be rejected.
   - One empty/partial source metadata case that must be handled safely.

7. **Run validation.**
   ```
   dart format packages/kumoriya_matching/
   dart analyze packages/kumoriya_matching/
   dart test packages/kumoriya_matching/
   ```

8. **Produce match decision report** for the specific scenario being worked on, using the explainability format.

## Required Checks

- [ ] `dart format packages/kumoriya_matching/` passes.
- [ ] `dart analyze packages/kumoriya_matching/` reports no issues.
- [ ] `dart test packages/kumoriya_matching/` all tests pass.
- [ ] At least one no-match rejection test exists for every new acceptance heuristic.
- [ ] No heuristic was added without a corresponding `MatchReasonCode`.
- [ ] Thresholds changed are documented with before/after values and rationale.

## Expected Outputs

- Modified matching logic (normalization, scoring, or decision).
- Table-driven tests covering acceptance and rejection.
- Structured match decision report for the worked scenario.
- Limitation documentation for any known weakness.
- Validation evidence (commands run, pass/fail).

## Anti-Patterns

- **Silent auto-link on weak evidence.** Never create an automatic link when confidence is below `high` or verdict is not `autoMatch`.
- **Opaque scoring.** Never add score bonuses/penalties without a named `MatchReasonCode` that explains why.
- **Aggressive fuzzy matching.** Never use fuzzy thresholds so low that dissimilar titles match.
- **Inventing aliases.** Never generate synthetic aliases not present in AniList metadata.
- **Ignoring conflicts.** Never accept a match when year or format conflicts exist, even if title similarity is high.
- **Testing only happy paths.** Never ship matching changes without rejection test cases.
- **Destroying semantic content during normalization.** Never strip season numbers, part indicators, or format suffixes that differentiate entries.

## Constraints

- AniList is the sole canonical metadata source. No other metadata provider overrides it.
- `Result<T, KumoriyaError>` is the error handling pattern at domain boundaries.
- Matching logic lives in `packages/kumoriya_matching/`, not in UI or source plugins.
- The `SeriesEntityResolver` is generic (`<T>`); changes must not break other consumers.
- Thresholds in `MatchingConfig` must remain configurable, not hardcoded in scorer logic.
- Prefer no-match over false match in every ambiguous scenario.

## Minimal Example

Task: "Naruto Shippuden from JKAnime matches the wrong AniList entry (matches Naruto instead of Naruto: Shippuuden)."

1. Read `series_entity_resolver.dart` and `hybrid_series_scorer.dart`.
2. Scope lock: fix scoring to penalize partial title matches when a more specific candidate exists.
3. Add test case: AniList candidates `[Naruto (2002, TV), Naruto: Shippuuden (2007, TV)]`, source query `"Naruto Shippuden"`, expected verdict: `autoMatch` on Shippuuden, `reject` on Naruto.
4. Adjust scoring to boost exact substring match on disambiguating suffix.
5. Run `dart format`, `dart analyze`, `dart test` on `packages/kumoriya_matching/`.
6. Report: match decision with signals, confidence `high`, verdict `autoMatch` for Shippuuden.

## Definition of Done

- The specific matching scenario works correctly (verified by test).
- No existing passing test was broken.
- At least one rejection test covers the inverse of the new logic.
- All validation commands pass.
- Limitations are documented if the fix is partial.
- No opaque heuristic was introduced.

## Project Assumptions

- AniList metadata includes native, romaji, and english titles plus synonyms. **Risk: AniList may have sparse synonyms for niche anime.**
- Source catalogs provide at least one title string and optionally year/format. **Risk: some sources omit year and format entirely, reducing matching confidence.**
- `HybridSeriesScorer` uses Jaro-Winkler and token-set similarity as primary lexical metrics. Changes to the scorer affect all source plugin matching.
- `MatchingConfig` thresholds are calibrated for the current source plugin set. Adding a source with very different naming conventions may require threshold review.
