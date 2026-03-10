import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/playback_preference_table.dart';

part 'playback_preference_dao.g.dart';

@DriftAccessor(tables: [PlaybackPreferenceTable])
class PlaybackPreferenceDao extends DatabaseAccessor<AppDatabase>
    with _$PlaybackPreferenceDaoMixin {
  PlaybackPreferenceDao(super.db);

  Future<void> upsertPlaybackPreference(
    PlaybackPreferenceTableCompanion entry,
  ) {
    return into(playbackPreferenceTable).insertOnConflictUpdate(entry);
  }

  Future<PlaybackPreferenceTableData?> getPlaybackPreference(int anilistId) {
    return (select(playbackPreferenceTable)
          ..where((t) => t.anilistId.equals(anilistId))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> deletePlaybackPreference(int anilistId) {
    return (delete(
      playbackPreferenceTable,
    )..where((t) => t.anilistId.equals(anilistId))).go();
  }
}
