/// Per-entity durability cursors returned by the server on every push/pull.
///
/// Each field is the highest client-assigned timestamp (milliseconds since
/// epoch) that has been **persisted to Neon** for this user. Any queue entry
/// with payload timestamp <= this cursor can be safely removed from the local
/// sync queue.
///
/// A value of `0` (or missing field) means "server has not confirmed any
/// durability yet" — nothing is safe to prune.
final class DurableUntil {
  const DurableUntil({
    this.episodeProgress = 0,
    this.watchHistory = 0,
    this.playbackPreference = 0,
    this.libraryEntry = 0,
  });

  final int episodeProgress;
  final int watchHistory;
  final int playbackPreference;
  final int libraryEntry;

  static const empty = DurableUntil();

  factory DurableUntil.fromJson(Map<String, dynamic>? data) {
    if (data == null) return empty;
    int read(String k) => (data[k] as num?)?.toInt() ?? 0;
    return DurableUntil(
      episodeProgress: read('episode_progress'),
      watchHistory: read('watch_history'),
      playbackPreference: read('playback_preference'),
      libraryEntry: read('library_entry'),
    );
  }
}
