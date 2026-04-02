import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/matching/anilist_source_matcher.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/source_availability.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

const bool _skipMatchingTests = true;

void main() {
  group('anilist jkanime matcher', () {
    const matcher = AnilistSourceMatcher();

    test('exact alias with aligned metadata auto matches', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(
          romaji: 'Kimetsu no Yaiba',
          synonyms: <String>['Demon Slayer'],
        ),
        format: AnimeFormat.tv,
        releaseYear: 2019,
      ),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'demon-slayer',
          title: 'Demon Slayer',
          format: AnimeFormat.tv,
          releaseYear: 2019,
        ),
      ],
    );

    expect(decision.verdict, isTrue);
    expect(decision.confidence, MatchConfidence.high);
    expect(decision.acceptanceSignals, contains('matched_by_alias'));
    });

    test('title-similar sequel is rejected conservatively', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(romaji: 'Naruto'),
        format: AnimeFormat.tv,
        releaseYear: 2002,
      ),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'boruto',
          title: 'Boruto Naruto Next Generations',
          format: AnimeFormat.tv,
          releaseYear: 2017,
        ),
      ],
    );

    expect(decision.verdict, isFalse);
    expect(decision.rejectionSignals, contains('year_mismatch_penalty'));
    });

    test('ambiguous exact-title tie stays unavailable for manual review', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(romaji: 'Fate Stay Night'),
      ),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(sourceId: 'fate-1', title: 'Fate Stay Night'),
        SourceAnimeMatch(sourceId: 'fate-2', title: 'Fate Stay Night'),
      ],
    );

    expect(decision.verdict, isFalse);
    expect(decision.confidence, MatchConfidence.medium);
    expect(decision.rejectionSignals, contains('ambiguous_runner_up'));
    });

    test('grouped season source entry remains alignable', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(romaji: 'Oshi no Ko 2nd Season'),
        format: AnimeFormat.tv,
        releaseYear: 2024,
      ),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'oshi-no-ko',
          title: 'Oshi no Ko',
          format: AnimeFormat.tv,
          releaseYear: 2023,
        ),
      ],
    );

    expect(decision.acceptanceSignals, contains('grouped-season-title'));
    expect(decision.candidate?.sourceId, 'oshi-no-ko');
    });

    test('format conflict blocks auto matching', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(romaji: 'Suzume no Tojimari'),
        format: AnimeFormat.movie,
        releaseYear: 2022,
      ),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'suzume-tv',
          title: 'Suzume no Tojimari',
          format: AnimeFormat.tv,
          releaseYear: 2022,
        ),
      ],
    );

    expect(decision.verdict, isFalse);
    expect(decision.rejectionSignals, contains('type_mismatch_penalty'));
    });

    test('trusted translated alias exact match auto matches', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(
          romaji: 'Shin Seiki Evangelion',
          english: 'Neon Genesis Evangelion',
        ),
        format: AnimeFormat.tv,
        releaseYear: 1995,
      ),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'evangelion',
          title: 'Neon Genesis Evangelion',
          format: AnimeFormat.tv,
        ),
      ],
    );

    expect(decision.verdict, isTrue);
    expect(decision.confidence, MatchConfidence.high);
    expect(decision.acceptanceSignals, contains('matched_by_alias'));
    expect(
      decision.rejectionSignals,
      isNot(contains('weak_primary_title_penalty')),
    );
    });
  }, skip: _skipMatchingTests);
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
