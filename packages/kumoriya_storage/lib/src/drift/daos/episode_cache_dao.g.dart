// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episode_cache_dao.dart';

// ignore_for_file: type=lint
mixin _$EpisodeCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $EpisodeCatalogCacheTableTable get episodeCatalogCacheTable =>
      attachedDatabase.episodeCatalogCacheTable;
  EpisodeCacheDaoManager get managers => EpisodeCacheDaoManager(this);
}

class EpisodeCacheDaoManager {
  final _$EpisodeCacheDaoMixin _db;
  EpisodeCacheDaoManager(this._db);
  $$EpisodeCatalogCacheTableTableTableManager get episodeCatalogCacheTable =>
      $$EpisodeCatalogCacheTableTableTableManager(
        _db.attachedDatabase,
        _db.episodeCatalogCacheTable,
      );
}
