# JKAnime Dynamic Source Audit (2026-03-08)

## Episode audited
- `https://jkanime.net/jigokuraku-2nd-season/1/`

## Key finding
- Static HTTP payload exposes only `video[0]` and `video[1]` (`um`/`umv` wrappers).
- Browser runtime state exposes all source buttons and `window.video` indexes `0..10`.
- Same page contains `var servers = [...]` where `remote` values are base64-encoded source URLs.

## Practical extraction mechanism
- Existing static extraction from `video[index]` still works for Desu/Magi.
- Missing hosts can be discovered by decoding:
  - `var servers[n].remote` (base64 URL)
  - `var servers[n].server` (visual label)
  - `var servers[n].lang` (language hint)

## Safety note
- A visible button is not enough evidence by itself.
- Extraction should only output links when:
  - `video[index]` yields a valid URL, or
  - `servers[n].remote` decodes into a valid HTTP(S) URL.
