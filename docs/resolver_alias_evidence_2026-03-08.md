# Resolver Alias Evidence (2026-03-08)

## bysekoze.com -> Filemoon-equivalent
- Runtime audit (`jigokuraku-2nd-season` ep 1) reports:
  - `serverName: Filemoon`
  - `detectedHost: bysekoze.com`
  - `initialUrl: https://bysekoze.com/e/wl5t0od7nc7l/`
  - `supports: ["kumoriya.resolver.filemoon"]`
- Live API evidence:
  - `GET https://bysekoze.com/api/videos/wl5t0od7nc7l/embed/details`
  - returns JSON with `embed_frame_url: "https://f75s.com/03ns/wl5t0od7nc7l"`
- Interpretation:
  - alias is part of the same host family flow used by current Filemoon resolver dynamic branch.

## mxdrop.to -> Mixdrop-equivalent
- Runtime audit (`jigokuraku-2nd-season` ep 1) reports:
  - `serverName: Mixdrop`
  - `detectedHost: mxdrop.to`
  - `initialUrl: https://mxdrop.to/e/ow9q71zjsloe3r`
  - `supports: ["kumoriya.resolver.mixdrop"]`
- Live payload evidence from `https://mxdrop.to/e/ow9q71zjsloe3r` includes packed JS defining:
  - `MDCore.wurl`
  - `mxcontent.net` media host patterns
- Interpretation:
  - alias is Mixdrop-family payload and should be resolved by Mixdrop resolver.

## Not assumed
- No new speculative aliases were added.
- No host acceptance by substring-only matching was kept.
