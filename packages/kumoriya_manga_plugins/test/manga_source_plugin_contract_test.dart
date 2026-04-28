import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:test/test.dart';

void main() {
  group('MangaSourceCapabilities', () {
    test('defaults are conservative (everything off)', () {
      const caps = MangaSourceCapabilities();
      expect(caps.supportsLanguageFilter, isFalse);
      expect(caps.supportsScanlatorFilter, isFalse);
      expect(caps.supportsLatestFeed, isFalse);
      expect(caps.requiresPageHeaders, isFalse);
    });

    test('value equality on all flags', () {
      const a = MangaSourceCapabilities(
        supportsLanguageFilter: true,
        supportsLatestFeed: true,
      );
      const b = MangaSourceCapabilities(
        supportsLanguageFilter: true,
        supportsLatestFeed: true,
      );
      const c = MangaSourceCapabilities(supportsLanguageFilter: true);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('Query value objects', () {
    test('MangaSearchQuery rejects non-positive page/limit', () {
      expect(
        () => MangaSearchQuery(query: 'x', page: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => MangaSearchQuery(query: 'x', limit: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('MangaChapterQuery defaults are sensible', () {
      const q = MangaChapterQuery(sourceMangaId: 'abc');
      expect(q.page, 1);
      expect(q.limit, 100);
      expect(q.languages, isEmpty);
      expect(q.scanlators, isEmpty);
    });
  });

  group('SourcePage', () {
    test('rejects negative index', () {
      expect(
        () => SourcePage(index: -1, imageUrl: Uri.parse('https://x/y.jpg')),
        throwsA(isA<AssertionError>()),
      );
    });

    test('headers default to empty', () {
      final page = SourcePage(index: 0, imageUrl: Uri.parse('https://x/y.jpg'));
      expect(page.headers, isEmpty);
    });
  });

  group('SourceChapter', () {
    test('preserves fractional numbers (12.5)', () {
      const ch = SourceChapter(
        sourceMangaId: 'm1',
        sourceChapterId: 'c12_5',
        number: 12.5,
      );
      expect(ch.number, 12.5);
    });
  });

  group('Contract surface', () {
    test('a fake implementation satisfies the interface', () async {
      final fake = _FakeMangaSource();
      expect(fake.manifest.type, PluginType.source);
      final search = await fake.search(const MangaSearchQuery(query: 'x'));
      expect(search.isSuccess, isTrue);
      final detail = await fake.getMangaDetail('m1');
      expect(detail.isSuccess, isTrue);
      final chapters = await fake.getChapters(
        const MangaChapterQuery(sourceMangaId: 'm1'),
      );
      expect(chapters.isSuccess, isTrue);
      final pages = await fake.getChapterPages(_chapter);
      expect(pages.isSuccess, isTrue);
      final latest = await fake.getLatestUpdates();
      expect(latest.isSuccess, isTrue);
    });
  });
}

const _chapter = SourceChapter(
  sourceMangaId: 'm1',
  sourceChapterId: 'c1',
  number: 1,
);

final class _FakeMangaSource implements MangaSourcePlugin {
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'fake',
    displayName: 'Fake',
    type: PluginType.source,
    capabilities: <PluginCapability>{},
  );

  @override
  MangaSourceCapabilities get mangaCapabilities =>
      const MangaSourceCapabilities();

  @override
  Future<Result<List<SourceMangaMatch>, KumoriyaError>> search(
    MangaSearchQuery query,
  ) async => const Success(<SourceMangaMatch>[]);

  @override
  Future<Result<List<SourceMangaMatch>, KumoriyaError>> getLatestUpdates({
    int page = 1,
    int limit = 20,
  }) async => const Success(<SourceMangaMatch>[]);

  @override
  Future<Result<SourceMangaDetail, KumoriyaError>> getMangaDetail(
    String sourceMangaId,
  ) async => Success(SourceMangaDetail(sourceId: sourceMangaId, title: 'Fake'));

  @override
  Future<Result<List<SourceChapter>, KumoriyaError>> getChapters(
    MangaChapterQuery query,
  ) async => const Success(<SourceChapter>[]);

  @override
  Future<Result<List<SourcePage>, KumoriyaError>> getChapterPages(
    SourceChapter chapter,
  ) async => Success(<SourcePage>[
    SourcePage(index: 0, imageUrl: Uri.parse('https://x/0.jpg')),
  ]);
}

// Reference parameter just to keep MangaFormat import meaningful in
// case tests are extended; format mapping itself is exercised in the
// kumoriya_manga_domain tests.
// ignore: unused_element
const _exampleFormat = MangaFormat.manhwa;
