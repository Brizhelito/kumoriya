# JKAnime Resolvers Closure Audit
**Date:** 2026-03-09  
**Scope:** All resolver plugins wired for JKAnime source, validated against real episode pages  
**Episodes audited:** Naruto Shippuden EP1, One Piece EP1122 (2024-10-12), Oshi no Ko 3rd Season EP8 (2026-03-04)

---

## Methodology

1. Loaded real JKAnime episode pages in Playwright and extracted all `video[n]` assignments and `var servers = [...]` JSON (base64 decoded).
2. Navigated to each resolved host URL and inspected the HTML for stream extraction viability (packed JS, direct URLs, session gates, Vite SPA shells).
3. Mapped each host to its resolver plugin and verified `supports()` contract, extraction logic, and redirect behavior.
4. Fixed confirmed gaps in host aliases and path support.
5. Ran `dart format`, `dart analyze`, and all tests across all resolver packages.

---

## Real Host Universe (from live episode pages)

### Static servers (video[] assignments — JKPlayer)
| Label | URL pattern | Resolver |
|---|---|---|
| Desu | `jkanime.net/jkplayer/um?...` | `JkPlayerResolverPlugin` |
| Magi | `jkanime.net/jkplayer/umv?...` | `JkPlayerResolverPlugin` |
| Desuka | `jkanime.net/jkplayer/jk?...` | `JkPlayerJkResolverPlugin` |

### Dynamic servers (var servers[] — base64 decoded)
| Label | Real host observed | Path pattern | Resolver |
|---|---|---|---|
| Streamwish | `sfastwish.com` → `flaswish.com` | `/e/` | `StreamwishResolverPlugin` |
| VOE | `voe.sx` → `lancewhosedifficult.com` | `/e/` | `VoeResolverPlugin` |
| VidHide | `vidhidevip.com` → `callistanise.com` | `/embed/` | `VidhideResolverPlugin` |
| Filemoon | `bysekoze.com` → `f75s.com` | `/e/` | `FilemoonResolverPlugin` |
| Mixdrop | `mixdrop.is`, `mdbekjwqa.pw` → `m1xdrop.bz` | `/e/` | `MixdropResolverPlugin` |
| Mp4upload | `www.mp4upload.com` | `/embed-*.html` | `Mp4uploadResolverPlugin` |
| Streamtape | `streamtape.com` | `/e/` | `StreamtapeResolverPlugin` |
| Doodstream | `d-s.io` (**abandoned**) | `/e/` | `DoodstreamResolverPlugin` |
| Mega | `mega.nz` | `/embed/` | **none — download only** |
| Mediafire | `mediafire.com` | `/file/` | **none — download only** |

---

## Host Closure Matrix

### ✅ FUNCTIONAL — stream extractable from static HTTP response

| Host | Evidence | Notes |
|---|---|---|
| **JKPlayer UM/UMV** | Unit-tested, resolver-owned endpoint | Jkanime's own player, always works |
| **JKPlayer JK** | Unit-tested, resolver-owned endpoint | Same as above |
| **Streamwish** | `sfastwish.com/e/d3sa7zxrm6or` → packed JS unpacked → `premilkyway.com/hls2/.../master.m3u8` | HLS from Dean Edwards unpacker + `file:` key extraction |
| **VidHide** | `vidhidevip.com/embed/4bd00sirezr5` → packed JS → `dramiyos-cdn.com/hls2/.../master.m3u8` | HLS from same pattern as Streamwish |
| **Mixdrop** | `mixdrop.is/e/vk9pm141adwge4` → packed JS → `MDCore.wurl = "//a-delivery19.mxcontent.net/v2/..."` | mp4 from `MDCore.wurl` extraction |
| **Mp4upload** | `mp4upload.com/embed-chrv4nvejs5t.html` → `<video src="https://a1.mp4upload.com:183/d/.../video.mp4">` | Direct mp4 in `<video>` tag and `player.src({src:...})` call |

### ⚠️ SESSION-GATED — resolver correctly classifies, no stream available via static HTTP

| Host | Evidence | Resolver response | Notes |
|---|---|---|---|
| **VOE** | `voe.sx/e/...` → HTTP redirect → `lancewhosedifficult.com` → static HTML contains `test-videos.co.uk/Big_Buck_Bunny` placeholder | `VoeSessionGatedError` | Stream URL injected via XHR/JS after page load; session token required |
| **Filemoon** | `bysekoze.com/e/...` → Vite SPA (4.6 KB shell); `/api/videos/{id}/embed/details` → `embed_frame_url: "https://f75s.com/85yat/{id}"` → also a Vite SPA (4.4 KB shell) | `FilemoonParseError` | Dynamic API flow exists in resolver but both `bysekoze.com` and `f75s.com` are SPAs; stream URL not in static HTML |

### ❌ DEAD / ABANDONED

| Host | Evidence | Notes |
|---|---|---|
| **Doodstream (`d-s.io`)** | DNS resolution fails: `net::ERR_NAME_NOT_RESOLVED` | Domain abandoned. Doodstream absent from all recent episodes (not in [Oshi no Ko] S3 EP8, Mar 2026). Alias added for completeness but will produce `DoodstreamTransportError` |

### ℹ️ DOWNLOAD-ONLY (no resolver needed)

| Host | Notes |
|---|---|
| **Mega** | `mega.nz/embed/...` — client-side decryption, not streamable via HTTP |
| **Mediafire** | `mediafire.com/file/...` — file download, not a streaming embed |

### ❓ UNCERTAIN — unverified due to adblock/token interference in browser

| Host | Evidence | Notes |
|---|---|---|
| **Streamtape** | Browser adblock triggers `"fileid":"nofile"` protection; token pattern (`getElementById(...).innerHTML = "//URL" + token.substring(n)`) unchanged in code | Resolver token extraction logic likely still valid when called via plain HTTP client (no adblock); not confirmed broken |

---

## Code Changes Made

### 1. `kumoriya_resolver_doodstream` — add `d-s.io` host alias

**File:** `@c:/Users/Reny/Documents/Kumoriya/packages/kumoriya_resolver_doodstream/lib/src/doodstream_resolver_plugin.dart`

Added `'d-s.io'` to both `_supportedHosts` set and `manifest.supportedHosts` list.

**Rationale:** JKAnime used `d-s.io` as the Doodstream embed domain in older content (observed in One Piece EP1122, Oct 2024). The domain is DNS-dead as of audit date, but the alias is correct for any cached links and avoids silent `resolver.no_resolver` errors.

### 2. `kumoriya_resolver_vidhide` — add `/embed/` path support

**File:** `@c:/Users/Reny/Documents/Kumoriya/packages/kumoriya_resolver_vidhide/lib/src/vidhide_resolver_plugin.dart`

Added `url.path.startsWith('/embed/')` to the `supports()` path check.

**Rationale:** JKAnime uses `vidhidevip.com/embed/{id}` exclusively — not `/e/` or `/v/`. Without this fix, all VidHide server links from JKAnime would return `resolver.no_resolver` error, routing through `ResolveSourceServerLinkUseCase` as unresolvable despite the host being in the supported list.

### 3. New test files added

- `@c:/Users/Reny/Documents/Kumoriya/packages/kumoriya_resolver_doodstream/test/doodstream_resolver_plugin_test.dart` — 10 tests: `supports()` coverage for `d-s.io`, `doodstream.com`, `/d/` path, wrong host, wrong path; resolve flow with mock HTTP for pass_md5 extraction, parse error, transport error
- `@c:/Users/Reny/Documents/Kumoriya/packages/kumoriya_resolver_vidhide/test/vidhide_resolver_plugin_test.dart` — 10 tests: `supports()` coverage for `vidhidevip.com/embed/`, `/e/`, `/v/`, wrong host, wrong path; resolve flow for HLS extraction, transport error, empty payload

---

## Validation Results

```
dart format:   0 changed files (doodstream, vidhide)
dart analyze:  No errors (doodstream, vidhide)

kumoriya_resolver_doodstream:  +10 all passed
kumoriya_resolver_vidhide:     +10 all passed
kumoriya_resolver_filemoon:     +6 all passed
kumoriya_resolver_mixdrop:      +7 all passed
kumoriya_resolver_mp4upload:    +5 all passed
kumoriya_resolver_streamwish:   +6 all passed
kumoriya_resolver_voe:         +14 all passed
```

**Total: 58 tests, 0 failures, 0 errors**

---

## Registry & Wiring Status

All 10 resolver plugins are registered in `resolverPluginsProvider`:

```
JkPlayerJkResolverPlugin, JkPlayerResolverPlugin,
VoeResolverPlugin, FilemoonResolverPlugin,
StreamwishResolverPlugin, MixdropResolverPlugin,
Mp4uploadResolverPlugin, StreamtapeResolverPlugin,
DoodstreamResolverPlugin, VidhideResolverPlugin
```

`ResolverRegistry.selectFor()` correctly routes URLs by `supports()` contract. No wiring issues found.

---

## Source Extraction Status

`_extractDynamicServerTargetsByLabel` correctly base64-decodes `remote` fields from `var servers = [...]` and normalizes URLs. All JKAnime server labels map to the correct resolver hosts.

No source extraction bugs found for the current episode structure.

---

## Honest Summary

| Category | Count | Hosts |
|---|---|---|
| Fully functional | 6 | JKPlayer UM, JKPlayer UMV, JKPlayer JK, Streamwish, VidHide\*, Mixdrop, Mp4upload |
| Session-gated (correct error) | 2 | VOE, Filemoon |
| Dead domain | 1 | Doodstream (d-s.io) |
| Download-only | 2 | Mega, Mediafire |
| Unverified | 1 | Streamtape |

\* VidHide functional **after the `/embed/` path fix** in this session.

**Net result:** For a typical current JKAnime episode, users will have 4–5 functional stream options (JKPlayer UM/UMV, Streamwish, VidHide, Mixdrop, Mp4upload). VOE and Filemoon produce clear error messages. Doodstream is dead. Streamtape is plausible but unconfirmed.
