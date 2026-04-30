import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_mangabaka/kumoriya_mangabaka.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../shared/cache/fallback_reason.dart';

/// One row of the "Fuente" picker on the manga detail screen. Carries
/// the scanlator's display name and how many chapters of the current
/// manga it has uploaded. Used to render the picker sorted by
/// coverage so the user can pick the most-complete option first.
typedef ScanlatorOption = ({String name, int chapterCount});

/// One row of the source picker. The picker UI itself lands in S1.E;
/// S1.C only computes the option list and routes by `sourceId`
/// internally so multi-source dedup and reader resolution work.
typedef SourceOption = ({
  String sourceId,
  String displayName,
  int chapterCount,
});

/// Pairs a `SourceChapter` with the id of the plugin that produced
/// it. Used both as the value type of the per-manga reader cache and
/// as a transient tag during fan-out.
final class _TaggedSourceChapter {
  const _TaggedSourceChapter({required this.sourceId, required this.chapter});
  final String sourceId;
  final SourceChapter chapter;
}

/// Outcome of a single plugin's chapter fetch during fan-out.
final class _PluginChapterResult {
  const _PluginChapterResult({
    required this.sourceId,
    required this.attempted,
    required this.chapters,
    required this.failure,
  });

  /// `false` when the plugin had no `sourceMangaId` resolution and we
  /// did not even call `getChapters` on it. Distinguishes "plugin
  /// doesn't carry this manga" from "plugin failed for this manga".
  final bool attempted;
  final String sourceId;
  final List<SourceChapter> chapters;
  final KumoriyaError? failure;
}

/// Composes the AniList-backed `MangaCatalogRepository` with one or
/// more `MangaSourcePlugin`s to materialize the chapter list AniList
/// itself does not expose.
///
/// Multi-source (Slice S1.C):
///
/// - Catalog metadata (home/search/detail/genres/tags/batch) is
///   delegated to the AniList implementation. On transport failure we
///   attempt a best-effort fallback from `MangaCacheStore` so the UI
///   stays useful while the remote API is unavailable.
/// - Catalog reads write-through into the cache so the next offline
///   open can render something.
/// - `fetchMangaChapters(int anilistId)` resolves the AniList id to a
///   per-plugin `sourceMangaId` (memoized including memoized
///   negatives), then fans out `getChapters` to every plugin **in
///   parallel with a per-plugin timeout**.
/// - Plugin failures and timeouts are isolated: one plugin failing
///   does NOT fail the whole call. We log the failure, exclude the
///   plugin's contribution, and surface what the others returned.
///   Only when EVERY attempted plugin failed do we lift a failure.
/// - The visible dedup key stays `(number, language)` — same chapter
///   from two sources is collapsed using the existing
///   [_isBetterChapter] heuristic. The cache snapshot also includes
///   `sourceId` so the reader can re-resolve a `MangaChapter` to its
///   source-side counterpart even when two plugins shipped the same
///   number.
/// - `availableSources(anilistId)` exposes which plugins contributed,
///   feeding the optional source picker in S1.E.
///
/// The repository is pure dart (no Flutter widgets, no Riverpod).
/// Wire it from the providers layer.
final class CompositeMangaCatalogRepository implements MangaCatalogRepository {
  CompositeMangaCatalogRepository({
    required MangaCatalogRepository delegate,
    required List<MangaSourcePlugin> sourcePlugins,
    required MangaCacheStore cacheStore,
    required List<String> Function() preferredLanguages,
    Duration perPluginTimeout = const Duration(seconds: 8),
    MangaBakaMetadataGateway? mangaBaka,
  }) : assert(
         sourcePlugins.length > 0, // ignore: prefer_is_empty
         'CompositeMangaCatalogRepository requires at least one source plugin.',
       ),
       _delegate = delegate,
       _sourcePlugins = List<MangaSourcePlugin>.unmodifiable(sourcePlugins),
       _cacheStore = cacheStore,
       _preferredLanguages = preferredLanguages,
       _perPluginTimeout = perPluginTimeout,
       _mangaBaka = mangaBaka {
    final ids = _sourcePlugins
        .map((p) => p.manifest.id)
        .toList(growable: false);
    assert(
      ids.toSet().length == ids.length,
      'CompositeMangaCatalogRepository: duplicate source plugin ids: $ids',
    );
  }

  final MangaCatalogRepository _delegate;
  final List<MangaSourcePlugin> _sourcePlugins;
  final MangaCacheStore _cacheStore;
  final List<String> Function() _preferredLanguages;
  final Duration _perPluginTimeout;

  /// Optional MangaBaka metadata gateway. When wired, the matching
  /// pipeline (S1.D) uses it to:
  ///
  ///  1. Bypass per-plugin search when a `SourceMangaMatch` exposes a
  ///     cross-tracker id (`mu`, `mal`) that aligns with MangaBaka's
  ///     `crossIds` for the same AniList row.
  ///  2. Expand the fuzzy candidate pool with MangaBaka's title corpus
  ///     (canonical + romanized + native + secondary titles).
  ///
  /// MangaBaka transport failures are non-fatal: the resolver falls
  /// back to the legacy AniList-titles-only path.
  final MangaBakaMetadataGateway? _mangaBaka;

  /// Per-AniList id memoization of MangaBaka context resolutions.
  /// Stores `Future<MangaBakaSeries?>` so concurrent fan-out calls
  /// share a single in-flight lookup. The future may complete with
  /// `null` to mean "MangaBaka was asked and has no row pointing at
  /// this AniList id" — that null is itself memoized for the session.
  final Map<int, Future<MangaBakaSeries?>> _mangaBakaByAnilistId =
      <int, Future<MangaBakaSeries?>>{};

  /// Read-only view over the registered source plugins, in the order
  /// supplied to the constructor. Useful for diagnostics and tests.
  List<MangaSourcePlugin> get sourcePlugins => _sourcePlugins;

  /// Indicates why the most recent catalog fetch fell back to locally
  /// cached data, or [FallbackReason.none] when operating normally.
  /// Mirrors the same notifier pattern as `CachedAnimeCatalogRepository`
  /// so the navigation shell can collapse both signals into one banner.
  final ValueNotifier<FallbackReason> fallbackReason = ValueNotifier(
    FallbackReason.none,
  );

  /// Per-(AniList id, plugin id) memoization of `sourceMangaId`
  /// resolutions. Inner value `null` means "we asked that plugin and
  /// it didn't match"; missing inner key means "we haven't asked yet".
  /// One plugin's positive resolution and another plugin's memoized
  /// negative cohabit naturally.
  final Map<int, Map<String, String?>> _sourceMangaIdByPlugin =
      <int, Map<String, String?>>{};

  /// Per-manga snapshot of the last fan-out's `SourceChapter` list
  /// keyed by composite `${number}|${language}|${scanlator}|${sourceId}`.
  /// The `sourceId` segment keeps two plugins' chapter 1 from
  /// colliding when both translated the same original.
  ///
  /// Lifetime: per-session. Refreshed on every successful
  /// `fetchMangaChapters` call.
  final Map<int, Map<String, _TaggedSourceChapter>> _sourceChaptersByManga =
      <int, Map<String, _TaggedSourceChapter>>{};

  /// Per-manga catalog of distinct scanlator names sourced from the
  /// last fan-out's raw (pre-dedup) playable list. Aggregated across
  /// all plugins. Sorted by chapter count desc, then alphabetically.
  ///
  /// Externals are not counted because the user can't pick them as a
  /// per-manga preferred scanlator.
  final Map<int, List<ScanlatorOption>> _scanlatorsByManga =
      <int, List<ScanlatorOption>>{};

  /// Per-manga catalog of source plugins that contributed at least
  /// one playable chapter during the last fan-out. Sorted by chapter
  /// count desc, then by source id (stable across rebuilds). Used by
  /// the source picker (S1.E) to label and route the active source.
  final Map<int, List<SourceOption>> _sourcesByManga =
      <int, List<SourceOption>>{};

  // ---------------------------------------------------------------------------
  // Catalog metadata (delegate + write-through)
  // ---------------------------------------------------------------------------

  @override
  Future<Result<List<Manga>, KumoriyaError>> fetchHomeCatalog({
    int page = 1,
    int perPage = 20,
  }) async {
    final result = await _delegate.fetchHomeCatalog(
      page: page,
      perPage: perPage,
    );
    if (result.isSuccess) {
      fallbackReason.value = FallbackReason.none;
      await _persistList(result);
      return result;
    }
    return _fallbackList(
      result,
      () => _cacheStore.getRecent(limit: perPage, offset: (page - 1) * perPage),
    );
  }

  @override
  Future<Result<MangaHomeSections, KumoriyaError>> fetchHomeSections({
    int page = 1,
    int perPage = 20,
  }) async {
    final result = await _delegate.fetchHomeSections(
      page: page,
      perPage: perPage,
    );
    if (result is Success<MangaHomeSections, KumoriyaError>) {
      fallbackReason.value = FallbackReason.none;
      // Write-through every shelf so cold-launch / offline still
      // populates the carousels with the most recently seen catalog.
      final sections = result.value;
      for (final shelf in <List<Manga>>[
        sections.trending,
        sections.popular,
        sections.latest,
        sections.topRated,
      ]) {
        for (final manga in shelf) {
          await _persistManga(manga);
        }
      }
      return result;
    }

    // Offline / AniList-down fallback: serve whatever the local cache
    // has so the home stays useful. We pull a generous slice and split
    // it across the four shelves; if the cache has fewer than 4*perPage
    // entries the trailing shelves end up empty rather than duplicating.
    final reason = _classifyTransportError(result);
    if (reason == null) return result;

    final cached = await _cacheStore.getRecent(limit: perPage * 4);
    return cached.fold<Result<MangaHomeSections, KumoriyaError>>(
      onSuccess: (entries) {
        if (entries.isEmpty) return result;
        fallbackReason.value = reason;
        final mangas = entries.map(_entryToManga).toList(growable: false);
        List<Manga> slice(int start) {
          if (start >= mangas.length) return const <Manga>[];
          final end = (start + perPage).clamp(0, mangas.length);
          return mangas.sublist(start, end);
        }

        return Success(
          MangaHomeSections(
            trending: slice(0),
            popular: slice(perPage),
            latest: slice(perPage * 2),
            topRated: slice(perPage * 3),
          ),
        );
      },
      onFailure: (_) => result,
    );
  }

  @override
  Future<Result<List<Manga>, KumoriyaError>> searchManga(
    MangaSearchRequest request,
  ) async {
    final result = await _delegate.searchManga(request);
    if (result.isSuccess) {
      await _persistList(result);
      return result;
    }
    return _fallbackList(
      result,
      () => _cacheStore.searchByTitle(
        request.query,
        limit: request.perPage,
        offset: (request.page - 1) * request.perPage,
      ),
    );
  }

  @override
  Future<Result<List<Manga>, KumoriyaError>> browseManga(
    MangaBrowseRequest request,
  ) async {
    final result = await _delegate.browseManga(request);
    if (result.isSuccess) {
      await _persistList(result);
    }
    return result;
  }

  @override
  Future<Result<MangaDetail, KumoriyaError>> fetchMangaDetail(
    int anilistId,
  ) async {
    final result = await _delegate.fetchMangaDetail(anilistId);
    if (result.isSuccess) {
      fallbackReason.value = FallbackReason.none;
      final detail = (result as Success<MangaDetail, KumoriyaError>).value;
      await _persistManga(detail.manga);
      return result;
    }

    // Offline / AniList-down fallback: synthesize a minimal MangaDetail
    // from the cached entry so the UI can still navigate to the manga
    // page (chapters list will populate independently from the source
    // plugin, which is its own network domain — MangaDex is up even when
    // AniList is down).
    final reason = _classifyTransportError(result);
    if (reason == null) return result;

    final cached = await _cacheStore.get(anilistId);
    return cached.fold<Result<MangaDetail, KumoriyaError>>(
      onSuccess: (entry) {
        if (entry == null) return result;
        fallbackReason.value = reason;
        return Success(MangaDetail(manga: _entryToManga(entry)));
      },
      onFailure: (_) => result,
    );
  }

  @override
  Future<Result<List<Manga>, KumoriyaError>> fetchBatchMangaByIds(
    List<int> ids,
  ) async {
    final result = await _delegate.fetchBatchMangaByIds(ids);
    if (result.isSuccess) {
      await _persistList(result);
      return result;
    }
    return _fallbackList(result, () => _cacheStore.getByIds(ids));
  }

  @override
  Future<Result<List<String>, KumoriyaError>> fetchGenreCollection() {
    return _delegate.fetchGenreCollection();
  }

  @override
  Future<Result<List<MangaTag>, KumoriyaError>> fetchTagCollection() {
    return _delegate.fetchTagCollection();
  }

  // ---------------------------------------------------------------------------
  // Chapter list (AniList -> source plugin via matching)
  // ---------------------------------------------------------------------------

  @override
  Future<Result<List<MangaChapter>, KumoriyaError>> fetchMangaChapters(
    int anilistId,
  ) {
    return fetchMangaChaptersWithPreference(anilistId);
  }

  /// Composite-only extension of [fetchMangaChapters] that lets the
  /// caller pick a preferred scanlator and/or a preferred source for
  /// the playable bucket.
  ///
  /// When [preferredScanlator] is non-null, the playable list is
  /// strictly filtered to chapters whose `scanlator` matches.
  /// Chapters that scanlator did not translate are intentionally
  /// absent — the picker is a hard filter (see 2026-04-28 dev diary).
  ///
  /// When [preferredSourceId] is non-null, only the matching plugin
  /// is consulted. Useful for the source picker (S1.E) and as an
  /// override when a user explicitly prefers e.g. MangaDex over
  /// Olympus for a given manga. Unknown ids resolve to an empty
  /// chapter list (no failure).
  ///
  /// Externals are not affected by either filter (they are rendered
  /// in their own bucket regardless of preference).
  Future<Result<List<MangaChapter>, KumoriyaError>>
  fetchMangaChaptersWithPreference(
    int anilistId, {
    String? preferredScanlator,
    String? preferredSourceId,
  }) async {
    // 1. Need the canonical AniList manga to drive matching.
    final detailResult = await _delegate.fetchMangaDetail(anilistId);
    if (detailResult.isFailure) {
      return Failure(
        (detailResult as Failure<MangaDetail, KumoriyaError>).error,
      );
    }
    final manga =
        (detailResult as Success<MangaDetail, KumoriyaError>).value.manga;

    // 2. Decide which plugins to consult.
    final activePlugins = preferredSourceId == null
        ? _sourcePlugins
        : _sourcePlugins
              .where((p) => p.manifest.id == preferredSourceId)
              .toList(growable: false);
    if (activePlugins.isEmpty) {
      // User picked a source we don't have wired up. Treat as no
      // chapters rather than a hard failure — the picker UI shows
      // an empty-state hint (per Kumoriya rule #2).
      return const Success(<MangaChapter>[]);
    }

    // 3. Resolve sourceMangaId on every active plugin in parallel
    //    (memoized including memoized negatives).
    final mangaIdResults =
        await Future.wait(<Future<Result<String?, KumoriyaError>>>[
          for (final plugin in activePlugins)
            _resolveSourceMangaIdForPlugin(plugin, manga),
        ]);

    // 4. Fan out getChapters to plugins that resolved, in parallel,
    //    with a per-plugin timeout. Failures are tagged but never
    //    short-circuit the call: one plugin's outage must not blank
    //    the chapter list of the others.
    final pluginResults = await Future.wait(<Future<_PluginChapterResult>>[
      for (var i = 0; i < activePlugins.length; i++)
        _fetchPluginChapters(activePlugins[i], mangaIdResults[i]),
    ]);

    // 5. Collect successful contributions; track first failure as a
    //    fall-back to surface when EVERY attempted plugin failed.
    final allRaw = <_TaggedSourceChapter>[];
    KumoriyaError? firstFailure;
    var anyAttempted = false;
    var anySuccess = false;
    for (final res in pluginResults) {
      if (!res.attempted) continue;
      anyAttempted = true;
      final failure = res.failure;
      if (failure != null) {
        firstFailure ??= failure;
        developer.log(
          'manga plugin ${res.sourceId} failed: '
          '${failure.code} ${failure.message}',
          name: 'CompositeMangaCatalogRepository',
        );
        continue;
      }
      anySuccess = true;
      for (final c in res.chapters) {
        allRaw.add(_TaggedSourceChapter(sourceId: res.sourceId, chapter: c));
      }
    }

    if (!anySuccess) {
      // Distinguish "no plugin matched" (no chapters, not an error)
      // from "every attempted plugin failed" (lift the first error so
      // the UI can render a proper retry banner instead of empty).
      if (!anyAttempted) {
        _scanlatorsByManga[anilistId] = const <ScanlatorOption>[];
        _sourcesByManga[anilistId] = const <SourceOption>[];
        _sourceChaptersByManga[anilistId] =
            const <String, _TaggedSourceChapter>{};
        return const Success(<MangaChapter>[]);
      }
      return Failure(firstFailure!);
    }

    // 6. Split playable vs external — same rule as the single-source
    //    path; externals are publisher republications we can only
    //    link out to.
    final playableRaw = <_TaggedSourceChapter>[];
    final externalRaw = <_TaggedSourceChapter>[];
    for (final t in allRaw) {
      if (t.chapter.externalUrl != null) {
        externalRaw.add(t);
      } else {
        playableRaw.add(t);
      }
    }

    // 7. Update picker catalogs from the raw playable list. Both
    //    aggregate across sources so the user sees one chip per
    //    distinct scanlator and one chip per contributing plugin.
    _scanlatorsByManga[anilistId] = _computeScanlatorOptions(
      playableRaw.map((t) => t.chapter).toList(growable: false),
    );
    _sourcesByManga[anilistId] = _computeSourceOptions(
      activePlugins,
      playableRaw,
    );

    // 8. Apply the scanlator filter (strict — see dev diary 2026-04-28).
    final playableFiltered = preferredScanlator == null
        ? playableRaw
        : playableRaw
              .where((t) => t.chapter.scanlator == preferredScanlator)
              .toList(growable: false);

    // 9. Dedup each bucket independently by (number, language) using
    //    `_isBetterChapter` to pick the best across sources, then
    //    suppress externals already covered by a playable row.
    final playable = _dedupByNumberLanguageTagged(playableFiltered);
    final external = _dedupByNumberLanguageTagged(externalRaw);
    final playableKeys = <String>{
      for (final t in playable)
        _numberLanguageKey(t.chapter.number, t.chapter.language),
    };
    final externalFiltered = external
        .where(
          (t) => !playableKeys.contains(
            _numberLanguageKey(t.chapter.number, t.chapter.language),
          ),
        )
        .toList(growable: false);

    // 10. Stable order across plugins: chapter number desc, with
    //     externals trailing playables. With a single plugin this
    //     reproduces the previous order; with N plugins it makes the
    //     interleaved list readable instead of "plugin1 then plugin2".
    final all = <_TaggedSourceChapter>[...playable, ...externalFiltered]
      ..sort((a, b) {
        // Externals always trail playables.
        final aExt = a.chapter.externalUrl != null;
        final bExt = b.chapter.externalUrl != null;
        if (aExt != bExt) return aExt ? 1 : -1;
        return b.chapter.number.compareTo(a.chapter.number);
      });

    // 11. Snapshot keyed by composite (incl. sourceId) so the reader
    //     can re-resolve via `MangaChapter.sourceId` even when two
    //     plugins shipped the same number.
    _sourceChaptersByManga[anilistId] = <String, _TaggedSourceChapter>{
      for (final t in all)
        _sourceChapterKey(
          t.chapter.number,
          t.chapter.language,
          t.chapter.scanlator,
          t.sourceId,
        ): t,
    };

    final chapters = all.map(_toDomainChapter).toList(growable: false);
    return Success(chapters);
  }

  /// Single-plugin getChapters call, lifted into a `_PluginChapterResult`
  /// with timeout handling. The timeout converts a hung plugin into a
  /// transport failure that the fan-out aggregator skips, instead of
  /// stalling the whole call.
  Future<_PluginChapterResult> _fetchPluginChapters(
    MangaSourcePlugin plugin,
    Result<String?, KumoriyaError> idResult,
  ) async {
    final sourceId = plugin.manifest.id;

    if (idResult.isFailure) {
      return _PluginChapterResult(
        sourceId: sourceId,
        attempted: true,
        chapters: const <SourceChapter>[],
        failure: (idResult as Failure<String?, KumoriyaError>).error,
      );
    }
    final mangaId = (idResult as Success<String?, KumoriyaError>).value;
    if (mangaId == null) {
      // Plugin doesn't carry this manga — no failure, just no contribution.
      return _PluginChapterResult(
        sourceId: sourceId,
        attempted: false,
        chapters: const <SourceChapter>[],
        failure: null,
      );
    }

    final query = MangaChapterQuery(
      sourceMangaId: mangaId,
      languages: _preferredLanguages(),
      page: 1,
      limit: 200,
    );
    try {
      final result = await plugin.getChapters(query).timeout(_perPluginTimeout);
      return result.fold(
        onSuccess: (chapters) => _PluginChapterResult(
          sourceId: sourceId,
          attempted: true,
          chapters: chapters,
          failure: null,
        ),
        onFailure: (err) => _PluginChapterResult(
          sourceId: sourceId,
          attempted: true,
          chapters: const <SourceChapter>[],
          failure: err,
        ),
      );
    } on TimeoutException catch (_) {
      return _PluginChapterResult(
        sourceId: sourceId,
        attempted: true,
        chapters: const <SourceChapter>[],
        failure: SimpleError(
          code: 'manga.plugin.timeout',
          message:
              'Source plugin `$sourceId` timed out after ${_perPluginTimeout.inSeconds}s.',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    }
  }

  /// Deduplicates a tagged chapter list by `(number, language)`
  /// keeping the "best" candidate per key under the
  /// [_isBetterChapter] heuristic (more pages > more recent >
  /// non-null scanlator). When two sources tie on every signal, the
  /// row from the plugin that was registered first wins — deterministic
  /// and obvious to debug.
  ///
  /// Output preserves the first-occurrence order of each unique key
  /// in the input. The caller is expected to apply a final stable
  /// sort if the rendered order matters.
  static List<_TaggedSourceChapter> _dedupByNumberLanguageTagged(
    List<_TaggedSourceChapter> tagged,
  ) {
    final best = <String, _TaggedSourceChapter>{};
    for (final t in tagged) {
      final key = _numberLanguageKey(t.chapter.number, t.chapter.language);
      final existing = best[key];
      if (existing == null || _isBetterChapter(t.chapter, existing.chapter)) {
        best[key] = t;
      }
    }
    final emitted = <String>{};
    final out = <_TaggedSourceChapter>[];
    for (final t in tagged) {
      final key = _numberLanguageKey(t.chapter.number, t.chapter.language);
      if (emitted.add(key)) {
        out.add(best[key]!);
      }
    }
    return out;
  }

  /// Reads the raw playable chapter list and returns one
  /// [ScanlatorOption] per distinct non-empty scanlator, sorted by
  /// chapter count desc, then alphabetically (stable across rebuilds).
  static List<ScanlatorOption> _computeScanlatorOptions(
    List<SourceChapter> rawPlayable,
  ) {
    final counts = <String, int>{};
    for (final c in rawPlayable) {
      final s = c.scanlator;
      if (s == null || s.isEmpty) continue;
      counts[s] = (counts[s] ?? 0) + 1;
    }
    final entries = counts.entries.toList(growable: false)
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });
    return <ScanlatorOption>[
      for (final e in entries) (name: e.key, chapterCount: e.value),
    ];
  }

  /// Available scanlators (with chapter counts) for a manga whose
  /// chapter list has already been fetched. Returns an empty list
  /// when the per-manga cache has not been warmed yet.
  List<ScanlatorOption> availableScanlators(int anilistId) {
    return _scanlatorsByManga[anilistId] ?? const <ScanlatorOption>[];
  }

  /// Source plugins that contributed playable chapters for a manga
  /// during the last fan-out, sorted by chapter count desc then by
  /// source id (stable). Returns an empty list before the first
  /// fetch. The list never includes plugins that failed to resolve
  /// the manga or that returned only externals.
  List<SourceOption> availableSources(int anilistId) {
    return _sourcesByManga[anilistId] ?? const <SourceOption>[];
  }

  /// Computes [SourceOption] entries from the raw playable list
  /// emitted by the fan-out. The plugin set used here is the same
  /// list passed to [fetchMangaChaptersWithPreference] (i.e. honors
  /// `preferredSourceId` filtering).
  static List<SourceOption> _computeSourceOptions(
    List<MangaSourcePlugin> activePlugins,
    List<_TaggedSourceChapter> rawPlayable,
  ) {
    if (rawPlayable.isEmpty) return const <SourceOption>[];
    final counts = <String, int>{};
    for (final t in rawPlayable) {
      counts[t.sourceId] = (counts[t.sourceId] ?? 0) + 1;
    }
    final byId = <String, MangaSourcePlugin>{
      for (final p in activePlugins) p.manifest.id: p,
    };
    final entries = counts.entries.toList(growable: false)
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    return <SourceOption>[
      for (final e in entries)
        (
          sourceId: e.key,
          displayName: byId[e.key]?.manifest.displayName ?? e.key,
          chapterCount: e.value,
        ),
    ];
  }

  /// `true` when [candidate] should replace [current] under the dedup
  /// rule documented on [_dedupByNumberLanguage].
  static bool _isBetterChapter(SourceChapter candidate, SourceChapter current) {
    final candPages = candidate.pageCount ?? 0;
    final currPages = current.pageCount ?? 0;
    if (candPages != currPages) return candPages > currPages;
    final candAt =
        candidate.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final currAt =
        current.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (candAt != currAt) return candAt.isAfter(currAt);
    final candHasScanlator =
        candidate.scanlator != null && candidate.scanlator!.isNotEmpty;
    final currHasScanlator =
        current.scanlator != null && current.scanlator!.isNotEmpty;
    if (candHasScanlator != currHasScanlator) return candHasScanlator;
    return false;
  }

  static String _numberLanguageKey(double number, String language) {
    return '$number|$language';
  }

  /// Resolves a domain `MangaChapter` back to its plugin-level
  /// `SourceChapter` and asks the plugin for the page list. Returns a
  /// `Failure` when the chapter is not in the per-manga cache (the
  /// caller should call `fetchMangaChapters` first) or when the plugin
  /// fails.
  ///
  /// Returned `MangaPage` list is index-ordered ascending and includes
  /// any per-page headers the plugin requires.
  ///
  /// Also exposes the `sourceChapterId` so the caller can persist
  /// resume state via `MangaProgressStore` (which keys on it).
  Future<
    Result<({String sourceChapterId, List<MangaPage> pages}), KumoriyaError>
  >
  openChapter({
    required int mangaAnilistId,
    required MangaChapter chapter,
  }) async {
    final ref = _resolveCachedRef(mangaAnilistId, chapter);
    if (ref == null) {
      return Failure(
        const SimpleError(
          code: 'reader.chapter_not_resolved',
          message:
              'Chapter is not in the per-manga cache; '
              'fetch the chapter list before opening the reader.',
          kind: KumoriyaErrorKind.notFound,
        ),
      );
    }
    final plugin = _pluginById(ref.sourceId);
    if (plugin == null) {
      return Failure(
        SimpleError(
          code: 'reader.source_unavailable',
          message:
              'Source plugin `${ref.sourceId}` is no longer registered; '
              're-fetch the chapter list to refresh the cache.',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
    final pagesResult = await plugin.getChapterPages(ref.chapter);
    if (pagesResult.isFailure) {
      return Failure(
        (pagesResult as Failure<List<SourcePage>, KumoriyaError>).error,
      );
    }
    final sourcePages =
        (pagesResult as Success<List<SourcePage>, KumoriyaError>).value;
    final mangaPages = sourcePages
        .map(
          (p) => MangaPage(
            index: p.index,
            imageUrl: p.imageUrl,
            headers: p.headers,
          ),
        )
        .toList(growable: false);
    return Success((
      sourceChapterId: ref.chapter.sourceChapterId,
      pages: mangaPages,
    ));
  }

  /// Looks up the cached `SourceChapter` for a domain `MangaChapter`
  /// without going to the network. Used by the downloads slice to read
  /// `sourceMangaId` / `sourceChapterId` ids before queuing a CBZ
  /// download. Returns `null` when the per-manga cache has not been
  /// warmed yet — the caller is expected to have triggered
  /// `fetchMangaChapters` already (e.g. by viewing the detail screen).
  SourceChapter? lookupSourceChapter({
    required int mangaAnilistId,
    required MangaChapter chapter,
  }) {
    return _resolveCachedRef(mangaAnilistId, chapter)?.chapter;
  }

  /// Resolves a domain `MangaChapter` back to its tagged source-side
  /// counterpart from the per-manga snapshot. Tries the precise key
  /// first (when the chapter carries a `sourceId`); falls back to a
  /// scan over the cache for legacy callers that constructed a
  /// `MangaChapter` without a sourceId tag.
  _TaggedSourceChapter? _resolveCachedRef(
    int mangaAnilistId,
    MangaChapter chapter,
  ) {
    final cache = _sourceChaptersByManga[mangaAnilistId];
    if (cache == null) return null;
    final tagged = chapter.sourceId;
    if (tagged != null) {
      final precise =
          cache[_sourceChapterKey(
            chapter.number,
            chapter.language,
            chapter.scanlator,
            tagged,
          )];
      if (precise != null) return precise;
    }
    // Backward-compat: untagged MangaChapter — scan for a row that
    // matches (number, language, scanlator) regardless of source.
    for (final entry in cache.values) {
      final c = entry.chapter;
      if (c.number != chapter.number) continue;
      if (c.language != chapter.language) continue;
      if (c.scanlator != chapter.scanlator) continue;
      return entry;
    }
    return null;
  }

  MangaSourcePlugin? _pluginById(String id) {
    for (final p in _sourcePlugins) {
      if (p.manifest.id == id) return p;
    }
    return null;
  }

  /// Composite key for the per-manga `SourceChapter` cache. Mirrors
  /// the disambiguators users see in the chapter list: a scanlator
  /// translation in language X is a different chapter from another
  /// scanlator's translation of the same number, even though both
  /// share `MangaChapter.number`. The trailing `sourceId` segment
  /// keeps two plugins' chapter 1 from colliding.
  static String _sourceChapterKey(
    double number,
    String? language,
    String? scanlator,
    String sourceId,
  ) {
    return '$number|${language ?? ''}|${scanlator ?? ''}|$sourceId';
  }

  /// Resolves an AniList id to a single plugin's `sourceMangaId`.
  ///
  /// Strategy (in order):
  ///
  /// 1. Per-(AniList id, plugin id) memoization — including memoized
  ///    negatives.
  /// 2. **Strategy A** — plugin search by canonical romaji title; accept
  ///    the result whose `externalIds['al']` matches `anilistId`.
  /// 3. **Strategy A2** (S1.D) — when a MangaBaka gateway is wired and
  ///    has a row for this AniList id, accept the result whose
  ///    `externalIds['mu']` matches MangaBaka's `crossIds.mangaUpdatesId`
  ///    or whose `externalIds['mal']` matches `myAnimeListId`. This
  ///    bypasses fuzzy matching entirely for plugins that surface
  ///    cross-tracker ids on their search rows (MangaDex, ComicK).
  /// 4. **Strategy B** — fuzzy fallback: case/whitespace-insensitive
  ///    equality between any AniList title (romaji/english/native/
  ///    synonyms), expanded with MangaBaka's `titleCorpus` when
  ///    available, and the source result's title or aliases.
  /// 5. No match → memoize `null`. The plugin contributes zero
  ///    chapters for this manga in the fan-out aggregator.
  ///
  /// MangaBaka transport / parsing failures are swallowed (logged) so
  /// that a metadata-gateway outage degrades to the legacy A+B path
  /// instead of taking the whole resolution down.
  Future<Result<String?, KumoriyaError>> _resolveSourceMangaIdForPlugin(
    MangaSourcePlugin plugin,
    Manga manga,
  ) async {
    final pluginId = plugin.manifest.id;
    final perManga = _sourceMangaIdByPlugin.putIfAbsent(
      manga.anilistId,
      () => <String, String?>{},
    );
    if (perManga.containsKey(pluginId)) {
      return Success(perManga[pluginId]);
    }

    // Resolve MangaBaka context once per AniList id (memoized + shared
    // across concurrent fan-out callers). Failures are logged and
    // treated as "no MangaBaka context".
    final mbContext = await _resolveMangaBakaContext(manga);

    final query = MangaSearchQuery(
      query: manga.title.romaji,
      page: 1,
      limit: 10,
      languages: _preferredLanguages(),
    );
    final searchResult = await plugin.search(query);
    if (searchResult.isFailure) {
      // Don't memoize transport failures — a transient outage shouldn't
      // poison the cache for the rest of the session.
      return Failure(
        (searchResult as Failure<List<SourceMangaMatch>, KumoriyaError>).error,
      );
    }
    final matches =
        (searchResult as Success<List<SourceMangaMatch>, KumoriyaError>).value;

    String? resolved;

    // Strategy A: explicit AniList link in the source row.
    final anilistIdString = manga.anilistId.toString();
    for (final m in matches) {
      if (m.externalIds['al'] == anilistIdString) {
        resolved = m.sourceId;
        break;
      }
    }

    // Strategy A2 (S1.D): cross-tracker bypass via MangaBaka.
    if (resolved == null && mbContext != null) {
      final mu = mbContext.crossIds.mangaUpdatesId;
      final mal = mbContext.crossIds.myAnimeListId?.toString();
      for (final m in matches) {
        final mMu = m.externalIds['mu'];
        final mMal = m.externalIds['mal'];
        if ((mu != null && mu.isNotEmpty && mMu == mu) ||
            (mal != null && mal.isNotEmpty && mMal == mal)) {
          resolved = m.sourceId;
          break;
        }
      }
    }

    // Strategy B: fuzzy title equality, optionally expanded with
    // MangaBaka's title corpus.
    if (resolved == null) {
      final candidates = <String>{
        _normalize(manga.title.romaji),
        if (manga.title.english != null) _normalize(manga.title.english!),
        if (manga.title.native != null) _normalize(manga.title.native!),
        for (final s in manga.title.synonyms) _normalize(s),
        if (mbContext != null)
          for (final t in mbContext.titleCorpus) _normalize(t),
      }..removeWhere((s) => s.isEmpty);
      for (final m in matches) {
        final names = <String>{
          _normalize(m.title),
          for (final a in m.aliases) _normalize(a),
        }..removeWhere((s) => s.isEmpty);
        if (names.any(candidates.contains)) {
          resolved = m.sourceId;
          break;
        }
      }
    }

    perManga[pluginId] = resolved;
    return Success(resolved);
  }

  /// Returns the MangaBaka row whose `crossIds.anilistId` matches
  /// [manga.anilistId], or `null` when no such row exists / the gateway
  /// is not wired / the gateway failed.
  ///
  /// The lookup is memoized per AniList id for the session and shared
  /// across concurrent callers (fan-out triggers N parallel resolves
  /// for the same manga; we want exactly one MangaBaka call).
  Future<MangaBakaSeries?> _resolveMangaBakaContext(Manga manga) {
    final gateway = _mangaBaka;
    if (gateway == null) return Future<MangaBakaSeries?>.value(null);

    return _mangaBakaByAnilistId.putIfAbsent(manga.anilistId, () async {
      try {
        final result = await gateway.searchSeries(
          query: manga.title.romaji,
          limit: 20,
        );
        if (result is! Success<List<MangaBakaSeries>, KumoriyaError>) {
          developer.log(
            'MangaBaka search failed; falling back to AniList titles only.',
            name: 'CompositeMangaCatalogRepository',
            error:
                (result as Failure<List<MangaBakaSeries>, KumoriyaError>).error,
          );
          return null;
        }
        for (final series in result.value) {
          if (series.crossIds.anilistId == manga.anilistId) {
            return series;
          }
        }
        return null;
      } catch (error, stack) {
        developer.log(
          'MangaBaka resolution threw; degrading to legacy matching.',
          name: 'CompositeMangaCatalogRepository',
          error: error,
          stackTrace: stack,
        );
        return null;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Cache write-through helpers
  // ---------------------------------------------------------------------------

  Future<void> _persistList(Result<List<Manga>, KumoriyaError> result) async {
    if (result is! Success<List<Manga>, KumoriyaError>) return;
    for (final manga in result.value) {
      await _persistManga(manga);
    }
  }

  Future<void> _persistManga(Manga manga) async {
    await _cacheStore.upsert(
      MangaCacheEntry(
        anilistId: manga.anilistId,
        titleRomaji: manga.title.romaji,
        titleEnglish: manga.title.english,
        titleNative: manga.title.native,
        synonyms: manga.title.synonyms.isNotEmpty ? manga.title.synonyms : null,
        coverImageUrl: manga.coverImageUrl,
        bannerImageUrl: manga.bannerImageUrl,
        status: _statusCode(manga.status),
        format: _formatCode(manga.format),
        countryOfOrigin: manga.countryOfOrigin?.code,
        releaseYear: manga.releaseYear,
        totalChapters: manga.totalChapters,
        totalVolumes: manga.totalVolumes,
        averageScore: manga.averageScore,
        popularity: manga.popularity,
        genres: manga.genres.isNotEmpty ? manga.genres : null,
        synopsis: manga.synopsis,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<Result<List<Manga>, KumoriyaError>> _fallbackList(
    Result<List<Manga>, KumoriyaError> networkResult,
    Future<Result<List<MangaCacheEntry>, KumoriyaError>> Function() cacheQuery,
  ) async {
    final reason = _classifyTransportError(networkResult);
    if (reason == null) return networkResult;
    final cached = await cacheQuery();
    return cached.fold(
      onSuccess: (entries) {
        if (entries.isEmpty) return networkResult;
        fallbackReason.value = reason;
        return Success(entries.map(_entryToManga).toList(growable: false));
      },
      onFailure: (_) => networkResult,
    );
  }

  /// Classifies a failure into [FallbackReason.offline] (device has no
  /// connectivity, e.g. SocketException / timeout) vs
  /// [FallbackReason.anilistDown] (reachable upstream returning errors).
  /// Returns `null` when the failure isn't a candidate for cache fallback
  /// (e.g. NotFound, mapping errors).
  ///
  /// Mirrors `CachedAnimeCatalogRepository._classifyTransportError`.
  FallbackReason? _classifyTransportError(
    Result<dynamic, KumoriyaError> result,
  ) {
    if (result is! Failure<dynamic, KumoriyaError>) return null;
    if (result.error.kind != KumoriyaErrorKind.transport) return null;
    return switch (result.error.code) {
      'anilist.service_unavailable' ||
      'anilist.rate_limit' => FallbackReason.anilistDown,
      _ => FallbackReason.offline,
    };
  }

  // ---------------------------------------------------------------------------
  // Mappers
  // ---------------------------------------------------------------------------

  Manga _entryToManga(MangaCacheEntry entry) {
    return Manga(
      anilistId: entry.anilistId,
      title: MangaTitle(
        romaji: entry.titleRomaji,
        english: entry.titleEnglish,
        native: entry.titleNative,
        synonyms: entry.synonyms ?? const <String>[],
      ),
      format: _toFormat(entry.format),
      releaseYear: entry.releaseYear,
      coverImageUrl: entry.coverImageUrl,
      bannerImageUrl: entry.bannerImageUrl,
      totalChapters: entry.totalChapters,
      totalVolumes: entry.totalVolumes,
      averageScore: entry.averageScore,
      popularity: entry.popularity,
      synopsis: entry.synopsis,
      genres: entry.genres ?? const <String>[],
      status: _toStatus(entry.status),
      countryOfOrigin: _toCountry(entry.countryOfOrigin),
    );
  }

  MangaChapter _toDomainChapter(_TaggedSourceChapter tagged) {
    final chapter = tagged.chapter;
    return MangaChapter(
      number: chapter.number,
      title: chapter.title ?? '',
      volume: chapter.volume,
      language: chapter.language,
      scanlator: chapter.scanlator,
      publishedAt: chapter.publishedAt,
      pageCount: chapter.pageCount,
      externalUrl: chapter.externalUrl,
      sourceId: tagged.sourceId,
    );
  }

  static String _normalize(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _formatCode(MangaFormat format) {
    return switch (format) {
      MangaFormat.manga => 'MANGA',
      MangaFormat.manhwa => 'MANHWA',
      MangaFormat.manhua => 'MANHUA',
      MangaFormat.oneShot => 'ONE_SHOT',
      MangaFormat.doujinshi => 'DOUJINSHI',
      MangaFormat.unknown => 'UNKNOWN',
    };
  }

  static MangaFormat _toFormat(String? code) {
    return switch (code) {
      'MANGA' => MangaFormat.manga,
      'MANHWA' => MangaFormat.manhwa,
      'MANHUA' => MangaFormat.manhua,
      'ONE_SHOT' => MangaFormat.oneShot,
      'DOUJINSHI' => MangaFormat.doujinshi,
      _ => MangaFormat.unknown,
    };
  }

  static String _statusCode(MangaStatus status) {
    return switch (status) {
      MangaStatus.finished => 'FINISHED',
      MangaStatus.releasing => 'RELEASING',
      MangaStatus.notYetReleased => 'NOT_YET_RELEASED',
      MangaStatus.cancelled => 'CANCELLED',
      MangaStatus.hiatus => 'HIATUS',
      MangaStatus.unknown => 'UNKNOWN',
    };
  }

  static MangaStatus _toStatus(String? code) {
    return switch (code) {
      'FINISHED' => MangaStatus.finished,
      'RELEASING' => MangaStatus.releasing,
      'NOT_YET_RELEASED' => MangaStatus.notYetReleased,
      'CANCELLED' => MangaStatus.cancelled,
      'HIATUS' => MangaStatus.hiatus,
      _ => MangaStatus.unknown,
    };
  }

  static MangaCountryOfOrigin? _toCountry(String? code) {
    if (code == null) return null;
    return switch (code) {
      'JP' => MangaCountryOfOrigin.jp,
      'KR' => MangaCountryOfOrigin.kr,
      'CN' => MangaCountryOfOrigin.cn,
      'TW' => MangaCountryOfOrigin.tw,
      _ => null,
    };
  }
}
