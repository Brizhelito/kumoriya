import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_mangabaka/kumoriya_mangabaka.dart';
import 'package:kumoriya_mangaupdates/kumoriya_mangaupdates.dart';
import 'package:kumoriya_source_inmanga/kumoriya_source_inmanga.dart';
import 'package:kumoriya_source_lectortmo/kumoriya_source_lectortmo.dart';
import 'package:kumoriya_source_mangadex/kumoriya_source_mangadex.dart';
import 'package:kumoriya_source_manhwaweb/kumoriya_source_manhwaweb.dart';
import 'package:kumoriya_source_nekoscan/kumoriya_source_nekoscan.dart';
import 'package:kumoriya_source_olympus/kumoriya_source_olympus.dart';
import 'package:kumoriya_source_runtime/kumoriya_source_runtime.dart';
import 'package:kumoriya_source_visormanga/kumoriya_source_visormanga.dart';

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
/// Default API base URL for MangaDex when no user override is set. Kept as
/// a module-level constant so the override-aware provider builds a stable
/// `MirrorList` (override-first, default-second) without re-parsing on
/// every rebuild.
final Uri _mangaDexDefaultBaseUri = Uri.parse('https://api.mangadex.org/');

final mangaSourcePluginsProvider = Provider<List<MangaSourcePlugin>>((ref) {
  // S2: honor per-plugin user overrides. Reads the resolved snapshot, not
  // the AsyncValue, so a missing/loading state degrades to manifest
  // defaults instead of blocking the catalog.
  final overrides = ref
      .watch(pluginBaseUrlOverridesProvider)
      .maybeWhen(data: (m) => m, orElse: () => const <String, Uri>{});
  return <MangaSourcePlugin>[
    _buildMangaDex(overrides),
    _buildOlympus(overrides),
    _buildInManga(overrides),
    _buildManhwaWeb(overrides),
    _buildLectorTmo(overrides),
    _buildNekoScan(overrides),
    _buildVisorManga(overrides),
  ];
});

MangaSourcePlugin _buildMangaDex(Map<String, Uri> overrides) {
  const pluginId = 'kumoriya.source.mangadex';
  final override = overrides[pluginId];
  if (override == null) {
    return MangaDexSourcePlugin();
  }
  return MangaDexSourcePlugin(
    mirrors: MirrorList(<Uri>[override, _mangaDexDefaultBaseUri]),
  );
}

/// Default web mirrors for Olympus (frontend host pair). The dashboard
/// API host is derived by prefixing each web mirror with `dashboard.`,
/// per the discovered Olympus convention.
final List<Uri> _olympusDefaultWebMirrors = <Uri>[
  Uri.parse('https://olympusbiblioteca.com/'),
  Uri.parse('https://olympusscanlation.com/'),
  Uri.parse('https://tomanhua.com/'),
];

MangaSourcePlugin _buildOlympus(Map<String, Uri> overrides) {
  const pluginId = 'kumoriya.source.olympus';
  final override = overrides[pluginId];
  if (override == null) {
    return OlympusSourcePlugin();
  }
  // The user override is interpreted as the preferred web frontend
  // host. The matching dashboard host is derived by prefixing the
  // authority with `dashboard.`, mirroring the Olympus deployment
  // convention.
  return OlympusSourcePlugin(
    webMirrors: MirrorList(<Uri>[override, ..._olympusDefaultWebMirrors]),
    dashboardMirrors: MirrorList(<Uri>[
      _dashboardForWeb(override),
      ..._olympusDefaultWebMirrors.map(_dashboardForWeb),
    ]),
  );
}

Uri _dashboardForWeb(Uri web) => web.replace(host: 'dashboard.${web.host}');

final Uri _inMangaDefaultBaseUri = Uri.parse('https://inmanga.com/');

MangaSourcePlugin _buildInManga(Map<String, Uri> overrides) {
  const pluginId = 'kumoriya.source.inmanga';
  final override = overrides[pluginId];
  if (override == null) {
    return InMangaSourcePlugin();
  }
  return InMangaSourcePlugin(
    mirrors: MirrorList(<Uri>[override, _inMangaDefaultBaseUri]),
  );
}

final Uri _manhwaWebDefaultBaseUri = Uri.parse(
  'https://manhwawebbackend-production.up.railway.app/',
);

MangaSourcePlugin _buildManhwaWeb(Map<String, Uri> overrides) {
  const pluginId = 'kumoriya.source.manhwaweb';
  final override = overrides[pluginId];
  if (override == null) {
    return ManhwaWebSourcePlugin();
  }
  return ManhwaWebSourcePlugin(
    mirrors: MirrorList(<Uri>[override, _manhwaWebDefaultBaseUri]),
  );
}

final Uri _lectorTmoDefaultBaseUri = Uri.parse('https://lectortmoo.com/');

MangaSourcePlugin _buildLectorTmo(Map<String, Uri> overrides) {
  const pluginId = 'kumoriya.source.lectortmo';
  final override = overrides[pluginId];
  if (override == null) {
    return LectorTmoSourcePlugin();
  }
  return LectorTmoSourcePlugin(
    mirrors: MirrorList(<Uri>[override, _lectorTmoDefaultBaseUri]),
  );
}

final Uri _nekoScanDefaultBaseUri = Uri.parse('https://nekoproject.org/');

MangaSourcePlugin _buildNekoScan(Map<String, Uri> overrides) {
  const pluginId = 'kumoriya.source.nekoscan';
  final override = overrides[pluginId];
  if (override == null) {
    return NekoScanSourcePlugin();
  }
  return NekoScanSourcePlugin(
    mirrors: MirrorList(<Uri>[override, _nekoScanDefaultBaseUri]),
  );
}

final Uri _visorMangaDefaultBaseUri = Uri.parse('https://visormanga.com/');

MangaSourcePlugin _buildVisorManga(Map<String, Uri> overrides) {
  const pluginId = 'kumoriya.source.visormanga';
  final override = overrides[pluginId];
  if (override == null) {
    return VisorMangaSourcePlugin();
  }
  return VisorMangaSourcePlugin(
    mirrors: MirrorList(<Uri>[override, _visorMangaDefaultBaseUri]),
  );
}

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

/// Process-wide MangaUpdates HTTP client (S1.F). Same caching +
/// rate-limit posture as the MangaBaka client. The composite uses
/// this gateway to enrich scanlator picker options with last-release
/// timestamps; failures are non-fatal.
final mangaUpdatesHttpClientProvider = Provider<MangaUpdatesHttpClient>((ref) {
  return HttpMangaUpdatesClient();
});

/// Optional MangaUpdates metadata gateway. Wired into the composite
/// repository; when MangaBaka surfaces an `mu` cross-id for the
/// AniList row the composite calls `searchReleases(seriesId)` once
/// per session and tags every scanlator option with the most recent
/// release timestamp from that group.
final mangaUpdatesMetadataGatewayProvider =
    Provider<MangaUpdatesMetadataGateway>((ref) {
      return HttpMangaUpdatesMetadataGateway(
        client: ref.watch(mangaUpdatesHttpClientProvider),
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
        mangaUpdates: ref.watch(mangaUpdatesMetadataGatewayProvider),
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
