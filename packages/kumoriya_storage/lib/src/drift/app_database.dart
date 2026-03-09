import 'package:drift/drift.dart';

import 'tables/episode_progress_table.dart';
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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(playbackPreferenceTable);
      }
      if (from < 3) {
        await migrator.createTable(sourceAvailabilityCacheTable);
      }
    },
  );
}
