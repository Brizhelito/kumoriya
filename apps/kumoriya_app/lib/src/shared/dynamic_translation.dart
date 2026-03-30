import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:kumoriya_storage/kumoriya_storage.dart';

import 'storage_providers.dart';

typedef DynamicTranslationRequest = ({String text, String targetLanguage});

final dynamicTranslationServiceProvider = Provider<DynamicTranslationService>((
  ref,
) {
  final client = http.Client();
  ref.onDispose(client.close);
  return DynamicTranslationService(
    client: client,
    cacheStore: ref.watch(translationCacheStoreProvider),
  );
});

final translatedDynamicTextProvider = FutureProvider.autoDispose
    .family<String, DynamicTranslationRequest>((ref, request) async {
      return ref
          .watch(dynamicTranslationServiceProvider)
          .translate(
            text: request.text,
            targetLanguage: request.targetLanguage,
          );
    });

/// Client-side translation service using Google Translate's free endpoint.
///
/// Uses `translate.googleapis.com/translate_a/single?client=gtx` which does
/// not require an API key. Includes in-memory caching, request deduplication,
/// and automatic chunking for long texts.
final class DynamicTranslationService {
  DynamicTranslationService({
    required http.Client client,
    TranslationCacheStore? cacheStore,
    Duration maxCacheAge = const Duration(days: 30),
  }) : _client = client,
       _cacheStore = cacheStore,
       _maxCacheAge = maxCacheAge;

  static const String _host = 'translate.googleapis.com';
  static const String _path = '/translate_a/single';

  /// Google Translate accepts ~5000 chars per request; we stay safe.
  static const int _maxChunkSize = 4500;

  final http.Client _client;
  final TranslationCacheStore? _cacheStore;
  final Duration _maxCacheAge;
  final Map<String, String> _cache = <String, String>{};
  final Map<String, Future<String>> _pending = <String, Future<String>>{};

  Future<String> translate({
    required String text,
    required String targetLanguage,
  }) {
    final normalizedText = text.trim();
    final normalizedTarget = targetLanguage.trim().toLowerCase();
    if (normalizedText.isEmpty || !_shouldTranslate(normalizedTarget)) {
      return Future<String>.value(text);
    }

    final cacheKey = '$normalizedTarget::$normalizedText';
    final cached = _cache[cacheKey];
    if (cached != null) {
      return Future<String>.value(cached);
    }

    final pending = _pending[cacheKey];
    if (pending != null) {
      return pending;
    }

    final future =
        _resolveTranslation(
              text: normalizedText,
              targetLanguage: normalizedTarget,
            )
            .then((value) {
              _cache[cacheKey] = value;
              _pending.remove(cacheKey);
              return value;
            })
            .onError<Object>((error, stackTrace) {
              _pending.remove(cacheKey);
              return normalizedText;
            });
    _pending[cacheKey] = future;
    return future;
  }

  bool _shouldTranslate(String targetLanguage) {
    return targetLanguage == 'es';
  }

  Future<String> _resolveTranslation({
    required String text,
    required String targetLanguage,
  }) async {
    final persisted = await _readPersistedTranslation(
      text: text,
      targetLanguage: targetLanguage,
    );
    if (persisted != null) {
      return persisted;
    }

    final translated = await _translateFull(
      text: text,
      targetLanguage: targetLanguage,
    );
    if (translated == null) {
      return text;
    }

    unawaited(
      _persistTranslation(
        text: text,
        targetLanguage: targetLanguage,
        translatedText: translated,
      ),
    );
    return translated;
  }

  Future<String?> _readPersistedTranslation({
    required String text,
    required String targetLanguage,
  }) async {
    final store = _cacheStore;
    if (store == null) {
      return null;
    }

    final result = await store.get(
      sourceText: text,
      targetLanguage: targetLanguage,
    );

    return result.fold(
      onFailure: (_) => null,
      onSuccess: (entry) {
        if (entry == null) {
          return null;
        }

        final cutoff = DateTime.now().subtract(_maxCacheAge);
        if (entry.updatedAt.isBefore(cutoff)) {
          return null;
        }

        return entry.translatedText;
      },
    );
  }

  Future<void> _persistTranslation({
    required String text,
    required String targetLanguage,
    required String translatedText,
  }) async {
    final store = _cacheStore;
    if (store == null) {
      return;
    }

    await store.upsert(
      TranslationCacheEntry(
        sourceText: text,
        targetLanguage: targetLanguage,
        translatedText: translatedText,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Translates full text, chunking if needed.
  Future<String?> _translateFull({
    required String text,
    required String targetLanguage,
  }) async {
    if (text.length <= _maxChunkSize) {
      return _translateChunk(text: text, targetLanguage: targetLanguage);
    }

    final chunks = _splitIntoChunks(text, _maxChunkSize);
    final translated = <String>[];
    for (final chunk in chunks) {
      final translatedChunk = await _translateChunk(
        text: chunk,
        targetLanguage: targetLanguage,
      );
      if (translatedChunk == null) {
        return null;
      }
      translated.add(translatedChunk);
    }
    return translated.join(' ');
  }

  /// Sends a single chunk to Google Translate.
  Future<String?> _translateChunk({
    required String text,
    required String targetLanguage,
  }) async {
    try {
      final uri = Uri.https(_host, _path, <String, String>{
        'client': 'gtx',
        'sl': 'auto',
        'tl': targetLanguage,
        'dt': 't',
        'ie': 'UTF-8',
        'oe': 'UTF-8',
        'q': text,
      });

      final response = await _client
          .get(
            uri,
            headers: const <String, String>{
              'Accept': '*/*',
              'User-Agent': 'Kumoriya/1.0',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null;
      }

      return _parseGoogleResponse(response.body, fallback: text);
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Parses Google Translate's non-standard JSON response.
  ///
  /// Response shape: `[[[translatedSegment, originalSegment, ...], ...], ...]`
  static String? _parseGoogleResponse(String body, {required String fallback}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! List || decoded.isEmpty) return null;

      final segments = decoded[0];
      if (segments is! List) return null;

      final buffer = StringBuffer();
      for (final segment in segments) {
        if (segment is List && segment.isNotEmpty && segment[0] is String) {
          buffer.write(segment[0] as String);
        }
      }

      final result = buffer.toString().trim();
      return result.isEmpty ? fallback : result;
    } catch (_) {
      return null;
    }
  }

  /// Splits text into chunks at sentence/paragraph boundaries.
  static List<String> _splitIntoChunks(String text, int maxSize) {
    if (text.length <= maxSize) return <String>[text];

    final chunks = <String>[];
    var remaining = text;

    while (remaining.isNotEmpty) {
      if (remaining.length <= maxSize) {
        chunks.add(remaining);
        break;
      }

      // Try to split at last newline within limit.
      var splitAt = remaining.lastIndexOf('\n', maxSize);
      if (splitAt <= 0) {
        // Try last sentence end within limit.
        splitAt = remaining.lastIndexOf('. ', maxSize);
        if (splitAt > 0) {
          splitAt += 2; // Include the period and space.
        }
      }
      if (splitAt <= 0) {
        // Hard split at limit.
        splitAt = maxSize;
      }

      chunks.add(remaining.substring(0, splitAt).trim());
      remaining = remaining.substring(splitAt).trim();
    }

    return chunks;
  }
}
