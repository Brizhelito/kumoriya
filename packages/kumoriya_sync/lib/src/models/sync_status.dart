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
  // Anime universe (existing).
  episodeProgress,
  watchHistory,
  watchHistoryDeletion,
  playbackPreference,
  libraryEntry,
  libraryEntryDeletion,

  // Manga universe. Added in Slice 10C. The HTTP sync service does
  // not push these to the backend yet — they accumulate locally so
  // the user's writes survive logout/login round-trips and so the
  // service-side rollout (10C-2 / backend) can drain a populated
  // queue. Skipping is gated explicitly in `HttpSyncService`.
  mangaChapterProgress,
  mangaReadHistory,
  mangaReadHistoryDeletion,
  mangaLibraryEntry,
  mangaLibraryEntryDeletion,
}
