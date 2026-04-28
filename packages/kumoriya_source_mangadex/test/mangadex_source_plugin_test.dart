import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_mangadex/kumoriya_source_mangadex.dart';
import 'package:test/test.dart';

String _readFixture(String name) =>
    File('test/fixtures/$name').readAsStringSync();

const _jsonHeaders = <String, String>{
  'content-type': 'application/json; charset=utf-8',
};

http.Response _ok(String body) =>
    http.Response(body, 200, headers: _jsonHeaders);

void main() {
  final searchFixture = _readFixture('manga_search_chainsaw.json');
  final emptyFixture = _readFixture('manga_search_empty.json');
  final latestFixture = _readFixture('manga_latest.json');
  final detailFixture = _readFixture('manga_detail.json');
  final feedFixture = _readFixture('manga_feed.json');
  final atHomeFixture = _readFixture('at_home_chapter.json');

  // ---------------------------------------------------------------------------
  // manifest / capabilities

  test('manifest declares the source plugin and base URLs', () {
    final plugin = MangaDexSourcePlugin(
      httpClient: MockClient((_) async {
        return http.Response('', 200);
      }),
    );
    expect(plugin.manifest.id, 'kumoriya.source.mangadex');
    expect(plugin.manifest.type, PluginType.source);
    expect(plugin.manifest.baseUrls, contains('https://api.mangadex.org'));
  });

  test('mangaCapabilities advertises language/scanlator/latest support', () {
    final plugin = MangaDexSourcePlugin(
      httpClient: MockClient((_) async {
        return http.Response('', 200);
      }),
    );
    expect(plugin.mangaCapabilities.supportsLanguageFilter, isTrue);
    expect(plugin.mangaCapabilities.supportsScanlatorFilter, isTrue);
    expect(plugin.mangaCapabilities.supportsLatestFeed, isTrue);
    expect(plugin.mangaCapabilities.requiresPageHeaders, isFalse);
  });

  // ---------------------------------------------------------------------------
  // search

  test('search hits /manga with title and pagination', () async {
    Uri? capturedUri;
    final plugin = MangaDexSourcePlugin(
      httpClient: MockClient((req) async {
        capturedUri = req.url;
        return _ok(searchFixture);
      }),
    );

    final result = await plugin.search(
      const MangaSearchQuery(query: 'chainsaw man', page: 2, limit: 10),
    );

    expect(capturedUri!.path, '/manga');
    expect(capturedUri!.queryParameters['title'], 'chainsaw man');
    expect(capturedUri!.queryParameters['limit'], '10');
    expect(capturedUri!.queryParameters['offset'], '10');
    expect(
      capturedUri!.queryParametersAll['includes[]'],
      contains('cover_art'),
    );

    expect(result.isSuccess, isTrue);
    final matches =
        (result as Success<List<SourceMangaMatch>, KumoriyaError>).value;
    expect(matches, hasLength(2));

    final first = matches.first;
    expect(first.sourceId, 'a96676e5-8ae2-425e-b549-7f15dd34a6d8');
    expect(first.title, 'Chainsaw Man');
    expect(first.aliases, containsAll(<String>['Chainsaw Man', 'チェンソーマン']));
    expect(first.releaseYear, 2018);
    expect(first.format, MangaFormat.manga);
    expect(first.country, MangaCountryOfOrigin.jp);
    expect(first.thumbnailUrl, isNotNull);
    expect(
      first.thumbnailUrl.toString(),
      contains('chainsaw-cover.jpg.256.jpg'),
    );

    // attributes.links is parsed into externalIds keyed by short db code.
    expect(first.externalIds['al'], '105778');
    expect(first.externalIds['mal'], '116778');
    expect(first.externalIds['mu'], '171848');

    final second = matches[1];
    // No `title` and no cover; falls back to altTitle and null thumbnail.
    expect(second.title, 'Backup Title');
    expect(second.thumbnailUrl, isNull);
    expect(second.releaseYear, isNull);
    // No links block → externalIds stays empty.
    expect(second.externalIds, isEmpty);
  });

  test('search forwards languages as availableTranslatedLanguage[]', () async {
    Uri? capturedUri;
    final plugin = MangaDexSourcePlugin(
      httpClient: MockClient((req) async {
        capturedUri = req.url;
        return _ok(emptyFixture);
      }),
    );

    await plugin.search(
      const MangaSearchQuery(query: 'x', languages: ['es', 'en']),
    );

    expect(capturedUri!.queryParametersAll['availableTranslatedLanguage[]'], [
      'es',
      'en',
    ]);
  });

  test('search maps non-200 status to a transport failure', () async {
    final plugin = MangaDexSourcePlugin(
      httpClient: MockClient((_) async => http.Response('boom', 503)),
    );
    final result = await plugin.search(const MangaSearchQuery(query: 'x'));
    expect(result.isFailure, isTrue);
    final err =
        (result as Failure<List<SourceMangaMatch>, KumoriyaError>).error;
    expect(err.kind, KumoriyaErrorKind.transport);
    expect(err.code, 'mangadex.bad_status');
  });

  test('search maps 404 to a notFound failure', () async {
    final plugin = MangaDexSourcePlugin(
      httpClient: MockClient((_) async => http.Response('nope', 404)),
    );
    final result = await plugin.search(const MangaSearchQuery(query: 'x'));
    expect(result.isFailure, isTrue);
    expect(
      (result as Failure<List<SourceMangaMatch>, KumoriyaError>).error.kind,
      KumoriyaErrorKind.notFound,
    );
  });

  test('search maps malformed JSON to a mapping failure', () async {
    final plugin = MangaDexSourcePlugin(
      httpClient: MockClient((_) async => http.Response('not-json', 200)),
    );
    final result = await plugin.search(const MangaSearchQuery(query: 'x'));
    expect(result.isFailure, isTrue);
    expect(
      (result as Failure<List<SourceMangaMatch>, KumoriyaError>).error.kind,
      KumoriyaErrorKind.mapping,
    );
  });

  // ---------------------------------------------------------------------------
  // latest updates

  test('getLatestUpdates orders by latestUploadedChapter desc', () async {
    Uri? capturedUri;
    final plugin = MangaDexSourcePlugin(
      httpClient: MockClient((req) async {
        capturedUri = req.url;
        return _ok(latestFixture);
      }),
    );

    final result = await plugin.getLatestUpdates();
    expect(capturedUri!.queryParametersAll['order[latestUploadedChapter]'], [
      'desc',
    ]);
    expect(capturedUri!.queryParameters['hasAvailableChapters'], 'true');

    final list =
        (result as Success<List<SourceMangaMatch>, KumoriyaError>).value;
    expect(list.map((m) => m.sourceId), ['latest-1', 'latest-2']);
    expect(list.first.format, MangaFormat.manhwa); // ko + Long Strip tag
    expect(list.first.country, MangaCountryOfOrigin.kr);
  });

  // ---------------------------------------------------------------------------
  // detail

  test('getMangaDetail rejects empty id without hitting the network', () async {
    var called = false;
    final plugin = MangaDexSourcePlugin(
      httpClient: MockClient((_) async {
        called = true;
        return http.Response('', 200);
      }),
    );
    final result = await plugin.getMangaDetail('');
    expect(called, isFalse);
    expect(result.isFailure, isTrue);
  });

  test('getMangaDetail parses a single manga with relationships', () async {
    Uri? capturedUri;
    final plugin = MangaDexSourcePlugin(
      httpClient: MockClient((req) async {
        capturedUri = req.url;
        return _ok(detailFixture);
      }),
    );

    final result = await plugin.getMangaDetail(
      'a96676e5-8ae2-425e-b549-7f15dd34a6d8',
    );

    expect(capturedUri!.path, '/manga/a96676e5-8ae2-425e-b549-7f15dd34a6d8');
    expect(
      capturedUri!.queryParametersAll['includes[]'],
      containsAll(<String>['cover_art', 'author', 'artist']),
    );

    final detail = (result as Success<SourceMangaDetail, KumoriyaError>).value;
    expect(detail.title, 'Chainsaw Man');
    expect(detail.authors, ['Tatsuki Fujimoto']);
    expect(detail.artists, ['Tatsuki Fujimoto']);
    expect(detail.tags, containsAll(<String>['Action', 'Demons']));
    expect(detail.synopsis, startsWith('A young man'));
    expect(detail.status, MangaStatus.releasing);
    expect(detail.country, MangaCountryOfOrigin.jp);
    expect(detail.originalLanguage, 'ja');
    expect(detail.releaseYear, 2018);
    expect(
      detail.thumbnailUrl.toString(),
      'https://uploads.mangadex.org/covers/'
      'a96676e5-8ae2-425e-b549-7f15dd34a6d8/chainsaw-cover.jpg',
    );
  });

  test('getMangaDetail maps missing data block to notFound', () async {
    final plugin = MangaDexSourcePlugin(
      httpClient: MockClient(
        (_) async => http.Response('{"result":"ok"}', 200),
      ),
    );
    final result = await plugin.getMangaDetail('id-1');
    expect(result.isFailure, isTrue);
    final err = (result as Failure<SourceMangaDetail, KumoriyaError>).error;
    expect(err.kind, KumoriyaErrorKind.notFound);
    expect(err.code, 'mangadex.detail_not_found');
  });

  // ---------------------------------------------------------------------------
  // chapters

  test(
    'getChapters returns chapters sorted by source order, including 1.5',
    () async {
      Uri? capturedUri;
      final plugin = MangaDexSourcePlugin(
        httpClient: MockClient((req) async {
          capturedUri = req.url;
          return _ok(feedFixture);
        }),
      );

      final result = await plugin.getChapters(
        const MangaChapterQuery(sourceMangaId: 'm-1', languages: ['en']),
      );

      expect(capturedUri!.path, '/manga/m-1/feed');
      expect(capturedUri!.queryParametersAll['translatedLanguage[]'], ['en']);
      expect(
        capturedUri!.queryParametersAll['includes[]'],
        contains('scanlation_group'),
      );

      final chapters =
          (result as Success<List<SourceChapter>, KumoriyaError>).value;
      // Skips the null-numbered "Prologue" chapter.
      expect(chapters.map((c) => c.sourceChapterId), [
        'ch-1',
        'ch-1-5',
        'ch-2-es',
      ]);
      final firstHalf = chapters[1];
      expect(firstHalf.number, 1.5);
      expect(firstHalf.scanlator, 'Other Scans');
      expect(chapters.first.publishedAt?.year, 2020);
      expect(chapters.first.volume, 1);
    },
  );

  test('getChapters scanlator filter keeps only matching rows', () async {
    final plugin = MangaDexSourcePlugin(
      httpClient: MockClient((_) async => _ok(feedFixture)),
    );

    final result = await plugin.getChapters(
      const MangaChapterQuery(
        sourceMangaId: 'm-1',
        scanlators: ['Other Scans'],
      ),
    );
    final chapters =
        (result as Success<List<SourceChapter>, KumoriyaError>).value;
    expect(chapters.map((c) => c.sourceChapterId), ['ch-1-5']);
  });

  // ---------------------------------------------------------------------------
  // chapter pages

  test(
    'getChapterPages builds {baseUrl}/data/{hash}/{filename} URLs',
    () async {
      Uri? capturedUri;
      final plugin = MangaDexSourcePlugin(
        httpClient: MockClient((req) async {
          capturedUri = req.url;
          return _ok(atHomeFixture);
        }),
      );

      const chapter = SourceChapter(
        sourceMangaId: 'm-1',
        sourceChapterId: 'ch-1',
        number: 1,
      );

      final result = await plugin.getChapterPages(chapter);

      expect(capturedUri!.path, '/at-home/server/ch-1');

      final pages = (result as Success<List<SourcePage>, KumoriyaError>).value;
      expect(pages, hasLength(3));
      expect(pages[0].index, 0);
      expect(pages[1].index, 1);
      expect(
        pages[2].imageUrl.toString(),
        'https://uploads.mangadex.org/data/abcd1234hash/3-page-three.png',
      );
      // requiresPageHeaders is false → no per-page headers needed.
      expect(pages[0].headers, isEmpty);
    },
  );

  test('getChapterPages fails when MD@Home returns no pages', () async {
    final plugin = MangaDexSourcePlugin(
      httpClient: MockClient(
        (_) async => http.Response(
          '{"result":"ok","baseUrl":"https://x.example",'
          '"chapter":{"hash":"h","data":[]}}',
          200,
        ),
      ),
    );

    final result = await plugin.getChapterPages(
      const SourceChapter(
        sourceMangaId: 'm-1',
        sourceChapterId: 'ch-1',
        number: 1,
      ),
    );
    expect(result.isFailure, isTrue);
    expect(
      (result as Failure<List<SourcePage>, KumoriyaError>).error.code,
      'mangadex.pages_empty',
    );
  });

  test('result-level "error" envelope is mapped to a failure', () async {
    final plugin = MangaDexSourcePlugin(
      httpClient: MockClient(
        (_) async => http.Response('{"result":"error","errors":[]}', 200),
      ),
    );
    final result = await plugin.search(const MangaSearchQuery(query: 'x'));
    expect(result.isFailure, isTrue);
    final err =
        (result as Failure<List<SourceMangaMatch>, KumoriyaError>).error;
    expect(err.code, 'mangadex.api_error');
  });
}
