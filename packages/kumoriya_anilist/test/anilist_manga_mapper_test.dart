import 'package:kumoriya_anilist/src/mappers/anilist_manga_mapper.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:test/test.dart';

void main() {
  group('AnilistMangaMapper.mapManga', () {
    test('maps AniList manga payload into domain manga', () {
      final media = <String, dynamic>{
        'id': 30002,
        'title': <String, dynamic>{
          'romaji': 'Berserk',
          'english': 'Berserk',
          'native': 'ベルセルク',
        },
        'synonyms': <String>['BSK'],
        'format': 'MANGA',
        'chapters': null,
        'volumes': 41,
        'averageScore': 94,
        'popularity': 200000,
        'status': 'RELEASING',
        'description': 'Guts.',
        'genres': <String>['Action', 'Fantasy'],
        'bannerImage': 'https://img.test/banner.jpg',
        'countryOfOrigin': 'JP',
        'startDate': <String, dynamic>{'year': 1989},
        'coverImage': <String, dynamic>{'large': 'https://img.test/cover.jpg'},
      };

      final manga = AnilistMangaMapper.mapManga(media);

      expect(manga.anilistId, 30002);
      expect(manga.title.romaji, 'Berserk');
      expect(manga.title.synonyms, <String>['BSK']);
      expect(manga.format, MangaFormat.manga);
      expect(manga.status, MangaStatus.releasing);
      expect(manga.totalChapters, isNull);
      expect(manga.totalVolumes, 41);
      expect(manga.releaseYear, 1989);
      expect(manga.countryOfOrigin, MangaCountryOfOrigin.jp);
      expect(manga.synopsis, 'Guts.');
      expect(manga.genres, <String>['Action', 'Fantasy']);
      expect(manga.coverImageUrl, 'https://img.test/cover.jpg');
    });

    test('maps MANHWA / MANHUA / ONE_SHOT formats', () {
      MangaFormat formatOf(String raw) {
        return AnilistMangaMapper.mapManga(<String, dynamic>{
          'id': 1,
          'title': <String, dynamic>{'romaji': 'X'},
          'format': raw,
        }).format;
      }

      expect(formatOf('MANHWA'), MangaFormat.manhwa);
      expect(formatOf('MANHUA'), MangaFormat.manhua);
      expect(formatOf('ONE_SHOT'), MangaFormat.oneShot);
      expect(formatOf('DOUJINSHI'), MangaFormat.doujinshi);
    });

    test('NOVEL format maps to unknown to keep light novels out of scope', () {
      final manga = AnilistMangaMapper.mapManga(<String, dynamic>{
        'id': 1,
        'title': <String, dynamic>{'romaji': 'X'},
        'format': 'NOVEL',
      });
      expect(manga.format, MangaFormat.unknown);
    });

    test('cleans synopsis HTML tags', () {
      final manga = AnilistMangaMapper.mapManga(<String, dynamic>{
        'id': 1,
        'title': <String, dynamic>{'romaji': 'X'},
        'description': 'A<br>B<br/><i>C</i><b>D</b>',
      });
      expect(manga.synopsis, 'A\nB\nCD');
    });

    test('throws FormatException on missing id', () {
      expect(
        () => AnilistMangaMapper.mapManga(<String, dynamic>{
          'title': <String, dynamic>{'romaji': 'X'},
        }),
        throwsFormatException,
      );
    });

    test('throws FormatException when all title fields are empty', () {
      expect(
        () => AnilistMangaMapper.mapManga(<String, dynamic>{
          'id': 1,
          'title': <String, dynamic>{'romaji': '', 'english': '', 'native': ''},
        }),
        throwsFormatException,
      );
    });

    test('falls back from romaji to english to native', () {
      final manga = AnilistMangaMapper.mapManga(<String, dynamic>{
        'id': 1,
        'title': <String, dynamic>{
          'romaji': '',
          'english': 'English Title',
          'native': '原題',
        },
      });
      expect(manga.title.romaji, 'English Title');
      expect(manga.title.english, 'English Title');
      expect(manga.title.native, '原題');
    });

    test('country of origin is null when missing or empty', () {
      MangaCountryOfOrigin? countryOf(dynamic raw) {
        return AnilistMangaMapper.mapManga(<String, dynamic>{
          'id': 1,
          'title': <String, dynamic>{'romaji': 'X'},
          'countryOfOrigin': raw,
        }).countryOfOrigin;
      }

      expect(countryOf(null), isNull);
      expect(countryOf(''), isNull);
      expect(countryOf('  '), isNull);
      expect(countryOf('KR'), MangaCountryOfOrigin.kr);
    });
  });

  group('AnilistMangaMapper.mapDetail', () {
    test('builds detail with manga relations only (anime nodes filtered)', () {
      final media = <String, dynamic>{
        'id': 100,
        'title': <String, dynamic>{'romaji': 'Series'},
        'format': 'MANGA',
        'relations': <String, dynamic>{
          'edges': <Map<String, dynamic>>[
            <String, dynamic>{'relationType': 'SEQUEL'},
            <String, dynamic>{'relationType': 'ADAPTATION'},
            <String, dynamic>{'relationType': 'SIDE_STORY'},
          ],
          'nodes': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 101,
              'type': 'MANGA',
              'title': <String, dynamic>{'romaji': 'Series 2'},
              'format': 'MANGA',
            },
            <String, dynamic>{
              'id': 102,
              'type': 'ANIME',
              'title': <String, dynamic>{'romaji': 'Series Anime'},
              'format': 'TV',
            },
            <String, dynamic>{
              'id': 103,
              'type': 'MANGA',
              'title': <String, dynamic>{'romaji': 'Series Side'},
              'format': 'MANGA',
            },
          ],
        },
      };

      final detail = AnilistMangaMapper.mapDetail(media);

      expect(detail.relations, hasLength(2));
      expect(detail.relations[0].type, MangaRelationType.sequel);
      expect(detail.relations[0].manga.anilistId, 101);
      expect(detail.relations[1].type, MangaRelationType.sideStory);
      expect(detail.relations[1].manga.anilistId, 103);
    });
  });
}
