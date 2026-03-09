// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_availability_cache_dao.dart';

// ignore_for_file: type=lint
mixin _$SourceAvailabilityCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $SourceAvailabilityCacheTableTable get sourceAvailabilityCacheTable =>
      attachedDatabase.sourceAvailabilityCacheTable;
  SourceAvailabilityCacheDaoManager get managers =>
      SourceAvailabilityCacheDaoManager(this);
}

class SourceAvailabilityCacheDaoManager {
  final _$SourceAvailabilityCacheDaoMixin _db;
  SourceAvailabilityCacheDaoManager(this._db);
  $$SourceAvailabilityCacheTableTableTableManager
  get sourceAvailabilityCacheTable =>
      $$SourceAvailabilityCacheTableTableTableManager(
        _db.attachedDatabase,
        _db.sourceAvailabilityCacheTable,
      );
}
