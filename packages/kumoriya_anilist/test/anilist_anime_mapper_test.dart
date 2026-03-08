import 'package:kumoriya_anilist/src/mappers/anilist_anime_mapper.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:test/test.dart';

void main() {
  test('mapAnime maps AniList media into domain anime', () {
    final media = <String, dynamic>{
      'id': 100,
      'title': <String, dynamic>{
        'romaji': 'Shingeki no Kyojin',
        'english': 'Attack on Titan',
        'native': '進撃の巨人',
      },
      'format': 'TV',
      'seasonYear': 2013,
      'episodes': 25,
      'averageScore': 86,
      'status': 'FINISHED',
      'coverImage': <String, dynamic>{'large': 'https://img.test/cover.jpg'},
    };

    final anime = AnilistAnimeMapper.mapAnime(media);

    expect(anime.anilistId, 100);
    expect(anime.title.romaji, 'Shingeki no Kyojin');
    expect(anime.format, AnimeFormat.tv);
    expect(anime.status, AnimeStatus.finished);
    expect(anime.totalEpisodes, 25);
  });

  test('mapDetail builds episode list and relations', () {
    final media = <String, dynamic>{
      'id': 200,
      'title': <String, dynamic>{
        'romaji': 'Frieren',
        'english': 'Frieren: Beyond Journey\'s End',
        'native': '葬送のフリーレン',
      },
      'format': 'TV',
      'seasonYear': 2023,
      'episodes': 3,
      'averageScore': 90,
      'status': 'RELEASING',
      'description': 'Story<br>line',
      'genres': <String>['Fantasy'],
      'bannerImage': 'https://img.test/banner.jpg',
      'coverImage': <String, dynamic>{'large': 'https://img.test/cover.jpg'},
      'nextAiringEpisode': <String, dynamic>{'episode': 3, 'airingAt': 1},
      'airingSchedule': <String, dynamic>{
        'nodes': <Map<String, dynamic>>[
          <String, dynamic>{'episode': 3, 'airingAt': 1700000000},
        ],
      },
      'relations': <String, dynamic>{
        'edges': <Map<String, dynamic>>[
          <String, dynamic>{'relationType': 'SEQUEL'},
        ],
        'nodes': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 201,
            'title': <String, dynamic>{'romaji': 'Frieren 2'},
            'format': 'TV',
            'seasonYear': 2026,
            'episodes': 12,
            'status': 'NOT_YET_RELEASED',
            'coverImage': <String, dynamic>{'large': 'https://img.test/2.jpg'},
          },
        ],
      },
    };

    final detail = AnilistAnimeMapper.mapDetail(media);

    expect(detail.episodes, hasLength(3));
    expect(detail.episodes[0].isAired, isTrue);
    expect(detail.episodes[2].isAired, isFalse);
    expect(detail.relations, hasLength(1));
    expect(detail.relations.first.type, AnimeRelationType.sequel);
  });
}
