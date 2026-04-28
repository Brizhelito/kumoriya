// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manga_cache_dao.dart';

// ignore_for_file: type=lint
mixin _$MangaCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $MangaCacheTableTable get mangaCacheTable => attachedDatabase.mangaCacheTable;
  MangaCacheDaoManager get managers => MangaCacheDaoManager(this);
}

class MangaCacheDaoManager {
  final _$MangaCacheDaoMixin _db;
  MangaCacheDaoManager(this._db);
  $$MangaCacheTableTableTableManager get mangaCacheTable =>
      $$MangaCacheTableTableTableManager(
        _db.attachedDatabase,
        _db.mangaCacheTable,
      );
}
