import 'package:kumoriya_core/kumoriya_core.dart';

final class TranslationCacheEntry {
  const TranslationCacheEntry({
    required this.sourceText,
    required this.targetLanguage,
    required this.translatedText,
    required this.updatedAt,
  });

  final String sourceText;
  final String targetLanguage;
  final String translatedText;
  final DateTime updatedAt;
}

abstract interface class TranslationCacheStore {
  Future<Result<void, KumoriyaError>> upsert(TranslationCacheEntry entry);

  Future<Result<TranslationCacheEntry?, KumoriyaError>> get({
    required String sourceText,
    required String targetLanguage,
  });

  Future<Result<int, KumoriyaError>> deleteOlderThan(Duration maxAge);
}
