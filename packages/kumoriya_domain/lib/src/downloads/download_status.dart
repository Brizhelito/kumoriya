/// Lifecycle states a download task can be in.
///
/// [remuxing] is emitted by the native HLS pipeline while Media3's
/// Transformer transmuxes the concatenated `.ts` into the final `.mp4`
/// — no bytes are added to [DownloadTask.downloadedBytes] during this
/// phase, so the UI should treat it like "downloading, buffer at 100%".
///
/// [disconnected] means the network dropped mid-download (not a server
/// error, not a user pause). The native engine preserves partial bytes.
enum DownloadStatus {
  pending,
  downloading,
  paused,
  remuxing,
  disconnected,
  completed,
  failed,
  cancelled,
}
