/// MangaBaka metadata gateway. Exposes a stable, defensive surface
/// over `https://api.mangabaka.dev/v1/` for the matching pipeline:
/// title corpus expansion plus cross-tracker IDs (AniList, MAL, Kitsu,
/// MangaUpdates, AnimePlanet, Anime News Network, Shikimori).
library;

export 'src/client/mangabaka_http_client.dart';
export 'src/contracts/mangabaka_metadata_gateway.dart';
export 'src/errors/mangabaka_error.dart';
export 'src/gateway/http_mangabaka_metadata_gateway.dart';
export 'src/mappers/mangabaka_series_mapper.dart';
export 'src/models/mangabaka_series.dart';
