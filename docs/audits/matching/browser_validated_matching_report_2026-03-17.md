# Browser-Validated AniList-to-Source Matching Report

Captured on March 17, 2026 with integrated browser evidence.

## Scope

- Sources: AnimeFLV, JKanime, AnimeAV1, Anime Nexus
- Manual seed rows preserved: 19
- Browser audit sample: 44 canonical anime across 176 source observations
- Sampling strategy: start from the manual seed, then extend with exact positives, alias-driven positives, grouped ambiguities, sequel traps, movie-versus-TV conflicts, and empty or failed search cases.

## Per-Source Counts

- jkanime: match=41, reject=3, review_needed=0, confirmed_absent=0, search_failed_query_strategy=0, search_failed_transport=0
- animeflv: match=29, reject=6, review_needed=1, confirmed_absent=0, search_failed_query_strategy=8, search_failed_transport=0
- animeav1: match=34, reject=6, review_needed=3, confirmed_absent=0, search_failed_query_strategy=1, search_failed_transport=0
- anime_nexus: match=41, reject=1, review_needed=0, confirmed_absent=0, search_failed_query_strategy=2, search_failed_transport=0

## Anime Nexus Findings

- Anime Nexus produced 41 matches across the 44-title browser sample.
- The recurring misses on Anime Nexus cluster around alias-only searches such as Pokemon, Suzume, and A Silent Voice where the API returned no usable candidate for the chosen human query.
- Anime Nexus exact confirmations improved after source-specific follow-up on My Hero Academia Season 7 and Demon Slayer: Kimetsu no Yaiba - The Movie: Infinity Train.
- Baki was kept as a confirmed source-side title mapping for the audited Anime Nexus row.
- Pocket Monsters (2023): search_failed_query_strategy via alias_query_no_candidates
- Suzume no Tojimari: reject via franchise_false_positive; strongest candidate was Sakugan
- Koe no Katachi: search_failed_query_strategy via alias_query_no_candidates
- Boku no Hero Academia 7: match via browser_match; strongest candidate was My Hero Academia Season 7
- Kimetsu no Yaiba Movie: Mugen Ressha-hen: match via browser_match; strongest candidate was Demon Slayer: Kimetsu no Yaiba - The Movie: Infinity Train
- BAKI-DOU: match via source_title_mapping_confirmed; strongest candidate was Baki

## Confirmed Grouped Entries

- animeflv / Oshi no Ko 2nd Season: [Oshi No Ko] remains a grouped catalog page, but the season content was confirmed on that entry.
- animeflv / [Oshi no Ko] 3rd Season: [Oshi No Ko] remains a grouped catalog page, but the season content was confirmed on that entry.
- animeav1 / 86: Eighty Six: the 86 page was confirmed to carry the relevant grouped season content.
- animeav1 / 86: Eighty Six Part 2: the 86 page was confirmed to carry the second-season content.

## Ambiguous Clusters

- animeflv / Boku no Hero Academia: Boku no Hero Academia 4th Season at rank 1; same_franchise_root, rank_1, type_aligned, needs_detail_confirmation
- animeav1 / Boku no Hero Academia: Boku no Hero Academia: Final Season at rank 2; same_franchise_root, rank_2, type_aligned, higher_ranked_competitors_present, needs_detail_confirmation
- animeav1 / Boku no Hero Academia 7: Boku no Hero Academia 7th Season at rank 5; same_franchise_root, rank_5, type_aligned, higher_ranked_competitors_present, needs_detail_confirmation
- animeav1 / Spy x Family Season 2: Spy x Family Part 2 at rank 4; same_franchise_root, rank_4, type_aligned, higher_ranked_competitors_present, needs_detail_confirmation

## Transport Failures

- No reproducible transport failures occurred during the March 17 browser audit batches.

## Dataset Limitations

- Many source misses are query-strategy misses, not confirmed catalog absence, because the audit intentionally exercised human alias queries rather than exhaustive fallback expansion.
- Only search-surface evidence was needed for most rows; ambiguous franchise clusters remain labeled conservatively as review_needed instead of being forced into auto-match decisions.
- AnimeFLV, JKanime, and AnimeAV1 browser evidence was collected from live HTML search pages; Anime Nexus evidence was collected from the live search API surface exposed to the browser.
- Manual seed cases remain included separately so their original labels are not overwritten by this broader sample.

## Next Calibration Targets

- Add controlled query expansion for alias-heavy misses: Pokemon Horizons, Suzume no Tojimari, and Koe no Katachi.
- Tighten grouped-entry handling for Oshi no Ko, My Hero Academia, 86, and Spy x Family so season-aware candidates beat franchise-root entries without over-linking.
- Keep hard penalties for sequel and movie/TV traps visible in Naruto, Frieren, Chainsaw Man, and Demon Slayer search rankings.
- Promote detail-page follow-up only for review_needed clusters instead of broadening fuzzy thresholds globally.

## Failure Sample

- animeflv / Suzume no Tojimari: search_failed_query_strategy (alias_query_no_candidates)
- animeflv / 86: Eighty Six: search_failed_query_strategy (alias_query_no_candidates)
- animeflv / 86: Eighty Six Part 2: search_failed_query_strategy (alias_query_no_candidates)
- animeflv / Ansatsu Kyoushitsu: search_failed_query_strategy (alias_query_no_candidates)
- animeflv / Ansatsu Kyoushitsu 2nd Season: search_failed_query_strategy (alias_query_no_candidates)
- animeflv / Boku dake ga Inai Machi: search_failed_query_strategy (alias_query_no_candidates)
- animeflv / Chi. Chikyuu no Undou ni Tsuite: search_failed_query_strategy (alias_query_no_candidates)
- animeflv / Koe no Katachi: search_failed_query_strategy (alias_query_no_candidates)
- animeav1 / Pocket Monsters (2023): search_failed_query_strategy (alias_query_no_candidates)
- anime_nexus / Pocket Monsters (2023): search_failed_query_strategy (alias_query_no_candidates)
- anime_nexus / Koe no Katachi: search_failed_query_strategy (alias_query_no_candidates)
