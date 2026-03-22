import 'package:kumoriya_core/kumoriya_core.dart';

/// Status of an individual HLS segment within a download task.
enum HlsSegmentStatus { pending, downloading, completed, failed }

/// Immutable model representing a single HLS segment's download state.
///
/// Each segment maps to one .ts chunk parsed from the m3u8 playlist.
/// Segment state is persisted to allow pause/resume at segment granularity
/// without re-downloading completed chunks.
final class HlsSegment {
  const HlsSegment({
    required this.id,
    required this.downloadTaskId,
    required this.segmentIndex,
    required this.url,
    required this.status,
    this.localPath,
    this.byteSize,
    this.retryCount = 0,
  });

  /// Deterministic ID: `{downloadTaskId}:seg:{segmentIndex}`.
  final String id;

  /// FK reference to the parent DownloadTask.
  final String downloadTaskId;

  /// Zero-based position in the playlist — determines concatenation order.
  final int segmentIndex;

  /// Absolute URL of the .ts segment.
  final String url;

  /// Current download status.
  final HlsSegmentStatus status;

  /// Local file path where the segment bytes are saved.
  final String? localPath;

  /// Byte count of the downloaded segment (null until completed).
  final int? byteSize;

  /// Number of failed retry attempts for this segment.
  final int retryCount;

  /// Creates a copy with optional field overrides.
  HlsSegment copyWith({
    HlsSegmentStatus? status,
    String? localPath,
    int? byteSize,
    int? retryCount,
  }) {
    return HlsSegment(
      id: id,
      downloadTaskId: downloadTaskId,
      segmentIndex: segmentIndex,
      url: url,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
      byteSize: byteSize ?? this.byteSize,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

/// Persistence contract for HLS segment state.
abstract interface class HlsSegmentStore {
  /// Batch-insert all segments for a task (used after m3u8 parsing).
  Future<Result<void, KumoriyaError>> insertSegments(List<HlsSegment> segments);

  /// Load all segments for a task, ordered by [segmentIndex].
  Future<Result<List<HlsSegment>, KumoriyaError>> getSegmentsForTask(
    String downloadTaskId,
  );

  /// Update a single segment's status and optional metadata.
  Future<Result<void, KumoriyaError>> updateSegment(HlsSegment segment);

  /// Batch-update multiple segments (e.g. marking range as failed on cancel).
  Future<Result<void, KumoriyaError>> updateSegments(List<HlsSegment> segments);

  /// Delete all segment records for a task (cleanup after completion/cancel).
  Future<Result<void, KumoriyaError>> deleteSegmentsForTask(
    String downloadTaskId,
  );

  /// Count segments by status for progress tracking.
  Future<Result<int, KumoriyaError>> countSegmentsByStatus(
    String downloadTaskId,
    HlsSegmentStatus status,
  );
}
