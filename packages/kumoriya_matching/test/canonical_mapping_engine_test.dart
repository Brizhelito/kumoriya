import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_matching/kumoriya_matching.dart';
import 'package:test/test.dart';

const bool _skipMatchingTests = true;

void main() {
  group('canonical mapping engine', () {
    test('maps source record to the correct canonical series', () {
    final engine = CanonicalMappingEngine(
      canonicals: <CanonicalSeries>[
        const CanonicalSeries(
          canonicalId: 'anilist:52991',
          anilistId: 52991,
          primaryTitle: 'Sousou no Frieren',
          aliases: <String>['Frieren: Beyond Journey\'s End'],
          format: AnimeFormat.tv,
          releaseYear: 2023,
          episodeCount: 28,
        ),
        const CanonicalSeries(
          canonicalId: 'anilist:16498',
          anilistId: 16498,
          primaryTitle: 'Shingeki no Kyojin',
          aliases: <String>['Attack on Titan'],
          format: AnimeFormat.tv,
          releaseYear: 2013,
        ),
      ],
    );

    final decision = engine.mapSourceRecord(
      const SourceSeriesRecord(
        recordId: 'animeflv:frieren',
        sourceId: 'animeflv',
        sourceSeriesId: 'frieren',
        primaryTitle: 'Frieren Beyond Journeys End',
        aliases: <String>['Sousou no Frieren'],
        format: AnimeFormat.tv,
        releaseYear: 2023,
        episodeCount: 28,
      ),
    );

    expect(decision.verdict, SeriesDecisionVerdict.autoMatch);
    expect(decision.bestCandidate?.canonicalId, 'anilist:52991');
    });

    test('returns impacted canonical ids for incremental recalculation', () {
    final engine = CanonicalMappingEngine(
      canonicals: <CanonicalSeries>[
        const CanonicalSeries(
          canonicalId: 'anilist:20',
          anilistId: 20,
          primaryTitle: 'Kimetsu no Yaiba',
          aliases: <String>['Demon Slayer'],
          format: AnimeFormat.tv,
          releaseYear: 2019,
        ),
      ],
    );

    final plan = engine.planSourceUpsert(
      const SourceSeriesRecord(
        recordId: 'animeflv:demon-slayer',
        sourceId: 'animeflv',
        sourceSeriesId: 'demon-slayer',
        primaryTitle: 'Demon Slayer',
        format: AnimeFormat.tv,
        releaseYear: 2019,
      ),
    );

    expect(plan.impactedCanonicalIds, contains('anilist:20'));
    expect(plan.fullReindexRecommended, isFalse);
    expect(plan.blockingKeys, isNotEmpty);
    });
  }, skip: _skipMatchingTests);
}
