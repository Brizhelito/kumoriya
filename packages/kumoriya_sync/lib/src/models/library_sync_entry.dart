final class LibrarySyncEntry {
  const LibrarySyncEntry({
    required this.anilistId,
    required this.isFavorite,
    required this.notify,
    this.lastNotifiedEpisode,
    this.autoDownloadNewEpisodes = false,
    this.autoDownloadAudioPreference,
    this.addedAt,
    this.updatedAt,
  });

  final int anilistId;
  final bool isFavorite;
  final bool notify;
  final int? lastNotifiedEpisode;
  final bool autoDownloadNewEpisodes;
  final String? autoDownloadAudioPreference;

  /// Milliseconds since epoch for when this entry was added as a favorite.
  /// `null` (or 0 on the wire) means "not favorite" — the row may still exist
  /// to carry subscription or auto-download state.
  final DateTime? addedAt;

  /// LWW cursor for library state. Server uses this to decide whether an
  /// incoming push should overwrite the current row. `null` for legacy rows.
  final DateTime? updatedAt;
}
