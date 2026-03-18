---
description: "Build a browser-validated AniList-to-source dataset with at least 40 anime, including the manual search seed and Anime Nexus evidence."
agent: "browser-matching-dataset-validator"
argument-hint: "Describe the sources, target sample size, and desired output files"
---

Build a browser-validated AniList-to-source matching dataset for Kumoriya.

Non-negotiable requirements:

- Include at least 40 anime.
- Include every case from `docs/audits/matching/manual_search_seed_dataset_2026-03-12.json`.
- Include `anime_nexus` in the audit scope unless I explicitly exclude it.
- Use the integrated browser for live validation when labels are not already strong.
- Produce both a dataset file and a human-readable report under `docs/audits/matching/`.

Execution requirements:

1. Publish the dataset scope first using:

```md
Browser Dataset Scope
- Sources:
- Minimum anime count:
- Seed datasets included:
- Sampling strategy:
- Output files:
- Acceptance rule:
```

2. Start from the manual seed titles and extend to a balanced sample of at least 40 anime.

3. Ensure the extended sample includes:
   - exact positives
   - alias positives
   - grouped ambiguities
   - sequel traps
   - movie versus TV conflicts
   - empty or failed search cases

4. Use browser evidence to validate search ranking, candidate identity, and when necessary detail-page confirmation.

5. Label each case explicitly and record the reasons.

6. End with a report that summarizes:
   - per-source counts
   - Anime Nexus findings
   - ambiguous clusters
   - transport failures
   - dataset limitations
   - next calibration targets

My dataset request:

{{input}}
