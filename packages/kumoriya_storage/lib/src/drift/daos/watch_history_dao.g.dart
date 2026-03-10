// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watch_history_dao.dart';

// ignore_for_file: type=lint
mixin _$WatchHistoryDaoMixin on DatabaseAccessor<AppDatabase> {
  $WatchHistoryTableTable get watchHistoryTable =>
      attachedDatabase.watchHistoryTable;
  WatchHistoryDaoManager get managers => WatchHistoryDaoManager(this);
}

class WatchHistoryDaoManager {
  final _$WatchHistoryDaoMixin _db;
  WatchHistoryDaoManager(this._db);
  $$WatchHistoryTableTableTableManager get watchHistoryTable =>
      $$WatchHistoryTableTableTableManager(
        _db.attachedDatabase,
        _db.watchHistoryTable,
      );
}
