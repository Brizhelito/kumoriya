import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/matching/anilist_jkanime_matcher.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/source_availability.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

void main() {
  const matcher = AnilistJkanimeMatcher();

  test('exact title + format yields high-confidence match', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(romaji: 'Naruto'),
        format: AnimeFormat.tv,
      ),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'naruto',
          title: 'Naruto',
          format: AnimeFormat.tv,
        ),
      ],
    );

    expect(decision.verdict, isTrue);
    expect(decision.confidence, MatchConfidence.high);
  });

  test('alias exact title can match conservatively', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(
          romaji: 'Kimetsu no Yaiba',
          synonyms: <String>['Demon Slayer'],
        ),
      ),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'kimetsu-no-yaiba',
          title: 'Demon Slayer',
          format: AnimeFormat.tv,
        ),
      ],
    );

    expect(decision.verdict, isTrue);
    expect(decision.confidence, MatchConfidence.high);
  });

  test('title-similar candidate is rejected when evidence is weak', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(title: const AnimeTitle(romaji: 'Naruto')),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'boruto-naruto-next-generations',
          title: 'Boruto Naruto Next Generations',
        ),
      ],
    );

    expect(decision.verdict, isFalse);
  });

  test('year conflict rejects near match', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(romaji: 'Ranma 1/2'),
        releaseYear: 2024,
      ),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'ranma-1-2',
          title: 'Ranma 1/2',
          releaseYear: 1989,
        ),
      ],
    );

    expect(decision.verdict, isFalse);
    expect(decision.rejectionSignals, contains('conflict-year'));
  });

  test('ambiguous tie returns no-match', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(romaji: 'Fate Stay Night'),
      ),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'fate-stay-night-tv',
          title: 'Fate Stay Night',
        ),
        SourceAnimeMatch(
          sourceId: 'fate-stay-night-unlimited-blade-works',
          title: 'Fate Stay Night',
        ),
      ],
    );

    expect(decision.verdict, isFalse);
    expect(decision.rejectionSignals, contains('ambiguous-top-candidates'));
  });

  test('empty candidates returns explicit no-match', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(title: const AnimeTitle(romaji: 'Frieren')),
      candidates: const <SourceAnimeMatch>[],
    );

    expect(decision.verdict, isFalse);
    expect(decision.reason, contains('No JKAnime candidates'));
  });
}

AnimeDetail _anilistDetail({
  required AnimeTitle title,
  AnimeFormat format = AnimeFormat.tv,
  int? releaseYear,
}) {
  return AnimeDetail(
    anime: Anime(
      anilistId: 1,
      title: title,
      format: format,
      releaseYear: releaseYear,
    ),
  );
}
