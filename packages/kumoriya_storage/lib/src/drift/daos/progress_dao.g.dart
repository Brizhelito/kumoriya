// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_dao.dart';

// ignore_for_file: type=lint
mixin _$ProgressDaoMixin on DatabaseAccessor<AppDatabase> {
  $EpisodeProgressTableTable get episodeProgressTable =>
      attachedDatabase.episodeProgressTable;
  $WatchHistoryTableTable get watchHistoryTable =>
      attachedDatabase.watchHistoryTable;
  $PlaybackPreferenceTableTable get playbackPreferenceTable =>
      attachedDatabase.playbackPreferenceTable;
  ProgressDaoManager get managers => ProgressDaoManager(this);
}

class ProgressDaoManager {
  final _$ProgressDaoMixin _db;
  ProgressDaoManager(this._db);
  $$EpisodeProgressTableTableTableManager get episodeProgressTable =>
      $$EpisodeProgressTableTableTableManager(
        _db.attachedDatabase,
        _db.episodeProgressTable,
      );
  $$WatchHistoryTableTableTableManager get watchHistoryTable =>
      $$WatchHistoryTableTableTableManager(
        _db.attachedDatabase,
        _db.watchHistoryTable,
      );
  $$PlaybackPreferenceTableTableTableManager get playbackPreferenceTable =>
      $$PlaybackPreferenceTableTableTableManager(
        _db.attachedDatabase,
        _db.playbackPreferenceTable,
      );
}
