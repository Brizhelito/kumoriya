import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/manga_catalog/application/services/composite_manga_catalog_repository.dart';
import 'package:kumoriya_app/src/shared/cache/fallback_reason.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

// ---------------------------------------------------------------------------
// Test doubles

class _FakeAnilistMangaRepo implements MangaCatalogRepository {
  _FakeAnilistMangaRepo({
    this.detail,
    this.home = const <Manga>[],
    this.failHomeWith,
    this.sections,
    this.failSectionsWith,
  });

  MangaDetail? detail;
  List<Manga> home;
  KumoriyaError? failHomeWith;
  MangaHomeSections? sections;
  KumoriyaError? failSectionsWith;
  int homeSectionsCalls = 0;

  @override
  Future<Result<List<Manga>, KumoriyaError>> fetchHomeCatalog({
    int page = 1,
    int perPage = 20,
  }) async {
    if (failHomeWith != null) return Failure(failHomeWith!);
    return Success(home);
  }

  @override
  Future<Result<MangaHomeSections, KumoriyaError>> fetchHomeSections({
    int page = 1,
    int perPage = 20,
  }) async {
    homeSectionsCalls += 1;
    if (failSectionsWith != null) return Failure(failSectionsWith!);
    return Success(sections ?? const MangaHomeSections());
  }

  @override
  Future<Result<List<Manga>, KumoriyaError>> searchManga(
    MangaSearchRequest request,
  ) async {
    return Success(home);
  }

  @override
  Future<Result<List<Manga>, KumoriyaError>> browseManga(
    MangaBrowseRequest request,
  ) async {
    return Success(home);
  }

  @override
  Future<Result<MangaDetail, KumoriyaError>> fetchMangaDetail(
    int anilistId,
  ) async {
    if (detail == null) {
      return Failure(
        SimpleError(
          code: 'fake.detail.missing',
          message: 'no detail',
          kind: KumoriyaErrorKind.notFound,
        ),
      );
    }
    return Success(detail!);
  }

  @override
  Future<Result<List<MangaChapter>, KumoriyaError>> fetchMangaChapters(
    int anilistId,
  ) async {
    return const Success(<MangaChapter>[]);
  }

  @override
  Future<Result<List<Manga>, KumoriyaError>> fetchBatchMangaByIds(
    List<int> ids,
  ) async {
    return Success(home);
  }

  @override
  Future<Result<List<String>, KumoriyaError>> fetchGenreCollection() async {
    return const Success(<String>[]);
  }

  @override
  Future<Result<List<MangaTag>, KumoriyaError>> fetchTagCollection() async {
    return const Success(<MangaTag>[]);
  }
}

class _FakeMangaSourcePlugin implements MangaSourcePlugin {
  _FakeMangaSourcePlugin({
    this.searchResults = const <SourceMangaMatch>[],
    this.chaptersById = const <String, List<SourceChapter>>{},
    this.pagesByChapterId = const <String, List<SourcePage>>{},
  });

  List<SourceMangaMatch> searchResults;
  Map<String, List<SourceChapter>> chaptersById;
  Map<String, List<SourcePage>> pagesByChapterId;
  int searchCalls = 0;
  int chaptersCalls = 0;
  int pageCalls = 0;

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'test.fake.source',
    displayName: 'Fake source',
    type: PluginType.source,
    capabilities: <PluginCapability>{PluginCapability.search},
    baseUrls: <String>['https://fake.test'],
  );

  @override
  MangaSourceCapabilities get mangaCapabilities =>
      const MangaSourceCapabilities(
        supportsLanguageFilter: true,
        supportsScanlatorFilter: true,
        supportsLatestFeed: false,
        requiresPageHeaders: false,
      );

  @override
  Future<Result<List<SourceMangaMatch>, KumoriyaError>> search(
    MangaSearchQuery query,
  ) async {
    searchCalls++;
    return Success(searchResults);
  }

  @override
  Future<Result<List<SourceMangaMatch>, KumoriyaError>> getLatestUpdates({
    int page = 1,
    int limit = 20,
  }) async {
    return const Success(<SourceMangaMatch>[]);
  }

  @override
  Future<Result<SourceMangaDetail, KumoriyaError>> getMangaDetail(
    String sourceMangaId,
  ) async {
    return Failure(
      SimpleError(
        code: 'fake.detail.unsupported',
        message: 'not used in tests',
        kind: KumoriyaErrorKind.unexpected,
      ),
    );
  }

  @override
  Future<Result<List<SourceChapter>, KumoriyaError>> getChapters(
    MangaChapterQuery query,
  ) async {
    chaptersCalls++;
    final ch = chaptersById[query.sourceMangaId] ?? const <SourceChapter>[];
    return Success(ch);
  }

  @override
  Future<Result<List<SourcePage>, KumoriyaError>> getChapterPages(
    SourceChapter chapter,
  ) async {
    pageCalls++;
    final pages = pagesByChapterId[chapter.sourceChapterId];
    if (pages == null) {
      return Failure(
        const SimpleError(
          code: 'fake.pages.missing',
          message: 'no fixture for chapter',
          kind: KumoriyaErrorKind.notFound,
        ),
      );
    }
    return Success(pages);
  }
}

class _InMemoryMangaCacheStore implements MangaCacheStore {
  final Map<int, MangaCacheEntry> _entries = <int, MangaCacheEntry>{};

  @override
  Future<Result<void, KumoriyaError>> upsert(MangaCacheEntry entry) async {
    _entries[entry.anilistId] = entry;
    return const Success(null);
  }

  @override
  Future<Result<MangaCacheEntry?, KumoriyaError>> get(int anilistId) async {
    return Success(_entries[anilistId]);
  }

  @override
  Future<Result<void, KumoriyaError>> remove(int anilistId) async {
    _entries.remove(anilistId);
    return const Success(null);
  }

  @override
  Future<Result<int, KumoriyaError>> deleteOlderThan(Duration maxAge) async {
    return const Success(0);
  }

  @override
  Future<Result<List<MangaCacheEntry>, KumoriyaError>> getRecent({
    int limit = 20,
    int offset = 0,
  }) async {
    final all = _entries.values.toList();
    return Success(all.skip(offset).take(limit).toList(growable: false));
  }

  @override
  Future<Result<List<MangaCacheEntry>, KumoriyaError>> getByStatus(
    String status, {
    int limit = 20,
    int offset = 0,
  }) async {
    return const Success(<MangaCacheEntry>[]);
  }

  @override
  Future<Result<List<MangaCacheEntry>, KumoriyaError>> searchByTitle(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    final q = query.toLowerCase();
    final hits = _entries.values
        .where((e) => e.titleRomaji.toLowerCase().contains(q))
        .toList();
    return Success(hits.skip(offset).take(limit).toList(growable: false));
  }

  @override
  Future<Result<List<MangaCacheEntry>, KumoriyaError>> getByIds(
    List<int> ids,
  ) async {
    return Success(
      ids
          .map((i) => _entries[i])
          .whereType<MangaCacheEntry>()
          .toList(growable: false),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers

Manga _manga({
  int id = 100,
  String romaji = 'Chainsaw Man',
  String? english = 'Chainsaw Man',
  String? native = 'チェンソーマン',
  List<String> synonyms = const <String>[],
}) {
  return Manga(
    anilistId: id,
    title: MangaTitle(
      romaji: romaji,
      english: english,
      native: native,
      synonyms: synonyms,
    ),
    format: MangaFormat.manga,
    coverImageUrl: 'https://example/cover.jpg',
  );
}

MangaDetail _detail(Manga manga) => MangaDetail(manga: manga);

SourceChapter _ch({
  required String sourceMangaId,
  required String id,
  required double number,
  String? title,
}) {
  return SourceChapter(
    sourceMangaId: sourceMangaId,
    sourceChapterId: id,
    number: number,
    title: title,
    language: 'en',
  );
}

void main() {
  group('CompositeMangaCatalogRepository.fetchMangaChapters', () {
    test('matches via externalIds["al"] and returns mapped chapters', () async {
      final manga = _manga(id: 105778);
      final delegate = _FakeAnilistMangaRepo(detail: _detail(manga));
      final source = _FakeMangaSourcePlugin(
        searchResults: <SourceMangaMatch>[
          const SourceMangaMatch(
            sourceId: 'wrong-id',
            title: 'Different Manga',
          ),
          const SourceMangaMatch(
            sourceId: 'mangadex-uuid-1',
            title: 'Chainsaw Man',
            externalIds: <String, String>{'al': '105778'},
          ),
        ],
        chaptersById: <String, List<SourceChapter>>{
          'mangadex-uuid-1': <SourceChapter>[
            _ch(sourceMangaId: 'mangadex-uuid-1', id: 'c1', number: 1),
            _ch(sourceMangaId: 'mangadex-uuid-1', id: 'c2', number: 2),
          ],
        },
      );
      final repo = CompositeMangaCatalogRepository(
        delegate: delegate,
        sourcePlugin: source,
        cacheStore: _InMemoryMangaCacheStore(),
        preferredLanguages: () => const <String>['en'],
      );

      final result = await repo.fetchMangaChapters(105778);
      expect(result.isSuccess, isTrue);
      final chapters =
          (result as Success<List<MangaChapter>, KumoriyaError>).value;
      expect(chapters, hasLength(2));
      expect(chapters.first.number, 1);
    });

    test('falls back to fuzzy title match when no externalIds["al"]', () async {
      final manga = _manga(id: 1, romaji: 'Berserk', english: 'Berserk');
      final delegate = _FakeAnilistMangaRepo(detail: _detail(manga));
      final source = _FakeMangaSourcePlugin(
        searchResults: const <SourceMangaMatch>[
          SourceMangaMatch(sourceId: 'src-berserk', title: 'BERSERK '),
        ],
        chaptersById: <String, List<SourceChapter>>{
          'src-berserk': <SourceChapter>[
            _ch(sourceMangaId: 'src-berserk', id: 'c1', number: 1),
          ],
        },
      );
      final repo = CompositeMangaCatalogRepository(
        delegate: delegate,
        sourcePlugin: source,
        cacheStore: _InMemoryMangaCacheStore(),
        preferredLanguages: () => const <String>['en'],
      );

      final result = await repo.fetchMangaChapters(1);
      expect(result.isSuccess, isTrue);
      expect(
        (result as Success<List<MangaChapter>, KumoriyaError>).value,
        hasLength(1),
      );
    });

    test('returns empty list when no source candidate matches', () async {
      final manga = _manga(id: 999, romaji: 'Obscure Webtoon Original');
      final delegate = _FakeAnilistMangaRepo(detail: _detail(manga));
      final source = _FakeMangaSourcePlugin(
        searchResults: const <SourceMangaMatch>[
          SourceMangaMatch(
            sourceId: 'unrelated',
            title: 'Something Else Entirely',
          ),
        ],
      );
      final repo = CompositeMangaCatalogRepository(
        delegate: delegate,
        sourcePlugin: source,
        cacheStore: _InMemoryMangaCacheStore(),
        preferredLanguages: () => const <String>['en'],
      );

      final result = await repo.fetchMangaChapters(999);
      expect(result.isSuccess, isTrue);
      expect(
        (result as Success<List<MangaChapter>, KumoriyaError>).value,
        isEmpty,
      );
    });

    test('memoizes the resolved sourceMangaId across calls', () async {
      final manga = _manga(id: 7);
      final delegate = _FakeAnilistMangaRepo(detail: _detail(manga));
      final source = _FakeMangaSourcePlugin(
        searchResults: const <SourceMangaMatch>[
          SourceMangaMatch(
            sourceId: 'cache-me',
            title: 'Chainsaw Man',
            externalIds: <String, String>{'al': '7'},
          ),
        ],
        chaptersById: <String, List<SourceChapter>>{
          'cache-me': <SourceChapter>[
            _ch(sourceMangaId: 'cache-me', id: 'a', number: 1),
          ],
        },
      );
      final repo = CompositeMangaCatalogRepository(
        delegate: delegate,
        sourcePlugin: source,
        cacheStore: _InMemoryMangaCacheStore(),
        preferredLanguages: () => const <String>['en'],
      );

      await repo.fetchMangaChapters(7);
      await repo.fetchMangaChapters(7);
      expect(
        source.searchCalls,
        1,
        reason: 'second call must reuse memoized sourceMangaId',
      );
      expect(source.chaptersCalls, 2);
    });

    test(
      'dedups (number, language) keeping the chapter with more pages',
      () async {
        final manga = _manga(id: 200);
        final delegate = _FakeAnilistMangaRepo(detail: _detail(manga));
        final source = _FakeMangaSourcePlugin(
          searchResults: const <SourceMangaMatch>[
            SourceMangaMatch(
              sourceId: 'src-200',
              title: 'Chainsaw Man',
              externalIds: <String, String>{'al': '200'},
            ),
          ],
          chaptersById: <String, List<SourceChapter>>{
            'src-200': <SourceChapter>[
              // Same number+language uploaded by three different
              // scanlators with different page counts → only the
              // 22-page version must survive (best pageCount).
              SourceChapter(
                sourceMangaId: 'src-200',
                sourceChapterId: 'a',
                number: 1,
                title: 'cap. 1 lower',
                language: 'en',
                scanlator: 'Scans A',
                pageCount: 18,
              ),
              SourceChapter(
                sourceMangaId: 'src-200',
                sourceChapterId: 'b',
                number: 1,
                title: 'CAP. 1 UPPER',
                language: 'en',
                scanlator: 'Scans B',
                pageCount: 22,
              ),
              SourceChapter(
                sourceMangaId: 'src-200',
                sourceChapterId: 'c',
                number: 1,
                title: 'partial',
                language: 'en',
                scanlator: 'Scans C',
                pageCount: 12,
              ),
            ],
          },
        );
        final repo = CompositeMangaCatalogRepository(
          delegate: delegate,
          sourcePlugin: source,
          cacheStore: _InMemoryMangaCacheStore(),
          preferredLanguages: () => const <String>['en'],
        );

        final result = await repo.fetchMangaChapters(200);
        final chapters =
            (result as Success<List<MangaChapter>, KumoriyaError>).value;
        expect(chapters, hasLength(1));
        expect(chapters.single.scanlator, 'Scans B');
        expect(chapters.single.pageCount, 22);
      },
    );

    test('splits external chapters into a trailing bucket and suppresses '
        'externals already covered by a playable entry', () async {
      final manga = _manga(id: 300);
      final delegate = _FakeAnilistMangaRepo(detail: _detail(manga));
      final source = _FakeMangaSourcePlugin(
        searchResults: const <SourceMangaMatch>[
          SourceMangaMatch(
            sourceId: 'src-300',
            title: 'Jujutsu Kaisen',
            externalIds: <String, String>{'al': '300'},
          ),
        ],
        chaptersById: <String, List<SourceChapter>>{
          'src-300': <SourceChapter>[
            // Playable cap 1 from a scanlation group.
            SourceChapter(
              sourceMangaId: 'src-300',
              sourceChapterId: 'p1',
              number: 1,
              title: 'Bonus',
              language: 'en',
              scanlator: 'Scans X',
              pageCount: 20,
            ),
            // External cap 1 from MangaPlus — must be suppressed
            // because the playable version covers (1, en).
            SourceChapter(
              sourceMangaId: 'src-300',
              sourceChapterId: 'mp1',
              number: 1,
              title: 'MangaPlus',
              language: 'en',
              externalUrl: Uri.parse('https://mangaplus.example/1'),
            ),
            // External cap 5 with no playable counterpart — kept.
            SourceChapter(
              sourceMangaId: 'src-300',
              sourceChapterId: 'mp5',
              number: 5,
              title: 'MangaPlus 5',
              language: 'en',
              externalUrl: Uri.parse('https://mangaplus.example/5'),
            ),
            // Two external duplicates of cap 5 — only one survives
            // and the externalUrl carries through.
            SourceChapter(
              sourceMangaId: 'src-300',
              sourceChapterId: 'viz5',
              number: 5,
              title: 'Viz 5',
              language: 'en',
              externalUrl: Uri.parse('https://viz.example/5'),
            ),
          ],
        },
      );
      final repo = CompositeMangaCatalogRepository(
        delegate: delegate,
        sourcePlugin: source,
        cacheStore: _InMemoryMangaCacheStore(),
        preferredLanguages: () => const <String>['en'],
      );

      final result = await repo.fetchMangaChapters(300);
      final chapters =
          (result as Success<List<MangaChapter>, KumoriyaError>).value;

      // Playable first, externals trailing.
      expect(chapters, hasLength(2));
      expect(chapters[0].number, 1);
      expect(chapters[0].externalUrl, isNull);
      expect(chapters[0].scanlator, 'Scans X');
      expect(chapters[1].number, 5);
      expect(chapters[1].externalUrl, isNotNull);
    });

    test('preferredScanlator strictly filters playable chapters to that '
        'scanlator (no fallback)', () async {
      final manga = _manga(id: 400);
      final delegate = _FakeAnilistMangaRepo(detail: _detail(manga));
      final source = _FakeMangaSourcePlugin(
        searchResults: const <SourceMangaMatch>[
          SourceMangaMatch(
            sourceId: 'src-400',
            title: 'Same',
            externalIds: <String, String>{'al': '400'},
          ),
        ],
        chaptersById: <String, List<SourceChapter>>{
          'src-400': const <SourceChapter>[
            // Cap. 1 has both MangaReworks (12 pgs) and Asura (20
            // pgs). Auto-pick prefers Asura (more pages); with
            // preferredScanlator='MangaReworks' the picker must
            // override and return MangaReworks.
            SourceChapter(
              sourceMangaId: 'src-400',
              sourceChapterId: 'mr-1',
              number: 1,
              language: 'en',
              scanlator: 'MangaReworks',
              pageCount: 12,
            ),
            SourceChapter(
              sourceMangaId: 'src-400',
              sourceChapterId: 'as-1',
              number: 1,
              language: 'en',
              scanlator: 'Asura',
              pageCount: 20,
            ),
            // Cap. 2 only Asura — preferred fallback must surface
            // Asura's release so there's no gap.
            SourceChapter(
              sourceMangaId: 'src-400',
              sourceChapterId: 'as-2',
              number: 2,
              language: 'en',
              scanlator: 'Asura',
              pageCount: 18,
            ),
          ],
        },
      );
      final repo = CompositeMangaCatalogRepository(
        delegate: delegate,
        sourcePlugin: source,
        cacheStore: _InMemoryMangaCacheStore(),
        preferredLanguages: () => const <String>['en'],
      );

      final result = await repo.fetchMangaChaptersWithPreference(
        400,
        preferredScanlator: 'MangaReworks',
      );
      final chapters =
          (result as Success<List<MangaChapter>, KumoriyaError>).value;
      // Strict filter: only MangaReworks releases survive. Cap. 2
      // (only Asura) is intentionally absent — switching back to
      // "Auto" lifts the filter.
      expect(chapters, hasLength(1));
      expect(chapters.single.number, 1);
      expect(chapters.single.scanlator, 'MangaReworks');

      // Sanity: with no preference, both chapters render and Asura
      // wins cap. 1 by page-count tie-break.
      final auto =
          (await repo.fetchMangaChaptersWithPreference(400)
                  as Success<List<MangaChapter>, KumoriyaError>)
              .value;
      expect(auto.map((c) => (c.number, c.scanlator)), <(double, String?)>[
        (1, 'Asura'),
        (2, 'Asura'),
      ]);
    });

    test(
      'availableScanlators reports counts ordered by coverage desc',
      () async {
        final manga = _manga(id: 500);
        final delegate = _FakeAnilistMangaRepo(detail: _detail(manga));
        final source = _FakeMangaSourcePlugin(
          searchResults: const <SourceMangaMatch>[
            SourceMangaMatch(
              sourceId: 'src-500',
              title: 'Same',
              externalIds: <String, String>{'al': '500'},
            ),
          ],
          chaptersById: <String, List<SourceChapter>>{
            'src-500': <SourceChapter>[
              for (var n = 1; n <= 5; n++)
                SourceChapter(
                  sourceMangaId: 'src-500',
                  sourceChapterId: 'a-$n',
                  number: n.toDouble(),
                  language: 'en',
                  scanlator: 'Asura',
                ),
              for (var n = 1; n <= 2; n++)
                SourceChapter(
                  sourceMangaId: 'src-500',
                  sourceChapterId: 'b-$n',
                  number: n.toDouble(),
                  language: 'en',
                  scanlator: 'MangaReworks',
                ),
              const SourceChapter(
                sourceMangaId: 'src-500',
                sourceChapterId: 'orphan',
                number: 99,
                language: 'en',
                pageCount: 5,
              ),
            ],
          },
        );
        final repo = CompositeMangaCatalogRepository(
          delegate: delegate,
          sourcePlugin: source,
          cacheStore: _InMemoryMangaCacheStore(),
          preferredLanguages: () => const <String>['en'],
        );

        // Empty before warm-up.
        expect(repo.availableScanlators(500), isEmpty);

        await repo.fetchMangaChapters(500);
        final options = repo.availableScanlators(500);
        expect(options.map((o) => o.name), <String>['Asura', 'MangaReworks']);
        expect(options[0].chapterCount, 5);
        expect(options[1].chapterCount, 2);
      },
    );
  });

  group('CompositeMangaCatalogRepository catalog fallbacks', () {
    test(
      'serves from cache when AniList home returns transport failure',
      () async {
        final cache = _InMemoryMangaCacheStore();
        await cache.upsert(
          MangaCacheEntry(
            anilistId: 1,
            titleRomaji: 'Cached Manga',
            updatedAt: DateTime.now(),
          ),
        );
        final delegate = _FakeAnilistMangaRepo(
          failHomeWith: SimpleError(
            code: 'anilist.service_unavailable',
            message: 'down',
            kind: KumoriyaErrorKind.transport,
          ),
        );
        final repo = CompositeMangaCatalogRepository(
          delegate: delegate,
          sourcePlugin: _FakeMangaSourcePlugin(),
          cacheStore: cache,
          preferredLanguages: () => const <String>['en'],
        );

        final result = await repo.fetchHomeCatalog();
        expect(result.isSuccess, isTrue);
        final manga = (result as Success<List<Manga>, KumoriyaError>).value;
        expect(manga, hasLength(1));
        expect(manga.first.title.romaji, 'Cached Manga');
      },
    );

    test('writes through to cache on successful home read', () async {
      final cache = _InMemoryMangaCacheStore();
      final delegate = _FakeAnilistMangaRepo(
        home: <Manga>[_manga(id: 42, romaji: 'Fresh Manga')],
      );
      final repo = CompositeMangaCatalogRepository(
        delegate: delegate,
        sourcePlugin: _FakeMangaSourcePlugin(),
        cacheStore: cache,
        preferredLanguages: () => const <String>['en'],
      );

      final result = await repo.fetchHomeCatalog();
      expect(result.isSuccess, isTrue);
      final cached = await cache.get(42);
      expect(
        (cached as Success<MangaCacheEntry?, KumoriyaError>).value,
        isNotNull,
      );
    });
  });

  group('CompositeMangaCatalogRepository.fetchHomeSections', () {
    test(
      'delegates to inner repo and returns the four-shelf payload as-is',
      () async {
        final cache = _InMemoryMangaCacheStore();
        final delegate = _FakeAnilistMangaRepo(
          sections: MangaHomeSections(
            trending: <Manga>[_manga(id: 1, romaji: 'Trending Pick')],
            popular: <Manga>[_manga(id: 2, romaji: 'Popular Pick')],
            latest: <Manga>[_manga(id: 3, romaji: 'Latest Pick')],
            topRated: <Manga>[_manga(id: 4, romaji: 'Top Pick')],
          ),
        );
        final repo = CompositeMangaCatalogRepository(
          delegate: delegate,
          sourcePlugin: _FakeMangaSourcePlugin(),
          cacheStore: cache,
          preferredLanguages: () => const <String>['en'],
        );

        final result = await repo.fetchHomeSections();
        expect(result.isSuccess, isTrue);
        final sections =
            (result as Success<MangaHomeSections, KumoriyaError>).value;
        expect(sections.trending.single.anilistId, 1);
        expect(sections.popular.single.anilistId, 2);
        expect(sections.latest.single.anilistId, 3);
        expect(sections.topRated.single.anilistId, 4);
        expect(delegate.homeSectionsCalls, 1);
      },
    );

    test('writes every shelf through to the cache', () async {
      final cache = _InMemoryMangaCacheStore();
      final delegate = _FakeAnilistMangaRepo(
        sections: MangaHomeSections(
          trending: <Manga>[_manga(id: 10, romaji: 'A')],
          popular: <Manga>[_manga(id: 20, romaji: 'B')],
          latest: <Manga>[_manga(id: 30, romaji: 'C')],
          topRated: <Manga>[_manga(id: 40, romaji: 'D')],
        ),
      );
      final repo = CompositeMangaCatalogRepository(
        delegate: delegate,
        sourcePlugin: _FakeMangaSourcePlugin(),
        cacheStore: cache,
        preferredLanguages: () => const <String>['en'],
      );

      await repo.fetchHomeSections();

      for (final id in const <int>[10, 20, 30, 40]) {
        final cached = await cache.get(id);
        expect(
          (cached as Success<MangaCacheEntry?, KumoriyaError>).value,
          isNotNull,
          reason: 'expected manga $id to be cached',
        );
      }
    });

    test('propagates upstream failure without writing to cache', () async {
      final cache = _InMemoryMangaCacheStore();
      final delegate = _FakeAnilistMangaRepo(
        failSectionsWith: const SimpleError(
          code: 'fake.network',
          message: 'down',
          kind: KumoriyaErrorKind.transport,
        ),
      );
      final repo = CompositeMangaCatalogRepository(
        delegate: delegate,
        sourcePlugin: _FakeMangaSourcePlugin(),
        cacheStore: cache,
        preferredLanguages: () => const <String>['en'],
      );

      // Cache is empty → cannot fall back, must propagate failure.
      final result = await repo.fetchHomeSections();
      expect(result.isFailure, isTrue);
      final cached = await cache.getRecent();
      expect(
        (cached as Success<List<MangaCacheEntry>, KumoriyaError>).value,
        isEmpty,
      );
    });

    test(
      'falls back to local cache and signals offline on transport failure',
      () async {
        final cache = _InMemoryMangaCacheStore();
        // Pre-seed the cache with 25 entries so the fallback can populate
        // trending (20) + the start of popular (5).
        for (var i = 0; i < 25; i++) {
          await cache.upsert(_cacheEntry(id: 100 + i, romaji: 'Cached $i'));
        }
        final delegate = _FakeAnilistMangaRepo(
          failSectionsWith: const SimpleError(
            code: 'unreachable',
            message: 'offline',
            kind: KumoriyaErrorKind.transport,
          ),
        );
        final repo = CompositeMangaCatalogRepository(
          delegate: delegate,
          sourcePlugin: _FakeMangaSourcePlugin(),
          cacheStore: cache,
          preferredLanguages: () => const <String>['en'],
        );

        final result = await repo.fetchHomeSections();
        expect(result.isSuccess, isTrue);
        final sections =
            (result as Success<MangaHomeSections, KumoriyaError>).value;
        expect(sections.trending, hasLength(20));
        expect(sections.popular, hasLength(5));
        expect(sections.latest, isEmpty);
        expect(sections.topRated, isEmpty);
        expect(repo.fallbackReason.value, FallbackReason.offline);
      },
    );

    test(
      'classifies upstream 503 / rate-limit as anilistDown rather than offline',
      () async {
        final cache = _InMemoryMangaCacheStore();
        await cache.upsert(_cacheEntry(id: 1, romaji: 'X'));
        final delegate = _FakeAnilistMangaRepo(
          failSectionsWith: const SimpleError(
            code: 'anilist.service_unavailable',
            message: '503',
            kind: KumoriyaErrorKind.transport,
          ),
        );
        final repo = CompositeMangaCatalogRepository(
          delegate: delegate,
          sourcePlugin: _FakeMangaSourcePlugin(),
          cacheStore: cache,
          preferredLanguages: () => const <String>['en'],
        );

        final result = await repo.fetchHomeSections();
        expect(result.isSuccess, isTrue);
        expect(repo.fallbackReason.value, FallbackReason.anilistDown);
      },
    );

    test('successful fetch resets fallbackReason back to none', () async {
      final cache = _InMemoryMangaCacheStore();
      final delegate = _FakeAnilistMangaRepo(
        sections: const MangaHomeSections(),
      );
      final repo = CompositeMangaCatalogRepository(
        delegate: delegate,
        sourcePlugin: _FakeMangaSourcePlugin(),
        cacheStore: cache,
        preferredLanguages: () => const <String>['en'],
      );

      // Force the notifier into a degraded state first so we can verify
      // the next successful fetch clears it.
      repo.fallbackReason.value = FallbackReason.anilistDown;
      await repo.fetchHomeSections();
      expect(repo.fallbackReason.value, FallbackReason.none);
    });
  });

  group('CompositeMangaCatalogRepository.openChapter', () {
    test(
      'fails with reader.chapter_not_resolved when chapter list never fetched',
      () async {
        final cache = _InMemoryMangaCacheStore();
        final repo = CompositeMangaCatalogRepository(
          delegate: _FakeAnilistMangaRepo(),
          sourcePlugin: _FakeMangaSourcePlugin(),
          cacheStore: cache,
          preferredLanguages: () => const <String>['en'],
        );

        final res = await repo.openChapter(
          mangaAnilistId: 1,
          chapter: const MangaChapter(number: 1, title: 'X', language: 'en'),
        );
        expect(res.isFailure, isTrue);
        expect((res as Failure).error.code, 'reader.chapter_not_resolved');
      },
    );

    test(
      'returns mapped pages and sourceChapterId after fetchMangaChapters',
      () async {
        final manga = _manga(id: 42);
        final delegate = _FakeAnilistMangaRepo(detail: _detail(manga));
        final source = _FakeMangaSourcePlugin(
          searchResults: const <SourceMangaMatch>[
            SourceMangaMatch(
              sourceId: 'src-42',
              title: 'Same',
              externalIds: <String, String>{'al': '42'},
            ),
          ],
          chaptersById: <String, List<SourceChapter>>{
            'src-42': <SourceChapter>[
              const SourceChapter(
                sourceMangaId: 'src-42',
                sourceChapterId: 'ch-1',
                number: 1,
                language: 'en',
                scanlator: 'Group',
              ),
            ],
          },
          pagesByChapterId: <String, List<SourcePage>>{
            'ch-1': <SourcePage>[
              SourcePage(index: 0, imageUrl: Uri.parse('https://x/p0.jpg')),
              SourcePage(index: 1, imageUrl: Uri.parse('https://x/p1.jpg')),
            ],
          },
        );
        final repo = CompositeMangaCatalogRepository(
          delegate: delegate,
          sourcePlugin: source,
          cacheStore: _InMemoryMangaCacheStore(),
          preferredLanguages: () => const <String>['en'],
        );

        // Prime the per-manga SourceChapter cache.
        final chaptersRes = await repo.fetchMangaChapters(42);
        expect(chaptersRes.isSuccess, isTrue);

        final res = await repo.openChapter(
          mangaAnilistId: 42,
          chapter: const MangaChapter(
            number: 1,
            title: '',
            language: 'en',
            scanlator: 'Group',
          ),
        );
        expect(res.isSuccess, isTrue);
        final value =
            (res
                    as Success<
                      ({String sourceChapterId, List<MangaPage> pages}),
                      KumoriyaError
                    >)
                .value;
        expect(value.sourceChapterId, 'ch-1');
        expect(value.pages, hasLength(2));
        expect(value.pages[0].imageUrl.toString(), 'https://x/p0.jpg');
      },
    );
  });

  group('CompositeMangaCatalogRepository.fetchMangaDetail (offline)', () {
    test(
      'synthesizes a minimal MangaDetail from cache when AniList is unreachable',
      () async {
        final cache = _InMemoryMangaCacheStore();
        await cache.upsert(_cacheEntry(id: 99, romaji: 'Cached Title'));

        final delegate = _FakeAnilistMangaRepo();
        // Force fetchMangaDetail to fail with a transport error (default
        // fake returns fake.detail.missing/notFound which is not a
        // candidate for fallback). We do this via a thin subclass.
        final failing = _FailingDetailRepo(
          underlying: delegate,
          error: const SimpleError(
            code: 'unreachable',
            message: 'offline',
            kind: KumoriyaErrorKind.transport,
          ),
        );
        final repo = CompositeMangaCatalogRepository(
          delegate: failing,
          sourcePlugin: _FakeMangaSourcePlugin(),
          cacheStore: cache,
          preferredLanguages: () => const <String>['en'],
        );

        final result = await repo.fetchMangaDetail(99);
        expect(result.isSuccess, isTrue);
        final detail = (result as Success<MangaDetail, KumoriyaError>).value;
        expect(detail.manga.anilistId, 99);
        expect(detail.manga.title.romaji, 'Cached Title');
        expect(repo.fallbackReason.value, FallbackReason.offline);
      },
    );
  });
}

MangaCacheEntry _cacheEntry({required int id, required String romaji}) {
  return MangaCacheEntry(
    anilistId: id,
    titleRomaji: romaji,
    titleEnglish: null,
    titleNative: null,
    synonyms: null,
    coverImageUrl: null,
    bannerImageUrl: null,
    status: 'FINISHED',
    format: 'MANGA',
    countryOfOrigin: 'JP',
    releaseYear: 2020,
    totalChapters: null,
    totalVolumes: null,
    averageScore: null,
    popularity: null,
    genres: null,
    synopsis: null,
    updatedAt: DateTime.now(),
  );
}

/// Wraps another `MangaCatalogRepository` but forces `fetchMangaDetail`
/// to return a controlled failure. Used to drive the offline-fallback
/// path of the composite without rewiring the larger fake.
class _FailingDetailRepo implements MangaCatalogRepository {
  _FailingDetailRepo({required this.underlying, required this.error});

  final MangaCatalogRepository underlying;
  final KumoriyaError error;

  @override
  Future<Result<MangaDetail, KumoriyaError>> fetchMangaDetail(int anilistId) =>
      Future.value(Failure(error));

  @override
  Future<Result<List<Manga>, KumoriyaError>> fetchHomeCatalog({
    int page = 1,
    int perPage = 20,
  }) => underlying.fetchHomeCatalog(page: page, perPage: perPage);

  @override
  Future<Result<MangaHomeSections, KumoriyaError>> fetchHomeSections({
    int page = 1,
    int perPage = 20,
  }) => underlying.fetchHomeSections(page: page, perPage: perPage);

  @override
  Future<Result<List<Manga>, KumoriyaError>> searchManga(
    MangaSearchRequest request,
  ) => underlying.searchManga(request);

  @override
  Future<Result<List<Manga>, KumoriyaError>> browseManga(
    MangaBrowseRequest request,
  ) => underlying.browseManga(request);

  @override
  Future<Result<List<MangaChapter>, KumoriyaError>> fetchMangaChapters(
    int anilistId,
  ) => underlying.fetchMangaChapters(anilistId);

  @override
  Future<Result<List<Manga>, KumoriyaError>> fetchBatchMangaByIds(
    List<int> ids,
  ) => underlying.fetchBatchMangaByIds(ids);

  @override
  Future<Result<List<String>, KumoriyaError>> fetchGenreCollection() =>
      underlying.fetchGenreCollection();

  @override
  Future<Result<List<MangaTag>, KumoriyaError>> fetchTagCollection() =>
      underlying.fetchTagCollection();
}
