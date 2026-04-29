import 'package:flutter/foundation.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../shared/cache/fallback_reason.dart';

/// One row of the "Fuente" picker on the manga detail screen. Carries
/// the scanlator's display name and how many chapters of the current
/// manga it has uploaded. Used to render the picker sorted by
/// coverage so the user can pick the most-complete option first.
typedef ScanlatorOption = ({String name, int chapterCount});

/// Composes the AniList-backed `MangaCatalogRepository` with a
/// `MangaSourcePlugin` to materialize the chapter list AniList itself
/// does not expose.
///
/// Responsibilities:
///
/// - Catalog metadata (home/search/detail/genres/tags/batch) is delegated
///   to the AniList implementation. On transport failure we attempt a
///   best-effort fallback from `MangaCacheStore` so the UI stays useful
///   while the remote API is unavailable (mirrors the anime cached repo
///   pattern, kept lean for the manga MVP).
/// - Catalog reads write-through into the cache so the next offline open
///   can render something.
/// - `fetchMangaChapters(int anilistId)` resolves the AniList id to the
///   source plugin's `sourceMangaId` (`links.al` first, fuzzy title fallback,
///   in-memory mapping cache), then delegates to the plugin in the user's
///   preferred languages and maps `SourceChapter` → `MangaChapter`.
///
/// The repository is pure dart (no Flutter, no Riverpod). Wire it from
/// the providers layer.
final class CompositeMangaCatalogRepository implements MangaCatalogRepository {
  CompositeMangaCatalogRepository({
    required MangaCatalogRepository delegate,
    required MangaSourcePlugin sourcePlugin,
    required MangaCacheStore cacheStore,
    required List<String> Function() preferredLanguages,
  }) : _delegate = delegate,
       _sourcePlugin = sourcePlugin,
       _cacheStore = cacheStore,
       _preferredLanguages = preferredLanguages;

  final MangaCatalogRepository _delegate;
  final MangaSourcePlugin _sourcePlugin;
  final MangaCacheStore _cacheStore;
  final List<String> Function() _preferredLanguages;

  /// Indicates why the most recent catalog fetch fell back to locally
  /// cached data, or [FallbackReason.none] when operating normally.
  /// Mirrors the same notifier pattern as `CachedAnimeCatalogRepository`
  /// so the navigation shell can collapse both signals into one banner.
  final ValueNotifier<FallbackReason> fallbackReason = ValueNotifier(
    FallbackReason.none,
  );

  /// In-memory map from AniList id to the source plugin's
  /// `sourceMangaId`. Null entries memoize "we tried and didn't match"
  /// so the same negative resolution is not repeated within a session.
  /// Persisting this across launches is a follow-up — see Slice 8 plan.
  final Map<int, String?> _sourceMangaIdCache = <int, String?>{};

  /// Per-manga snapshot of the last `SourceChapter` list returned by
  /// the plugin during `fetchMangaChapters`. Indexed by AniList id;
  /// inner key is `${number}|${language}|${scanlator ?? ''}` so the
  /// reader can look up the exact `SourceChapter` it needs to call
  /// `getChapterPages` without re-fetching the chapter list.
  ///
  /// Lifetime: per-session (not persisted). When the user navigates
  /// out of the detail page and back, the next `fetchMangaChapters`
  /// call refreshes this cache; in between, the reader can open any
  /// chapter the user previously saw without an extra round-trip.
  final Map<int, Map<String, SourceChapter>> _sourceChaptersByManga =
      <int, Map<String, SourceChapter>>{};

  /// Per-manga catalog of distinct scanlator names sourced from the
  /// last `fetchMangaChapters` call's *raw* (pre-dedup) playable list,
  /// alongside how many chapters each scanlator contributes. Sorted
  /// by `chapterCount` desc, then alphabetically.
  ///
  /// Used by the detail page's "Fuente" picker. Externals are not
  /// counted because the user can't pick them as a per-manga
  /// preferred scanlator — they are always rendered separately.
  ///
  /// Lifetime mirrors `_sourceChaptersByManga` (per-session).
  final Map<int, List<ScanlatorOption>> _scanlatorsByManga =
      <int, List<ScanlatorOption>>{};

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
  /// caller pick a preferred scanlator for the playable bucket.
  ///
  /// When [preferredScanlator] is non-null, the per-`(number, language)`
  /// dedup picks the row whose `scanlator` matches. Numbers where the
  /// preferred scanlator has no release fall back to the auto-pick
  /// rule documented on [_dedupByNumberLanguage] — so the user never
  /// sees gaps just because their preferred group skipped a chapter.
  ///
  /// Externals are not affected by [preferredScanlator] (they are
  /// rendered in their own bucket regardless of preference).
  Future<Result<List<MangaChapter>, KumoriyaError>>
  fetchMangaChaptersWithPreference(
    int anilistId, {
    String? preferredScanlator,
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

    // 2. Resolve / cache the source plugin's manga id.
    final sourceIdResult = await _resolveSourceMangaId(manga);
    if (sourceIdResult.isFailure) {
      return Failure((sourceIdResult as Failure<String?, KumoriyaError>).error);
    }
    final sourceMangaId =
        (sourceIdResult as Success<String?, KumoriyaError>).value;
    if (sourceMangaId == null) {
      // Per Kumoriya rule #2: no chapters > wrong chapters. The UI
      // shows an empty-state explaining no source mapped to this manga.
      return const Success(<MangaChapter>[]);
    }

    // 3. Ask the plugin for chapters in the user's preferred languages.
    final query = MangaChapterQuery(
      sourceMangaId: sourceMangaId,
      languages: _preferredLanguages(),
      page: 1,
      limit: 200,
    );
    final chaptersResult = await _sourcePlugin.getChapters(query);
    if (chaptersResult.isFailure) {
      return Failure(
        (chaptersResult as Failure<List<SourceChapter>, KumoriyaError>).error,
      );
    }
    final source =
        (chaptersResult as Success<List<SourceChapter>, KumoriyaError>).value;

    // Split into "playable" (in-app reader works) and "external"
    // (re-publications hosted by MangaPlus / Viz / ComiXology / etc.
    // that we can only link out to). Then dedup each bucket
    // independently by (number, language) — same chapter uploaded by
    // different scanlators is the source of the "Cap. 1 repetido"
    // disaster in the UI.
    final playableRaw = <SourceChapter>[];
    final externalRaw = <SourceChapter>[];
    for (final c in source) {
      if (c.externalUrl != null) {
        externalRaw.add(c);
      } else {
        playableRaw.add(c);
      }
    }
    // Catalog the available scanlators across the *raw* playable list
    // so the picker shows MangaReworks (45), Asura (12), … even after
    // dedup collapses the list to one row per (number, language).
    // Externals are excluded because they aren't selectable as a
    // per-manga preferred scanlator.
    _scanlatorsByManga[anilistId] = _computeScanlatorOptions(playableRaw);

    // When the user has picked a preferred scanlator, the playable
    // list is **strictly filtered** to that scanlator. Chapters that
    // scanlator did not translate are intentionally absent — the
    // picker is a hard filter, not a tie-break hint, because the
    // fallback behaviour ("show another group's release for the
    // missing chapter") was confusing in practice (the user thought
    // the filter was broken when other groups' chapters kept
    // appearing). Switching back to "Auto" lifts the filter.
    final playableFiltered = preferredScanlator == null
        ? playableRaw
        : playableRaw
              .where((c) => c.scanlator == preferredScanlator)
              .toList(growable: false);

    final playable = _dedupByNumberLanguage(playableFiltered);
    final external = _dedupByNumberLanguage(externalRaw);

    // Suppress an external entry when the same (number, language) is
    // already playable in-app — the reader version always wins.
    final playableKeys = <String>{
      for (final c in playable) _numberLanguageKey(c.number, c.language),
    };
    final externalFiltered = external
        .where(
          (c) =>
              !playableKeys.contains(_numberLanguageKey(c.number, c.language)),
        )
        .toList(growable: false);

    final all = <SourceChapter>[...playable, ...externalFiltered];

    // Snapshot the SourceChapter list keyed by (number|language|scanlator)
    // so the reader can resolve a MangaChapter back to its source-side
    // counterpart without re-fetching the chapter list. Only playable
    // chapters need to be addressable from the reader, but we store
    // externals too so `lookupSourceChapter` can return the row for
    // the downloads slice / "open external" UI.
    _sourceChaptersByManga[anilistId] = <String, SourceChapter>{
      for (final c in all)
        _sourceChapterKey(c.number, c.language, c.scanlator): c,
    };

    final chapters = all.map(_toDomainChapter).toList(growable: false);
    return Success(chapters);
  }

  /// Deduplicates a chapter list by `(number, language)` keeping the
  /// "best" candidate per key. Tie-breaking, in order:
  ///
  /// 1. Higher `pageCount` (treats null as 0).
  /// 2. More recent `publishedAt` (treats null as `DateTime(0)`).
  /// 3. Non-null `scanlator` over null.
  ///
  /// Output preserves the *first occurrence* order of each unique key
  /// in the input — i.e. if the source returned chapters in
  /// `(volume asc, chapter asc)` order, the dedup'd list keeps that
  /// order.
  static List<SourceChapter> _dedupByNumberLanguage(
    List<SourceChapter> chapters,
  ) {
    final best = <String, SourceChapter>{};
    for (final c in chapters) {
      final key = _numberLanguageKey(c.number, c.language);
      final existing = best[key];
      if (existing == null || _isBetterChapter(c, existing)) {
        best[key] = c;
      }
    }
    final emitted = <String>{};
    final out = <SourceChapter>[];
    for (final c in chapters) {
      final key = _numberLanguageKey(c.number, c.language);
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
    final cached = _sourceChaptersByManga[mangaAnilistId];
    final key = _sourceChapterKey(
      chapter.number,
      chapter.language,
      chapter.scanlator,
    );
    final source = cached?[key];
    if (source == null) {
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
    final pagesResult = await _sourcePlugin.getChapterPages(source);
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
      sourceChapterId: source.sourceChapterId,
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
    final cache = _sourceChaptersByManga[mangaAnilistId];
    if (cache == null) return null;
    return cache[_sourceChapterKey(
      chapter.number,
      chapter.language,
      chapter.scanlator,
    )];
  }

  /// Composite key for the per-manga `SourceChapter` cache. Mirrors
  /// the disambiguators users see in the chapter list: a scanlator
  /// translation in language X is a different chapter from another
  /// scanlator's translation of the same number, even though both
  /// share `MangaChapter.number`.
  static String _sourceChapterKey(
    double number,
    String? language,
    String? scanlator,
  ) {
    return '$number|${language ?? ''}|${scanlator ?? ''}';
  }

  /// Resolves an AniList id to the source plugin's manga id.
  ///
  /// Strategy (in order):
  ///
  /// 1. In-memory cache — including memoized negatives.
  /// 2. MangaDex search by canonical romaji title; accept the result whose
  ///    `externalIds['al']` matches `anilistId`.
  /// 3. Fuzzy fallback: case/whitespace-insensitive equality between the
  ///    AniList title (any of romaji/english/native/synonyms) and the
  ///    source result's title or aliases. Avoids `kumoriya_matching` for
  ///    now — the fuzzy rule is conservative and good enough until the
  ///    Slice 8 follow-up wires the full matcher.
  /// 4. No match → memoize `null`. Caller treats this as "no chapters".
  Future<Result<String?, KumoriyaError>> _resolveSourceMangaId(
    Manga manga,
  ) async {
    final cached = _sourceMangaIdCache[manga.anilistId];
    if (cached != null || _sourceMangaIdCache.containsKey(manga.anilistId)) {
      return Success(cached);
    }

    final query = MangaSearchQuery(
      query: manga.title.romaji,
      page: 1,
      limit: 10,
      languages: _preferredLanguages(),
    );
    final searchResult = await _sourcePlugin.search(query);
    if (searchResult.isFailure) {
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

    // Strategy B: fuzzy title equality.
    if (resolved == null) {
      final candidates = <String>{
        _normalize(manga.title.romaji),
        if (manga.title.english != null) _normalize(manga.title.english!),
        if (manga.title.native != null) _normalize(manga.title.native!),
        for (final s in manga.title.synonyms) _normalize(s),
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

    _sourceMangaIdCache[manga.anilistId] = resolved;
    return Success(resolved);
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

  MangaChapter _toDomainChapter(SourceChapter chapter) {
    return MangaChapter(
      number: chapter.number,
      title: chapter.title ?? '',
      volume: chapter.volume,
      language: chapter.language,
      scanlator: chapter.scanlator,
      publishedAt: chapter.publishedAt,
      pageCount: chapter.pageCount,
      externalUrl: chapter.externalUrl,
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
