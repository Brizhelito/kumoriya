enum SyncStatus { idle, pushing, pulling, success, failed }

enum SyncQueueEntryStatus { pending, syncing, synced, failed }

enum SyncEntityType {
  episodeProgress,
  watchHistory,
  playbackPreference,
  libraryEntry,
}
