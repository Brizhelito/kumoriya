// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manga_chapter_dao.dart';

// ignore_for_file: type=lint
mixin _$MangaChapterDaoMixin on DatabaseAccessor<AppDatabase> {
  $MangaChapterTableTable get mangaChapterTable =>
      attachedDatabase.mangaChapterTable;
  MangaChapterDaoManager get managers => MangaChapterDaoManager(this);
}

class MangaChapterDaoManager {
  final _$MangaChapterDaoMixin _db;
  MangaChapterDaoManager(this._db);
  $$MangaChapterTableTableTableManager get mangaChapterTable =>
      $$MangaChapterTableTableTableManager(
        _db.attachedDatabase,
        _db.mangaChapterTable,
      );
}
