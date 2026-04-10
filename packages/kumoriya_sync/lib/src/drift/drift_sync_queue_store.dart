import 'package:drift/drift.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../contracts/sync_queue_store.dart';
import '../models/sync_queue_entry.dart';
import '../models/sync_status.dart';

final class DriftSyncQueueStore implements SyncQueueStore {
  DriftSyncQueueStore(this._db);

  final AppDatabase _db;

  @override
  Future<Result<SyncQueueEntry, KumoriyaError>> enqueue(
    SyncQueueEntry entry,
  ) async {
    try {
      final inserted = await _db.transaction(() async {
        await _db.customStatement(
          'INSERT INTO sync_queue ('
          'entity_type, entity_key, payload, created_at, status, retry_count, last_error'
          ') VALUES (?, ?, ?, ?, ?, ?, NULLIF(?, ?))',
          <Variable<Object>>[
            Variable.withString(_entityTypeToDb(entry.entityType)),
            Variable.withString(entry.entityKey),
            Variable.withString(entry.payload),
            Variable.withInt(entry.createdAt.millisecondsSinceEpoch),
            Variable.withString(_statusToDb(entry.status)),
            Variable.withInt(entry.retryCount),
            Variable.withString(entry.lastError ?? ''),
            Variable.withString(''),
          ],
        );

        final row = await _db
            .customSelect(
              'SELECT * FROM sync_queue WHERE id = last_insert_rowid()',
            )
            .getSingle();
        return _mapRow(row);
      });

      return Success(inserted);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'sync.queue.enqueue_failed',
          message: 'Failed to enqueue sync item: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<SyncQueueEntry>, KumoriyaError>>
  getPendingEntries() async {
    try {
      final rows = await _db
          .customSelect(
            'SELECT * FROM sync_queue '
            'WHERE status IN (?, ?) '
            'ORDER BY created_at ASC, id ASC',
            variables: <Variable<Object>>[
              Variable.withString(_statusToDb(SyncQueueEntryStatus.pending)),
              Variable.withString(_statusToDb(SyncQueueEntryStatus.failed)),
            ],
          )
          .get();
      return Success(rows.map(_mapRow).toList(growable: false));
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'sync.queue.read_failed',
          message: 'Failed to load pending sync queue: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> updateStatus({
    required int id,
    required SyncQueueEntryStatus status,
    int? retryCount,
    String? lastError,
  }) async {
    try {
      await _db.customStatement(
        'UPDATE sync_queue '
        'SET status = ?, '
        'retry_count = COALESCE(NULLIF(?, ?), retry_count), '
        'last_error = NULLIF(?, ?) '
        'WHERE id = ?',
        <Variable<Object>>[
          Variable.withString(_statusToDb(status)),
          Variable.withInt(retryCount ?? -1),
          Variable.withInt(-1),
          Variable.withString(lastError ?? ''),
          Variable.withString(''),
          Variable.withInt(id),
        ],
      );
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'sync.queue.update_failed',
          message: 'Failed to update sync queue status: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> deleteEntry(int id) async {
    try {
      await _db.customStatement(
        'DELETE FROM sync_queue WHERE id = ?',
        <Variable<Object>>[Variable.withInt(id)],
      );
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'sync.queue.delete_failed',
          message: 'Failed to delete sync queue entry: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> clearSyncedEntries() async {
    try {
      await _db.customStatement(
        'DELETE FROM sync_queue WHERE status = ?',
        <Variable<Object>>[
          Variable.withString(_statusToDb(SyncQueueEntryStatus.synced)),
        ],
      );
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'sync.queue.clear_synced_failed',
          message: 'Failed to clear synced queue entries: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  SyncQueueEntry _mapRow(QueryRow row) {
    return SyncQueueEntry(
      id: row.read<int>('id'),
      entityType: _entityTypeFromDb(row.read<String>('entity_type')),
      entityKey: row.read<String>('entity_key'),
      payload: row.read<String>('payload'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('created_at'),
      ),
      status: _statusFromDb(row.read<String>('status')),
      retryCount: row.read<int>('retry_count'),
      lastError: row.readNullable<String>('last_error'),
    );
  }

  String _statusToDb(SyncQueueEntryStatus status) {
    switch (status) {
      case SyncQueueEntryStatus.pending:
        return 'pending';
      case SyncQueueEntryStatus.syncing:
        return 'syncing';
      case SyncQueueEntryStatus.synced:
        return 'synced';
      case SyncQueueEntryStatus.failed:
        return 'failed';
    }
  }

  SyncQueueEntryStatus _statusFromDb(String value) {
    switch (value) {
      case 'pending':
        return SyncQueueEntryStatus.pending;
      case 'syncing':
        return SyncQueueEntryStatus.syncing;
      case 'synced':
        return SyncQueueEntryStatus.synced;
      case 'failed':
        return SyncQueueEntryStatus.failed;
      default:
        return SyncQueueEntryStatus.pending;
    }
  }

  String _entityTypeToDb(SyncEntityType type) {
    switch (type) {
      case SyncEntityType.episodeProgress:
        return 'episode_progress';
      case SyncEntityType.watchHistory:
        return 'watch_history';
      case SyncEntityType.playbackPreference:
        return 'playback_preference';
      case SyncEntityType.libraryEntry:
        return 'library_entry';
    }
  }

  SyncEntityType _entityTypeFromDb(String value) {
    switch (value) {
      case 'episode_progress':
        return SyncEntityType.episodeProgress;
      case 'watch_history':
        return SyncEntityType.watchHistory;
      case 'playback_preference':
        return SyncEntityType.playbackPreference;
      case 'library_entry':
        return SyncEntityType.libraryEntry;
      default:
        return SyncEntityType.episodeProgress;
    }
  }
}
