---
name: anilist-matching
description: Strict AniList-to-source matching for Kumoriya. Use for matching heuristics, title normalization, confidence rules, and match/no-match tests. Prefer no-match over false positive.
---

# AniList Matching (Kumoriya)

Build conservative matching only. Prefer no-match over false match.

## Apply strict constraints

1. Treat AniList as canonical metadata source.
2. Never auto-link on weak evidence.
3. Reject aggressive fuzzy logic without clear guardrails.
4. Use deterministic normalization and explainable decisions.
5. If confidence is uncertain, return no-match.

## Scope lock for each matching task

Publish this block before coding:

```md
Matching Scope
- Target flow:
- In scope:
- Out of scope:
- Acceptance rule:
```

Keep scope on matching logic and tests only.

## Candidate preparation

1. Build candidate set from scraped source records.
2. Normalize candidate and AniList strings before comparison.
3. Use only reasonable aliases/synonyms:
   - AniList native/romaji/english titles
   - trusted synonyms already present in AniList metadata
4. Do not invent synthetic aliases from unrelated transformations.

## Normalization rules (conservative)

Apply stable normalization steps:
1. Unicode normalize and lowercase.
2. Trim and collapse whitespace.
3. Remove low-signal punctuation.
4. Normalize separators (`-`, `_`, `/`, `:`) into spaces where safe.
5. Avoid destructive transformations that erase semantic meaning.

Document exactly which normalization operations are active.

## Heuristic decision policy

Use weighted but conservative evidence:
1. Strong signal:
   - high similarity on primary title after normalization
2. Supporting signal:
   - alias/synonym alignment
   - year agreement (if available)
   - format/type agreement (TV, movie, OVA, etc.) when available
3. Rejection signal:
   - conflicting year/type on near-title match
   - only weak alias hit without title support
   - ambiguous ties across multiple candidates

Decision rule:
- Accept only when strong signal exists and no material conflict.
- Otherwise reject with no-match.

## Explainability requirements

Every decision must be auditable.

Output this structure:

```md
Match Decision
- AniList id/title:
- Candidate source id/title:
- Signals for acceptance:
- Signals for rejection:
- Confidence:
- Verdict: match | no-match
- Reason:
```

Confidence must be categorical (`high`, `medium`, `low`) and conservative:
- `high`: clear unique alignment, no conflicts
- `medium`: partial alignment; usually reject unless policy explicitly allows
- `low`: weak/noisy evidence; reject

## Test strategy (must include no-match cases)

Minimum required tests:
1. Exact/near-exact true positive with consistent year/type.
2. Alias-based true positive with strong supporting signals.
3. Title-similar false positive prevention (must return no-match).
4. Year/type conflict case (must return no-match).
5. Ambiguous multi-candidate tie (must return no-match).
6. Empty/partial source metadata case (must return no-match safely).

Prefer table-driven tests that enumerate:
- AniList input
- source candidates
- expected verdict
- expected confidence band
- expected rejection reason when no-match

## Validation checklist

```md
Validation Checklist
- [ ] dart format <affected paths>
- [ ] dart analyze <affected package>
- [ ] dart test <matching tests>
```

Do not claim robustness if no-match defenses were not tested.

## Limitation reporting

Always document current limits:

```md
Matching Limitations
- limitation:
- effect on verdicts:
- conservative fallback:
```

Examples:
- missing year/type in source
- alias sparsity in AniList entry
- highly generic titles across franchises

## Final report template

```md
AniList Matching Report
- Scope executed:
- Heuristics implemented/changed:
- Decision policy:
- Tests added/updated:
- Validation run:
  - command:
  - result:
- False-positive defenses:
- Known limitations:
- Residual risk:
```
