final class LibrarySyncEntry {
  const LibrarySyncEntry({
    required this.anilistId,
    required this.isFavorite,
    required this.notify,
    this.lastNotifiedEpisode,
    this.autoDownloadNewEpisodes = false,
    this.autoDownloadAudioPreference,
  });

  final int anilistId;
  final bool isFavorite;
  final bool notify;
  final int? lastNotifiedEpisode;
  final bool autoDownloadNewEpisodes;
  final String? autoDownloadAudioPreference;
}
