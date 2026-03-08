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
  String get jkanimeAvailable => 'Available in JKAnime';

  @override
  String jkanimeRealEpisodesFound(int count) {
    return 'Real episodes found: $count';
  }

  @override
  String get jkanimeViewRealEpisodes => 'View real JKAnime episodes';

  @override
  String jkanimeEpisodesTitle(Object animeTitle) {
    return 'JKAnime episodes | $animeTitle';
  }

  @override
  String animeListEpisodesShort(int count) {
    return '$count eps';
  }
}
