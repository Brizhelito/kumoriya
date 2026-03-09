import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/matching/anilist_source_matcher.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/source_availability.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

void main() {
  const matcher = AnilistSourceMatcher();

  test('exact title plus format yields high-confidence match', () {
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
    expect(decision.rejectionSignals, contains('title-mismatch'));
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
          sourceId: 'fate-stay-night-remake',
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
    expect(decision.reason, contains('No source candidates'));
  });

  test('format conflict is rejected even with exact title', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(romaji: 'Suzume no Tojimari'),
        format: AnimeFormat.movie,
      ),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'suzume-no-tojimari',
          title: 'Suzume no Tojimari',
          format: AnimeFormat.tv,
        ),
      ],
    );

    expect(decision.verdict, isFalse);
    expect(decision.rejectionSignals, contains('conflict-format'));
  });

  test('weak token overlap is rejected for safety', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(romaji: 'Boku no Hero Academia'),
      ),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'hero',
          title: 'Hero',
          format: AnimeFormat.tv,
        ),
      ],
    );

    expect(decision.verdict, isFalse);
    expect(decision.rejectionSignals, contains('title-mismatch'));
  });

  test('grouped season source entry is accepted conservatively', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(romaji: 'Oshi no Ko 2nd Season'),
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

    expect(decision.verdict, isTrue);
    expect(decision.confidence, MatchConfidence.high);
    expect(decision.acceptanceSignals, contains('grouped-season-title'));
  });

  test('exact season entry wins over grouped-season fallback candidate', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(romaji: 'Jigokuraku 2nd Season'),
        releaseYear: 2026,
      ),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'jigokuraku-2nd-season',
          title: 'Jigokuraku 2nd Season',
          format: AnimeFormat.tv,
          releaseYear: 2026,
        ),
        SourceAnimeMatch(
          sourceId: 'jigokuraku',
          title: 'Jigokuraku',
          format: AnimeFormat.tv,
          releaseYear: 2023,
        ),
      ],
    );

    expect(decision.verdict, isTrue);
    expect(decision.candidate?.sourceId, 'jigokuraku-2nd-season');
    expect(decision.acceptanceSignals, contains('exact-title'));
  });

  test('franchise umbrella entry can satisfy grouped franchise fallback', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(romaji: 'Mushoku Tensei: Megami ni Erabareshi'),
      ),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'mushoku-tensei-main',
          title: 'Mushoku Tensei: Isekai Ittara Honki Dasu',
          format: AnimeFormat.tv,
        ),
        SourceAnimeMatch(
          sourceId: 'mushoku-tensei-s2',
          title: 'Mushoku Tensei: Isekai Ittara Honki Dasu 2nd Season',
          format: AnimeFormat.tv,
        ),
      ],
    );

    expect(decision.verdict, isTrue);
    expect(decision.confidence, MatchConfidence.high);
    expect(decision.acceptanceSignals, contains('franchise-root-grouping'));
    expect(decision.candidate?.sourceId, 'mushoku-tensei-main');
  });

  test('subtitle alias alone stays rejected without umbrella evidence', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(
          romaji:
              'Mushoku Tensei: Isekai Ittara Honki Dasu - Megami ni Erabareshi',
        ),
      ),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'mushoku-tensei-megami-ni-erabareshi',
          title: 'Mushoku Tensei: Megami ni Erabareshi',
          format: AnimeFormat.tv,
        ),
      ],
    );

    expect(decision.verdict, isFalse);
    expect(decision.rejectionSignals, contains('title-mismatch'));
  });

  test('romanized no-de vs node title variant matches conservatively', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(
          romaji: 'Yuusha Party ni Kawaii Ko ga Ita no de, Kokuhaku Shitemita.',
        ),
      ),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'yuusha-party-ni-kawaii-ko-ga-ita-node-kokuhaku-shitemita',
          title: 'Yuusha Party ni Kawaii Ko ga Ita node, Kokuhaku shitemita.',
          format: AnimeFormat.tv,
        ),
      ],
    );

    expect(decision.verdict, isTrue);
    expect(decision.confidence, MatchConfidence.high);
    expect(decision.acceptanceSignals, contains('exact-title'));
  });

  test('collapsed honorific title still matches conservatively', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(
          romaji: 'Hime-sama, "Goumon" no Jikan desu 2nd Season',
        ),
        releaseYear: 2026,
      ),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'himesama-goumon-no-jikan-desu-2nd-season',
          title: 'Himesama "Goumon" no Jikan desu 2nd Season',
          format: AnimeFormat.tv,
          releaseYear: 2026,
        ),
      ],
    );

    expect(decision.verdict, isTrue);
    expect(decision.acceptanceSignals, contains('exact-title'));
  });

  test('candidate subtitle expansion can match a single-title work', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(romaji: 'Hikuidori'),
        releaseYear: 2026,
      ),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'hikuidori-ushuu-boro-tobigumi',
          title: 'Hikuidori: Ushuu Boro Tobi-gumi',
          format: AnimeFormat.tv,
          releaseYear: 2026,
        ),
      ],
    );

    expect(decision.verdict, isTrue);
    expect(
      decision.acceptanceSignals,
      contains('candidate-subtitle-expansion'),
    );
  });

  test(
    'shared subtitle root can match source subtitle elision conservatively',
    () {
      final decision = matcher.decideMatch(
        anilistDetail: _anilistDetail(
          title: const AnimeTitle(
            romaji: 'DARK MOON: Kuro no Tsuki - Tsuki no Saidan',
          ),
          releaseYear: 2026,
        ),
        candidates: const <SourceAnimeMatch>[
          SourceAnimeMatch(
            sourceId: 'dark-moon-tsuki-no-saidan',
            title: 'Dark Moon: Tsuki no Saidan',
            format: AnimeFormat.tv,
            releaseYear: 2026,
          ),
        ],
      );

      expect(decision.verdict, isTrue);
      expect(decision.acceptanceSignals, contains('shared-subtitle-root'));
    },
  );

  test(
    'generic suffix alias can match pokemon shinsaku anime conservatively',
    () {
      final decision = matcher.decideMatch(
        anilistDetail: _anilistDetail(
          title: const AnimeTitle(
            romaji: 'Pocket Monsters (2023)',
            english: 'Pokémon Horizons: The Series',
            synonyms: <String>['Pokémon (2023)'],
          ),
          releaseYear: 2023,
        ),
        candidates: const <SourceAnimeMatch>[
          SourceAnimeMatch(
            sourceId: 'pokemon-shinsaku-anime',
            title: 'Pokemon (Shinsaku Anime)',
            format: AnimeFormat.tv,
          ),
          SourceAnimeMatch(
            sourceId: 'pokemon',
            title: 'Pokemon',
            format: AnimeFormat.tv,
          ),
        ],
      );

      expect(decision.verdict, isTrue);
      expect(decision.candidate?.sourceId, 'pokemon-shinsaku-anime');
      expect(
        decision.acceptanceSignals,
        contains('canonical-prefix-generic-suffix'),
      );
    },
  );

  test('shared subtitle root covers romaji spacing variants like hell mode', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(
          romaji:
              'Hell Mode: Yarikomi Suki no Gamer wa Haisettei no Isekai de Musou Suru',
        ),
        releaseYear: 2026,
      ),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId:
              'hell-mode-yarikomizuki-no-gamer-wa-hai-settei-no-isekai-de-musou-suru',
          title:
              'Hell Mode: Yarikomizuki no Gamer wa Hai Settei no Isekai de Musou suru',
          format: AnimeFormat.tv,
          releaseYear: 2026,
        ),
      ],
    );

    expect(decision.verdict, isTrue);
    expect(decision.acceptanceSignals, contains('shared-subtitle-root'));
  });

  test('franchise root fallback does not fire for generic one-word roots', () {
    final decision = matcher.decideMatch(
      anilistDetail: _anilistDetail(
        title: const AnimeTitle(
          romaji: 'Pocket Monsters (2023)',
          english: 'Pokémon Horizons: The Series',
          synonyms: <String>['Pokémon (2023)'],
        ),
        releaseYear: 2023,
      ),
      candidates: const <SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'pokemon',
          title: 'Pokemon',
          format: AnimeFormat.tv,
        ),
        SourceAnimeMatch(
          sourceId: 'pokemon-best-wishes',
          title: 'Pokemon: Best Wishes!',
          format: AnimeFormat.tv,
        ),
      ],
    );

    expect(decision.verdict, isFalse);
    expect(
      decision.acceptanceSignals,
      isNot(contains('franchise-root-grouping')),
    );
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
