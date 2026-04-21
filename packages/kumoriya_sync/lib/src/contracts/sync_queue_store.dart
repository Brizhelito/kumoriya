import 'package:kumoriya_core/kumoriya_core.dart';

import '../models/sync_queue_entry.dart';
import '../models/sync_status.dart';

abstract interface class SyncQueueStore {
  Future<Result<SyncQueueEntry, KumoriyaError>> enqueue(SyncQueueEntry entry);

  Future<Result<List<SyncQueueEntry>, KumoriyaError>> getPendingEntries();

  Future<Result<void, KumoriyaError>> updateStatus({
    required int id,
    required SyncQueueEntryStatus status,
    int? retryCount,
    String? lastError,
  });

  Future<Result<void, KumoriyaError>> deleteEntry(int id);

  /// Bulk delete by ids. Used after a push to drop entries whose payload
  /// timestamp is ≤ the server's confirmed `durable_until` cursor.
  Future<Result<void, KumoriyaError>> deleteEntries(List<int> ids);

  Future<Result<void, KumoriyaError>> clearSyncedEntries();

  /// Wipes every entry in the sync queue regardless of status. Meant to be
  /// invoked at logout so pending writes from the previous user cannot be
  /// pushed to a different account on the next login.
  Future<Result<void, KumoriyaError>> clearAll();
}
