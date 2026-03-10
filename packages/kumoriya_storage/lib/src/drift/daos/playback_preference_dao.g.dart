// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_preference_dao.dart';

// ignore_for_file: type=lint
mixin _$PlaybackPreferenceDaoMixin on DatabaseAccessor<AppDatabase> {
  $PlaybackPreferenceTableTable get playbackPreferenceTable =>
      attachedDatabase.playbackPreferenceTable;
  PlaybackPreferenceDaoManager get managers =>
      PlaybackPreferenceDaoManager(this);
}

class PlaybackPreferenceDaoManager {
  final _$PlaybackPreferenceDaoMixin _db;
  PlaybackPreferenceDaoManager(this._db);
  $$PlaybackPreferenceTableTableTableManager get playbackPreferenceTable =>
      $$PlaybackPreferenceTableTableTableManager(
        _db.attachedDatabase,
        _db.playbackPreferenceTable,
      );
}
