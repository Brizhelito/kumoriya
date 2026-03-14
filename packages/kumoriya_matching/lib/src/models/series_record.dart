import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

final class SeriesSeasonInfo {
  const SeriesSeasonInfo({
    this.seasonNumber,
    this.partNumber,
    this.courNumber,
    this.isFinalSeason = false,
    this.label,
  });

  final int? seasonNumber;
  final int? partNumber;
  final int? courNumber;
  final bool isFinalSeason;
  final String? label;

  bool get hasSignal =>
      seasonNumber != null ||
      partNumber != null ||
      courNumber != null ||
      isFinalSeason;
}

final class SourceSeriesRecord {
  const SourceSeriesRecord({
    required this.recordId,
    required this.sourceId,
    required this.sourceSeriesId,
    required this.primaryTitle,
    this.aliases = const <String>[],
    this.format = AnimeFormat.unknown,
    this.releaseYear,
    this.episodeCount,
    this.seasonInfo = const SeriesSeasonInfo(),
  });

  final String recordId;
  final String sourceId;
  final String sourceSeriesId;
  final String primaryTitle;
  final List<String> aliases;
  final AnimeFormat format;
  final int? releaseYear;
  final int? episodeCount;
  final SeriesSeasonInfo seasonInfo;

  List<String> get titles => <String>[primaryTitle, ...aliases];

  factory SourceSeriesRecord.fromSourceAnimeMatch({
    required String sourceId,
    required SourceAnimeMatch match,
  }) {
    final inferredSeasonInfo = inferSeasonInfoFromTitles(<String>[
      match.title,
      ...match.aliases,
    ]);
    return SourceSeriesRecord(
      recordId: '$sourceId:${match.sourceId}',
      sourceId: sourceId,
      sourceSeriesId: match.sourceId,
      primaryTitle: match.title,
      aliases: match.aliases,
      format: match.format,
      releaseYear: match.releaseYear,
      episodeCount: match.totalEpisodes,
      seasonInfo: SeriesSeasonInfo(
        seasonNumber: match.seasonNumber ?? inferredSeasonInfo.seasonNumber,
        partNumber: match.partNumber ?? inferredSeasonInfo.partNumber,
        courNumber: inferredSeasonInfo.courNumber,
        isFinalSeason: inferredSeasonInfo.isFinalSeason,
      ),
    );
  }
}

SeriesSeasonInfo inferSeasonInfoFromTitles(Iterable<String> titles) {
  for (final title in titles) {
    final lower = title.toLowerCase();
    final seasonMatch = RegExp(
      r'\b(?:season\s+(\d+)|(\d+)(?:st|nd|rd|th)\s+season)\b',
    ).firstMatch(lower);
    final partMatch = RegExp(r'\bpart\s+(\d+)\b').firstMatch(lower);
    final courMatch = RegExp(r'\bcour\s+(\d+)\b').firstMatch(lower);
    final seasonNumber = int.tryParse(
      seasonMatch?.group(1) ?? seasonMatch?.group(2) ?? '',
    );
    final partNumber = int.tryParse(partMatch?.group(1) ?? '');
    final courNumber = int.tryParse(courMatch?.group(1) ?? '');
    final isFinalSeason = lower.contains('final season');

    if (seasonNumber != null ||
        partNumber != null ||
        courNumber != null ||
        isFinalSeason) {
      return SeriesSeasonInfo(
        seasonNumber: seasonNumber,
        partNumber: partNumber,
        courNumber: courNumber,
        isFinalSeason: isFinalSeason,
      );
    }
  }
  return const SeriesSeasonInfo();
}
