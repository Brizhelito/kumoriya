// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_entry_dao.dart';

// ignore_for_file: type=lint
mixin _$LibraryEntryDaoMixin on DatabaseAccessor<AppDatabase> {
  $LibraryEntryTableTable get libraryEntryTable =>
      attachedDatabase.libraryEntryTable;
  LibraryEntryDaoManager get managers => LibraryEntryDaoManager(this);
}

class LibraryEntryDaoManager {
  final _$LibraryEntryDaoMixin _db;
  LibraryEntryDaoManager(this._db);
  $$LibraryEntryTableTableTableManager get libraryEntryTable =>
      $$LibraryEntryTableTableTableManager(
        _db.attachedDatabase,
        _db.libraryEntryTable,
      );
}
