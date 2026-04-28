import 'package:kumoriya_core/kumoriya_core.dart';

enum MangaReadState { unread, reading, completed }

/// Per-chapter resume state.
final class MangaChapterProgress {
  const MangaChapterProgress({
    required this.mangaAnilistId,
    required this.sourceId,
    required this.sourceChapterId,
    required this.chapterNumber,
    required this.updatedAt,
    this.pageIndex = 0,
    this.scrollOffset,
    this.readState = MangaReadState.unread,
  });

  final int mangaAnilistId;
  final String sourceId;
  final String sourceChapterId;
  final double chapterNumber;
  final int pageIndex;

  /// Vertical-mode scroll offset (logical pixels). Null in paginated
  /// mode.
  final double? scrollOffset;

  final MangaReadState readState;
  final DateTime updatedAt;
}

/// Most-recently-accessed chapter, one per manga. Mirrors
/// `AnimeWatchHistory`.
final class MangaReadHistory {
  const MangaReadHistory({
    required this.mangaAnilistId,
    required this.lastChapterNumber,
    required this.lastAccessedAt,
    this.lastSourceId,
    this.lastSourceChapterId,
    this.lastPageIndex,
  });

  final int mangaAnilistId;
  final double lastChapterNumber;
  final DateTime lastAccessedAt;
  final String? lastSourceId;
  final String? lastSourceChapterId;
  final int? lastPageIndex;
}

abstract interface class MangaProgressStore {
  Future<Result<void, KumoriyaError>> upsert(MangaChapterProgress progress);

  Future<Result<void, KumoriyaError>> upsertReadHistory({
    required int mangaAnilistId,
    required double chapterNumber,
    String? lastSourceId,
    String? lastSourceChapterId,
    int? lastPageIndex,
    DateTime? lastAccessedAt,
  });

  Future<Result<MangaChapterProgress?, KumoriyaError>> getProgress({
    required int mangaAnilistId,
    required String sourceId,
    required String sourceChapterId,
  });

  /// Returns the most-recently-updated chapter progress row for
  /// [mangaAnilistId], or null if none exist.
  Future<Result<MangaChapterProgress?, KumoriyaError>> getLatestProgress(
    int mangaAnilistId,
  );

  Future<Result<List<MangaChapterProgress>, KumoriyaError>> getAllProgress(
    int mangaAnilistId,
  );

  Future<Result<List<MangaReadHistory>, KumoriyaError>> getRecentHistory({
    int limit = 20,
  });

  Future<Result<void, KumoriyaError>> deleteHistoryEntry(int mangaAnilistId);

  Future<Result<void, KumoriyaError>> clearAllHistory();

  /// Wipes every stored `MangaChapterProgress` row. Meant to be invoked
  /// when the user signs out.
  Future<Result<void, KumoriyaError>> clearAllProgress();
}
