import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_olympus/kumoriya_source_olympus.dart';
import 'package:kumoriya_source_runtime/kumoriya_source_runtime.dart';
import 'package:test/test.dart';

String _fix(String name) => File('test/fixtures/$name').readAsStringSync();

http.Response _ok(String body, {String? contentType}) => http.Response(
  body,
  200,
  headers: {'content-type': contentType ?? 'application/json; charset=utf-8'},
);

/// Wraps a Nuxt-data JSON payload in the minimal HTML envelope the
/// extractor expects.
String _wrapHtml(String nuxtJson) =>
    '<!doctype html><html><head>'
    '<script type="application/json" id="__NUXT_DATA__" data-ssr="true">'
    '$nuxtJson'
    '</script></head><body></body></html>';

void main() {
  // ---------------------------------------------------------------------------
  // manifest

  test('manifest declares Olympus and three mirror domains', () {
    final plugin = OlympusSourcePlugin(
      httpClient: MockClient((_) async => _ok('{}')),
    );
    expect(plugin.manifest.id, 'kumoriya.source.olympus');
    expect(plugin.manifest.type, PluginType.source);
    expect(plugin.manifest.baseUrls, hasLength(3));
    expect(
      plugin.manifest.baseUrls,
      containsAll(<String>[
        'https://olympusbiblioteca.com',
        'https://olympusscanlation.com',
        'https://tomanhua.com',
      ]),
    );
  });

  test('mangaCapabilities reflects Olympus reality', () {
    final plugin = OlympusSourcePlugin(
      httpClient: MockClient((_) async => _ok('{}')),
    );
    expect(plugin.mangaCapabilities.supportsLanguageFilter, isTrue);
    expect(plugin.mangaCapabilities.supportsScanlatorFilter, isTrue);
    expect(plugin.mangaCapabilities.supportsLatestFeed, isFalse);
    expect(plugin.mangaCapabilities.requiresPageHeaders, isFalse);
  });

  // ---------------------------------------------------------------------------
  // search

  test('search filters the catalog client-side and excludes novelas', () async {
    var hits = 0;
    final plugin = OlympusSourcePlugin(
      httpClient: MockClient((req) async {
        hits++;
        expect(req.url.path, '/api/series/list');
        // Same fixture but with a novela mixed in to prove filtering.
        const augmented = '''
{"data":[
  {"id":1197,"name":"El regreso de la espada perforadora","slug":"el-regreso-de-la-espada-perforadora","cover":"https://x/a.webp","type":"comic"},
  {"id":151,"name":"La vida de un mago","slug":"la-vida-de-un-mago","cover":null,"type":"comic"},
  {"id":2222,"name":"Una novela","slug":"una-novela","cover":null,"type":"novela"}
]}
''';
        return _ok(augmented);
      }),
    );

    final res = await plugin.search(
      const MangaSearchQuery(query: 'mago', limit: 10),
    );
    final matches =
        (res as Success<List<SourceMangaMatch>, KumoriyaError>).value;
    expect(matches, hasLength(1));
    expect(matches.first.title, 'La vida de un mago');
    expect(hits, 1);

    // Second call within TTL must NOT refetch.
    await plugin.search(const MangaSearchQuery(query: 'espada'));
    expect(hits, 1, reason: 'catalog should be served from cache');
  });

  test(
    'search with empty query returns the catalog head capped to limit',
    () async {
      final plugin = OlympusSourcePlugin(
        httpClient: MockClient((_) async => _ok(_fix('api_series_list.json'))),
      );
      final res = await plugin.search(
        const MangaSearchQuery(query: '   ', limit: 3),
      );
      final matches =
          (res as Success<List<SourceMangaMatch>, KumoriyaError>).value;
      expect(matches, hasLength(3));
    },
  );

  // ---------------------------------------------------------------------------
  // latest

  test('getLatestUpdates is an empty success per contract', () async {
    final plugin = OlympusSourcePlugin(
      httpClient: MockClient((_) async {
        fail('latest must NOT issue any HTTP call');
      }),
    );
    final res = await plugin.getLatestUpdates();
    expect(res.isSuccess, isTrue);
    expect(
      (res as Success<List<SourceMangaMatch>, KumoriyaError>).value,
      isEmpty,
    );
  });

  // ---------------------------------------------------------------------------
  // chapters

  test(
    'getChapters paginates against the dashboard API and parses rows',
    () async {
      Uri? captured;
      final plugin = OlympusSourcePlugin(
        httpClient: MockClient((req) async {
          captured = req.url;
          return _ok(_fix('api_chapters_page1.json'));
        }),
      );
      final res = await plugin.getChapters(
        const MangaChapterQuery(
          sourceMangaId: 'sangre-maldita-20260429-130413230',
          page: 1,
        ),
      );
      expect(captured!.host, 'dashboard.olympusbiblioteca.com');
      expect(captured!.path, contains('/api/series/sangre-maldita'));
      expect(captured!.queryParameters['page'], '1');
      expect(captured!.queryParameters['type'], 'comic');
      expect(captured!.queryParameters['direction'], 'desc');

      final chapters =
          (res as Success<List<SourceChapter>, KumoriyaError>).value;
      // Fixture has 7 rows; one is "74.1" fractional, one is "66.5".
      expect(chapters, hasLength(7));
      expect(chapters.first.sourceChapterId, '127748');
      expect(chapters.first.number, 83.0);
      expect(chapters.first.language, 'es');
      expect(chapters.first.scanlator, 'Olympus');
      expect(chapters.firstWhere((c) => c.number == 74.1), isNotNull);
      expect(chapters.firstWhere((c) => c.number == 66.5), isNotNull);
    },
  );

  test('getChapters honors scanlator filter when provided', () async {
    final plugin = OlympusSourcePlugin(
      httpClient: MockClient((_) async => _ok(_fix('api_chapters_page1.json'))),
    );
    final res = await plugin.getChapters(
      const MangaChapterQuery(
        sourceMangaId: 'sangre-maldita-20260429-130413230',
        page: 1,
        scanlators: <String>['Olympus'],
      ),
    );
    final chapters = (res as Success<List<SourceChapter>, KumoriyaError>).value;
    expect(chapters, isNotEmpty);
    expect(chapters.every((c) => c.scanlator == 'Olympus'), isTrue);
  });

  test('getChapters surfaces a typed failure on bad envelope', () async {
    final plugin = OlympusSourcePlugin(
      httpClient: MockClient((_) async => _ok('{"unexpected":true}')),
    );
    final res = await plugin.getChapters(
      const MangaChapterQuery(sourceMangaId: 'x', page: 1),
    );
    expect(res.isFailure, isTrue);
    expect(
      (res as Failure<List<SourceChapter>, KumoriyaError>).error.code,
      'olympus.chapters_bad_envelope',
    );
  });

  // ---------------------------------------------------------------------------
  // detail

  test(
    'getMangaDetail parses synopsis, status, genres from Nuxt data',
    () async {
      final plugin = OlympusSourcePlugin(
        httpClient: MockClient((req) async {
          // The web rotator hits `{web}/series/comic-{slug}`.
          expect(req.url.path, contains('/series/comic-sangre-maldita'));
          return http.Response(
            _wrapHtml(_fix('nuxt_data_detail.json')),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );

      final res = await plugin.getMangaDetail(
        'sangre-maldita-20260429-130413230',
      );
      final detail = (res as Success<SourceMangaDetail, KumoriyaError>).value;
      expect(detail.title, 'Sangre Maldita');
      expect(detail.sourceId, startsWith('sangre-maldita'));
      expect(detail.synopsis, contains('Solo Leveling'));
      expect(detail.status, MangaStatus.releasing);
      expect(detail.tags, hasLength(3));
      expect(
        detail.tags,
        containsAll(<String>['Acción', 'Apocalíptico', 'Sistema']),
      );
      expect(detail.artists, contains('Olympus'));
      expect(detail.format, MangaFormat.manhwa);
      expect(detail.country, MangaCountryOfOrigin.kr);
    },
  );

  test('getMangaDetail returns typed failure when Nuxt data missing', () async {
    final plugin = OlympusSourcePlugin(
      httpClient: MockClient(
        (_) async => http.Response(
          '<html><body>nope</body></html>',
          200,
          headers: {'content-type': 'text/html'},
        ),
      ),
    );
    final res = await plugin.getMangaDetail('whatever');
    expect(res.isFailure, isTrue);
    expect(
      (res as Failure<SourceMangaDetail, KumoriyaError>).error.code,
      'olympus.detail_no_nuxt_data',
    );
  });

  test('getMangaDetail rejects empty id without HTTP call', () async {
    final plugin = OlympusSourcePlugin(
      httpClient: MockClient((_) async => fail('must not hit network')),
    );
    final res = await plugin.getMangaDetail('');
    expect(res.isFailure, isTrue);
    expect(
      (res as Failure<SourceMangaDetail, KumoriyaError>).error.code,
      'olympus.detail_invalid_id',
    );
  });

  // ---------------------------------------------------------------------------
  // pages

  test(
    'getChapterPages extracts ordered pages from reader Nuxt data',
    () async {
      final plugin = OlympusSourcePlugin(
        httpClient: MockClient((req) async {
          expect(req.url.path, contains('/capitulo/127865/comic-some-slug'));
          return http.Response(
            _wrapHtml(_fix('nuxt_data_chapter.json')),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );

      final res = await plugin.getChapterPages(
        const SourceChapter(
          sourceMangaId: 'some-slug',
          sourceChapterId: '127865',
          number: 7,
        ),
      );
      final pages = (res as Success<List<SourcePage>, KumoriyaError>).value;
      expect(pages, hasLength(30));
      for (var i = 0; i < pages.length; i++) {
        expect(pages[i].index, i);
        expect(pages[i].imageUrl.scheme, 'https');
        expect(pages[i].imageUrl.host, 'dashboard.olympusbiblioteca.com');
      }
    },
  );

  // ---------------------------------------------------------------------------
  // mirror rotation

  test('search rotates web mirrors on transport failure', () async {
    final hits = <String>[];
    final plugin = OlympusSourcePlugin(
      httpClient: MockClient((req) async {
        hits.add(req.url.host);
        if (req.url.host == 'olympusbiblioteca.com') {
          throw const SocketException('refused');
        }
        return _ok('{"data":[]}');
      }),
    );
    final res = await plugin.search(const MangaSearchQuery(query: 'x'));
    expect(res.isSuccess, isTrue);
    expect(hits, <String>['olympusbiblioteca.com', 'olympusscanlation.com']);
  });

  test('search bubbles transport_failed when every mirror is down', () async {
    final plugin = OlympusSourcePlugin(
      httpClient: MockClient((req) async {
        throw const SocketException('all down');
      }),
    );
    final res = await plugin.search(const MangaSearchQuery(query: 'x'));
    expect(res.isFailure, isTrue);
    expect(
      (res as Failure<List<SourceMangaMatch>, KumoriyaError>).error.code,
      'olympus.catalog_transport_failed',
    );
  });

  test('honors override mirror via webMirrors / dashboardMirrors', () async {
    final hits = <String>[];
    final plugin = OlympusSourcePlugin(
      webMirrors: MirrorList.single(
        Uri.parse('https://my-private-mirror.example/'),
      ),
      dashboardMirrors: MirrorList.single(
        Uri.parse('https://my-private-dashboard.example/'),
      ),
      httpClient: MockClient((req) async {
        hits.add(req.url.host);
        if (req.url.path.endsWith('/api/series/list')) {
          return _ok('{"data":[]}');
        }
        return _ok(_fix('api_chapters_page1.json'));
      }),
    );

    await plugin.search(const MangaSearchQuery(query: 'x'));
    await plugin.getChapters(
      const MangaChapterQuery(sourceMangaId: 's', page: 1),
    );

    expect(hits, contains('my-private-mirror.example'));
    expect(hits, contains('my-private-dashboard.example'));
  });
}
