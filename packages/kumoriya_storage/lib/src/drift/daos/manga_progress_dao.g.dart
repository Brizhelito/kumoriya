// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manga_progress_dao.dart';

// ignore_for_file: type=lint
mixin _$MangaProgressDaoMixin on DatabaseAccessor<AppDatabase> {
  $MangaProgressTableTable get mangaProgressTable =>
      attachedDatabase.mangaProgressTable;
  $MangaHistoryTableTable get mangaHistoryTable =>
      attachedDatabase.mangaHistoryTable;
  MangaProgressDaoManager get managers => MangaProgressDaoManager(this);
}

class MangaProgressDaoManager {
  final _$MangaProgressDaoMixin _db;
  MangaProgressDaoManager(this._db);
  $$MangaProgressTableTableTableManager get mangaProgressTable =>
      $$MangaProgressTableTableTableManager(
        _db.attachedDatabase,
        _db.mangaProgressTable,
      );
  $$MangaHistoryTableTableTableManager get mangaHistoryTable =>
      $$MangaHistoryTableTableTableManager(
        _db.attachedDatabase,
        _db.mangaHistoryTable,
      );
}
