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
      await _ensureTable();
      final inserted = await _db.transaction(() async {
        // Collapse opposing intents on the same entity_key. When the user
        // writes an upsert, any pending deletion for the same entity becomes
        // obsolete; and vice versa. This prevents the server from receiving
        // both in the same batch, which would be order-sensitive and can
        // destroy fresh writes if the server applies the deletion last.
        final opposite = _oppositeEntityType(entry.entityType);
        if (opposite != null) {
          await _db.customStatement(
            'DELETE FROM sync_queue '
            'WHERE entity_type = ? AND entity_key = ?',
            <Object?>[_entityTypeToDb(opposite), entry.entityKey],
          );
        }

        final existing = await _db
            .customSelect(
              'SELECT * FROM sync_queue WHERE entity_type = ? AND entity_key = ? LIMIT 1',
              variables: <Variable<Object>>[
                Variable.withString(_entityTypeToDb(entry.entityType)),
                Variable.withString(entry.entityKey),
              ],
            )
            .getSingleOrNull();

        if (existing != null) {
          final existingId = existing.read<int>('id');
          await _db.customStatement(
            'UPDATE sync_queue '
            'SET payload = ?, created_at = ?, status = ?, retry_count = ?, last_error = NULLIF(?, ?) '
            'WHERE id = ?',
            <Object?>[
              entry.payload,
              entry.createdAt.millisecondsSinceEpoch,
              _statusToDb(entry.status),
              entry.retryCount,
              entry.lastError ?? '',
              '',
              existingId,
            ],
          );

          final row = await _db
              .customSelect(
                'SELECT * FROM sync_queue WHERE id = ?',
                variables: <Variable<Object>>[Variable.withInt(existingId)],
              )
              .getSingle();
          return _mapRow(row);
        }

        await _db.customStatement(
          'INSERT INTO sync_queue ('
          'entity_type, entity_key, payload, created_at, status, retry_count, last_error'
          ') VALUES (?, ?, ?, ?, ?, ?, NULLIF(?, ?))',
          <Object?>[
            _entityTypeToDb(entry.entityType),
            entry.entityKey,
            entry.payload,
            entry.createdAt.millisecondsSinceEpoch,
            _statusToDb(entry.status),
            entry.retryCount,
            entry.lastError ?? '',
            '',
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
      await _ensureTable();
      // Intentionally excludes `synced` (already durable on server) and
      // `poisoned` (repeatedly rejected; kept only for inspection).
      final rows = await _db
          .customSelect(
            'SELECT * FROM sync_queue '
            'WHERE status IN (?, ?, ?) '
            'ORDER BY created_at ASC, id ASC',
            variables: <Variable<Object>>[
              Variable.withString(_statusToDb(SyncQueueEntryStatus.pending)),
              Variable.withString(_statusToDb(SyncQueueEntryStatus.syncing)),
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
      await _ensureTable();
      await _db.customStatement(
        'UPDATE sync_queue '
        'SET status = ?, '
        'retry_count = COALESCE(NULLIF(?, ?), retry_count), '
        'last_error = NULLIF(?, ?) '
        'WHERE id = ?',
        <Object?>[
          _statusToDb(status),
          retryCount ?? -1,
          -1,
          lastError ?? '',
          '',
          id,
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
      await _ensureTable();
      await _db.customStatement(
        'DELETE FROM sync_queue WHERE id = ?',
        <Object?>[id],
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
  Future<Result<void, KumoriyaError>> deleteEntries(List<int> ids) async {
    if (ids.isEmpty) return const Success(null);
    try {
      await _ensureTable();
      // Chunk to avoid SQLite's default variable limit (999 params).
      const chunkSize = 500;
      for (var i = 0; i < ids.length; i += chunkSize) {
        final end = (i + chunkSize < ids.length) ? i + chunkSize : ids.length;
        final chunk = ids.sublist(i, end);
        final placeholders = List.filled(chunk.length, '?').join(',');
        await _db.customStatement(
          'DELETE FROM sync_queue WHERE id IN ($placeholders)',
          chunk.cast<Object?>(),
        );
      }
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'sync.queue.bulk_delete_failed',
          message: 'Failed to bulk-delete sync queue entries: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> clearSyncedEntries() async {
    try {
      await _ensureTable();
      await _db.customStatement(
        'DELETE FROM sync_queue WHERE status = ?',
        <Object?>[_statusToDb(SyncQueueEntryStatus.synced)],
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

  @override
  Future<Result<void, KumoriyaError>> clearAll() async {
    try {
      await _ensureTable();
      await _db.customStatement('DELETE FROM sync_queue');
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'sync.queue.clear_all_failed',
          message: 'Failed to clear sync queue: $e',
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

  Future<void> _ensureTable() async {
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_key TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_status_created '
      'ON sync_queue (status, created_at)',
    );
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_entity '
      'ON sync_queue (entity_type, entity_key)',
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
      case SyncQueueEntryStatus.poisoned:
        return 'poisoned';
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
      case 'poisoned':
        return SyncQueueEntryStatus.poisoned;
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
      case SyncEntityType.watchHistoryDeletion:
        return 'watch_history_deletion';
      case SyncEntityType.playbackPreference:
        return 'playback_preference';
      case SyncEntityType.libraryEntry:
        return 'library_entry';
      case SyncEntityType.libraryEntryDeletion:
        return 'library_entry_deletion';
    }
  }

  SyncEntityType _entityTypeFromDb(String value) {
    switch (value) {
      case 'episode_progress':
        return SyncEntityType.episodeProgress;
      case 'watch_history':
        return SyncEntityType.watchHistory;
      case 'watch_history_deletion':
        return SyncEntityType.watchHistoryDeletion;
      case 'playback_preference':
        return SyncEntityType.playbackPreference;
      case 'library_entry':
        return SyncEntityType.libraryEntry;
      case 'library_entry_deletion':
        return SyncEntityType.libraryEntryDeletion;
      default:
        return SyncEntityType.episodeProgress;
    }
  }

  /// Returns the opposing entity type for collapse purposes: an upsert
  /// invalidates the matching deletion and vice versa. Returns `null` when
  /// the entity type has no meaningful opposite.
  SyncEntityType? _oppositeEntityType(SyncEntityType type) {
    switch (type) {
      case SyncEntityType.watchHistory:
        return SyncEntityType.watchHistoryDeletion;
      case SyncEntityType.watchHistoryDeletion:
        return SyncEntityType.watchHistory;
      case SyncEntityType.libraryEntry:
        return SyncEntityType.libraryEntryDeletion;
      case SyncEntityType.libraryEntryDeletion:
        return SyncEntityType.libraryEntry;
      case SyncEntityType.episodeProgress:
      case SyncEntityType.playbackPreference:
        return null;
    }
  }
}
