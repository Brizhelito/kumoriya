import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_matching/kumoriya_matching.dart';

void main() {
  final canonical = CanonicalSeries.fromAnimeDetail(
    AnimeDetail(
      anime: Anime(
        anilistId: 52991,
        title: const AnimeTitle(
          romaji: 'Sousou no Frieren',
          english: 'Frieren: Beyond Journey\'s End',
        ),
        format: AnimeFormat.tv,
        releaseYear: 2023,
        totalEpisodes: 28,
      ),
    ),
  );
  final engine = CanonicalMappingEngine(
    canonicals: <CanonicalSeries>[canonical],
  );
  final decision = engine.mapSourceRecord(
    const SourceSeriesRecord(
      recordId: 'jkanime:frieren',
      sourceId: 'jkanime',
      sourceSeriesId: 'frieren',
      primaryTitle: 'Frieren Beyond Journeys End',
      aliases: <String>['Sousou no Frieren'],
      format: AnimeFormat.tv,
      releaseYear: 2023,
      episodeCount: 28,
    ),
  );

  print('${decision.verdict} ${decision.bestScore}');
}
