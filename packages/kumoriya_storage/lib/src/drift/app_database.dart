import 'package:drift/drift.dart';

import 'daos/aniskip_cache_dao.dart';
import 'daos/chapter_page_cache_dao.dart';
import 'daos/episode_cache_dao.dart';
import 'daos/anilist_cache_dao.dart';
import 'daos/download_task_dao.dart';
import 'daos/hls_segment_dao.dart';
import 'daos/library_entry_dao.dart';
import 'daos/manga_cache_dao.dart';
import 'daos/manga_chapter_dao.dart';
import 'daos/manga_download_dao.dart';
import 'daos/manga_library_dao.dart';
import 'daos/manga_progress_dao.dart';
import 'daos/playback_preference_dao.dart';
import 'daos/progress_dao.dart';
import 'daos/source_availability_cache_dao.dart';
import 'daos/translation_cache_dao.dart';
import 'daos/watch_history_dao.dart';
import 'tables/aniskip_cache_table.dart';
import 'tables/chapter_page_cache_table.dart';
import 'tables/episode_catalog_cache_table.dart';
import 'tables/anilist_cache_table.dart';
import 'tables/download_task_table.dart';
import 'tables/hls_segment_table.dart';
import 'tables/episode_progress_table.dart';
import 'tables/library_entry_table.dart';
import 'tables/manga_cache_table.dart';
import 'tables/manga_chapter_table.dart';
import 'tables/manga_download_table.dart';
import 'tables/manga_history_table.dart';
import 'tables/manga_library_table.dart';
import 'tables/manga_progress_table.dart';
import 'tables/playback_preference_table.dart';
import 'tables/source_availability_cache_table.dart';
import 'tables/translation_cache_table.dart';
import 'tables/watch_history_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    EpisodeProgressTable,
    WatchHistoryTable,
    PlaybackPreferenceTable,
    SourceAvailabilityCacheTable,
    AniSkipCacheTable,
    DownloadTaskTable,
    HlsSegmentTable,
    LibraryEntryTable,
    AnilistCacheTable,
    TranslationCacheTable,
    EpisodeCatalogCacheTable,
    MangaCacheTable,
    MangaChapterTable,
    MangaProgressTable,
    MangaHistoryTable,
    MangaLibraryTable,
    ChapterPageCacheTable,
    MangaDownloadTable,
  ],
  daos: [
    ProgressDao,
    WatchHistoryDao,
    PlaybackPreferenceDao,
    SourceAvailabilityCacheDao,
    AniSkipCacheDao,
    DownloadTaskDao,
    HlsSegmentDao,
    LibraryEntryDao,
    AnilistCacheDao,
    TranslationCacheDao,
    EpisodeCacheDao,
    MangaCacheDao,
    MangaChapterDao,
    MangaProgressDao,
    MangaLibraryDao,
    ChapterPageCacheDao,
    MangaDownloadDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 20;

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
      if (from < 10) {
        await _createTableIfMissing(
          tableName: 'aniskip_cache',
          createTable: () => m.createTable(aniSkipCacheTable),
        );
        await _createIndices();
      }
      if (from < 11) {
        await _ensureColumn(
          tableName: 'library_entry',
          columnName: 'auto_download_audio_preference',
          sqlDefinition: "TEXT DEFAULT 'none'",
        );
      }
      if (from < 12) {
        await _ensureColumn(
          tableName: 'download_task',
          columnName: 'episode_title',
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
      if (from < 13) {
        await _createTableIfMissing(
          tableName: 'hls_segment',
          createTable: () => m.createTable(hlsSegmentTable),
        );
      }
      if (from < 14) {
        await _createIndices();
      }
      if (from < 15) {
        await _createTableIfMissing(
          tableName: 'translation_cache',
          createTable: () => m.createTable(translationCacheTable),
        );
        await _createIndices();
      }
      if (from < 16) {
        await _createTableIfMissing(
          tableName: 'episode_catalog_cache',
          createTable: () => m.createTable(episodeCatalogCacheTable),
        );
        await _createIndices();
      }
      if (from < 17) {
        await _ensureColumn(
          tableName: 'anilist_cache',
          columnName: 'synonyms',
          sqlDefinition: 'TEXT',
        );
        await _ensureColumn(
          tableName: 'anilist_cache',
          columnName: 'season',
          sqlDefinition: 'TEXT',
        );
        await _ensureColumn(
          tableName: 'anilist_cache',
          columnName: 'popularity',
          sqlDefinition: 'INTEGER',
        );
        await _ensureColumn(
          tableName: 'anilist_cache',
          columnName: 'next_airing_episode',
          sqlDefinition: 'INTEGER',
        );
        await _ensureColumn(
          tableName: 'anilist_cache',
          columnName: 'next_airing_at',
          sqlDefinition: 'INTEGER',
        );
      }
      if (from < 18) {
        await _ensureSyncQueueTable();
      }
      if (from < 19) {
        await _ensureColumn(
          tableName: 'anilist_cache',
          columnName: 'relations',
          sqlDefinition: 'TEXT',
        );
      }
      if (from < 20) {
        // Slice 5 (manga storage). Strictly additive: six new tables for
        // the manga universe, no anime tables touched.
        await _createTableIfMissing(
          tableName: 'manga_cache',
          createTable: () => m.createTable(mangaCacheTable),
        );
        await _createTableIfMissing(
          tableName: 'manga_chapter',
          createTable: () => m.createTable(mangaChapterTable),
        );
        await _createTableIfMissing(
          tableName: 'manga_progress',
          createTable: () => m.createTable(mangaProgressTable),
        );
        await _createTableIfMissing(
          tableName: 'manga_history',
          createTable: () => m.createTable(mangaHistoryTable),
        );
        await _createTableIfMissing(
          tableName: 'manga_library',
          createTable: () => m.createTable(mangaLibraryTable),
        );
        await _createTableIfMissing(
          tableName: 'chapter_page_cache',
          createTable: () => m.createTable(chapterPageCacheTable),
        );
        await _createTableIfMissing(
          tableName: 'manga_download',
          createTable: () => m.createTable(mangaDownloadTable),
        );
        await _createMangaIndices();
      }
      if (from < 21) {
        // S1.E (manga source picker): per-manga preferred source plugin
        // id. Strictly additive on the manga_library table.
        // Must run AFTER the from < 20 block so manga_library exists.
        await _ensureColumn(
          tableName: 'manga_library',
          columnName: 'preferred_source_id',
          sqlDefinition: 'TEXT',
        );
      }
    },
    beforeOpen: (details) async {
      if (details.wasCreated) {
        // For fresh databases, create all indices immediately.
        await _createIndices();
        await _createMangaIndices();
      }

      // sync_queue is managed via custom SQL to keep storage decoupled from
      // sync package contracts and generated drift table code.
      await _ensureSyncQueueTable();
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
    await _createTableIfMissing(
      tableName: 'aniskip_cache',
      createTable: () => m.createTable(aniSkipCacheTable),
    );
    await _createTableIfMissing(
      tableName: 'hls_segment',
      createTable: () => m.createTable(hlsSegmentTable),
    );
    await _createTableIfMissing(
      tableName: 'translation_cache',
      createTable: () => m.createTable(translationCacheTable),
    );
    await _createTableIfMissing(
      tableName: 'episode_catalog_cache',
      createTable: () => m.createTable(episodeCatalogCacheTable),
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
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_aniskip_cache_updated '
      'ON aniskip_cache (updated_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_aniskip_cache_anime '
      'ON aniskip_cache (anilist_id, episode_number)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_hls_segment_task '
      'ON hls_segment (download_task_id, segment_index)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_library_entry_notify '
      'ON library_entry (notify_new_episodes) WHERE notify_new_episodes = 1',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_library_entry_auto_download '
      'ON library_entry (auto_download_new_episodes) WHERE auto_download_new_episodes = 1',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_translation_cache_updated '
      'ON translation_cache (updated_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_episode_catalog_cache_anime '
      'ON episode_catalog_cache (anilist_id, episode_number)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_episode_catalog_cache_updated '
      'ON episode_catalog_cache (updated_at)',
    );
  }

  Future<void> _createMangaIndices() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_manga_cache_updated '
      'ON manga_cache (updated_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_manga_chapter_anime_number '
      'ON manga_chapter (manga_anilist_id, number)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_manga_chapter_source_lang '
      'ON manga_chapter (source_id, source_manga_id, language)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_manga_progress_manga_updated '
      'ON manga_progress (manga_anilist_id, updated_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_manga_history_last_accessed '
      'ON manga_history (last_accessed_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_manga_library_notify '
      'ON manga_library (notify_new_chapters) WHERE notify_new_chapters = 1',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_manga_library_auto_download '
      'ON manga_library (auto_download_new_chapters) WHERE auto_download_new_chapters = 1',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_chapter_page_cache_expires '
      'ON chapter_page_cache (expires_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_manga_download_manga '
      'ON manga_download (manga_anilist_id, created_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_manga_download_status '
      'ON manga_download (status, created_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_manga_download_status_manga '
      'ON manga_download (status, manga_anilist_id)',
    );
  }

  Future<void> _ensureSyncQueueTable() async {
    await customStatement('''
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
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_status_created '
      'ON sync_queue (status, created_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_entity '
      'ON sync_queue (entity_type, entity_key)',
    );
  }
}
