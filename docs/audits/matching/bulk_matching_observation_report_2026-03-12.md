# Bulk Matching Observation Report (2026-03-12)

- Dataset: `C:\Users\Reny\Documents\Kumoriya\docs\audits\matching\bulk_matching_observation_dataset_2026-03-12.json`
- Canonicals sampled from AniList trending: 200
- Target canonical count: 200
- Sources audited: jkanime, anime_nexus, animeflv, animeav1

## Source Summary

- `jkanime`
  - queries: 200
  - failures: 0
  - empty_results: 1
  - total_candidates: 579
  - auto_match: 147
  - review_needed: 15
  - reject: 38
- `anime_nexus`
  - queries: 200
  - failures: 12
  - empty_results: 0
  - total_candidates: 641
  - auto_match: 150
  - review_needed: 6
  - reject: 32
- `animeflv`
  - queries: 200
  - failures: 0
  - empty_results: 11
  - total_candidates: 502
  - auto_match: 128
  - review_needed: 15
  - reject: 57
- `animeav1`
  - queries: 200
  - failures: 0
  - empty_results: 1
  - total_candidates: 941
  - auto_match: 144
  - review_needed: 12
  - reject: 44

## Review Needed Sample

- `anime_nexus` | `Jujutsu Kaisen: Shimetsu Kaiyuu - Zenpen` -> `Jujutsu Kaisen: The Culling Game Part 1` (73.82876841666118)
- `animeflv` | `Enen no Shouboutai: San no Shou Part 2` -> `Enen no Shouboutai: San no Shou` (69.09036367904292)
- `jkanime` | `Yuusha Party ni Kawaii Ko ga Ita no de, Kokuhaku Shitemita.` -> `Yuusha Party ni Kawaii Ko ga Ita node, Kokuhaku shitemita.` (72.52254389868753)
- `animeflv` | `Yuusha Party ni Kawaii Ko ga Ita no de, Kokuhaku Shitemita.` -> `Yuusha Party ni Kawaii Ko ga Ita node, Kokuhaku shitemita.` (72.52254389868753)
- `animeav1` | `Yuusha Party ni Kawaii Ko ga Ita no de, Kokuhaku Shitemita.` -> `Yuusha Party ni Kawaii Ko ga Ita node, Kokuhaku shitemita.` (72.52254389868753)
- `animeflv` | `Sono Bisque Doll wa Koi wo Suru Season 2` -> `Sono Bisque Doll wa Koi wo Suru` (72.42929851510496)
- `jkanime` | `Boku no Hero Academia 7` -> `Boku no Hero Academia 7th Season` (72.8022641509434)
- `animeav1` | `Boku no Hero Academia 7` -> `Boku no Hero Academia 7th Season` (72.8022641509434)
- `jkanime` | `Re:Zero kara Hajimeru Isekai Seikatsu 4th Season` -> `Re:Zero kara Hajimeru Isekai Seikatsu` (72.08586072817249)
- `anime_nexus` | `Re:Zero kara Hajimeru Isekai Seikatsu 4th Season` -> `Re:ZERO -Starting Life in Another World-` (70.64185787790294)
- `animeflv` | `Re:Zero kara Hajimeru Isekai Seikatsu 4th Season` -> `Re:Zero kara Hajimeru Isekai Seikatsu` (72.08586072817249)
- `animeav1` | `Re:Zero kara Hajimeru Isekai Seikatsu 4th Season` -> `Re:Zero kara Hajimeru Isekai Seikatsu` (72.08586072817249)

## Search Errors

- `anime_nexus` | `Yuusha Party ni Kawaii Ko ga Ita no de, Kokuhaku Shitemita.` -> `anime_nexus.transport`: Anime Nexus search failed for "勇者パーティーにかわいい子がいたので、告白してみた。" (type=unknown): unknown transport error
- `anime_nexus` | `Ansatsusha de Aru Ore no Status ga Yuusha yori mo Akiraka ni Tsuyoi no da ga` -> `anime_nexus.transport`: Anime Nexus search failed for "暗殺者である俺のステータスが 勇者よりも明らかに強いのだが" (type=unknown): unknown transport error
- `anime_nexus` | `Isekai de Cheat Skill wo Te ni Shita Ore wa, Genjitsu Sekai wo mo Musou Suru: Level Up wa Jinsei wo Kaeta` -> `anime_nexus.transport`: Anime Nexus search failed for "異世界でチート能力を手にした俺は、現実世界をも無双する ～レベルアップは人生を変えた～" (type=unknown): unknown transport error
- `anime_nexus` | `Prism Rondo` -> `anime_nexus.transport`: Anime Nexus search failed for "プリズム輪舞曲" (type=unknown): unknown transport error
- `anime_nexus` | `Junket Bank` -> `anime_nexus.transport`: Anime Nexus search failed for "ジャンケットバンク" (type=unknown): unknown transport error
- `anime_nexus` | `Youkoso Jitsuryoku Shijou Shugi no Kyoushitsu e 4th Season 2-nensei-hen Ichi Gakki` -> `anime_nexus.transport`: Anime Nexus search failed for "4th 2nd season 1" (type=unknown): unknown transport error
- `anime_nexus` | `Vanitas no Carte` -> `anime_nexus.transport`: Anime Nexus search failed for "ヴァニタスの手記" (type=unknown): unknown transport error
- `anime_nexus` | `Golden Time` -> `anime_nexus.transport`: Anime Nexus search failed for "ゴールデンタイム" (type=unknown): unknown transport error
- `anime_nexus` | `Kanan-sama wa Akumade Choroi` -> `anime_nexus.transport`: Anime Nexus search failed for "カナン様はあくまでチョロい" (type=unknown): unknown transport error
- `anime_nexus` | `Kono Kaisha ni Suki na Hito ga Imasu` -> `anime_nexus.transport`: Anime Nexus search failed for "この会社に好きな人がいます" (type=unknown): unknown transport error
- `anime_nexus` | `Kubo-san wa Mob wo Yurusanai` -> `anime_nexus.transport`: Anime Nexus search failed for "久保さんは僕を許さない" (type=unknown): unknown transport error
- `anime_nexus` | `Tomodachi Game` -> `anime_nexus.transport`: Anime Nexus search failed for "トモダチゲーム" (type=unknown): unknown transport error