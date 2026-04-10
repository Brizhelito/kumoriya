/// In-memory tracker of download outcomes per server name.
///
/// Provides a Bayesian-smoothed score that lets the download pipeline prefer
/// historically reliable servers when multiple options are available.
///
/// Scores are session-scoped — they reset when the app restarts. This is
/// intentional: CDN reliability can change between sessions and stale data
/// would do more harm than good.
class DownloadServerScorer {
  final _successes = <String, int>{};
  final _failures = <String, int>{};

  /// Record a successful download from [serverName].
  void recordSuccess(String serverName) {
    _successes[serverName] = (_successes[serverName] ?? 0) + 1;
  }

  /// Record a failed download from [serverName].
  void recordFailure(String serverName) {
    _failures[serverName] = (_failures[serverName] ?? 0) + 1;
  }

  /// Score a server from 0.0 (worst) to 1.0 (best).
  ///
  /// Uses Laplace smoothing (add-1) so servers with no history score 0.5.
  double score(String serverName) {
    final s = _successes[serverName] ?? 0;
    final f = _failures[serverName] ?? 0;
    return (s + 1) / (s + f + 2);
  }

  /// Returns [links] sorted by server score (best first).
  ///
  /// Dart's sort is stable so items with equal scores retain their original
  /// relative order.
  List<T> rankByScore<T>(List<T> links, String Function(T) serverNameOf) {
    if (links.length <= 1) return links;
    final sorted = List<T>.of(links);
    sorted.sort((a, b) {
      final sa = score(serverNameOf(a));
      final sb = score(serverNameOf(b));
      return sb.compareTo(sa); // descending — best first
    });
    return sorted;
  }
}
