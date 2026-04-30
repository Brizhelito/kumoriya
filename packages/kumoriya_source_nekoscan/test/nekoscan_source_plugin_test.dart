import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_nekoscan/kumoriya_source_nekoscan.dart';
import 'package:kumoriya_source_runtime/kumoriya_source_runtime.dart';
import 'package:test/test.dart';

String _fix(String name) => File('test/fixtures/$name').readAsStringSync();

http.Response _okJson(String body) => http.Response(
  body,
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _okHtml(String body) => http.Response(
  body,
  200,
  headers: {'content-type': 'text/html; charset=utf-8'},
);

void main() {
  test('manifest declares Neko Scans and base URL', () {
    final plugin = NekoScanSourcePlugin(
      httpClient: MockClient((_) async => _okJson('[]')),
    );
    expect(plugin.manifest.id, 'kumoriya.source.nekoscan');
    expect(plugin.manifest.displayName, 'Neko Scans');
    expect(plugin.manifest.type, PluginType.source);
    expect(plugin.manifest.baseUrls, contains('https://nekoproject.org'));
    expect(plugin.mangaCapabilities.supportsLanguageFilter, isTrue);
    expect(plugin.mangaCapabilities.requiresPageHeaders, isFalse);
  });

  test(
    'search hits WP categories endpoint and parses category matches',
    () async {
      Uri? captured;
      final plugin = NekoScanSourcePlugin(
        httpClient: MockClient((req) async {
          captured = req.url;
          return _okJson(_fix('categories_search_hana.json'));
        }),
      );

      final res = await plugin.search(
        const MangaSearchQuery(query: 'hana', page: 1, limit: 5),
      );

      expect(captured!.path, '/wp-json/wp/v2/categories');
      expect(captured!.queryParameters['search'], 'hana');
      expect(captured!.queryParameters['per_page'], '5');

      final matches =
          (res as Success<List<SourceMangaMatch>, KumoriyaError>).value;
      expect(matches, isNotEmpty);
      expect(
        matches.any((m) => m.sourceId == 'hana-y-el-hombre-bestia'),
        isTrue,
      );
      expect(matches.any((m) => m.title == 'Hana y el hombre bestia'), isTrue);
    },
  );

  test('search returns empty success on empty query', () async {
    final plugin = NekoScanSourcePlugin(
      httpClient: MockClient((_) async => fail('must not call network')),
    );
    final res = await plugin.search(const MangaSearchQuery(query: '   '));
    expect(
      (res as Success<List<SourceMangaMatch>, KumoriyaError>).value,
      isEmpty,
    );
  });

  test('search returns transport failure on non-2xx', () async {
    final plugin = NekoScanSourcePlugin(
      httpClient: MockClient((_) async => http.Response('', 503)),
    );
    final res = await plugin.search(const MangaSearchQuery(query: 'hana'));
    expect(res, isA<Failure<List<SourceMangaMatch>, KumoriyaError>>());
    final err = (res as Failure<List<SourceMangaMatch>, KumoriyaError>).error;
    expect(err.code, 'nekoscan.search_transport_failed');
  });

  test('detail scrapes mangareader HTML metadata', () async {
    Uri? captured;
    final plugin = NekoScanSourcePlugin(
      httpClient: MockClient((req) async {
        captured = req.url;
        return _okHtml(_fix('manga_detail_hana.html'));
      }),
    );

    final res = await plugin.getMangaDetail('hana-y-el-hombre-bestia');

    expect(captured!.path, '/manga/hana-y-el-hombre-bestia/');
    final detail = (res as Success<SourceMangaDetail, KumoriyaError>).value;
    expect(detail.sourceId, 'hana-y-el-hombre-bestia');
    expect(detail.title, 'Hana y el hombre bestia');
    expect(detail.thumbnailUrl, isNotNull);
    expect(detail.status, MangaStatus.finished);
    expect(detail.format, MangaFormat.manga);
    expect(detail.country, MangaCountryOfOrigin.jp);
    expect(detail.authors, contains('YUZUKI Chihiro'));
    expect(detail.artists, contains('YUZUKI Chihiro'));
    expect(detail.tags, containsAll(<String>['Josei', 'Romance', 'Smut']));
    expect(detail.aliases, contains('Hana and the Beast Man'));
    expect(detail.synopsis, contains('Advertencia'));
  });

  test('chapters scrape eplister and return ascending order', () async {
    final plugin = NekoScanSourcePlugin(
      httpClient: MockClient(
        (_) async => _okHtml(_fix('manga_detail_hana.html')),
      ),
    );

    final res = await plugin.getChapters(
      const MangaChapterQuery(sourceMangaId: 'hana-y-el-hombre-bestia'),
    );

    final chapters = (res as Success<List<SourceChapter>, KumoriyaError>).value;
    expect(chapters, hasLength(23));
    expect(chapters.first.number, 1);
    expect(chapters.first.language, 'es');
    expect(chapters.first.scanlator, 'Neko Scans');
    expect(
      chapters.any(
        (c) => c.sourceChapterId == 'hana-y-el-hombre-bestia-capitulo-1',
      ),
      isTrue,
    );
    expect(
      chapters.any(
        (c) => c.sourceChapterId == 'hana-y-el-hombre-bestia-extra-1',
      ),
      isTrue,
    );
    expect(chapters.last.number, 17.5);
    expect(chapters.last.title, 'Capítulo 17.5');
    expect(chapters.last.publishedAt, DateTime.utc(2022, 12, 28));
  });

  test(
    'pages fetch post by slug and parse image URLs from content.rendered',
    () async {
      Uri? captured;
      final plugin = NekoScanSourcePlugin(
        httpClient: MockClient((req) async {
          captured = req.url;
          return _okJson(_fix('post_chapter_hana_extra4.json'));
        }),
      );

      final res = await plugin.getChapterPages(
        const SourceChapter(
          sourceMangaId: 'hana-y-el-hombre-bestia',
          sourceChapterId: 'hana-y-el-hombre-bestia-extra-4',
          number: 4,
        ),
      );

      expect(captured!.path, '/wp-json/wp/v2/posts');
      expect(
        captured!.queryParameters['slug'],
        'hana-y-el-hombre-bestia-extra-4',
      );

      final pages = (res as Success<List<SourcePage>, KumoriyaError>).value;
      expect(pages, hasLength(13));
      expect(pages.first.index, 0);
      expect(pages.first.imageUrl.host, 'blogger.googleusercontent.com');
      expect(pages.last.index, 12);
    },
  );

  test('mirror rotator falls through transport failure', () async {
    var calls = 0;
    final plugin = NekoScanSourcePlugin(
      mirrors: MirrorList(<Uri>[
        Uri.parse('https://dead.example/'),
        Uri.parse('https://nekoproject.org/'),
      ]),
      httpClient: MockClient((req) async {
        calls++;
        if (req.url.host == 'dead.example') return http.Response('', 503);
        return _okJson(_fix('categories_search_hana.json'));
      }),
    );

    final res = await plugin.search(const MangaSearchQuery(query: 'hana'));
    expect(res, isA<Success<List<SourceMangaMatch>, KumoriyaError>>());
    expect(calls, 2);
  });
}
