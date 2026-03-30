import 'package:drift/drift.dart';

class TranslationCacheTable extends Table {
  @override
  String get tableName => 'translation_cache';

  TextColumn get sourceText => text()();
  TextColumn get targetLanguage => text()();
  TextColumn get translatedText => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {sourceText, targetLanguage};
}
