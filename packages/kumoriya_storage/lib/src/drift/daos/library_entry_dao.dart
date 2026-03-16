import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/library_entry_table.dart';

part 'library_entry_dao.g.dart';

@DriftAccessor(tables: [LibraryEntryTable])
class LibraryEntryDao extends DatabaseAccessor<AppDatabase>
    with _$LibraryEntryDaoMixin {
  LibraryEntryDao(super.db);

  Future<void> addFavorite(int anilistId, int addedAt) {
    return into(libraryEntryTable).insertOnConflictUpdate(
      LibraryEntryTableCompanion(
        anilistId: Value(anilistId),
        addedAt: Value(addedAt),
      ),
    );
  }

  Future<void> removeFavorite(int anilistId) {
    return (delete(
      libraryEntryTable,
    )..where((t) => t.anilistId.equals(anilistId))).go();
  }

  Future<List<LibraryEntryTableData>> getAllFavorites() {
    return (select(
      libraryEntryTable,
    )..orderBy([(t) => OrderingTerm.desc(t.addedAt)])).get();
  }

  Future<void> updateSubscription(int anilistId, {required bool notify}) {
    return (update(libraryEntryTable)
          ..where((t) => t.anilistId.equals(anilistId)))
        .write(LibraryEntryTableCompanion(notifyNewEpisodes: Value(notify)));
  }

  Future<List<LibraryEntryTableData>> getSubscribedEntries() {
    return (select(libraryEntryTable)
          ..where((t) => t.notifyNewEpisodes.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]))
        .get();
  }

  Future<void> updateLastNotifiedEpisode(int anilistId, int episodeNumber) {
    return (update(
      libraryEntryTable,
    )..where((t) => t.anilistId.equals(anilistId))).write(
      LibraryEntryTableCompanion(lastNotifiedEpisode: Value(episodeNumber)),
    );
  }
}
