enum SyncStatus { idle, pushing, pulling, success, failed }

/// Lifecycle of a sync queue entry.
///
/// - [pending]: waiting to be pushed.
/// - [syncing]: included in an in-flight push. Until the server confirms the
///   payload is durable (via `durable_until`), the entry stays here and will
///   be re-pushed on the next cycle.
/// - [synced]: server confirmed durability. Entry is safe to delete.
/// - [failed]: last push attempt failed (HTTP or transport). Will be retried.
/// - [poisoned]: repeatedly rejected (e.g. permanent 4xx) or exceeded retry
///   cap. Excluded from future pushes; kept for inspection/telemetry.
enum SyncQueueEntryStatus { pending, syncing, synced, failed, poisoned }

enum SyncEntityType {
  episodeProgress,
  watchHistory,
  watchHistoryDeletion,
  playbackPreference,
  libraryEntry,
  libraryEntryDeletion,
}
