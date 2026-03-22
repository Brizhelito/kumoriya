// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hls_segment_dao.dart';

// ignore_for_file: type=lint
mixin _$HlsSegmentDaoMixin on DatabaseAccessor<AppDatabase> {
  $HlsSegmentTableTable get hlsSegmentTable => attachedDatabase.hlsSegmentTable;
  HlsSegmentDaoManager get managers => HlsSegmentDaoManager(this);
}

class HlsSegmentDaoManager {
  final _$HlsSegmentDaoMixin _db;
  HlsSegmentDaoManager(this._db);
  $$HlsSegmentTableTableTableManager get hlsSegmentTable =>
      $$HlsSegmentTableTableTableManager(
        _db.attachedDatabase,
        _db.hlsSegmentTable,
      );
}
