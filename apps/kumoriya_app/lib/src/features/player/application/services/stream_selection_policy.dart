import 'package:flutter/foundation.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

final class StreamSelectionPolicy {
  const StreamSelectionPolicy({TargetPlatform? platform})
    : _platform = platform;

  final TargetPlatform? _platform;

  List<ResolvedStream> rankCandidates(List<ResolvedStream> candidates) {
    if (candidates.isEmpty) {
      return const <ResolvedStream>[];
    }

    final dedupedByUrl = <String, ResolvedStream>{};
    for (final candidate in candidates) {
      dedupedByUrl[candidate.url.toString()] = candidate;
    }

    final sorted = dedupedByUrl.values.toList(growable: false)
      ..sort((a, b) => _score(b).compareTo(_score(a)));
    return sorted;
  }

  ResolvedStream? selectBest(List<ResolvedStream> candidates) {
    final ranked = rankCandidates(candidates);
    if (ranked.isEmpty) {
      return null;
    }
    return ranked.first;
  }

  int _score(ResolvedStream stream) {
    var score = 0;
    if (stream.isHls) {
      // Prefer adaptive streams as safer default under unstable networks.
      score += 2000;
    }

    final quality = (stream.qualityLabel ?? '').toLowerCase();
    final qualityScore = _extractQualityScore(quality);
    if (qualityScore != null) {
      score += qualityScore;
    }

    if (stream.mimeType != null) {
      score += 10;
    }

    score -= _androidAnimeNexusCompatibilityPenalty(stream);

    return score;
  }

  int _androidAnimeNexusCompatibilityPenalty(ResolvedStream stream) {
    if (_effectivePlatform != TargetPlatform.android ||
        !_isAnimeNexusLoopback(stream.url)) {
      return 0;
    }

    final quality = _extractQualityScore(
      (stream.qualityLabel ?? '').toLowerCase(),
    );
    if (quality == null || quality <= 720) {
      return 0;
    }

    // Android devices are currently failing codec init on the highest
    // Anime Nexus profile, so prefer the next compatible HLS variant first.
    return 1000 + quality;
  }

  TargetPlatform get _effectivePlatform => _platform ?? defaultTargetPlatform;

  bool _isAnimeNexusLoopback(Uri url) {
    return url.pathSegments.isNotEmpty &&
        url.pathSegments.first == 'anime-nexus';
  }

  int? _extractQualityScore(String qualityLabel) {
    if (qualityLabel.isEmpty || !qualityLabel.endsWith('p')) {
      return null;
    }

    final digits = qualityLabel.substring(0, qualityLabel.length - 1);
    return int.tryParse(digits);
  }
}
