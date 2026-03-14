import 'package:kumoriya_domain/kumoriya_domain.dart';

import 'series_record.dart';

final class CanonicalSourceBinding {
  const CanonicalSourceBinding({
    required this.sourceId,
    required this.sourceSeriesId,
    required this.matchScore,
    this.requiresReview = false,
  });

  final String sourceId;
  final String sourceSeriesId;
  final double matchScore;
  final bool requiresReview;
}

final class CanonicalSeries {
  const CanonicalSeries({
    required this.canonicalId,
    required this.anilistId,
    required this.primaryTitle,
    this.aliases = const <String>[],
    this.format = AnimeFormat.unknown,
    this.releaseYear,
    this.episodeCount,
    this.seasonInfo = const SeriesSeasonInfo(),
    this.sourceBindings = const <CanonicalSourceBinding>[],
    this.relatedCanonicalIds = const <String>[],
  });

  final String canonicalId;
  final int anilistId;
  final String primaryTitle;
  final List<String> aliases;
  final AnimeFormat format;
  final int? releaseYear;
  final int? episodeCount;
  final SeriesSeasonInfo seasonInfo;
  final List<CanonicalSourceBinding> sourceBindings;
  final List<String> relatedCanonicalIds;

  List<String> get titles => <String>[primaryTitle, ...aliases];

  factory CanonicalSeries.fromAnimeDetail(AnimeDetail detail) {
    final anime = detail.anime;
    final aliases = <String>[
      if (anime.title.english != null) anime.title.english!,
      if (anime.title.native != null) anime.title.native!,
      ...anime.title.synonyms,
    ];
    return CanonicalSeries(
      canonicalId: 'anilist:${anime.anilistId}',
      anilistId: anime.anilistId,
      primaryTitle: anime.title.romaji,
      aliases: aliases,
      format: anime.format,
      releaseYear: anime.releaseYear,
      episodeCount: anime.totalEpisodes,
      seasonInfo: inferSeasonInfoFromTitles(<String>[
        anime.title.romaji,
        ...aliases,
      ]),
      relatedCanonicalIds: detail.relations
          .map((relation) => 'anilist:${relation.anime.anilistId}')
          .toList(growable: false),
    );
  }
}
