import 'package:flutter/material.dart';

/// Quality tier for a resolver/server host, used to rank and recommend
/// download and streaming servers to the user.
enum ServerQualityTier {
  /// Premium — proven fast CDN, consistent availability, good quality.
  /// Examples: anime.nexus dedicated player, JKAnime Desu/Magi.
  premium(weight: 1.0, label: 'Premium', color: Color(0xFF4CAF50)),

  /// Good — reliable for most cases, decent speed.
  /// Examples: Pixeldrain, Zilla Networks, Filemoon.
  good(weight: 0.75, label: 'Good', color: Color(0xFF8BC34A)),

  /// Average — works but may have inconsistent speed or availability.
  /// Examples: Streamwish, Vidhide, Streamtape.
  average(weight: 0.5, label: 'OK', color: Color(0xFFFFC107)),

  /// Low — slow, unreliable, or limited quality.
  /// Examples: DoodStream, YourUpload, OkRu.
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

  static const _hostTiers = <String, ServerQualityTier>{
    // Premium tier — fastest, most reliable
    'anime.nexus': ServerQualityTier.premium,

    // Premium tier (cont.) — direct download, max priority
    'mediafire.com': ServerQualityTier.premium,
    'www.mediafire.com': ServerQualityTier.premium,
    'dl.mediafire.com': ServerQualityTier.premium,

    // Good tier — reliable, decent speed
    'pixeldrain.com': ServerQualityTier.good,
    // Zilla serves AV1 1080p. Mid-tier Android SoCs (Helio G99) need the
    // dav1d-perf tuning in media_kit_playback_engine._configureDecoderForStream
    // (skiploopfilter=all + skipframe=nonref + fast + framedrop=vo + large
    // cache) to reach sustained playback in ~12 s. On desktop with HW or
    // fast software AV1 it already works inside 12 s.
    'player.zilla-networks.com': ServerQualityTier.good,
    'bysekoze.com': ServerQualityTier.good,
    'filemoon.sx': ServerQualityTier.good,
    'filemoon.to': ServerQualityTier.good,
    'filemoon.nl': ServerQualityTier.good,
    'f75s.com': ServerQualityTier.good,
    'kerapoxy.cc': ServerQualityTier.good,

    // Average tier — works but not ideal
    'sfastwish.com': ServerQualityTier.average,
    'streamwish.to': ServerQualityTier.average,
    'streamwish.com': ServerQualityTier.average,
    'embedwish.com': ServerQualityTier.average,
    'vidhide.com': ServerQualityTier.average,
    'vidhidepro.com': ServerQualityTier.average,
    'streamtape.com': ServerQualityTier.average,
    'streamtape.to': ServerQualityTier.average,
    'upnshare.com': ServerQualityTier.average,
    'animeav1.uns.bio': ServerQualityTier.low,
    'mega.nz': ServerQualityTier.average,

    // Low tier — slow or unreliable
    'doodstream.com': ServerQualityTier.low,
    'dood.la': ServerQualityTier.low,
    'dood.yt': ServerQualityTier.low,
    'd000d.com': ServerQualityTier.low,
    'ds2play.com': ServerQualityTier.low,
    'yourupload.com': ServerQualityTier.low,
    'ok.ru': ServerQualityTier.low,
    'odnoklassniki.ru': ServerQualityTier.low,
    'www.mp4upload.com': ServerQualityTier.low,
    'mp4upload.com': ServerQualityTier.low,
  };

  /// Server names from JKAnime that map to quality tiers
  /// (used when detectedHost is not available).
  static const _serverNameTiers = <String, ServerQualityTier>{
    'desu': ServerQualityTier.premium,
    'magi': ServerQualityTier.premium,
    'nexus': ServerQualityTier.premium,
    'anime nexus': ServerQualityTier.premium,
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
