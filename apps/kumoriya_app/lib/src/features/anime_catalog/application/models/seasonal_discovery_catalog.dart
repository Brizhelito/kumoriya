import 'package:kumoriya_domain/kumoriya_domain.dart';

final class SeasonalDiscoveryCatalog {
  const SeasonalDiscoveryCatalog({
    required this.request,
    required this.inSeason,
    required this.upcoming,
    required this.recommended,
  });

  final SeasonalCatalogRequest request;
  final List<Anime> inSeason;
  final List<Anime> upcoming;
  final List<Anime> recommended;
}
