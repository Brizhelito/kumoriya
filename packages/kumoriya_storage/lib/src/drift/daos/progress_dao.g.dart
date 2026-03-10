// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_dao.dart';

// ignore_for_file: type=lint
mixin _$ProgressDaoMixin on DatabaseAccessor<AppDatabase> {
  $EpisodeProgressTableTable get episodeProgressTable =>
      attachedDatabase.episodeProgressTable;
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
}
