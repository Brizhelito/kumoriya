/// Optional hook the reader uses to persist the user's reading
/// position so re-opening the same chapter resumes mid-page.
///
/// The reader calls `save` periodically while reading (debounced) and
/// once on dispose. The implementation is expected to be cheap (an
/// upsert into a local store) and to swallow errors silently — the
/// reader does not surface storage failures to the user; in the worst
/// case the next session just starts from page 0.
abstract interface class ReaderProgressSink {
  /// Persist the user's current position.
  ///
  /// One of [pageIndex] / [scrollOffsetPx] is meaningful depending on
  /// the active reader mode. Implementations should store both and
  /// let the loader decide which to use when re-entering.
  Future<void> save({
    required int mangaAnilistId,
    required String sourceId,
    required double chapterNumber,
    required int pageIndex,
    double? scrollOffsetPx,
    bool completed = false,
  });
}
