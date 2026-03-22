import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_matching/kumoriya_matching.dart';
import 'package:test/test.dart';

void main() {
  const fingerprintBuilder = SeriesFingerprintBuilder();

  test('auto matches exact alias with consistent metadata', () {
    final query = fingerprintBuilder.fromCanonical(
      const CanonicalSeries(
        canonicalId: 'anilist:20',
        anilistId: 20,
        primaryTitle: 'Kimetsu no Yaiba',
        aliases: <String>['Demon Slayer'],
        format: AnimeFormat.tv,
        releaseYear: 2019,
      ),
    );
    final candidate = fingerprintBuilder.fromSource(
      const SourceSeriesRecord(
        recordId: 'jkanime:demon-slayer',
        sourceId: 'jkanime',
        sourceSeriesId: 'demon-slayer',
        primaryTitle: 'Demon Slayer',
        format: AnimeFormat.tv,
        releaseYear: 2019,
      ),
    );
    final resolver = SeriesEntityResolver<SourceSeriesRecord>(
      candidateIndex: SeriesCandidateIndex<SourceSeriesRecord>(
        <SeriesFingerprint<SourceSeriesRecord>>[candidate],
      ),
    );

    final decision = resolver.resolve(query);

    expect(decision.verdict, SeriesDecisionVerdict.autoMatch);
    expect(decision.bestScore, greaterThanOrEqualTo(84));
    expect(
      decision.reasons.map((reason) => reason.code),
      contains(MatchReasonCode.matchedByAlias),
    );
  });

  test('rejects sequel false positive with weak lexical evidence', () {
    final query = fingerprintBuilder.fromCanonical(
      const CanonicalSeries(
        canonicalId: 'anilist:1',
        anilistId: 1,
        primaryTitle: 'Naruto',
        format: AnimeFormat.tv,
        releaseYear: 2002,
      ),
    );
    final candidate = fingerprintBuilder.fromSource(
      const SourceSeriesRecord(
        recordId: 'animeflv:boruto',
        sourceId: 'animeflv',
        sourceSeriesId: 'boruto-naruto-next-generations',
        primaryTitle: 'Boruto Naruto Next Generations',
        format: AnimeFormat.tv,
        releaseYear: 2017,
      ),
    );
    final resolver = SeriesEntityResolver<SourceSeriesRecord>(
      candidateIndex: SeriesCandidateIndex<SourceSeriesRecord>(
        <SeriesFingerprint<SourceSeriesRecord>>[candidate],
      ),
    );

    final decision = resolver.resolve(query);

    expect(decision.verdict, SeriesDecisionVerdict.reject);
    expect(
      decision.reasons.map((reason) => reason.code),
      contains(MatchReasonCode.yearMismatchPenalty),
    );
  });

  test('reviews ambiguous exact-title tie instead of auto-linking', () {
    final query = fingerprintBuilder.fromCanonical(
      const CanonicalSeries(
        canonicalId: 'anilist:356',
        anilistId: 356,
        primaryTitle: 'Fate Stay Night',
        format: AnimeFormat.tv,
      ),
    );
    final resolver = SeriesEntityResolver<SourceSeriesRecord>(
      candidateIndex: SeriesCandidateIndex<SourceSeriesRecord>(
        <SeriesFingerprint<SourceSeriesRecord>>[
          fingerprintBuilder.fromSource(
            const SourceSeriesRecord(
              recordId: 'src:fate-1',
              sourceId: 'src',
              sourceSeriesId: 'fate-1',
              primaryTitle: 'Fate Stay Night',
            ),
          ),
          fingerprintBuilder.fromSource(
            const SourceSeriesRecord(
              recordId: 'src:fate-2',
              sourceId: 'src',
              sourceSeriesId: 'fate-2',
              primaryTitle: 'Fate Stay Night',
            ),
          ),
        ],
      ),
    );

    final decision = resolver.resolve(query);

    expect(decision.verdict, SeriesDecisionVerdict.reviewNeeded);
    expect(
      decision.reasons.map((reason) => reason.code),
      contains(MatchReasonCode.ambiguousRunnerUp),
    );
  });

  test('handles grouped season catalog entries conservatively', () {
    final query = fingerprintBuilder.fromCanonical(
      const CanonicalSeries(
        canonicalId: 'anilist:200',
        anilistId: 200,
        primaryTitle: 'Oshi no Ko 2nd Season',
        format: AnimeFormat.tv,
        releaseYear: 2024,
        seasonInfo: SeriesSeasonInfo(seasonNumber: 2),
      ),
    );
    final candidate = fingerprintBuilder.fromSource(
      const SourceSeriesRecord(
        recordId: 'jkanime:oshi',
        sourceId: 'jkanime',
        sourceSeriesId: 'oshi-no-ko',
        primaryTitle: 'Oshi no Ko',
        format: AnimeFormat.tv,
        releaseYear: 2023,
      ),
    );
    final resolver = SeriesEntityResolver<SourceSeriesRecord>(
      candidateIndex: SeriesCandidateIndex<SourceSeriesRecord>(
        <SeriesFingerprint<SourceSeriesRecord>>[candidate],
      ),
    );

    final decision = resolver.resolve(query);

    expect(decision.verdict, isNot(SeriesDecisionVerdict.reject));
    expect(
      decision.reasons.map((reason) => reason.code),
      contains(MatchReasonCode.groupedSeasonTitle),
    );
  });

  test('downgrades exact alias hits without primary-title or year support', () {
    final query = fingerprintBuilder.fromCanonical(
      const CanonicalSeries(
        canonicalId: 'anilist:5000',
        anilistId: 5000,
        primaryTitle: 'Pocket Monsters (2023)',
        aliases: <String>['Pokemon (2023)', 'Pokemon (Shinsaku Anime)'],
        format: AnimeFormat.tv,
        releaseYear: 2023,
      ),
    );
    final candidate = fingerprintBuilder.fromSource(
      const SourceSeriesRecord(
        recordId: 'jkanime:pokemon-shinsaku-anime',
        sourceId: 'jkanime',
        sourceSeriesId: 'pokemon-shinsaku-anime',
        primaryTitle: 'Pokemon (Shinsaku Anime)',
        format: AnimeFormat.tv,
      ),
    );
    final resolver = SeriesEntityResolver<SourceSeriesRecord>(
      candidateIndex: SeriesCandidateIndex<SourceSeriesRecord>(
        <SeriesFingerprint<SourceSeriesRecord>>[candidate],
      ),
    );

    final decision = resolver.resolve(query);

    expect(decision.verdict, SeriesDecisionVerdict.reviewNeeded);
    expect(
      decision.reasons.map((reason) => reason.code),
      contains(MatchReasonCode.weakPrimaryTitlePenalty),
    );
  });

  test('keeps hell mode compound-word variant out of reject bucket', () {
    final query = fingerprintBuilder.fromCanonical(
      const CanonicalSeries(
        canonicalId: 'anilist:127549',
        anilistId: 127549,
        primaryTitle:
            'Hell Mode: Yarikomi Suki no Gamer wa Hai Settei no Isekai de Musou Suru',
        aliases: <String>[
          'Hell Mode',
          'Hell Mode: The Hardcore Gamer Dominates in Another World with Garbage Balancing',
        ],
        format: AnimeFormat.tv,
      ),
    );
    final candidate = fingerprintBuilder.fromSource(
      const SourceSeriesRecord(
        recordId:
            'jkanime:hell-mode-yarikomizuki-no-gamer-wa-hai-settei-no-isekai-de-musou-suru',
        sourceId: 'jkanime',
        sourceSeriesId:
            'hell-mode-yarikomizuki-no-gamer-wa-hai-settei-no-isekai-de-musou-suru',
        primaryTitle:
            'Hell Mode Yarikomizuki no Gamer wa Haisettei no Isekai de Musou Suru',
        format: AnimeFormat.tv,
      ),
    );
    final resolver = SeriesEntityResolver<SourceSeriesRecord>(
      candidateIndex: SeriesCandidateIndex<SourceSeriesRecord>(
        <SeriesFingerprint<SourceSeriesRecord>>[candidate],
      ),
    );

    final decision = resolver.resolve(query);

    expect(decision.verdict, isNot(SeriesDecisionVerdict.reject));
    expect(decision.bestScore, greaterThanOrEqualTo(68));
    expect(
      decision.reasons.map((reason) => reason.code),
      contains(MatchReasonCode.compactSimilarityBonus),
    );
  });
}
