import 'package:drift/native.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:test/test.dart';

bool _isSqliteRuntimeAvailable() {
  try {
    final db = sqlite.sqlite3.openInMemory();
    db.dispose();
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  final sqliteAvailable = _isSqliteRuntimeAvailable();

  late AppDatabase db;
  late DriftTranslationCacheStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftTranslationCacheStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  group(
    'DriftTranslationCacheStore',
    skip: sqliteAvailable
        ? false
        : 'SQLite runtime is unavailable in this test environment.',
    () {
    test('upsert and get translation entry', () async {
      final entry = TranslationCacheEntry(
        sourceText: 'Hello world',
        targetLanguage: 'es',
        translatedText: 'Hola mundo',
        updatedAt: DateTime(2026, 3, 23),
      );

      final upsertResult = await store.upsert(entry);
      upsertResult.fold(
        onFailure: (error) => fail('upsert failed: ${error.message}'),
        onSuccess: (_) {},
      );

      final getResult = await store.get(
        sourceText: 'Hello world',
        targetLanguage: 'es',
      );
      final saved = getResult.fold<TranslationCacheEntry?>(
        onFailure: (error) => fail('get failed: ${error.message}'),
        onSuccess: (entry) => entry,
      );

      expect(saved, isNotNull);
      expect(saved!.translatedText, 'Hola mundo');
      expect(saved.targetLanguage, 'es');
    });

    test('upsert overwrites existing translation entry', () async {
      await store.upsert(
        TranslationCacheEntry(
          sourceText: 'Hello world',
          targetLanguage: 'es',
          translatedText: 'Hola mundo',
          updatedAt: DateTime(2026, 3, 23),
        ),
      );

      await store.upsert(
        TranslationCacheEntry(
          sourceText: 'Hello world',
          targetLanguage: 'es',
          translatedText: 'Hola, mundo',
          updatedAt: DateTime(2026, 3, 24),
        ),
      );

      final getResult = await store.get(
        sourceText: 'Hello world',
        targetLanguage: 'es',
      );
      final saved = getResult.fold<TranslationCacheEntry?>(
        onFailure: (error) => fail('get failed: ${error.message}'),
        onSuccess: (entry) => entry,
      );

      expect(saved, isNotNull);
      expect(saved!.translatedText, 'Hola, mundo');
    });

    test('deleteOlderThan removes stale translation entries', () async {
      await store.upsert(
        TranslationCacheEntry(
          sourceText: 'old',
          targetLanguage: 'es',
          translatedText: 'viejo',
          updatedAt: DateTime(2024, 1, 1),
        ),
      );
      await store.upsert(
        TranslationCacheEntry(
          sourceText: 'new',
          targetLanguage: 'es',
          translatedText: 'nuevo',
          updatedAt: DateTime.now(),
        ),
      );

      final result = await store.deleteOlderThan(const Duration(days: 180));
      final count = result.fold<int>(
        onFailure: (error) => fail('deleteOlderThan failed: ${error.message}'),
        onSuccess: (value) => value,
      );
      expect(count, 1);

      final gone = await store.get(sourceText: 'old', targetLanguage: 'es');
      final goneEntry = gone.fold<TranslationCacheEntry?>(
        onFailure: (error) => fail('get old failed: ${error.message}'),
        onSuccess: (entry) => entry,
      );
      expect(goneEntry, isNull);

      final kept = await store.get(sourceText: 'new', targetLanguage: 'es');
      final keptEntry = kept.fold<TranslationCacheEntry?>(
        onFailure: (error) => fail('get new failed: ${error.message}'),
        onSuccess: (entry) => entry,
      );
      expect(keptEntry, isNotNull);
    });
  });
}
