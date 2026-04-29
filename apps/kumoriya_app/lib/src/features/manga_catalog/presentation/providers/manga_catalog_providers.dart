import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_source_mangadex/kumoriya_source_mangadex.dart';

import '../../../../shared/cache/fallback_reason.dart';
import '../../../../shared/storage_providers.dart';
import '../../../anime_catalog/presentation/providers/anime_catalog_providers.dart';
import '../../application/services/composite_manga_catalog_repository.dart';

/// Aggregate payload for the manga Home screen. Re-exports the domain
/// `MangaHomeSections` under the legacy name so existing UI code keeps
/// compiling while the call path collapses to a single repository call.
typedef MangaHomeData = MangaHomeSections;

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

final _compositeMangaCatalogRepositoryProvider =
    Provider<CompositeMangaCatalogRepository>((ref) {
      final gateway = ref.watch(anilistMetadataGatewayProvider);
      final delegate = AnilistMangaCatalogRepository(gateway: gateway);
      return CompositeMangaCatalogRepository(
        delegate: delegate,
        sourcePlugin: ref.watch(mangaSourcePluginProvider),
        cacheStore: ref.watch(mangaCacheStoreProvider),
        preferredLanguages: ref.watch(mangaPreferredLanguagesProvider),
      );
    });

final mangaCatalogRepositoryProvider = Provider<MangaCatalogRepository>((ref) {
  return ref.watch(_compositeMangaCatalogRepositoryProvider);
});

/// Indicates why the most recent manga catalog fetch fell back to
/// locally-cached data, or [FallbackReason.none] when operating
/// normally. Exposed alongside the anime equivalent so the navigation
/// shell can collapse both into one banner.
final mangaCacheFallbackReasonProvider =
    Provider<ValueNotifier<FallbackReason>>((ref) {
      return ref.watch(_compositeMangaCatalogRepositoryProvider).fallbackReason;
    });

// ---------------------------------------------------------------------------
// Catalog reads
// ---------------------------------------------------------------------------

const _kHomeSectionPerPage = 20;

final mangaHomeProvider = FutureProvider.autoDispose<MangaHomeData>((
  ref,
) async {
  final repo = ref.watch(mangaCatalogRepositoryProvider);

  // Single backend-cached round-trip returns the four shelves
  // (trending / popular / latest / topRated). The Kumoriya Go backend
  // serves an aliased AniList query from a stale-while-revalidate
  // cache, so warm hits are ~150-300ms instead of the ~2-4s the
  // previous "4 sequential AniList queries" path took. On any
  // backend or upstream failure the gateway decorator transparently
  // falls back to direct AniList, which still uses the multi-alias
  // query — so we never burst-429 the AniList rate limit.
  final result = await repo.fetchHomeSections(perPage: _kHomeSectionPerPage);
  return result.fold(
    onSuccess: (sections) => sections,
    onFailure: (err) {
      developer.log(
        'mangaHome[sections] failed: ${err.code} ${err.message}',
        name: 'mangaHomeProvider',
      );
      throw _toException(err);
    },
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

/// Resolves a batch of AniList ids to `Manga` records, used by the
/// Library tabs (favorites / subscribed / history) to render covers.
/// Empty input short-circuits to `<Manga>[]` so callers can pass in
/// `ids.isEmpty` lists without an extra branch.
final mangaBatchByIdsProvider = FutureProvider.autoDispose
    .family<List<Manga>, List<int>>((ref, ids) async {
      if (ids.isEmpty) return const <Manga>[];
      final repo = ref.watch(mangaCatalogRepositoryProvider);
      final result = await repo.fetchBatchMangaByIds(ids);
      return result.fold(
        onSuccess: (list) => list,
        onFailure: (err) => throw _toException(err),
      );
    });

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
