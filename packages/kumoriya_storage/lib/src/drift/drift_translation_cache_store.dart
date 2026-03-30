import 'package:drift/drift.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import '../contracts/translation_cache_store.dart';
import 'app_database.dart';
import 'daos/translation_cache_dao.dart';

final class DriftTranslationCacheStore implements TranslationCacheStore {
  DriftTranslationCacheStore(AppDatabase db) : _dao = TranslationCacheDao(db);

  final TranslationCacheDao _dao;

  @override
  Future<Result<void, KumoriyaError>> upsert(
    TranslationCacheEntry entry,
  ) async {
    try {
      await _dao.upsert(
        TranslationCacheTableCompanion(
          sourceText: Value(entry.sourceText),
          targetLanguage: Value(entry.targetLanguage),
          translatedText: Value(entry.translatedText),
          updatedAt: Value(entry.updatedAt.millisecondsSinceEpoch),
        ),
      );
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.translation_cache_upsert_failed',
          message: 'Failed to cache translated text: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<TranslationCacheEntry?, KumoriyaError>> get({
    required String sourceText,
    required String targetLanguage,
  }) async {
    try {
      final row = await _dao.get(
        sourceText: sourceText,
        targetLanguage: targetLanguage,
      );
      return Success(
        row == null
            ? null
            : TranslationCacheEntry(
                sourceText: row.sourceText,
                targetLanguage: row.targetLanguage,
                translatedText: row.translatedText,
                updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
              ),
      );
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.translation_cache_read_failed',
          message: 'Failed to read translation cache: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<int, KumoriyaError>> deleteOlderThan(Duration maxAge) async {
    try {
      final cutoff = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;
      final count = await _dao.deleteOlderThan(cutoff);
      return Success(count);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.translation_cache_cleanup_failed',
          message: 'Failed to clean up translation cache: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }
}
