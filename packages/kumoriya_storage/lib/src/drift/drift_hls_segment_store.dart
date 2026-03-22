import 'package:drift/drift.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import '../contracts/hls_segment_store.dart';
import 'app_database.dart';
import 'daos/hls_segment_dao.dart';

final class DriftHlsSegmentStore implements HlsSegmentStore {
  DriftHlsSegmentStore(AppDatabase db) : _dao = HlsSegmentDao(db);

  final HlsSegmentDao _dao;

  @override
  Future<Result<void, KumoriyaError>> insertSegments(
    List<HlsSegment> segments,
  ) async {
    try {
      await _dao.insertAll(segments.map(_toCompanion).toList());
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.hls_segment_insert_failed',
          message: 'Failed to insert HLS segments: $e',
        ),
      );
    }
  }

  @override
  Future<Result<List<HlsSegment>, KumoriyaError>> getSegmentsForTask(
    String downloadTaskId,
  ) async {
    try {
      final rows = await _dao.getByTask(downloadTaskId);
      return Success(rows.map(_fromRow).toList());
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.hls_segment_read_failed',
          message: 'Failed to read HLS segments: $e',
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> updateSegment(HlsSegment segment) async {
    try {
      await _dao.updateSegment(_toCompanion(segment));
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.hls_segment_update_failed',
          message: 'Failed to update HLS segment: $e',
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> updateSegments(
    List<HlsSegment> segments,
  ) async {
    try {
      await _dao.updateAll(segments.map(_toCompanion).toList());
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.hls_segment_batch_update_failed',
          message: 'Failed to batch-update HLS segments: $e',
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> deleteSegmentsForTask(
    String downloadTaskId,
  ) async {
    try {
      await _dao.deleteByTask(downloadTaskId);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.hls_segment_delete_failed',
          message: 'Failed to delete HLS segments: $e',
        ),
      );
    }
  }

  @override
  Future<Result<int, KumoriyaError>> countSegmentsByStatus(
    String downloadTaskId,
    HlsSegmentStatus status,
  ) async {
    try {
      final count = await _dao.countByStatus(downloadTaskId, status.name);
      return Success(count);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.hls_segment_count_failed',
          message: 'Failed to count HLS segments: $e',
        ),
      );
    }
  }

  HlsSegmentTableCompanion _toCompanion(HlsSegment segment) {
    return HlsSegmentTableCompanion(
      id: Value(segment.id),
      downloadTaskId: Value(segment.downloadTaskId),
      segmentIndex: Value(segment.segmentIndex),
      url: Value(segment.url),
      status: Value(segment.status.name),
      localPath: Value(segment.localPath),
      byteSize: Value(segment.byteSize),
      retryCount: Value(segment.retryCount),
    );
  }

  HlsSegment _fromRow(HlsSegmentTableData row) {
    return HlsSegment(
      id: row.id,
      downloadTaskId: row.downloadTaskId,
      segmentIndex: row.segmentIndex,
      url: row.url,
      status: HlsSegmentStatus.values.firstWhere(
        (s) => s.name == row.status,
        orElse: () => HlsSegmentStatus.pending,
      ),
      localPath: row.localPath,
      byteSize: row.byteSize,
      retryCount: row.retryCount,
    );
  }
}
