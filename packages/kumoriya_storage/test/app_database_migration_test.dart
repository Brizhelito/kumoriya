import 'dart:io';

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
      expect(versionRow.read<int>('user_version'), 8);
    },
  );
}
