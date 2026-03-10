// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_task_dao.dart';

// ignore_for_file: type=lint
mixin _$DownloadTaskDaoMixin on DatabaseAccessor<AppDatabase> {
  $DownloadTaskTableTable get downloadTaskTable =>
      attachedDatabase.downloadTaskTable;
  DownloadTaskDaoManager get managers => DownloadTaskDaoManager(this);
}

class DownloadTaskDaoManager {
  final _$DownloadTaskDaoMixin _db;
  DownloadTaskDaoManager(this._db);
  $$DownloadTaskTableTableTableManager get downloadTaskTable =>
      $$DownloadTaskTableTableTableManager(
        _db.attachedDatabase,
        _db.downloadTaskTable,
      );
}
