/// MangaUpdates metadata gateway. Exposes a stable, defensive
/// surface over `https://api.mangaupdates.com/v1/`:
///
///  * series search and detail (relevance-ranked, with associated
///    titles for matching)
///  * group detail with the canonical `active` flag (the picker
///    uses this to label scanlator options)
///  * release timelines for picker enrichment ("last activity" and
///    "lifetime releases" per group on a given series)
library;

export 'src/client/mangaupdates_http_client.dart';
export 'src/contracts/mangaupdates_metadata_gateway.dart';
export 'src/errors/mangaupdates_error.dart';
export 'src/gateway/http_mangaupdates_metadata_gateway.dart';
export 'src/mappers/mangaupdates_group_mapper.dart';
export 'src/mappers/mangaupdates_release_mapper.dart';
export 'src/mappers/mangaupdates_series_mapper.dart';
export 'src/models/mangaupdates_group.dart';
export 'src/models/mangaupdates_release.dart';
export 'src/models/mangaupdates_series.dart';
