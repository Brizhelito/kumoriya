import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_inmanga/kumoriya_source_inmanga.dart';
import 'package:kumoriya_source_runtime/kumoriya_source_runtime.dart';
import 'package:test/test.dart';

String _fix(String name) => File('test/fixtures/$name').readAsStringSync();

http.Response _ok(String body, {String? contentType}) => http.Response(
  body,
  200,
  headers: {'content-type': contentType ?? 'application/json; charset=utf-8'},
);

void main() {
  // ---------------------------------------------------------------------------
  // manifest

  test('manifest declares InManga and the canonical host', () {
    final plugin = InMangaSourcePlugin(
      httpClient: MockClient((_) async => _ok('{}')),
    );
    expect(plugin.manifest.id, 'kumoriya.source.inmanga');
    expect(plugin.manifest.type, PluginType.source);
    expect(plugin.manifest.baseUrls, <String>['https://inmanga.com']);
  });

  test('mangaCapabilities reflects InManga reality', () {
    final plugin = InMangaSourcePlugin(
      httpClient: MockClient((_) async => _ok('{}')),
    );
    expect(plugin.mangaCapabilities.supportsLanguageFilter, isTrue);
    expect(plugin.mangaCapabilities.supportsScanlatorFilter, isTrue);
    expect(plugin.mangaCapabilities.supportsLatestFeed, isFalse);
    expect(plugin.mangaCapabilities.requiresPageHeaders, isFalse);
  });

  // ---------------------------------------------------------------------------
  // search

  test('search hits GetQuickSearch and decodes the double envelope', () async {
    Uri? captured;
    final plugin = InMangaSourcePlugin(
      httpClient: MockClient((req) async {
        captured = req.url;
        return _ok(_fix('quick_search_one_piece.json'));
      }),
    );
    final res = await plugin.search(const MangaSearchQuery(query: 'one piece'));
    expect(captured!.path, '/manga/GetQuickSearch');
    expect(captured!.queryParameters['name'], 'one piece');
    final matches =
        (res as Success<List<SourceMangaMatch>, KumoriyaError>).value;
    expect(matches, hasLength(3));
    expect(matches.first.title, 'One Piece');
    expect(matches.first.sourceId, 'dfc7ecb5-e9b3-4aa5-a61b-a498993cd935');
    expect(matches.first.releaseYear, 1997);
    expect(matches.first.thumbnailUrl, isNotNull);
  });

  test('empty search query returns empty success without HTTP', () async {
    final plugin = InMangaSourcePlugin(
      httpClient: MockClient((_) async => fail('must not call network')),
    );
    final res = await plugin.search(const MangaSearchQuery(query: ''));
    expect(
      (res as Success<List<SourceMangaMatch>, KumoriyaError>).value,
      isEmpty,
    );
  });

  test('search returns empty success when "result" is missing', () async {
    final plugin = InMangaSourcePlugin(
      httpClient: MockClient(
        (_) async =>
            _ok('{"data":"{\\"message\\":\\"OK\\",\\"success\\":true}"}'),
      ),
    );
    final res = await plugin.search(const MangaSearchQuery(query: 'x'));
    expect(
      (res as Success<List<SourceMangaMatch>, KumoriyaError>).value,
      isEmpty,
    );
  });

  test('search surfaces typed failure on bad envelope', () async {
    final plugin = InMangaSourcePlugin(
      httpClient: MockClient((_) async => _ok('{"unexpected":1}')),
    );
    final res = await plugin.search(const MangaSearchQuery(query: 'x'));
    expect(res.isFailure, isTrue);
    expect(
      (res as Failure<List<SourceMangaMatch>, KumoriyaError>).error.code,
      'inmanga.search_bad_envelope',
    );
  });

  // ---------------------------------------------------------------------------
  // latest

  test('getLatestUpdates is empty success without HTTP', () async {
    final plugin = InMangaSourcePlugin(
      httpClient: MockClient((_) async => fail('must not call network')),
    );
    final res = await plugin.getLatestUpdates();
    expect(
      (res as Success<List<SourceMangaMatch>, KumoriyaError>).value,
      isEmpty,
    );
  });

  // ---------------------------------------------------------------------------
  // chapters

  test(
    'getChapters paginates against /chapter/getall and parses rows',
    () async {
      Uri? captured;
      final plugin = InMangaSourcePlugin(
        httpClient: MockClient((req) async {
          captured = req.url;
          return _ok(_fix('chapters_one_piece.json'));
        }),
      );
      final res = await plugin.getChapters(
        const MangaChapterQuery(
          sourceMangaId: 'dfc7ecb5-e9b3-4aa5-a61b-a498993cd935',
          page: 1,
        ),
      );
      expect(captured!.path, '/chapter/getall');
      expect(
        captured!.queryParameters['mangaIdentification'],
        'dfc7ecb5-e9b3-4aa5-a61b-a498993cd935',
      );
      final chapters =
          (res as Success<List<SourceChapter>, KumoriyaError>).value;
      expect(chapters, hasLength(5));
      // Sorted ascending by number — InManga returns 1,10,11,12,13 lexically.
      expect(chapters.map((c) => c.number).toList(), <double>[
        1,
        10,
        11,
        12,
        13,
      ]);
      expect(
        chapters.first.sourceChapterId,
        '8d23d3d6-7c59-4223-bfbc-6f87aa8259dd',
      );
      expect(chapters.first.scanlator, 'InManga');
      expect(chapters.first.language, 'es');
      expect(chapters.first.pageCount, 56);
      expect(chapters.first.publishedAt, isNotNull);
    },
  );

  test('getChapters honors scanlator filter', () async {
    final plugin = InMangaSourcePlugin(
      httpClient: MockClient((_) async => _ok(_fix('chapters_one_piece.json'))),
    );
    final res = await plugin.getChapters(
      const MangaChapterQuery(
        sourceMangaId: 'dfc7ecb5-e9b3-4aa5-a61b-a498993cd935',
        page: 1,
        scanlators: <String>['Olympus'], // wrong scanlator
      ),
    );
    final chapters = (res as Success<List<SourceChapter>, KumoriyaError>).value;
    expect(chapters, isEmpty);
  });

  // ---------------------------------------------------------------------------
  // detail (HTML scrape)

  test(
    'getMangaDetail scrapes title, synopsis, status and cover from HTML',
    () async {
      Uri? captured;
      final plugin = InMangaSourcePlugin(
        httpClient: MockClient((req) async {
          captured = req.url;
          return http.Response(
            _fix('detail_one_piece.html'),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      final res = await plugin.getMangaDetail(
        'DFC7ECB5-E9B3-4AA5-A61B-A498993CD935',
      );
      expect(captured!.path, contains('/ver/manga/_/'));
      expect(
        captured!.path.endsWith('dfc7ecb5-e9b3-4aa5-a61b-a498993cd935'),
        isTrue,
        reason: 'detail URL must lowercase the UUID',
      );
      final detail = (res as Success<SourceMangaDetail, KumoriyaError>).value;
      expect(detail.title, 'One Piece');
      expect(detail.synopsis, contains('Gol D. Roger'));
      expect(detail.status, MangaStatus.releasing);
      expect(detail.thumbnailUrl, isNotNull);
      expect(detail.thumbnailUrl!.host, 'inmanga.com');
      expect(detail.format, MangaFormat.manga);
      expect(detail.country, MangaCountryOfOrigin.jp);
    },
  );

  test('getMangaDetail returns parse failure on missing markup', () async {
    final plugin = InMangaSourcePlugin(
      httpClient: MockClient(
        (_) async => http.Response(
          '<html><body>nope</body></html>',
          200,
          headers: {'content-type': 'text/html'},
        ),
      ),
    );
    final res = await plugin.getMangaDetail('whatever-uuid');
    expect(res.isFailure, isTrue);
    expect(
      (res as Failure<SourceMangaDetail, KumoriyaError>).error.code,
      'inmanga.detail_not_parseable',
    );
  });

  test('getMangaDetail rejects empty id without HTTP', () async {
    final plugin = InMangaSourcePlugin(
      httpClient: MockClient((_) async => fail('must not call network')),
    );
    final res = await plugin.getMangaDetail('');
    expect(res.isFailure, isTrue);
    expect(
      (res as Failure<SourceMangaDetail, KumoriyaError>).error.code,
      'inmanga.detail_invalid_id',
    );
  });

  // ---------------------------------------------------------------------------
  // pages

  test('getChapterPages parses PageList select and builds CDN URLs', () async {
    Uri? captured;
    final plugin = InMangaSourcePlugin(
      httpClient: MockClient((req) async {
        captured = req.url;
        return http.Response(
          _fix('reader_one_piece_ch1.html'),
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }),
    );
    final res = await plugin.getChapterPages(
      const SourceChapter(
        sourceMangaId: 'dfc7ecb5-e9b3-4aa5-a61b-a498993cd935',
        sourceChapterId: '8d23d3d6-7c59-4223-bfbc-6f87aa8259dd',
        number: 1,
      ),
    );
    expect(
      captured!.path,
      '/ver/manga/_/1/8d23d3d6-7c59-4223-bfbc-6f87aa8259dd',
    );
    final pages = (res as Success<List<SourcePage>, KumoriyaError>).value;
    expect(pages, hasLength(5));
    expect(pages[0].index, 0);
    expect(
      pages[0].imageUrl.toString(),
      'https://cdn1.intomanga.com/i/m/dfc7ecb5-e9b3-4aa5-a61b-a498993cd935'
      '/c/8d23d3d6-7c59-4223-bfbc-6f87aa8259dd'
      '/o/e720d0bf-cc16-4419-8118-dcc03433f8b7.jpg',
    );
  });

  test('getChapterPages emits fractional chapter URLs verbatim', () async {
    Uri? captured;
    final plugin = InMangaSourcePlugin(
      httpClient: MockClient((req) async {
        captured = req.url;
        return http.Response(
          _fix('reader_one_piece_ch1.html'),
          200,
          headers: {'content-type': 'text/html'},
        );
      }),
    );
    await plugin.getChapterPages(
      const SourceChapter(
        sourceMangaId: 'mid',
        sourceChapterId: 'cid',
        number: 12.5,
      ),
    );
    expect(captured!.path, '/ver/manga/_/12.5/cid');
  });

  test(
    'getChapterPages returns typed failure when PageList is missing',
    () async {
      final plugin = InMangaSourcePlugin(
        httpClient: MockClient(
          (_) async => http.Response(
            '<html><body>no select here</body></html>',
            200,
            headers: {'content-type': 'text/html'},
          ),
        ),
      );
      final res = await plugin.getChapterPages(
        const SourceChapter(
          sourceMangaId: 'mid',
          sourceChapterId: 'cid',
          number: 1,
        ),
      );
      expect(res.isFailure, isTrue);
      expect(
        (res as Failure<List<SourcePage>, KumoriyaError>).error.code,
        'inmanga.pages_empty',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // mirror rotation

  test('honors override mirror via mirrors constructor', () async {
    final hits = <String>[];
    final plugin = InMangaSourcePlugin(
      mirrors: MirrorList.single(Uri.parse('https://my-mirror.example/')),
      httpClient: MockClient((req) async {
        hits.add(req.url.host);
        return _ok(_fix('quick_search_one_piece.json'));
      }),
    );
    await plugin.search(const MangaSearchQuery(query: 'one piece'));
    expect(hits, contains('my-mirror.example'));
  });
}
