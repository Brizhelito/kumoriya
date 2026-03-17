import 'package:drift/drift.dart';

import 'daos/anilist_cache_dao.dart';
import 'daos/download_task_dao.dart';
import 'daos/library_entry_dao.dart';
import 'daos/playback_preference_dao.dart';
import 'daos/progress_dao.dart';
import 'daos/source_availability_cache_dao.dart';
import 'daos/watch_history_dao.dart';
import 'tables/anilist_cache_table.dart';
import 'tables/download_task_table.dart';
import 'tables/episode_progress_table.dart';
import 'tables/library_entry_table.dart';
import 'tables/playback_preference_table.dart';
import 'tables/source_availability_cache_table.dart';
import 'tables/watch_history_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    EpisodeProgressTable,
    WatchHistoryTable,
    PlaybackPreferenceTable,
    SourceAvailabilityCacheTable,
    DownloadTaskTable,
    LibraryEntryTable,
    AnilistCacheTable,
  ],
  daos: [
    ProgressDao,
    WatchHistoryDao,
    PlaybackPreferenceDao,
    SourceAvailabilityCacheDao,
    DownloadTaskDao,
    LibraryEntryDao,
    AnilistCacheDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 4) {
        await _repairLegacySchema(m);
      }
      if (from < 5) {
        await _ensureColumn(
          tableName: 'library_entry',
          columnName: 'notify_new_episodes',
          sqlDefinition: 'INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 6) {
        await _ensureColumn(
          tableName: 'library_entry',
          columnName: 'last_notified_episode',
          sqlDefinition: 'INTEGER',
        );
      }
      if (from < 7) {
        await _ensureColumn(
          tableName: 'library_entry',
          columnName: 'auto_download_new_episodes',
          sqlDefinition: 'INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 9) {
        await _ensureColumn(
          tableName: 'download_task',
          columnName: 'anime_title',
          sqlDefinition: 'TEXT',
        );
        await _ensureColumn(
          tableName: 'download_task',
          columnName: 'quality_label',
          sqlDefinition: 'TEXT',
        );
      }
      if (from < 8) {
        await _ensureColumn(
          tableName: 'download_task',
          columnName: 'headers',
          sqlDefinition: 'TEXT',
        );
        await _ensureColumn(
          tableName: 'download_task',
          columnName: 'is_hls',
          sqlDefinition: 'INTEGER DEFAULT 0',
        );
      }
    },
    beforeOpen: (details) async {
      if (details.wasCreated) {
        // For fresh databases, create all indices immediately.
        await _createIndices();
      }
    },
  );

  Future<void> _repairLegacySchema(Migrator m) async {
    await _createTableIfMissing(
      tableName: 'playback_preference',
      createTable: () => m.createTable(playbackPreferenceTable),
    );
    await _createTableIfMissing(
      tableName: 'source_availability_cache_table',
      createTable: () => m.createTable(sourceAvailabilityCacheTable),
    );
    await _ensureColumn(
      tableName: 'watch_history',
      columnName: 'last_position_seconds',
      sqlDefinition: 'INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      tableName: 'watch_history',
      columnName: 'last_total_duration_seconds',
      sqlDefinition: 'INTEGER',
    );
    await _createTableIfMissing(
      tableName: 'download_task',
      createTable: () => m.createTable(downloadTaskTable),
    );
    await _createTableIfMissing(
      tableName: 'library_entry',
      createTable: () => m.createTable(libraryEntryTable),
    );
    await _createTableIfMissing(
      tableName: 'anilist_cache',
      createTable: () => m.createTable(anilistCacheTable),
    );
    await _createIndices();
  }

  Future<void> _createTableIfMissing({
    required String tableName,
    required Future<void> Function() createTable,
  }) async {
    if (await _tableExists(tableName)) {
      return;
    }
    await createTable();
  }

  Future<void> _ensureColumn({
    required String tableName,
    required String columnName,
    required String sqlDefinition,
  }) async {
    final columnNames = await _columnNamesFor(tableName);
    if (columnNames.contains(columnName)) {
      return;
    }
    await customStatement(
      'ALTER TABLE $tableName ADD COLUMN $columnName $sqlDefinition',
    );
  }

  Future<bool> _tableExists(String tableName) async {
    final rows = await customSelect(
      'SELECT name FROM sqlite_master WHERE type = ? AND name = ?',
      variables: <Variable<Object>>[
        Variable.withString('table'),
        Variable.withString(tableName),
      ],
    ).get();
    return rows.isNotEmpty;
  }

  Future<Set<String>> _columnNamesFor(String tableName) async {
    if (!await _tableExists(tableName)) {
      return <String>{};
    }
    final rows = await customSelect('PRAGMA table_info($tableName)').get();
    return rows.map((row) => row.read<String>('name')).toSet();
  }

  Future<void> _createIndices() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_watch_history_last_accessed '
      'ON watch_history (last_accessed_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_episode_progress_anime_updated '
      'ON episode_progress (anilist_id, updated_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_source_availability_cache_updated '
      'ON source_availability_cache_table (updated_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_download_task_anime '
      'ON download_task (anilist_id, created_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_download_task_status '
      'ON download_task (status, created_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_download_task_status_anime '
      'ON download_task (status, anilist_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_anilist_cache_updated '
      'ON anilist_cache (updated_at)',
    );
  }
}
