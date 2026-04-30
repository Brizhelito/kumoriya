import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:test/test.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

void main() {
  test(
    'repairs legacy watch history schema when database version is stale',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'kumoriya-db-migration-',
      );
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}kumoriya_test.db',
      );

      final legacyDb = sqlite.sqlite3.open(dbFile.path);
      legacyDb.execute('PRAGMA user_version = 2;');
      legacyDb.execute('''
      CREATE TABLE episode_progress (
        anilist_id INTEGER NOT NULL,
        episode_number REAL NOT NULL,
        position_seconds INTEGER NOT NULL,
        total_duration_seconds INTEGER,
        watch_state TEXT NOT NULL DEFAULT 'unwatched',
        last_source_plugin_id TEXT,
        last_server_name TEXT,
        last_resolver_plugin_id TEXT,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (anilist_id, episode_number)
      );
    ''');
      legacyDb.execute('''
      CREATE TABLE watch_history (
        anilist_id INTEGER NOT NULL,
        last_episode_number REAL NOT NULL,
        last_source_plugin_id TEXT,
        last_accessed_at INTEGER NOT NULL,
        PRIMARY KEY (anilist_id)
      );
    ''');
      legacyDb.execute('''
      INSERT INTO watch_history (
        anilist_id,
        last_episode_number,
        last_source_plugin_id,
        last_accessed_at
      ) VALUES (182587, 8.0, 'kumoriya.source.jkanime', 1773112900476);
    ''');
      legacyDb.close();

      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(() async {
        await db.close();
        if (dbFile.existsSync()) {
          dbFile.deleteSync();
        }
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final store = DriftAnimeProgressStore(db);
      final historyResult = await store.getRecentHistory(limit: 5);

      expect(
        historyResult,
        isA<Success<List<AnimeWatchHistory>, KumoriyaError>>(),
      );

      final history =
          (historyResult as Success<List<AnimeWatchHistory>, KumoriyaError>)
              .value;
      expect(history, hasLength(1));
      expect(history.single.anilistId, 182587);
      expect(history.single.lastEpisodeNumber, 8.0);
      expect(history.single.lastPositionSeconds, 0);
      expect(history.single.lastTotalDurationSeconds, isNull);

      final columns = await db
          .customSelect('PRAGMA table_info(watch_history)')
          .get();
      final columnNames = columns
          .map((row) => row.read<String>('name'))
          .toList();
      expect(columnNames, contains('last_position_seconds'));
      expect(columnNames, contains('last_total_duration_seconds'));

      final versionRow = await db
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(versionRow.read<int>('user_version'), 22);

      final translationTables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'translation_cache'",
          )
          .get();
      expect(translationTables, isNotEmpty);

      final syncQueueTables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'sync_queue'",
          )
          .get();
      expect(syncQueueTables, isNotEmpty);
    },
  );

  test(
    'v19 → v20 migration creates manga tables and indices without touching anime',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'kumoriya-db-migration-v20-',
      );
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}kumoriya_test.db',
      );

      // Open at the current schema then forcibly downgrade user_version to
      // 19, dropping the v20 tables to simulate a pre-Slice-5 install.
      var db = AppDatabase(NativeDatabase(dbFile));
      await db.customSelect('SELECT 1').get();
      await db.customStatement('DROP TABLE IF EXISTS manga_cache');
      await db.customStatement('DROP TABLE IF EXISTS manga_chapter');
      await db.customStatement('DROP TABLE IF EXISTS manga_progress');
      await db.customStatement('DROP TABLE IF EXISTS manga_history');
      await db.customStatement('DROP TABLE IF EXISTS manga_library');
      await db.customStatement('DROP TABLE IF EXISTS chapter_page_cache');
      await db.customStatement('DROP TABLE IF EXISTS manga_download');
      await db.customStatement('PRAGMA user_version = 19');
      await db.close();

      // Snapshot the anime tables before migration so we can prove they
      // were not touched.
      final preDb = sqlite.sqlite3.open(dbFile.path);
      final animeTables = <String>[
        'episode_progress',
        'watch_history',
        'library_entry',
        'anilist_cache',
        'download_task',
        'aniskip_cache',
        'hls_segment',
        'translation_cache',
        'episode_catalog_cache',
      ];
      final preAnimeSchemas = {
        for (final t in animeTables)
          t: preDb
              .select(
                "SELECT sql FROM sqlite_master WHERE type='table' AND name = ?",
                [t],
              )
              .map((row) => row['sql'] as String?)
              .toList(),
      };
      preDb.close();

      // Reopen — triggers v19 → v20 migration.
      db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(() async {
        await db.close();
        if (dbFile.existsSync()) {
          dbFile.deleteSync();
        }
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final version = (await db.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version');
      expect(version, 22);

      final mangaTables = <String>[
        'manga_cache',
        'manga_chapter',
        'manga_progress',
        'manga_history',
        'manga_library',
        'chapter_page_cache',
        'manga_download',
      ];
      for (final t in mangaTables) {
        final found = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
              variables: [Variable.withString(t)],
            )
            .get();
        expect(found, isNotEmpty, reason: 'missing manga table $t');
      }

      final mangaIndices = <String>[
        'idx_manga_cache_updated',
        'idx_manga_chapter_anime_number',
        'idx_manga_chapter_source_lang',
        'idx_manga_progress_manga_updated',
        'idx_manga_history_last_accessed',
        'idx_manga_library_notify',
        'idx_manga_library_auto_download',
        'idx_chapter_page_cache_expires',
        'idx_manga_download_manga',
        'idx_manga_download_status',
        'idx_manga_download_status_manga',
      ];
      for (final ix in mangaIndices) {
        final found = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='index' AND name = ?",
              variables: [Variable.withString(ix)],
            )
            .get();
        expect(found, isNotEmpty, reason: 'missing manga index $ix');
      }

      // Anime schemas must be byte-identical post-migration.
      for (final t in animeTables) {
        final post = await db
            .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='table' AND name = ?",
              variables: [Variable.withString(t)],
            )
            .map((row) => row.read<String?>('sql'))
            .get();
        expect(
          post,
          equals(preAnimeSchemas[t]),
          reason: 'anime table $t schema changed during v20 migration',
        );
      }
    },
  );
}
