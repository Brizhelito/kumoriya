import 'sync_status.dart';

final class SyncConflict {
  const SyncConflict({
    required this.entityType,
    required this.entityKey,
    required this.reason,
  });

  final SyncEntityType entityType;
  final String entityKey;
  final String reason;
}
