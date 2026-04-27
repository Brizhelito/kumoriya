import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Manga', () {
    test('sensible defaults', () {
      const manga = Manga(
        anilistId: 1,
        title: MangaTitle(romaji: 'Berserk'),
        format: MangaFormat.manga,
      );
      expect(manga.status, MangaStatus.unknown);
      expect(manga.genres, isEmpty);
      expect(manga.countryOfOrigin, isNull);
    });
  });

  group('MangaCountryOfOrigin', () {
    test('value equality and helpers', () {
      expect(MangaCountryOfOrigin.jp, const MangaCountryOfOrigin('JP'));
      expect(MangaCountryOfOrigin.jp.isJapan, isTrue);
      expect(MangaCountryOfOrigin.kr.isKorea, isTrue);
      expect(MangaCountryOfOrigin.cn.isChina, isTrue);
      expect(MangaCountryOfOrigin.tw.isChina, isTrue);
      expect(MangaCountryOfOrigin.jp.isKorea, isFalse);
    });

    test('hashCode is keyed by code', () {
      final a = const MangaCountryOfOrigin('JP');
      final b = const MangaCountryOfOrigin('JP');
      final c = const MangaCountryOfOrigin('KR');
      expect(a.hashCode, b.hashCode);
      expect(a.hashCode == c.hashCode, isFalse);
    });
  });

  group('MangaTag', () {
    test('equality keyed by name', () {
      const a = MangaTag(name: 'Action');
      const b = MangaTag(name: 'Action', description: 'Fights');
      const c = MangaTag(name: 'Romance');
      expect(a, b);
      expect(a == c, isFalse);
    });
  });

  group('MangaChapter', () {
    test('supports fractional chapter numbers', () {
      const chapter = MangaChapter(number: 12.5, title: 'Side Story');
      expect(chapter.number, 12.5);
      expect(chapter.volume, isNull);
      expect(chapter.scanlator, isNull);
    });
  });

  group('MangaDetail', () {
    test('delegates convenience accessors to manga', () {
      const manga = Manga(
        anilistId: 42,
        title: MangaTitle(romaji: 'Vinland Saga'),
        format: MangaFormat.manga,
        synopsis: 'Vikings.',
        genres: <String>['Adventure', 'Drama'],
        bannerImageUrl: 'https://example.test/banner.jpg',
      );
      const detail = MangaDetail(manga: manga);
      expect(detail.synopsis, 'Vikings.');
      expect(detail.genres, <String>['Adventure', 'Drama']);
      expect(detail.bannerImageUrl, 'https://example.test/banner.jpg');
      expect(detail.chapters, isEmpty);
      expect(detail.relations, isEmpty);
    });
  });

  group('MangaBrowseRequest', () {
    test('default sort is trending', () {
      const req = MangaBrowseRequest();
      expect(req.sort, MangaSortType.trending);
      expect(req.page, 1);
      expect(req.perPage, 20);
    });

    test('copyWith overrides only specified fields', () {
      const req = MangaBrowseRequest(search: 'orig', page: 1);
      final next = req.copyWith(page: 3);
      expect(next.search, 'orig');
      expect(next.page, 3);
      expect(next.perPage, 20);
    });

    test('value equality across structurally equivalent requests', () {
      const a = MangaBrowseRequest(
        search: 'q',
        genres: <String>['Action'],
        formats: <MangaFormat>[MangaFormat.manhwa],
        countriesOfOrigin: <MangaCountryOfOrigin>[MangaCountryOfOrigin.kr],
        sort: MangaSortType.popularity,
      );
      const b = MangaBrowseRequest(
        search: 'q',
        genres: <String>['Action'],
        formats: <MangaFormat>[MangaFormat.manhwa],
        countriesOfOrigin: <MangaCountryOfOrigin>[MangaCountryOfOrigin.kr],
        sort: MangaSortType.popularity,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('inequality on differing list contents', () {
      const a = MangaBrowseRequest(genres: <String>['Action']);
      const b = MangaBrowseRequest(genres: <String>['Romance']);
      expect(a == b, isFalse);
    });
  });

  group('MangaPage', () {
    test('headers default to empty', () {
      final page = MangaPage(index: 0, imageUrl: Uri.parse('https://x/y.jpg'));
      expect(page.headers, isEmpty);
    });
  });
}
