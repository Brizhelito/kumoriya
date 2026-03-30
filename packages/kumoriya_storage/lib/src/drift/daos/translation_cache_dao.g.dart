// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'translation_cache_dao.dart';

// ignore_for_file: type=lint
mixin _$TranslationCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $TranslationCacheTableTable get translationCacheTable =>
      attachedDatabase.translationCacheTable;
  TranslationCacheDaoManager get managers => TranslationCacheDaoManager(this);
}

class TranslationCacheDaoManager {
  final _$TranslationCacheDaoMixin _db;
  TranslationCacheDaoManager(this._db);
  $$TranslationCacheTableTableTableManager get translationCacheTable =>
      $$TranslationCacheTableTableTableManager(
        _db.attachedDatabase,
        _db.translationCacheTable,
      );
}
