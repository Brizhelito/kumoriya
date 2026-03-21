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
    return transaction(() async {
      final existing = await (select(
        libraryEntryTable,
      )..where((t) => t.anilistId.equals(anilistId))).getSingleOrNull();
      if (existing == null) {
        return;
      }

      final shouldKeepTrackingRow =
          existing.notifyNewEpisodes || existing.autoDownloadNewEpisodes;
      if (shouldKeepTrackingRow) {
        await (update(libraryEntryTable)
              ..where((t) => t.anilistId.equals(anilistId)))
            .write(const LibraryEntryTableCompanion(addedAt: Value(0)));
        return;
      }

      await (delete(
        libraryEntryTable,
      )..where((t) => t.anilistId.equals(anilistId))).go();
    });
  }

  Future<List<LibraryEntryTableData>> getAllFavorites() {
    return (select(libraryEntryTable)
          ..where((t) => t.addedAt.isBiggerThanValue(0))
          ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]))
        .get();
  }

  Future<void> updateSubscription(int anilistId, {required bool notify}) {
    return transaction(() async {
      final existing = await (select(
        libraryEntryTable,
      )..where((t) => t.anilistId.equals(anilistId))).getSingleOrNull();

      if (existing == null) {
        if (!notify) {
          return;
        }

        await into(libraryEntryTable).insert(
          LibraryEntryTableCompanion(
            anilistId: Value(anilistId),
            addedAt: const Value(0),
            notifyNewEpisodes: Value(notify),
          ),
        );
        return;
      }

      await (update(libraryEntryTable)
            ..where((t) => t.anilistId.equals(anilistId)))
          .write(LibraryEntryTableCompanion(notifyNewEpisodes: Value(notify)));

      if (!notify &&
          existing.addedAt <= 0 &&
          !existing.autoDownloadNewEpisodes) {
        await (delete(
          libraryEntryTable,
        )..where((t) => t.anilistId.equals(anilistId))).go();
      }
    });
  }

  Future<List<LibraryEntryTableData>> getSubscribedEntries() {
    return (select(libraryEntryTable)
          ..where((t) => t.notifyNewEpisodes.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]))
        .get();
  }

  Future<List<LibraryEntryTableData>> getTrackedEntries() {
    return (select(libraryEntryTable)
          ..where(
            (t) =>
                t.notifyNewEpisodes.equals(true) |
                t.autoDownloadNewEpisodes.equals(true),
          )
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

  Future<void> updateAutoDownload(int anilistId, {required bool autoDownload}) {
    return (update(
      libraryEntryTable,
    )..where((t) => t.anilistId.equals(anilistId))).write(
      LibraryEntryTableCompanion(autoDownloadNewEpisodes: Value(autoDownload)),
    );
  }

  Future<String?> getAutoDownloadAudioPreference(int anilistId) async {
    final row = await (select(
      libraryEntryTable,
    )..where((t) => t.anilistId.equals(anilistId))).getSingleOrNull();
    return row?.autoDownloadAudioPreference;
  }

  Future<void> setAutoDownloadAudioPreference(
    int anilistId,
    String preference,
  ) {
    return (update(
      libraryEntryTable,
    )..where((t) => t.anilistId.equals(anilistId))).write(
      LibraryEntryTableCompanion(
        autoDownloadAudioPreference: Value(preference),
      ),
    );
  }

  Future<List<LibraryEntryTableData>> getAutoDownloadEntries() {
    return (select(libraryEntryTable)
          ..where((t) => t.autoDownloadNewEpisodes.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]))
        .get();
  }
}
