// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manga_download_dao.dart';

// ignore_for_file: type=lint
mixin _$MangaDownloadDaoMixin on DatabaseAccessor<AppDatabase> {
  $MangaDownloadTableTable get mangaDownloadTable =>
      attachedDatabase.mangaDownloadTable;
  MangaDownloadDaoManager get managers => MangaDownloadDaoManager(this);
}

class MangaDownloadDaoManager {
  final _$MangaDownloadDaoMixin _db;
  MangaDownloadDaoManager(this._db);
  $$MangaDownloadTableTableTableManager get mangaDownloadTable =>
      $$MangaDownloadTableTableTableManager(
        _db.attachedDatabase,
        _db.mangaDownloadTable,
      );
}
