import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_runtime/kumoriya_source_runtime.dart';
import 'package:kumoriya_source_visormanga/kumoriya_source_visormanga.dart';
import 'package:test/test.dart';

String _fix(String name) => File('test/fixtures/$name').readAsStringSync();

http.Response _okHtml(String body) => http.Response(
  body,
  200,
  headers: {'content-type': 'text/html; charset=utf-8'},
);

void main() {
  test('manifest declares Visor TMO Manga and base URL', () {
    final plugin = VisorMangaSourcePlugin(
      httpClient: MockClient((_) async => _okHtml('')),
    );
    expect(plugin.manifest.id, 'kumoriya.source.visormanga');
    expect(plugin.manifest.displayName, 'Visor TMO Manga');
    expect(plugin.manifest.type, PluginType.source);
    expect(plugin.manifest.baseUrls, contains('https://visormanga.com'));
    expect(plugin.mangaCapabilities.requiresPageHeaders, isFalse);
  });

  test('search hits /biblioteca and parses card anchors', () async {
    Uri? captured;
    final plugin = VisorMangaSourcePlugin(
      httpClient: MockClient((req) async {
        captured = req.url;
        return _okHtml(_fix('search_tower.html'));
      }),
    );

    final res = await plugin.search(
      const MangaSearchQuery(query: 'tower', page: 1, limit: 10),
    );

    expect(captured!.path, '/biblioteca');
    expect(captured!.queryParameters['search'], 'tower');
    expect(captured!.queryParameters['page'], '1');

    final matches =
        (res as Success<List<SourceMangaMatch>, KumoriyaError>).value;
    expect(matches, isNotEmpty);
    expect(matches.any((m) => m.sourceId == 'wizardly-tower'), isTrue);
    expect(matches.any((m) => m.sourceId == 'clock-tower'), isTrue);
    final wizardly = matches.firstWhere((m) => m.sourceId == 'wizardly-tower');
    expect(wizardly.title.toLowerCase(), contains('wizardly tower'));
    expect(wizardly.thumbnailUrl?.host, 'thumbs.visormanga.com');
    expect(wizardly.format, MangaFormat.manhwa);
    expect(wizardly.country, MangaCountryOfOrigin.kr);
  });

  test('search returns empty success on empty query', () async {
    final plugin = VisorMangaSourcePlugin(
      httpClient: MockClient((_) async => fail('must not call network')),
    );
    final res = await plugin.search(const MangaSearchQuery(query: '   '));
    expect(
      (res as Success<List<SourceMangaMatch>, KumoriyaError>).value,
      isEmpty,
    );
  });

  test('search bubbles transport failure on non-2xx', () async {
    final plugin = VisorMangaSourcePlugin(
      httpClient: MockClient((_) async => http.Response('', 503)),
    );
    final res = await plugin.search(const MangaSearchQuery(query: 'tower'));
    expect(res, isA<Failure<List<SourceMangaMatch>, KumoriyaError>>());
    expect(
      (res as Failure<List<SourceMangaMatch>, KumoriyaError>).error.code,
      'visormanga.search_transport_failed',
    );
  });

  test('detail scrapes title, year, cover, type, synopsis, genres', () async {
    Uri? captured;
    final plugin = VisorMangaSourcePlugin(
      httpClient: MockClient((req) async {
        captured = req.url;
        return _okHtml(_fix('manga_detail_dios.html'));
      }),
    );

    final res = await plugin.getMangaDetail('dios-te-bendiga');

    expect(captured!.path, '/manga/dios-te-bendiga');
    final detail = (res as Success<SourceMangaDetail, KumoriyaError>).value;
    expect(detail.sourceId, 'dios-te-bendiga');
    expect(detail.title, contains('Dios te bendiga'));
    expect(detail.releaseYear, 2024);
    expect(detail.thumbnailUrl?.host, 'thumbs.visormanga.com');
    expect(detail.format, MangaFormat.manhwa);
    expect(detail.country, MangaCountryOfOrigin.kr);
    expect(detail.originalLanguage, 'ko');
    expect(detail.tags, containsAll(<String>['Romance', 'Harem']));
    expect(detail.synopsis, contains('Joseon'));
  });

  test('chapters scrape li-manga-chapter and return ascending', () async {
    final plugin = VisorMangaSourcePlugin(
      httpClient: MockClient(
        (_) async => _okHtml(_fix('manga_detail_dios.html')),
      ),
    );

    final res = await plugin.getChapters(
      const MangaChapterQuery(sourceMangaId: 'dios-te-bendiga'),
    );

    final chapters = (res as Success<List<SourceChapter>, KumoriyaError>).value;
    expect(chapters, isNotEmpty);
    expect(chapters.first.number <= chapters.last.number, isTrue);
    expect(chapters.last.number, 43);
    final last = chapters.last;
    expect(last.sourceChapterId, '43.00');
    expect(last.language, 'es');
    expect(last.scanlator, 'Visor TMO Manga');
  });

  test('pages scrape image-alls and return ordered SourcePages', () async {
    Uri? captured;
    final plugin = VisorMangaSourcePlugin(
      httpClient: MockClient((req) async {
        captured = req.url;
        return _okHtml(_fix('reader_dios_43.html'));
      }),
    );

    final res = await plugin.getChapterPages(
      const SourceChapter(
        sourceMangaId: 'dios-te-bendiga',
        sourceChapterId: '43.00',
        number: 43,
      ),
    );

    expect(captured!.path, '/leer/dios-te-bendiga-43.00');
    final pages = (res as Success<List<SourcePage>, KumoriyaError>).value;
    expect(pages, isNotEmpty);
    expect(pages.first.index, 0);
    expect(pages.first.imageUrl.host, 'v2.imgvtmo.com');
    for (var i = 0; i < pages.length; i++) {
      expect(pages[i].index, i, reason: 'pages must be index-contiguous');
    }
  });

  test('pages report unavailable when site advertises empty chapter', () async {
    final plugin = VisorMangaSourcePlugin(
      httpClient: MockClient(
        (_) async => _okHtml(
          '<html><body>'
          '<div id="image-alls">'
          '<div class="alert alert-danger" role="alert">'
          '<span class="no-images-disponibles">Por el momento no hay imagenes disponibles</span>'
          '</div>'
          '</div>'
          '</body></html>',
        ),
      ),
    );

    final res = await plugin.getChapterPages(
      const SourceChapter(
        sourceMangaId: 'dios-te-bendiga',
        sourceChapterId: '1.00',
        number: 1,
      ),
    );

    expect(res, isA<Failure<List<SourcePage>, KumoriyaError>>());
    final err = (res as Failure<List<SourcePage>, KumoriyaError>).error;
    expect(err.code, 'visormanga.pages_unavailable');
  });

  test('mirror rotator falls through on transport failure', () async {
    var calls = 0;
    final plugin = VisorMangaSourcePlugin(
      mirrors: MirrorList(<Uri>[
        Uri.parse('https://dead.example/'),
        Uri.parse('https://visormanga.com/'),
      ]),
      httpClient: MockClient((req) async {
        calls++;
        if (req.url.host == 'dead.example') return http.Response('', 503);
        return _okHtml(_fix('search_tower.html'));
      }),
    );

    final res = await plugin.search(const MangaSearchQuery(query: 'tower'));
    expect(res, isA<Success<List<SourceMangaMatch>, KumoriyaError>>());
    expect(calls, 2);
  });
}
