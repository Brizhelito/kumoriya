import 'package:flutter/widgets.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../../../../app/l10n.dart';

SeasonalCatalogRequest currentSeasonalCatalogRequest({
  DateTime? now,
  int page = 1,
  int perPage = 30,
  bool includeCarryovers = true,
}) {
  final value = now ?? DateTime.now();
  final season = switch (value.month) {
    12 || 1 || 2 => AnimeSeason.winter,
    3 || 4 || 5 => AnimeSeason.spring,
    6 || 7 || 8 => AnimeSeason.summer,
    _ => AnimeSeason.fall,
  };

  return SeasonalCatalogRequest(
    season: season,
    year: value.year,
    page: page,
    perPage: perPage,
    includeCarryovers: includeCarryovers,
  );
}

String displaySeasonLabel(BuildContext context, AnimeSeason season) {
  return switch (season) {
    AnimeSeason.winter => context.l10n.seasonWinter,
    AnimeSeason.spring => context.l10n.seasonSpring,
    AnimeSeason.summer => context.l10n.seasonSummer,
    AnimeSeason.fall => context.l10n.seasonFall,
  };
}

String displaySeasonYearLabel(
  BuildContext context,
  AnimeSeason season,
  int year,
) {
  return '${displaySeasonLabel(context, season)} $year';
}

SeasonalCatalogRequest shiftSeason(SeasonalCatalogRequest request, int offset) {
  var seasonIndex = AnimeSeason.values.indexOf(request.season) + offset;
  var year = request.year;

  while (seasonIndex < 0) {
    seasonIndex += AnimeSeason.values.length;
    year -= 1;
  }
  while (seasonIndex >= AnimeSeason.values.length) {
    seasonIndex -= AnimeSeason.values.length;
    year += 1;
  }

  return SeasonalCatalogRequest(
    season: AnimeSeason.values[seasonIndex],
    year: year,
    page: request.page,
    perPage: request.perPage,
    includeCarryovers: request.includeCarryovers,
  );
}
