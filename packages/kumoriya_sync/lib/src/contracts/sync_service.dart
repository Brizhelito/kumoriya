import 'package:kumoriya_core/kumoriya_core.dart';

import '../models/sync_conflict.dart';
import '../models/sync_pull_response.dart';
import '../models/sync_status.dart';

final class SyncPushResult {
  const SyncPushResult({required this.applied, required this.conflicts});

  final int applied;
  final List<SyncConflict> conflicts;
}

abstract interface class SyncService {
  Future<Result<SyncPushResult, KumoriyaError>> pushPending();

  Future<Result<SyncPullResponse, KumoriyaError>> pullSince(DateTime since);

  Future<Result<void, KumoriyaError>> fullSync();

  Future<Result<SyncStatus, KumoriyaError>> getStatus();
}
