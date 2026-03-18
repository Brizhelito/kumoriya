---
description: "Run a coordinated AniList-to-source matching audit with evidence-driven search-surface review, existence verification, calibration, and regression gating. Includes Anime Nexus by default."
agent: "matching-orchestrator"
argument-hint: "Describe the matching goal, source plugins, AniList sample scope, and required output"
---

Run a premium AniList-to-source matching audit for Kumoriya.

Non-negotiable requirements:

- Include `anime_nexus` in the audit scope unless I explicitly exclude it.
- Treat AniList as canonical metadata.
- Prefer no-match over false match.
- Do not claim 100 percent accuracy beyond the evidence actually audited.
- Verify whether each source should use HTML search, direct search APIs, undocumented JSON search endpoints, or autocomplete.
- Distinguish true catalog absence from search weakness, alias weakness, grouped entries, season splits, ambiguity, or transport failure.

Execution requirements:

1. Publish the scope first using:

```md
Matching Program Scope
- Target plugins:
- AniList population:
- Evidence sources:
- In scope:
- Out of scope:
- Acceptance rule:
```

2. Parallelize the discovery phase across specialist agents where safe:
   - query strategy
   - source search-surface audit
   - source catalog existence verification

3. For each source, decide and justify the preferred search path in this order when supported by evidence:
   - direct documented API
   - stable undocumented API
   - autocomplete endpoint
   - HTML search route

4. Merge the evidence and classify misses precisely.

5. Run matcher calibration only after the discovery outputs are stable enough to explain misses and false positives.

6. End with a regression gate that states what datasets, fixtures, tests, or scorecards must protect the improvement.

Required output:

- per-source search-surface decision
- Anime Nexus findings explicitly called out
- confirmed-present vs confirmed-absent taxonomy
- key false-positive traps
- calibration recommendations
- regression requirements
- residual risk

My audit request:

{{input}}
