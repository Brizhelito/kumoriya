/// Reason a catalog read fell back to locally-cached data.
///
/// Shared between anime and manga repository decorators so the UI layer
/// can collapse "is anything degraded right now" into a single banner
/// regardless of which universe the user is currently browsing.
enum FallbackReason {
  /// Operating normally — every read came back from upstream.
  none,

  /// Transport-level failure (no network, DNS, TCP). Implies the device
  /// itself is offline.
  offline,

  /// Upstream (AniList or the Kumoriya Go cache that fronts it) is
  /// reachable but returning errors / rate limits. The device has
  /// connectivity; the data plane is degraded.
  anilistDown,
}
