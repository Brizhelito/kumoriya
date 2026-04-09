final class LibrarySyncEntry {
  const LibrarySyncEntry({
    required this.anilistId,
    required this.isFavorite,
    required this.notify,
    this.lastNotifiedEpisode,
    this.autoDownloadNewEpisodes = false,
    this.autoDownloadAudioPreference,
    this.addedAt,
  });

  final int anilistId;
  final bool isFavorite;
  final bool notify;
  final int? lastNotifiedEpisode;
  final bool autoDownloadNewEpisodes;
  final String? autoDownloadAudioPreference;

  /// Server-side timestamp (milliseconds since epoch) for when this entry was
  /// added to the library. `null` when the server omits the field.
  final DateTime? addedAt;
}
