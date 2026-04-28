import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import 'dev_fixtures.dart';

/// Seeds the local anime/manga caches with a small set of well-known
/// titles so the app boots into a usable state during development when
/// AniList is unreachable.
///
/// No-op in release builds. No-op when either cache already has at
/// least one entry — the assumption is that any user with cached data
/// from a prior session does not need the seed.
class DevCacheSeeder {
  DevCacheSeeder({
    required AnilistCacheStore animeStore,
    required MangaCacheStore mangaStore,
  }) : _animeStore = animeStore,
       _mangaStore = mangaStore;

  final AnilistCacheStore _animeStore;
  final MangaCacheStore _mangaStore;

  /// Seeds either store if it is empty. Safe to call multiple times —
  /// becomes a no-op once the cache has any content.
  Future<void> seedIfEmpty() async {
    if (!kDebugMode) return;
    final now = DateTime.now();
    await _maybeSeedAnime(now);
    await _maybeSeedManga(now);
  }

  Future<void> _maybeSeedAnime(DateTime now) async {
    final existing = await _animeStore.getRecent(limit: 1);
    final isEmpty = existing.fold(
      onSuccess: (entries) => entries.isEmpty,
      onFailure: (_) => false,
    );
    if (!isEmpty) return;

    var seeded = 0;
    for (final entry in DevFixtures.animeSeed(now)) {
      final res = await _animeStore.upsert(entry);
      if (res.isSuccess) seeded += 1;
    }
    developer.log(
      'seeded $seeded anime fixture entries (cache was empty)',
      name: 'DevCacheSeeder',
    );
  }

  Future<void> _maybeSeedManga(DateTime now) async {
    final existing = await _mangaStore.getRecent(limit: 1);
    final isEmpty = existing.fold(
      onSuccess: (entries) => entries.isEmpty,
      onFailure: (_) => false,
    );
    if (!isEmpty) return;

    var seeded = 0;
    for (final entry in DevFixtures.mangaSeed(now)) {
      final res = await _mangaStore.upsert(entry);
      if (res.isSuccess) seeded += 1;
    }
    developer.log(
      'seeded $seeded manga fixture entries (cache was empty)',
      name: 'DevCacheSeeder',
    );
  }
}
