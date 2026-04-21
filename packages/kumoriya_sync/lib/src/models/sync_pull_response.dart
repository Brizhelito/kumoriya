import 'package:kumoriya_storage/kumoriya_storage.dart';

import 'durable_until.dart';
import 'library_sync_entry.dart';

final class SyncPullResponse {
  const SyncPullResponse({
    required this.serverTime,
    required this.episodeProgress,
    required this.watchHistory,
    required this.playbackPreferences,
    required this.libraryEntries,
    this.durableUntil = DurableUntil.empty,
  });

  final DateTime serverTime;
  final List<EpisodeProgress> episodeProgress;
  final List<AnimeWatchHistory> watchHistory;
  final List<PlaybackPreference> playbackPreferences;
  final List<LibrarySyncEntry> libraryEntries;
  final DurableUntil durableUntil;
}
