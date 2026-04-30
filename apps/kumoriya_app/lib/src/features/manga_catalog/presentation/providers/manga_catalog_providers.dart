import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_mangabaka/kumoriya_mangabaka.dart';
import 'package:kumoriya_source_mangadex/kumoriya_source_mangadex.dart';

import '../../../../shared/cache/fallback_reason.dart';
import '../../../../shared/storage_providers.dart';
import '../../../../shared/sync/sync_refresh.dart';
import '../../../anime_catalog/presentation/providers/anime_catalog_providers.dart';
import '../../application/services/composite_manga_catalog_repository.dart';

/// Aggregate payload for the manga Home screen. Re-exports the domain
/// `MangaHomeSections` under the legacy name so existing UI code keeps
/// compiling while the call path collapses to a single repository call.
typedef MangaHomeData = MangaHomeSections;

// ---------------------------------------------------------------------------
// Source plugin + composite repository
// ---------------------------------------------------------------------------

/// Registered manga source plugins, ordered by registration priority.
/// The composite repository fans out to every entry in parallel and
/// dedups across them.
///
/// Currently single-element (MangaDex). When LatAm sources land
/// (S3-S6), append them here in priority order — earlier entries win
/// ties in the dedup heuristic. Lifted to a list in S1.C; in S1.E the
/// detail page surfaces this through the source picker chip.
final mangaSourcePluginsProvider = Provider<List<MangaSourcePlugin>>((ref) {
  return <MangaSourcePlugin>[MangaDexSourcePlugin()];
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

/// Process-wide MangaBaka HTTP client. Hot-reload safe: the client
/// caches responses in-memory for 5 min and rate-limits its outbound
/// requests, so we do NOT want a fresh instance per provider rebuild.
final mangaBakaHttpClientProvider = Provider<MangaBakaHttpClient>((ref) {
  final client = HttpMangaBakaClient();
  ref.onDispose(() {
    // The default constructor uses a pooled http.Client — closing it
    // is best-effort: the type holds a private field, and at the time
    // of writing there is no public dispose hook. Future versions of
    // the package can wire one in here.
  });
  return client;
});

/// Optional MangaBaka metadata gateway injected into the composite
/// repository. When the AniList row's id maps to a MangaBaka series,
/// the composite uses its `crossIds` (Strategy A2) and `titleCorpus`
/// (Strategy B+) to close cross-tracker matching gaps. See diary
/// 2026-04-29 (S1.D) for the full contract.
final mangaBakaMetadataGatewayProvider = Provider<MangaBakaMetadataGateway>((
  ref,
) {
  return HttpMangaBakaMetadataGateway(
    client: ref.watch(mangaBakaHttpClientProvider),
  );
});

final _compositeMangaCatalogRepositoryProvider =
    Provider<CompositeMangaCatalogRepository>((ref) {
      final gateway = ref.watch(anilistMetadataGatewayProvider);
      final delegate = AnilistMangaCatalogRepository(gateway: gateway);
      return CompositeMangaCatalogRepository(
        delegate: delegate,
        sourcePlugins: ref.watch(mangaSourcePluginsProvider),
        cacheStore: ref.watch(mangaCacheStoreProvider),
        preferredLanguages: ref.watch(mangaPreferredLanguagesProvider),
        mangaBaka: ref.watch(mangaBakaMetadataGatewayProvider),
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
      // Re-fetch when the user toggles preferred scanlator / preferred
      // source id (or any other library row mutation propagates a sync
      // refresh).
      ref.watch(syncDataRefreshEpochProvider);
      final composite = ref.watch(_compositeMangaCatalogRepositoryProvider);
      final preferredScan = await ref.watch(
        preferredScanlatorProvider(anilistId).future,
      );
      final preferredSrc = await ref.watch(
        preferredSourceIdProvider(anilistId).future,
      );
      final result = await composite.fetchMangaChaptersWithPreference(
        anilistId,
        preferredScanlator: preferredScan,
        preferredSourceId: preferredSrc,
      );
      return result.fold(
        onSuccess: (chapters) => chapters,
        onFailure: (err) => throw _toException(err),
      );
    });

/// Per-manga preferred scanlator stored in `MangaLibraryStore`. `null`
/// means "Auto" (apply the default dedup rule). Watched by
/// [mangaChaptersProvider] so flipping the preference re-fetches the
/// list, and by the picker UI so the chip reflects the active choice.
final preferredScanlatorProvider = FutureProvider.autoDispose
    .family<String?, int>((ref, anilistId) async {
      ref.watch(syncDataRefreshEpochProvider);
      final store = ref.watch(mangaLibraryStoreProvider);
      final entry = await store.getEntrySnapshot(anilistId);
      return entry?.preferredScanlator;
    });

/// Per-manga preferred source plugin id (e.g. `mangadex`, `olympus`).
/// `null` means "Auto" (fan out to every registered plugin and dedup
/// across them — the S1.C default). Mirrors [preferredScanlatorProvider]
/// in shape and lifecycle.
final preferredSourceIdProvider = FutureProvider.autoDispose
    .family<String?, int>((ref, anilistId) async {
      ref.watch(syncDataRefreshEpochProvider);
      final store = ref.watch(mangaLibraryStoreProvider);
      final entry = await store.getEntrySnapshot(anilistId);
      return entry?.preferredSourceId;
    });

/// Scanlator catalog for a manga whose chapter list has been fetched
/// at least once this session. Empty before the first fetch.
///
/// Depends on [mangaChaptersProvider] so the catalog is refreshed in
/// lockstep with the chapter list (the composite populates the cache
/// during `fetchMangaChaptersWithPreference`).
final availableScanlatorsProvider = Provider.autoDispose
    .family<List<ScanlatorOption>, int>((ref, anilistId) {
      // Force a dependency on the chapter fetch so this provider
      // recomputes once the cache is populated.
      ref.watch(mangaChaptersProvider(anilistId));
      return ref
          .watch(_compositeMangaCatalogRepositoryProvider)
          .availableScanlators(anilistId);
    });

/// Source picker catalog (one entry per plugin that contributed
/// playable chapters). Same lifecycle as [availableScanlatorsProvider].
/// Empty before the first chapter fetch and any time the user has
/// pinned a single source via `preferredSourceId` (the picker shows
/// only that one option in that case).
final availableSourcesProvider = Provider.autoDispose
    .family<List<SourceOption>, int>((ref, anilistId) {
      ref.watch(mangaChaptersProvider(anilistId));
      return ref
          .watch(_compositeMangaCatalogRepositoryProvider)
          .availableSources(anilistId);
    });

Exception _toException(KumoriyaError err) =>
    Exception('${err.code}: ${err.message}');
