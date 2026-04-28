import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_source_mangadex/kumoriya_source_mangadex.dart';

import '../../../../shared/storage_providers.dart';
import '../../../anime_catalog/presentation/providers/anime_catalog_providers.dart';
import '../../application/services/composite_manga_catalog_repository.dart';

/// Aggregate payload for the manga Home screen.
///
/// Each list is independently failed-tolerant: when the backing
/// repository call fails for one section, the others still render. The
/// composite call returns this struct in a single `FutureProvider` so
/// the UI can do a single `pumpAndSettle`-friendly load + retry cycle.
class MangaHomeData {
  const MangaHomeData({
    required this.trending,
    required this.popular,
    required this.latest,
    required this.topRated,
  });

  final List<Manga> trending;
  final List<Manga> popular;
  final List<Manga> latest;
  final List<Manga> topRated;

  bool get isEmpty =>
      trending.isEmpty && popular.isEmpty && latest.isEmpty && topRated.isEmpty;
}

// ---------------------------------------------------------------------------
// Source plugin + composite repository
// ---------------------------------------------------------------------------

final mangaSourcePluginProvider = Provider<MangaSourcePlugin>((ref) {
  // MangaDex is the only manga source available in the MVP. When more
  // sources land, lift this to a registry similar to anime
  // `sourcePluginsProvider`.
  return MangaDexSourcePlugin();
});

/// Preferred chapter languages, derived from the active locale at the
/// widget tree root.
///
/// Returned as a `List<String> Function()` so the composite repository
/// can resolve the latest value at call time without holding a
/// `WidgetRef`. We initialize it from `WidgetsBinding.instance.platformDispatcher`
/// for the rare case where the repository is constructed before the
/// first widget tree pumps.
final mangaPreferredLanguagesProvider = Provider<List<String> Function()>((
  ref,
) {
  return () {
    final locale = WidgetsBinding
        .instance
        .platformDispatcher
        .locale
        .languageCode
        .toLowerCase();
    return switch (locale) {
      'es' => const ['es', 'es-la', 'es-es', 'en'],
      _ => const ['en'],
    };
  };
});

final mangaCatalogRepositoryProvider = Provider<MangaCatalogRepository>((ref) {
  final gateway = ref.watch(anilistMetadataGatewayProvider);
  final delegate = AnilistMangaCatalogRepository(gateway: gateway);
  return CompositeMangaCatalogRepository(
    delegate: delegate,
    sourcePlugin: ref.watch(mangaSourcePluginProvider),
    cacheStore: ref.watch(mangaCacheStoreProvider),
    preferredLanguages: ref.watch(mangaPreferredLanguagesProvider),
  );
});

// ---------------------------------------------------------------------------
// Catalog reads
// ---------------------------------------------------------------------------

const _kHomeSectionPerPage = 20;

final mangaHomeProvider = FutureProvider.autoDispose<MangaHomeData>((
  ref,
) async {
  final repo = ref.watch(mangaCatalogRepositoryProvider);

  // Trending == default sort. The other sections come from `browseManga`
  // with explicit sorts so each row has a distinct flavor.
  //
  // We run the four calls SEQUENTIALLY rather than via `Future.wait`:
  // AniList rate-limits at 90 req/min and aggressively rejects bursts,
  // so 4 parallel queries from a cold cache often return 429 for the
  // last 2-3, leaving the user with only "Trending" populated. Sequential
  // adds ~1-2s of latency but keeps every shelf reliable. We also log
  // failures (instead of swallowing them silently) so missing sections
  // are diagnosable via logcat.
  Future<List<Manga>> readBrowse(MangaSortType sort) async {
    final result = await repo.browseManga(
      MangaBrowseRequest(sort: sort, perPage: _kHomeSectionPerPage),
    );
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (err) {
        developer.log(
          'mangaHome[${sort.name}] failed: ${err.code} ${err.message}',
          name: 'mangaHomeProvider',
        );
        return const <Manga>[];
      },
    );
  }

  final trending = await repo
      .fetchHomeCatalog(perPage: _kHomeSectionPerPage)
      .then(
        (r) => r.fold(
          onSuccess: (list) => list,
          onFailure: (err) {
            developer.log(
              'mangaHome[trending] failed: ${err.code} ${err.message}',
              name: 'mangaHomeProvider',
            );
            return const <Manga>[];
          },
        ),
      );
  final popular = await readBrowse(MangaSortType.popularity);
  final latest = await readBrowse(MangaSortType.startDate);
  final topRated = await readBrowse(MangaSortType.score);

  return MangaHomeData(
    trending: trending,
    popular: popular,
    latest: latest,
    topRated: topRated,
  );
});

/// Plain mutable state for the search query input. The page widget
/// debounces input before writing to this provider.
class MangaSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

final mangaSearchQueryProvider =
    NotifierProvider<MangaSearchQueryNotifier, String>(
      MangaSearchQueryNotifier.new,
    );

final mangaSearchProvider = FutureProvider.autoDispose
    .family<List<Manga>, String>((ref, query) async {
      final trimmed = query.trim();
      if (trimmed.isEmpty) return const <Manga>[];
      final repo = ref.watch(mangaCatalogRepositoryProvider);
      final result = await repo.searchManga(
        MangaSearchRequest(query: trimmed, perPage: 30),
      );
      return result.fold(
        onSuccess: (list) => list,
        onFailure: (err) => throw _toException(err),
      );
    });

final mangaDetailProvider = FutureProvider.autoDispose.family<MangaDetail, int>(
  (ref, anilistId) async {
    final repo = ref.watch(mangaCatalogRepositoryProvider);
    final result = await repo.fetchMangaDetail(anilistId);
    return result.fold(
      onSuccess: (detail) => detail,
      onFailure: (err) => throw _toException(err),
    );
  },
);

final mangaChaptersProvider = FutureProvider.autoDispose
    .family<List<MangaChapter>, int>((ref, anilistId) async {
      final repo = ref.watch(mangaCatalogRepositoryProvider);
      final result = await repo.fetchMangaChapters(anilistId);
      return result.fold(
        onSuccess: (chapters) => chapters,
        onFailure: (err) => throw _toException(err),
      );
    });

Exception _toException(KumoriyaError err) =>
    Exception('${err.code}: ${err.message}');
