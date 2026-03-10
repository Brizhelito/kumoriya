// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anilist_cache_dao.dart';

// ignore_for_file: type=lint
mixin _$AnilistCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $AnilistCacheTableTable get anilistCacheTable =>
      attachedDatabase.anilistCacheTable;
  AnilistCacheDaoManager get managers => AnilistCacheDaoManager(this);
}

class AnilistCacheDaoManager {
  final _$AnilistCacheDaoMixin _db;
  AnilistCacheDaoManager(this._db);
  $$AnilistCacheTableTableTableManager get anilistCacheTable =>
      $$AnilistCacheTableTableTableManager(
        _db.attachedDatabase,
        _db.anilistCacheTable,
      );
}
