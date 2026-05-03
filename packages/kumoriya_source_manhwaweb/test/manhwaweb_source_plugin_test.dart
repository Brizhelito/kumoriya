import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_manhwaweb/kumoriya_source_manhwaweb.dart';
import 'package:kumoriya_source_runtime/kumoriya_source_runtime.dart';
import 'package:test/test.dart';

String _fix(String name) => File('test/fixtures/$name').readAsStringSync();

http.Response _ok(String body) => http.Response(
  body,
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('manifest declares ManhwaWeb and the API host', () {
    final plugin = ManhwaWebSourcePlugin(
      httpClient: MockClient((_) async => _ok('{}')),
    );
    expect(plugin.manifest.id, 'kumoriya.source.manhwaweb');
    expect(plugin.manifest.type, PluginType.source);
    expect(
      plugin.manifest.baseUrls,
      containsAll(<String>[
        'https://manhwaweb.com',
        'https://manhwawebbackend-production.up.railway.app',
      ]),
    );
  });

  // ---------------------------------------------------------------------------
  // search

  test(
    'search hits /manhwa/library with full filter set and parses results',
    () async {
      Uri? captured;
      final plugin = ManhwaWebSourcePlugin(
        httpClient: MockClient((req) async {
          captured = req.url;
          return _ok(_fix('library_search_tower.json'));
        }),
      );
      final res = await plugin.search(
        const MangaSearchQuery(query: 'tower', page: 1),
      );
      expect(captured!.path, '/manhwa/library');
      expect(captured!.queryParameters['buscar'], 'tower');
      expect(
        captured!.queryParameters['page'],
        '0',
        reason: 'page is 0-indexed on ManhwaWeb',
      );
      // Required-but-empty filter params must still be present.
      expect(captured!.queryParameters['estado'], '');
      expect(captured!.queryParameters['tipo'], '');
      expect(captured!.queryParameters['order_item'], 'alfabetico');

      final matches =
          (res as Success<List<SourceMangaMatch>, KumoriyaError>).value;
      expect(matches, hasLength(3));
      expect(
        matches.first.title,
        'la torre del tutorial con el jugador avanzado',
      );
      expect(matches.first.format, MangaFormat.manhwa);
      expect(matches.first.thumbnailUrl, isNotNull);
    },
  );

  test(
    'search exposes name_esp as alias when it differs from the real name',
    () async {
      final plugin = ManhwaWebSourcePlugin(
        httpClient: MockClient((_) async {
          return _ok(
            '{"data":[{"_id":"solo_1","the_real_name":"Solo Leveling","name_esp":"Solo Leveling Español","_tipo":"manhwa"}]}',
          );
        }),
      );

      final res = await plugin.search(const MangaSearchQuery(query: 'solo'));
      final matches =
          (res as Success<List<SourceMangaMatch>, KumoriyaError>).value;
      expect(matches.single.title, 'Solo Leveling');
      expect(matches.single.aliases, contains('Solo Leveling Español'));
    },
  );

  test('search rejects empty query without HTTP', () async {
    final plugin = ManhwaWebSourcePlugin(
      httpClient: MockClient((_) async => fail('must not call network')),
    );
    final res = await plugin.search(const MangaSearchQuery(query: '   '));
    expect(
      (res as Success<List<SourceMangaMatch>, KumoriyaError>).value,
      isEmpty,
    );
  });

  test('search bubbles bad envelope as typed failure', () async {
    final plugin = ManhwaWebSourcePlugin(
      httpClient: MockClient((_) async => _ok('{"unexpected":1}')),
    );
    final res = await plugin.search(const MangaSearchQuery(query: 'x'));
    expect(res.isFailure, isTrue);
    expect(
      (res as Failure<List<SourceMangaMatch>, KumoriyaError>).error.code,
      'manhwaweb.search_bad_envelope',
    );
  });

  // ---------------------------------------------------------------------------
  // detail

  test('getMangaDetail parses synopsis, status, genres, format', () async {
    Uri? captured;
    final plugin = ManhwaWebSourcePlugin(
      httpClient: MockClient((req) async {
        captured = req.url;
        return _ok(_fix('manhwa_see_detail.json'));
      }),
    );
    final res = await plugin.getMangaDetail(
      'kikoetemasu-yo-yukimiya-san_1777504044211',
    );
    expect(
      captured!.path,
      '/manhwa/see/kikoetemasu-yo-yukimiya-san_1777504044211',
    );
    final detail = (res as Success<SourceMangaDetail, KumoriyaError>).value;
    expect(detail.title, 'Kikoetemasu Yo, Yukimiya San');
    expect(detail.synopsis, contains('Yukimiya'));
    expect(detail.status, MangaStatus.releasing);
    expect(detail.format, MangaFormat.manga);
    expect(detail.tags, containsAll(<String>['Romance', 'Comedia']));
    expect(detail.artists, contains('Kazoku Den'));
  });

  test('getMangaDetail rejects empty id without HTTP', () async {
    final plugin = ManhwaWebSourcePlugin(
      httpClient: MockClient((_) async => fail('must not call network')),
    );
    final res = await plugin.getMangaDetail('');
    expect(res.isFailure, isTrue);
    expect(
      (res as Failure<SourceMangaDetail, KumoriyaError>).error.code,
      'manhwaweb.detail_invalid_id',
    );
  });

  // ---------------------------------------------------------------------------
  // chapters

  test('getChapters reuses /manhwa/see and emits SourceChapter rows', () async {
    final plugin = ManhwaWebSourcePlugin(
      httpClient: MockClient((_) async => _ok(_fix('manhwa_see_detail.json'))),
    );
    final res = await plugin.getChapters(
      const MangaChapterQuery(
        sourceMangaId: 'kikoetemasu-yo-yukimiya-san_1777504044211',
        page: 1,
      ),
    );
    final chapters = (res as Success<List<SourceChapter>, KumoriyaError>).value;
    expect(chapters, hasLength(2));
    expect(chapters.map((c) => c.number).toList(), <double>[1, 2]);
    expect(chapters.first.scanlator, 'ManhwaWeb');
    expect(chapters.first.language, 'es');
    expect(
      chapters.first.sourceChapterId,
      'kikoetemasu-yo-yukimiya-san_1777504044211-1',
    );
    expect(chapters.first.publishedAt, isNotNull);
  });

  test('getChapters honors scanlator filter', () async {
    final plugin = ManhwaWebSourcePlugin(
      httpClient: MockClient((_) async => _ok(_fix('manhwa_see_detail.json'))),
    );
    final res = await plugin.getChapters(
      const MangaChapterQuery(
        sourceMangaId: 'kikoetemasu-yo-yukimiya-san_1777504044211',
        page: 1,
        scanlators: <String>['Olympus'],
      ),
    );
    expect((res as Success<List<SourceChapter>, KumoriyaError>).value, isEmpty);
  });

  // ---------------------------------------------------------------------------
  // pages

  test(
    'getChapterPages returns ordered SourcePage list from chapter.img',
    () async {
      Uri? captured;
      final plugin = ManhwaWebSourcePlugin(
        httpClient: MockClient((req) async {
          captured = req.url;
          return _ok(_fix('chapters_see_chapter1.json'));
        }),
      );
      final res = await plugin.getChapterPages(
        const SourceChapter(
          sourceMangaId: 'kikoetemasu-yo-yukimiya-san_1777504044211',
          sourceChapterId: 'kikoetemasu-yo-yukimiya-san_1777504044211-1',
          number: 1,
        ),
      );
      expect(
        captured!.path,
        '/chapters/see/kikoetemasu-yo-yukimiya-san_1777504044211-1',
      );
      final pages = (res as Success<List<SourcePage>, KumoriyaError>).value;
      expect(pages, hasLength(8));
      expect(pages.first.index, 0);
      expect(pages.first.imageUrl.host, 'imagizer.imageshack.com');
    },
  );

  test(
    'getChapterPages returns typed failure when chapter.img is missing',
    () async {
      final plugin = ManhwaWebSourcePlugin(
        httpClient: MockClient((_) async => _ok('{"chapter":{"chapter":1}}')),
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
        'manhwaweb.pages_empty',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // mirror override

  test('honors override mirror via mirrors constructor', () async {
    final hits = <String>[];
    final plugin = ManhwaWebSourcePlugin(
      mirrors: MirrorList.single(Uri.parse('https://my-mirror.example/')),
      httpClient: MockClient((req) async {
        hits.add(req.url.host);
        return _ok(_fix('library_search_tower.json'));
      }),
    );
    await plugin.search(const MangaSearchQuery(query: 'tower'));
    expect(hits, contains('my-mirror.example'));
  });

  // ---------------------------------------------------------------------------
  // latest

  test('getLatestUpdates is empty success without HTTP', () async {
    final plugin = ManhwaWebSourcePlugin(
      httpClient: MockClient((_) async => fail('must not call network')),
    );
    final res = await plugin.getLatestUpdates();
    expect(
      (res as Success<List<SourceMangaMatch>, KumoriyaError>).value,
      isEmpty,
    );
  });
}
