import 'package:drift/drift.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import '../contracts/manga_progress_store.dart';
import 'app_database.dart';
import 'daos/manga_progress_dao.dart';

final class DriftMangaProgressStore implements MangaProgressStore {
  DriftMangaProgressStore(AppDatabase db) : _dao = MangaProgressDao(db);

  final MangaProgressDao _dao;

  @override
  Future<Result<void, KumoriyaError>> upsert(
    MangaChapterProgress progress,
  ) async {
    try {
      await _dao.upsertProgress(
        MangaProgressTableCompanion(
          mangaAnilistId: Value(progress.mangaAnilistId),
          sourceId: Value(progress.sourceId),
          sourceChapterId: Value(progress.sourceChapterId),
          chapterNumber: Value(progress.chapterNumber),
          pageIndex: Value(progress.pageIndex),
          scrollOffset: Value(progress.scrollOffset),
          readState: Value(progress.readState.name),
          updatedAt: Value(progress.updatedAt.millisecondsSinceEpoch),
        ),
      );
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_progress_upsert_failed',
          message: 'Failed to upsert manga progress: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> upsertReadHistory({
    required int mangaAnilistId,
    required double chapterNumber,
    String? lastSourceId,
    String? lastSourceChapterId,
    int? lastPageIndex,
    DateTime? lastAccessedAt,
  }) async {
    try {
      await _dao.upsertHistory(
        MangaHistoryTableCompanion(
          mangaAnilistId: Value(mangaAnilistId),
          lastChapterNumber: Value(chapterNumber),
          lastSourceId: Value(lastSourceId),
          lastSourceChapterId: Value(lastSourceChapterId),
          lastPageIndex: Value(lastPageIndex),
          lastAccessedAt: Value(
            (lastAccessedAt ?? DateTime.now()).millisecondsSinceEpoch,
          ),
        ),
      );
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_history_upsert_failed',
          message: 'Failed to upsert manga read history: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<MangaChapterProgress?, KumoriyaError>> getProgress({
    required int mangaAnilistId,
    required String sourceId,
    required String sourceChapterId,
  }) async {
    try {
      final row = await _dao.getProgress(
        mangaAnilistId: mangaAnilistId,
        sourceId: sourceId,
        sourceChapterId: sourceChapterId,
      );
      return Success(row != null ? _rowToProgress(row) : null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_progress_read_failed',
          message: 'Failed to read manga progress: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<MangaChapterProgress?, KumoriyaError>> getLatestProgress(
    int mangaAnilistId,
  ) async {
    try {
      final row = await _dao.getLatestProgress(mangaAnilistId);
      return Success(row != null ? _rowToProgress(row) : null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_progress_read_failed',
          message: 'Failed to read latest manga progress: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<MangaChapterProgress>, KumoriyaError>> getAllProgress(
    int mangaAnilistId,
  ) async {
    try {
      final rows = await _dao.getAllProgress(mangaAnilistId);
      return Success(rows.map(_rowToProgress).toList(growable: false));
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_progress_read_failed',
          message: 'Failed to read manga progress: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<MangaReadHistory>, KumoriyaError>> getRecentHistory({
    int limit = 20,
  }) async {
    try {
      final rows = await _dao.getRecentHistory(limit: limit);
      return Success(rows.map(_rowToHistory).toList(growable: false));
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_history_read_failed',
          message: 'Failed to read manga history: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> deleteHistoryEntry(
    int mangaAnilistId,
  ) async {
    try {
      await _dao.deleteHistoryEntry(mangaAnilistId);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_history_delete_failed',
          message: 'Failed to delete manga history entry: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> clearAllHistory() async {
    try {
      await _dao.clearAllHistory();
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_history_clear_failed',
          message: 'Failed to clear manga history: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> clearAllProgress() async {
    try {
      await _dao.clearAllProgress();
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_progress_clear_failed',
          message: 'Failed to clear manga progress: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  MangaChapterProgress _rowToProgress(MangaProgressTableData row) {
    return MangaChapterProgress(
      mangaAnilistId: row.mangaAnilistId,
      sourceId: row.sourceId,
      sourceChapterId: row.sourceChapterId,
      chapterNumber: row.chapterNumber,
      pageIndex: row.pageIndex,
      scrollOffset: row.scrollOffset,
      readState: MangaReadState.values.firstWhere(
        (s) => s.name == row.readState,
        orElse: () => MangaReadState.unread,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  MangaReadHistory _rowToHistory(MangaHistoryTableData row) {
    return MangaReadHistory(
      mangaAnilistId: row.mangaAnilistId,
      lastChapterNumber: row.lastChapterNumber,
      lastSourceId: row.lastSourceId,
      lastSourceChapterId: row.lastSourceChapterId,
      lastPageIndex: row.lastPageIndex,
      lastAccessedAt: DateTime.fromMillisecondsSinceEpoch(row.lastAccessedAt),
    );
  }
}
