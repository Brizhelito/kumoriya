// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manga_library_dao.dart';

// ignore_for_file: type=lint
mixin _$MangaLibraryDaoMixin on DatabaseAccessor<AppDatabase> {
  $MangaLibraryTableTable get mangaLibraryTable =>
      attachedDatabase.mangaLibraryTable;
  MangaLibraryDaoManager get managers => MangaLibraryDaoManager(this);
}

class MangaLibraryDaoManager {
  final _$MangaLibraryDaoMixin _db;
  MangaLibraryDaoManager(this._db);
  $$MangaLibraryTableTableTableManager get mangaLibraryTable =>
      $$MangaLibraryTableTableTableManager(
        _db.attachedDatabase,
        _db.mangaLibraryTable,
      );
}
