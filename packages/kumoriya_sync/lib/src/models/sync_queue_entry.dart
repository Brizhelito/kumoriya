import 'sync_status.dart';

final class SyncQueueEntry {
  const SyncQueueEntry({
    required this.id,
    required this.entityType,
    required this.entityKey,
    required this.payload,
    required this.createdAt,
    required this.status,
    this.retryCount = 0,
    this.lastError,
  });

  final int id;
  final SyncEntityType entityType;
  final String entityKey;
  final String payload;
  final DateTime createdAt;
  final SyncQueueEntryStatus status;
  final int retryCount;
  final String? lastError;

  SyncQueueEntry copyWith({
    SyncQueueEntryStatus? status,
    int? retryCount,
    String? lastError,
  }) {
    return SyncQueueEntry(
      id: id,
      entityType: entityType,
      entityKey: entityKey,
      payload: payload,
      createdAt: createdAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }
}
