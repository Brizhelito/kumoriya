import 'package:kumoriya_plugins/kumoriya_plugins.dart';

final class StreamSelectionPolicy {
  const StreamSelectionPolicy();

  ResolvedStream? selectBest(List<ResolvedStream> candidates) {
    if (candidates.isEmpty) {
      return null;
    }

    final sorted = [...candidates]
      ..sort((a, b) => _score(b).compareTo(_score(a)));
    return sorted.first;
  }

  int _score(ResolvedStream stream) {
    var score = 0;
    if (stream.isHls) {
      score += 100;
    }

    final quality = stream.qualityLabel ?? '';
    final qualityMatch = RegExp(
      r'(2160|1440|1080|720|480|360)p',
    ).firstMatch(quality.toLowerCase());
    if (qualityMatch != null) {
      score += int.parse(qualityMatch.group(1)!);
    }

    if (stream.mimeType != null) {
      score += 10;
    }

    return score;
  }
}
