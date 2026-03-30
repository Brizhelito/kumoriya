import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/translation_cache_table.dart';

part 'translation_cache_dao.g.dart';

@DriftAccessor(tables: [TranslationCacheTable])
class TranslationCacheDao extends DatabaseAccessor<AppDatabase>
    with _$TranslationCacheDaoMixin {
  TranslationCacheDao(super.db);

  Future<void> upsert(TranslationCacheTableCompanion entry) {
    return into(translationCacheTable).insertOnConflictUpdate(entry);
  }

  Future<TranslationCacheTableData?> get({
    required String sourceText,
    required String targetLanguage,
  }) {
    return (select(translationCacheTable)
          ..where(
            (t) =>
                t.sourceText.equals(sourceText) &
                t.targetLanguage.equals(targetLanguage),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<int> deleteOlderThan(int epochMs) {
    return (delete(
      translationCacheTable,
    )..where((t) => t.updatedAt.isSmallerThanValue(epochMs))).go();
  }
}
