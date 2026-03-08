// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Kumoriya';

  @override
  String get retry => 'Retry';

  @override
  String get loadingGeneric => 'Loading...';

  @override
  String unexpectedStateError(Object error) {
    return 'Unexpected state error: $error';
  }

  @override
  String get errorTransportAnilist =>
      'Could not reach AniList. Check your connection and retry.';

  @override
  String get errorMappingAnilist =>
      'AniList returned data we could not parse safely.';

  @override
  String get errorNotFoundAnilist => 'Anime not found in AniList.';

  @override
  String get errorUnexpectedAnilist =>
      'Unexpected error while loading AniList data.';

  @override
  String get errorTransportSource =>
      'Could not reach the source. Try again in a moment.';

  @override
  String get errorMappingSource =>
      'The source response changed and could not be parsed safely.';

  @override
  String get errorNotFoundSource =>
      'No source data was found for this request.';

  @override
  String get errorUnexpectedSource =>
      'Unexpected source error while loading data.';

  @override
  String get errorJkanimeParse =>
      'JKAnime page structure changed and links could not be parsed safely.';

  @override
  String get errorJkanimeInconsistent =>
      'JKAnime returned inconsistent server data for this episode.';

  @override
  String get errorJkanimeEmpty =>
      'JKAnime has no data for this item right now.';

  @override
  String get homeLoadingCatalog => 'Loading home catalog...';

  @override
  String get homeEmptyCatalog =>
      'No trending anime found in AniList right now.';

  @override
  String get searchTitle => 'Search AniList';

  @override
  String get searchHintTitle => 'Search anime title';

  @override
  String get searchEmptyPrompt =>
      'Type a title and tap search to query AniList.';

  @override
  String get searchLoading => 'Searching AniList...';

  @override
  String searchNoResults(Object query) {
    return 'No AniList results found for \"$query\".';
  }

  @override
  String get animeDetailTitle => 'Anime detail';

  @override
  String get animeDetailLoading => 'Loading anime detail...';

  @override
  String get viewEpisodeList => 'View episode list';

  @override
  String get episodesWord => 'episodes';

  @override
  String get episodePreviewTitle => 'Episode preview';

  @override
  String get episodeStatusAired => 'Aired';

  @override
  String get episodeStatusUpcoming => 'Upcoming';

  @override
  String get relationsTitle => 'Relations';

  @override
  String episodeListTitle(Object animeTitle) {
    return '$animeTitle episodes';
  }

  @override
  String get episodeListLoading => 'Loading episodes...';

  @override
  String get episodeListEmpty =>
      'AniList has no episode metadata for this anime yet.';

  @override
  String get episodeMetadataAired => 'Aired metadata';

  @override
  String get episodeMetadataUpcoming => 'Upcoming metadata';

  @override
  String get jkanimeAvailabilityTitle => 'JKAnime availability';

  @override
  String get jkanimeChecking => 'Checking availability in JKAnime...';

  @override
  String jkanimeErrorConsulting(Object error) {
    return 'Error consulting JKAnime: $error';
  }

  @override
  String jkanimeNotAvailable(Object reason) {
    return 'Not available in JKAnime ($reason)';
  }

  @override
  String get jkanimeNotAvailableSimple => 'Not available in JKAnime';

  @override
  String get jkanimeNotAvailableNoMatch =>
      'No reliable JKAnime match was found.';

  @override
  String get jkanimeNotAvailableNoEpisodes =>
      'JKAnime match exists but no episodes were found.';

  @override
  String get jkanimeAvailable => 'Available in JKAnime';

  @override
  String jkanimeRealEpisodesFound(int count) {
    return 'Real episodes found: $count';
  }

  @override
  String get jkanimeViewRealEpisodes => 'View real JKAnime episodes';

  @override
  String get viewServerLinks => 'View servers';

  @override
  String get resolveServerLink => 'Resolve';

  @override
  String get resolverResolving => 'Resolving stream link...';

  @override
  String get resolverNoResolverFound =>
      'No resolver is available for this server link.';

  @override
  String get resolverMalformedLink =>
      'The source server link is malformed and cannot be resolved.';

  @override
  String get resolverParseFailure =>
      'Resolver could not parse a valid stream from provider payload.';

  @override
  String get resolverInconsistentPayload =>
      'Resolver received inconsistent provider payload.';

  @override
  String get resolverTransportFailure =>
      'Resolver request failed due to network/transport issue.';

  @override
  String get resolverUnexpectedFailure =>
      'Unexpected error while resolving stream link.';

  @override
  String get resolverNoStreams =>
      'Resolver did not return any stream candidate.';

  @override
  String resolverPageTitle(
    Object animeTitle,
    Object episodeNumber,
    Object serverName,
  ) {
    return '$animeTitle Ep.$episodeNumber | Resolve $serverName';
  }

  @override
  String resolverQuality(Object quality) {
    return 'Quality: $quality';
  }

  @override
  String get resolverQualityUnknown => 'unknown';

  @override
  String resolverMediaType(Object type) {
    return 'Type: $type';
  }

  @override
  String get resolverTypeHls => 'HLS';

  @override
  String get resolverTypeMp4 => 'MP4';

  @override
  String resolverMimeType(Object mimeType) {
    return 'MIME: $mimeType';
  }

  @override
  String resolverHeader(Object name, Object value) {
    return 'Header $name: $value';
  }

  @override
  String get jkanimeServerLinksLoading => 'Loading JKAnime server links...';

  @override
  String get jkanimeServerLinksEmpty =>
      'No servers found for this episode in JKAnime.';

  @override
  String jkanimeServerLinksTitle(Object animeTitle, Object episodeNumber) {
    return '$animeTitle | Episode $episodeNumber servers';
  }

  @override
  String jkanimeEpisodesTitle(Object animeTitle) {
    return 'JKAnime episodes | $animeTitle';
  }

  @override
  String animeListEpisodesShort(int count) {
    return '$count eps';
  }
}
