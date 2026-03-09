import 'package:drift/drift.dart';

class PlaybackPreferenceTable extends Table {
  @override
  String get tableName => 'playback_preference';

  IntColumn get anilistId => integer()();
  TextColumn get preferredSourcePluginId => text().nullable()();
  TextColumn get preferredServerName => text().nullable()();
  TextColumn get preferredResolverPluginId => text().nullable()();
  TextColumn get preferredAudioPreference => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {anilistId};
}
