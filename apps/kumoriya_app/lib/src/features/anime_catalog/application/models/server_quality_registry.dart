import 'package:flutter/material.dart';

/// Quality tier for a resolver/server host, used to rank and recommend
/// download and streaming servers to the user.
///
/// Tier assignments come from the Player Flow Playground runs on
/// `kumoriya_exoplayer`. Evidence is the clean 2026-04-23 batch (7
/// sessions, 498 probes, first run starting at 20:58 local time) —
/// anything older was noise from the pre-native-player engine. Each
/// entry is annotated with `{oks/runs @ openMedMs}` so future updates
/// can tell which mappings are empirical and which are inherited.
///
/// Tiers are assigned jointly on success rate **and** open latency:
///   premium: SR ≥ 95 %  AND openMed ≤ 1500 ms
///   good:    SR ≥ 70 %  AND openMed ≤ 3000 ms
///   average: SR ≥ 50 %
///   low:     SR < 50 %  OR openMed > 4000 ms (P75 near the 5 s cap)
///
/// Only that engine is considered because it is what ships in production.
/// `anime.nexus` is excluded from measurement because it requires VPN,
/// so its tier is based on historical behaviour and kept at premium.
enum ServerQualityTier {
  /// Premium — proven fast CDN, consistent availability, good quality.
  /// Evidence: Zilla Networks (100 % @ 1082 ms), Mediafire (100 % @ 1190 ms).
  premium(weight: 1.0, label: 'Premium', color: Color(0xFF4CAF50)),

  /// Good — reliable for most cases, decent speed.
  /// Evidence: JKAnime direct (81 % @ 1764 ms), UPNShare (71 % @ 2848 ms),
  /// streamwish.to (100 % @ 2569 ms), dsvplay (100 % @ 2540 ms).
  good(weight: 0.75, label: 'Good', color: Color(0xFF8BC34A)),

  /// Average — works but inconsistent speed or availability.
  /// Evidence: Pixeldrain (48 % @ 4011 ms, regression under audit).
  average(weight: 0.5, label: 'OK', color: Color(0xFFFFC107)),

  /// Low — slow, unreliable, or limited quality (no resolver, or
  /// openP75 at the 5 s timeout).
  /// Evidence: vidhidevip (41 % @ 5021 ms), sfastwish (47 % @ 5018 ms),
  /// bysekoze (0 % timeouts), Streamtape (13 %), YourUpload (6 %),
  /// legacy DoodStream mirrors, MEGA, MP4Upload, VOE, Mixdrop, OK.ru,
  /// TeraBox, hqq/Netu.
  low(weight: 0.25, label: 'Slow', color: Color(0xFFFF9800)),

  /// Unknown — no data on this host.
  unknown(weight: 0.4, label: '?', color: Color(0xFF9E9E9E)),

  /// Unavailable — source returned no working download links for this episode.
  unavailable(weight: -1.0, label: 'N/A', color: Color(0xFFF44336));

  const ServerQualityTier({
    required this.weight,
    required this.label,
    required this.color,
  });

  final double weight;
  final String label;
  final Color color;
}

/// Static registry mapping detected host patterns to quality tiers.
///
/// Updated manually based on resolver audit evidence. Entries are matched
/// case-insensitively against [SourceServerLink.detectedHost] or the URL host.
class ServerQualityRegistry {
  const ServerQualityRegistry._();

  // Tiers below reflect the clean 2026-04-23 Player Flow Playground run
  // (7 sessions, 498 probes across 7 anime and 4 source plugins) under
  // `kumoriya_exoplayer`. Earlier probes are excluded as noise from the
  // pre-native-player engine. Annotations use `{successes/runs @ openMedMs}`
  // so future updates can tell which mappings are empirical and which
  // are inherited without fresh evidence.
  static const _hostTiers = <String, ServerQualityTier>{
    // ── Premium (≥85 % success, or VPN-only and trusted) ──────────────
    // anime.nexus is VPN-only so it is excluded from playground runs; we
    // keep the historical premium rating.
    'anime.nexus': ServerQualityTier.premium,
    'mediafire.com': ServerQualityTier.premium, // 17/17 @ 1190 ms
    'www.mediafire.com': ServerQualityTier.premium,
    'dl.mediafire.com': ServerQualityTier.premium,
    // Zilla serves AV1 1080p. Under kumoriya_exoplayer (Media3 native)
    // it is the fastest host measured: 34/34 @ 1082 ms openMed. The
    // dav1d-perf decoder tuning in media_kit_playback_engine is no
    // longer the bottleneck.
    'player.zilla-networks.com': ServerQualityTier.premium, // 34/34 @ 1082 ms

    // ── Good (70 %–84 % success) ─────────────────────────────────────
    // UPNShare (animeav1.uns.bio): 24/34 = 71 % @ 2848 ms. openP75 is
    // 5054 ms (right at the timeout) so it's a borderline good; if the
    // next batch shows the same regression, downgrade.
    'animeav1.uns.bio': ServerQualityTier.good, // 24/34 @ 2848 ms
    // streamwish.to: 12/12 @ 2569 ms — unanimous in this batch.
    'streamwish.to': ServerQualityTier.good, // 12/12 @ 2569 ms
    // dsvplay is the only live DoodStream mirror. 4/4 @ 2540 ms in this
    // batch; all other DoodStream domains stay in `low`.
    'dsvplay.com': ServerQualityTier.good, // 4/4 @ 2540 ms
    // Filemoon variants with no direct measurement keep the historical
    // rating. bysekoze.com (a Filemoon mirror) measured 4/11 → low.
    'filemoon.sx': ServerQualityTier.good,
    'filemoon.to': ServerQualityTier.good,
    'filemoon.nl': ServerQualityTier.good,
    'f75s.com': ServerQualityTier.good,
    'kerapoxy.cc': ServerQualityTier.good,

    // ── Average (50 %–69 % success, or no fresh data) ─────────────────
    // Pixeldrain regressed hard: 16/33 @ 4011 ms (11 open_timeouts +
    // 6 resolver.pixeldrain.transport). Kept here rather than in `low`
    // because it previously scored 100 % — we hold this tier for one
    // more batch to decide whether the regression is transient or
    // CDN-side.
    'pixeldrain.com': ServerQualityTier.average, // 16/33 @ 4011 ms
    // JKAnime direct embeds (Desu / Magi / Xtreme S) after the jkplayer
    // resolver host-gating fixes: 34/42 = 81 %, openMed 1764 ms. Fast
    // and fairly reliable — the only low tier moves were `unsupported_host`
    // from the resolver (8 probes), not dead players.
    'jkanime.net': ServerQualityTier.good, // 34/42 @ 1764 ms
    'streamwish.com': ServerQualityTier.average, // no data
    'embedwish.com': ServerQualityTier.average, // no data
    'vidhide.com': ServerQualityTier.average, // no data
    'vidhidepro.com': ServerQualityTier.average, // no data
    'upnshare.com': ServerQualityTier.average, // no data (animeav1.uns.bio is the live path)

    // ── Low (<50 % success or openMed > 4 s) ─────────────────────────
    // vidhidevip: SR 41 % + openMed 5021 ms (10 open_timeouts) — P75 is
    // literally at the 5 s playground timeout, so in practice half of
    // the probes fail to open in time.
    'vidhidevip.com': ServerQualityTier.low, // 7/17 @ 5021 ms
    'bysekoze.com': ServerQualityTier.low, // 0/4 @ 5053 ms (timeouts)
    'sfastwish.com': ServerQualityTier.low, // 8/17 @ 5018 ms
    'streamtape.com': ServerQualityTier.low, // 7/56, mostly deleted
    'streamtape.to': ServerQualityTier.low,
    // MEGA, MP4Upload, VOE, Fembed (embedsito), Netu (hqq.tv/.ac), Maru
    // (my.mail.ru), TeraBox and the various Mixdrop mirrors have no
    // resolver available, so every probe fails with
    // playground.no_resolver. They are ranked last so the UI surfaces
    // something actually playable first.
    'mega.nz': ServerQualityTier.low, // 0/98
    'doodstream.com': ServerQualityTier.low,
    'dood.la': ServerQualityTier.low,
    'dood.yt': ServerQualityTier.low,
    'd000d.com': ServerQualityTier.low,
    'ds2play.com': ServerQualityTier.low,
    'd-s.io': ServerQualityTier.low, // 0/13 transport failures
    'yourupload.com': ServerQualityTier.low, // 1/17
    'ok.ru': ServerQualityTier.low, // 0/10, resolver.okru.parse
    'odnoklassniki.ru': ServerQualityTier.low,
    'www.mp4upload.com': ServerQualityTier.low,
    'mp4upload.com': ServerQualityTier.low, // 0/72
    'voe.sx': ServerQualityTier.low, // 0/24
    'mxdrop.to': ServerQualityTier.low, // 4/11, volatile
    'mixdrop.is': ServerQualityTier.low, // 0/4 parse errors
    'mdbekjwqa.pw': ServerQualityTier.low, // 2/4, Mixdrop mirror, low N
    'mdy48tn97.com': ServerQualityTier.low, // 0/5 Mixdrop mirror
    'my.mail.ru': ServerQualityTier.low,
    'embedsito.com': ServerQualityTier.low,
    'hqq.tv': ServerQualityTier.low, // 0/13
    'hqq.ac': ServerQualityTier.low,
    'terabox.com': ServerQualityTier.low, // 0/6, no resolver
    'ryderjet.com': ServerQualityTier.low, // 0/6, Vidhide alias, no resolver
  };

  /// Server names used as a fallback when [detectedHost] is empty or not
  /// matched by [_hostTiers]. Values follow the same 2026-04-23 evidence:
  /// when the primary host-level entry already covers a server, this map
  /// is only hit by other plugins that reuse the name without exposing a
  /// URL, so the tier here is conservative.
  static const _serverNameTiers = <String, ServerQualityTier>{
    // JKAnime direct players (`Desu` / `Magi` / `Xtreme S`): 34/42 on
    // jkanime.net — see the host entry above. This fallback mirrors
    // that tier for the rare case where the detectedHost is missing.
    'desu': ServerQualityTier.good,
    'magi': ServerQualityTier.good,
    // anime.nexus is VPN-only (excluded from playground); historical
    // behaviour is premium so server-name matches keep that tier.
    'nexus': ServerQualityTier.premium,
    'anime nexus': ServerQualityTier.premium,
    // No playground data for Nozomi / Rina; keep the historical rating
    // until evidence suggests otherwise.
    'nozomi': ServerQualityTier.good,
    'rina': ServerQualityTier.good,
  };

  /// Look up the quality tier for a server link.
  ///
  /// Checks [detectedHost] first, then [serverName] (case-insensitive).
  /// Returns [ServerQualityTier.unknown] if no match is found.
  static ServerQualityTier tierFor({
    String? detectedHost,
    required String serverName,
  }) {
    if (detectedHost != null) {
      final host = detectedHost.toLowerCase();
      final tier = _hostTiers[host];
      if (tier != null) return tier;
      // Check if any known host is a suffix (e.g. sub.streamwish.com).
      for (final entry in _hostTiers.entries) {
        if (host.endsWith('.${entry.key}')) return entry.value;
      }
    }
    final name = serverName.trim().toLowerCase();
    final nameTier = _serverNameTiers[name];
    if (nameTier != null) return nameTier;
    // Partial match on server name (e.g. "Desu (SUB)" → "desu").
    for (final entry in _serverNameTiers.entries) {
      if (name.contains(entry.key)) return entry.value;
    }
    return ServerQualityTier.unknown;
  }

  /// Compute a combined score for sorting: static quality weight (70%)
  /// blended with session-based Bayesian score (30%).
  ///
  /// [sessionScore] should be 0.0–1.0 from [DownloadServerScorer.score].
  /// If null, only the static tier weight is used.
  static double combinedScore({
    required ServerQualityTier tier,
    double? sessionScore,
  }) {
    if (sessionScore == null) return tier.weight;
    return tier.weight * 0.7 + sessionScore * 0.3;
  }
}
