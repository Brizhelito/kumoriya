# Manual Search Calibration Report

Captured on March 12, 2026 with live Playwright evidence.

## Scope

- Sources sampled: JKAnime, anime.nexus
- Queries sampled: Frieren, Oshi no Ko, Demon Slayer, Naruto, Boruto, Suzume, Fate Stay Night, Pokemon
- Output dataset: [manual_search_seed_dataset_2026-03-12.json](/C:/Users/Reny/Documents/Kumoriya/docs/audits/matching/manual_search_seed_dataset_2026-03-12.json)

## Observations

- `Naruto` is a real false-positive trap on both sources. `Boruto` appears before `Naruto`, so sequel penalties must stay hard.
- `Demon Slayer` and `Frieren` confirm alias-driven positives are common and should remain first-class evidence.
- `Oshi no Ko` shows both exact season entries and grouped franchise entries; grouped season handling is necessary but should not erase season-aware candidates.
- `Fate Stay Night` is a real ambiguity cluster. Base route, UBW, season 2, and Heaven's Feel all co-occur. Review queue remains necessary.
- `Pokemon` is highly ambiguous in JKAnime and empty in anime.nexus. Generic franchise labels should not auto-link without year/alias support.
- `Suzume` shows an important source miss: anime.nexus returns no relevant result for a broad human query. Conservative no-match is safer than aggressive fuzzy fallback.

## Calibration Implications

- Keep `type_mismatch_penalty`, `year_mismatch_penalty`, and `season_conflict` as hard reject signals.
- Preserve a strong alias bonus for high-confidence canonical synonym hits.
- Keep grouped-season matches below blind auto-link unless season-aware evidence is also strong.
- Route franchise-root ambiguities like `Fate` and `Pokemon` to `review_needed`.
- Add search-query expansion later using canonical aliases and normalized variants before widening fuzzy thresholds.

## Recommended Next Step

Convert this seed dataset into executable matcher regression tests and a small calibration harness that reports predicted verdict vs labeled verdict per case.
