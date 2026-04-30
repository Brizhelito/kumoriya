import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_lectortmo/kumoriya_source_lectortmo.dart';
import 'package:kumoriya_source_runtime/kumoriya_source_runtime.dart';
import 'package:test/test.dart';

String _fix(String name) => File('test/fixtures/$name').readAsStringSync();

http.Response _ok(String body) => http.Response(
  body,
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('manifest declares LectorTMOo and known mirrors', () {
    final plugin = LectorTmoSourcePlugin(
      httpClient: MockClient((_) async => _ok('[]')),
    );
    expect(plugin.manifest.id, 'kumoriya.source.lectortmo');
    expect(plugin.manifest.type, PluginType.source);
    expect(
      plugin.manifest.baseUrls,
      containsAll(<String>['https://lectortmoo.com', 'https://lectortmo.vip']),
    );
  });

  // ---------------------------------------------------------------------------
  // search

  test(
    'search hits /wp-json/wp/v2/manga with embed and parses results',
    () async {
      Uri? captured;
      final plugin = LectorTmoSourcePlugin(
        httpClient: MockClient((req) async {
          captured = req.url;
          return _ok(_fix('manga_search_tower.json'));
        }),
      );
      final res = await plugin.search(
        const MangaSearchQuery(query: 'tower', page: 1, limit: 5),
      );
      expect(captured!.path, '/wp-json/wp/v2/manga');
      expect(captured!.queryParameters['search'], 'tower');
      expect(captured!.queryParameters['page'], '1');
      expect(captured!.queryParameters['_embed'], 'wp:featuredmedia');

      final matches =
          (res as Success<List<SourceMangaMatch>, KumoriyaError>).value;
      expect(matches, hasLength(3));
      expect(matches.first.sourceId, '526733');
      // Title with HTML entity is decoded.
      expect(matches.first.title, contains('Urek\u2019s Ascent'));
      expect(matches.first.format, MangaFormat.manhwa);
      expect(matches.first.thumbnailUrl, isNotNull);
    },
  );

  test('search returns empty success on empty query', () async {
    final plugin = LectorTmoSourcePlugin(
      httpClient: MockClient((_) async => fail('must not call network')),
    );
    final res = await plugin.search(const MangaSearchQuery(query: '   '));
    expect(
      (res as Success<List<SourceMangaMatch>, KumoriyaError>).value,
      isEmpty,
    );
  });

  test('search bubbles transport failure for non-2xx responses', () async {
    final plugin = LectorTmoSourcePlugin(
      httpClient: MockClient((_) async => http.Response('', 503)),
    );
    final res = await plugin.search(const MangaSearchQuery(query: 'x'));
    expect(res.isFailure, isTrue);
    expect(
      (res as Failure<List<SourceMangaMatch>, KumoriyaError>).error.code,
      'lectortmo.search_transport_failed',
    );
  });

  // ---------------------------------------------------------------------------
  // detail

  test(
    'getMangaDetail parses title, synopsis, status, format, cover',
    () async {
      Uri? captured;
      final plugin = LectorTmoSourcePlugin(
        httpClient: MockClient((req) async {
          captured = req.url;
          return _ok(_fix('manga_detail_unordinary.json'));
        }),
      );
      final res = await plugin.getMangaDetail('138289');
      expect(captured!.path, '/wp-json/wp/v2/manga/138289');
      final detail = (res as Success<SourceMangaDetail, KumoriyaError>).value;
      expect(detail.title, 'Unordinary');
      expect(detail.synopsis, contains('uru-chan'));
      expect(detail.status, MangaStatus.releasing);
      expect(detail.format, MangaFormat.manhwa);
      expect(detail.thumbnailUrl, isNotNull);
      expect(detail.authors, contains('uru-chan'));
    },
  );

  test('getMangaDetail rejects non-numeric id without HTTP', () async {
    final plugin = LectorTmoSourcePlugin(
      httpClient: MockClient((_) async => fail('must not call network')),
    );
    final res = await plugin.getMangaDetail('not-a-number');
    expect(res.isFailure, isTrue);
    expect(
      (res as Failure<SourceMangaDetail, KumoriyaError>).error.code,
      'lectortmo.detail_invalid_id',
    );
  });

  // ---------------------------------------------------------------------------
  // chapters

  test(
    'getChapters hits eastmanga endpoint and sorts ascending by number',
    () async {
      Uri? captured;
      final plugin = LectorTmoSourcePlugin(
        httpClient: MockClient((req) async {
          captured = req.url;
          return _ok(_fix('eastmanga_chapters_unordinary.json'));
        }),
      );
      final res = await plugin.getChapters(
        const MangaChapterQuery(sourceMangaId: '138289', page: 1),
      );
      expect(captured!.path, '/wp-json/eastmanga/v1/chapters');
      expect(captured!.queryParameters['manga_id'], '138289');

      final chapters =
          (res as Success<List<SourceChapter>, KumoriyaError>).value;
      // Fixture has 6 entries: 1, 2, 3, "" (-> 34 from title), 368, 341.
      // Expect sorted ascending by parsed number.
      expect(chapters.map((c) => c.number).toList(), <double>[
        1,
        2,
        3,
        34,
        341,
        368,
      ]);
      expect(chapters.first.sourceChapterId, '138297');
      expect(chapters.first.scanlator, 'LectorTMOo');
      expect(chapters.first.language, 'es');
    },
  );

  test('getChapters falls back to title when chapter field is empty', () async {
    final plugin = LectorTmoSourcePlugin(
      httpClient: MockClient(
        (_) async => _ok(_fix('eastmanga_chapters_unordinary.json')),
      ),
    );
    final res = await plugin.getChapters(
      const MangaChapterQuery(sourceMangaId: '138289', page: 1),
    );
    final chapters = (res as Success<List<SourceChapter>, KumoriyaError>).value;
    final ch34 = chapters.singleWhere((c) => c.number == 34);
    expect(ch34.sourceChapterId, '138557');
  });

  test('getChapters honors scanlator filter', () async {
    final plugin = LectorTmoSourcePlugin(
      httpClient: MockClient(
        (_) async => _ok(_fix('eastmanga_chapters_unordinary.json')),
      ),
    );
    final res = await plugin.getChapters(
      const MangaChapterQuery(
        sourceMangaId: '138289',
        page: 1,
        scanlators: <String>['Olympus'],
      ),
    );
    expect((res as Success<List<SourceChapter>, KumoriyaError>).value, isEmpty);
  });

  // ---------------------------------------------------------------------------
  // pages

  test(
    'getChapterPages parses <img src> from content.rendered in order',
    () async {
      Uri? captured;
      final plugin = LectorTmoSourcePlugin(
        httpClient: MockClient((req) async {
          captured = req.url;
          return _ok(_fix('post_chapter_unordinary_ch1.json'));
        }),
      );
      final res = await plugin.getChapterPages(
        const SourceChapter(
          sourceMangaId: '138289',
          sourceChapterId: '138297',
          number: 1,
        ),
      );
      expect(captured!.path, '/wp-json/wp/v2/posts/138297');
      final pages = (res as Success<List<SourcePage>, KumoriyaError>).value;
      expect(pages, hasLength(5));
      expect(pages.first.index, 0);
      expect(pages.first.imageUrl.host, 'imagizer.imageshack.com');
      expect(pages.last.index, 4);
    },
  );

  test(
    'getChapterPages returns typed failure when content has no images',
    () async {
      final plugin = LectorTmoSourcePlugin(
        httpClient: MockClient(
          (_) async => _ok('{"id":1,"content":{"rendered":"<p>nothing</p>"}}'),
        ),
      );
      final res = await plugin.getChapterPages(
        const SourceChapter(
          sourceMangaId: '1',
          sourceChapterId: '2',
          number: 1,
        ),
      );
      expect(res.isFailure, isTrue);
      expect(
        (res as Failure<List<SourcePage>, KumoriyaError>).error.code,
        'lectortmo.pages_empty',
      );
    },
  );

  test('getChapterPages rejects non-numeric chapter id', () async {
    final plugin = LectorTmoSourcePlugin(
      httpClient: MockClient((_) async => fail('must not call network')),
    );
    final res = await plugin.getChapterPages(
      const SourceChapter(
        sourceMangaId: '1',
        sourceChapterId: 'not-numeric',
        number: 1,
      ),
    );
    expect(res.isFailure, isTrue);
    expect(
      (res as Failure<List<SourcePage>, KumoriyaError>).error.code,
      'lectortmo.pages_invalid_id',
    );
  });

  // ---------------------------------------------------------------------------
  // mirror override (for lectortmo.vip)

  test('honors override mirror via mirrors constructor', () async {
    final hits = <String>[];
    final plugin = LectorTmoSourcePlugin(
      mirrors: MirrorList.single(Uri.parse('https://lectortmo.vip/')),
      httpClient: MockClient((req) async {
        hits.add(req.url.host);
        return _ok(_fix('manga_search_tower.json'));
      }),
    );
    await plugin.search(const MangaSearchQuery(query: 'tower'));
    expect(hits, contains('lectortmo.vip'));
  });

  // ---------------------------------------------------------------------------
  // latest

  test('getLatestUpdates is empty success without HTTP', () async {
    final plugin = LectorTmoSourcePlugin(
      httpClient: MockClient((_) async => fail('must not call network')),
    );
    final res = await plugin.getLatestUpdates();
    expect(
      (res as Success<List<SourceMangaMatch>, KumoriyaError>).value,
      isEmpty,
    );
  });
}
