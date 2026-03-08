import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Kumoriya'**
  String get appTitle;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loadingGeneric.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loadingGeneric;

  /// No description provided for @unexpectedStateError.
  ///
  /// In en, this message translates to:
  /// **'Unexpected state error: {error}'**
  String unexpectedStateError(Object error);

  /// No description provided for @errorTransportAnilist.
  ///
  /// In en, this message translates to:
  /// **'Could not reach AniList. Check your connection and retry.'**
  String get errorTransportAnilist;

  /// No description provided for @errorMappingAnilist.
  ///
  /// In en, this message translates to:
  /// **'AniList returned data we could not parse safely.'**
  String get errorMappingAnilist;

  /// No description provided for @errorNotFoundAnilist.
  ///
  /// In en, this message translates to:
  /// **'Anime not found in AniList.'**
  String get errorNotFoundAnilist;

  /// No description provided for @errorUnexpectedAnilist.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error while loading AniList data.'**
  String get errorUnexpectedAnilist;

  /// No description provided for @errorTransportSource.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the source. Try again in a moment.'**
  String get errorTransportSource;

  /// No description provided for @errorMappingSource.
  ///
  /// In en, this message translates to:
  /// **'The source response changed and could not be parsed safely.'**
  String get errorMappingSource;

  /// No description provided for @errorNotFoundSource.
  ///
  /// In en, this message translates to:
  /// **'No source data was found for this request.'**
  String get errorNotFoundSource;

  /// No description provided for @errorUnexpectedSource.
  ///
  /// In en, this message translates to:
  /// **'Unexpected source error while loading data.'**
  String get errorUnexpectedSource;

  /// No description provided for @errorJkanimeParse.
  ///
  /// In en, this message translates to:
  /// **'JKAnime page structure changed and links could not be parsed safely.'**
  String get errorJkanimeParse;

  /// No description provided for @errorJkanimeInconsistent.
  ///
  /// In en, this message translates to:
  /// **'JKAnime returned inconsistent server data for this episode.'**
  String get errorJkanimeInconsistent;

  /// No description provided for @errorJkanimeEmpty.
  ///
  /// In en, this message translates to:
  /// **'JKAnime has no data for this item right now.'**
  String get errorJkanimeEmpty;

  /// No description provided for @homeLoadingCatalog.
  ///
  /// In en, this message translates to:
  /// **'Loading home catalog...'**
  String get homeLoadingCatalog;

  /// No description provided for @homeEmptyCatalog.
  ///
  /// In en, this message translates to:
  /// **'No trending anime found in AniList right now.'**
  String get homeEmptyCatalog;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search AniList'**
  String get searchTitle;

  /// No description provided for @searchHintTitle.
  ///
  /// In en, this message translates to:
  /// **'Search anime title'**
  String get searchHintTitle;

  /// No description provided for @searchEmptyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Type a title and tap search to query AniList.'**
  String get searchEmptyPrompt;

  /// No description provided for @searchLoading.
  ///
  /// In en, this message translates to:
  /// **'Searching AniList...'**
  String get searchLoading;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No AniList results found for \"{query}\".'**
  String searchNoResults(Object query);

  /// No description provided for @animeDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Anime detail'**
  String get animeDetailTitle;

  /// No description provided for @animeDetailLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading anime detail...'**
  String get animeDetailLoading;

  /// No description provided for @viewEpisodeList.
  ///
  /// In en, this message translates to:
  /// **'View episode list'**
  String get viewEpisodeList;

  /// No description provided for @episodesWord.
  ///
  /// In en, this message translates to:
  /// **'episodes'**
  String get episodesWord;

  /// No description provided for @episodePreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Episode preview'**
  String get episodePreviewTitle;

  /// No description provided for @episodeStatusAired.
  ///
  /// In en, this message translates to:
  /// **'Aired'**
  String get episodeStatusAired;

  /// No description provided for @episodeStatusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get episodeStatusUpcoming;

  /// No description provided for @relationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Relations'**
  String get relationsTitle;

  /// No description provided for @episodeListTitle.
  ///
  /// In en, this message translates to:
  /// **'{animeTitle} episodes'**
  String episodeListTitle(Object animeTitle);

  /// No description provided for @episodeListLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading episodes...'**
  String get episodeListLoading;

  /// No description provided for @episodeListEmpty.
  ///
  /// In en, this message translates to:
  /// **'AniList has no episode metadata for this anime yet.'**
  String get episodeListEmpty;

  /// No description provided for @episodeMetadataAired.
  ///
  /// In en, this message translates to:
  /// **'Aired metadata'**
  String get episodeMetadataAired;

  /// No description provided for @episodeMetadataUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming metadata'**
  String get episodeMetadataUpcoming;

  /// No description provided for @jkanimeAvailabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'JKAnime availability'**
  String get jkanimeAvailabilityTitle;

  /// No description provided for @jkanimeChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking availability in JKAnime...'**
  String get jkanimeChecking;

  /// No description provided for @jkanimeErrorConsulting.
  ///
  /// In en, this message translates to:
  /// **'Error consulting JKAnime: {error}'**
  String jkanimeErrorConsulting(Object error);

  /// No description provided for @jkanimeNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available in JKAnime ({reason})'**
  String jkanimeNotAvailable(Object reason);

  /// No description provided for @jkanimeNotAvailableSimple.
  ///
  /// In en, this message translates to:
  /// **'Not available in JKAnime'**
  String get jkanimeNotAvailableSimple;

  /// No description provided for @jkanimeNotAvailableNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No reliable JKAnime match was found.'**
  String get jkanimeNotAvailableNoMatch;

  /// No description provided for @jkanimeNotAvailableNoEpisodes.
  ///
  /// In en, this message translates to:
  /// **'JKAnime match exists but no episodes were found.'**
  String get jkanimeNotAvailableNoEpisodes;

  /// No description provided for @jkanimeAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available in JKAnime'**
  String get jkanimeAvailable;

  /// No description provided for @jkanimeRealEpisodesFound.
  ///
  /// In en, this message translates to:
  /// **'Real episodes found: {count}'**
  String jkanimeRealEpisodesFound(int count);

  /// No description provided for @jkanimeViewRealEpisodes.
  ///
  /// In en, this message translates to:
  /// **'View real JKAnime episodes'**
  String get jkanimeViewRealEpisodes;

  /// No description provided for @viewServerLinks.
  ///
  /// In en, this message translates to:
  /// **'View servers'**
  String get viewServerLinks;

  /// No description provided for @resolveServerLink.
  ///
  /// In en, this message translates to:
  /// **'Resolve'**
  String get resolveServerLink;

  /// No description provided for @resolverResolving.
  ///
  /// In en, this message translates to:
  /// **'Resolving stream link...'**
  String get resolverResolving;

  /// No description provided for @resolverNoResolverFound.
  ///
  /// In en, this message translates to:
  /// **'No resolver is available for this server link.'**
  String get resolverNoResolverFound;

  /// No description provided for @resolverAmbiguousSelection.
  ///
  /// In en, this message translates to:
  /// **'More than one resolver matches this link with the same priority.'**
  String get resolverAmbiguousSelection;

  /// No description provided for @resolverMalformedLink.
  ///
  /// In en, this message translates to:
  /// **'The source server link is malformed and cannot be resolved.'**
  String get resolverMalformedLink;

  /// No description provided for @resolverParseFailure.
  ///
  /// In en, this message translates to:
  /// **'Resolver could not parse a valid stream from provider payload.'**
  String get resolverParseFailure;

  /// No description provided for @resolverInconsistentPayload.
  ///
  /// In en, this message translates to:
  /// **'Resolver received inconsistent provider payload.'**
  String get resolverInconsistentPayload;

  /// No description provided for @resolverTransportFailure.
  ///
  /// In en, this message translates to:
  /// **'Resolver request failed due to network/transport issue.'**
  String get resolverTransportFailure;

  /// No description provided for @resolverUnexpectedFailure.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error while resolving stream link.'**
  String get resolverUnexpectedFailure;

  /// No description provided for @resolverNoStreams.
  ///
  /// In en, this message translates to:
  /// **'Resolver did not return any stream candidate.'**
  String get resolverNoStreams;

  /// No description provided for @resolverPageTitle.
  ///
  /// In en, this message translates to:
  /// **'{animeTitle} Ep.{episodeNumber} | Resolve {serverName}'**
  String resolverPageTitle(
    Object animeTitle,
    Object episodeNumber,
    Object serverName,
  );

  /// No description provided for @resolverQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality: {quality}'**
  String resolverQuality(Object quality);

  /// No description provided for @resolverQualityUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get resolverQualityUnknown;

  /// No description provided for @resolverMediaType.
  ///
  /// In en, this message translates to:
  /// **'Type: {type}'**
  String resolverMediaType(Object type);

  /// No description provided for @resolverTypeHls.
  ///
  /// In en, this message translates to:
  /// **'HLS'**
  String get resolverTypeHls;

  /// No description provided for @resolverTypeMp4.
  ///
  /// In en, this message translates to:
  /// **'MP4'**
  String get resolverTypeMp4;

  /// No description provided for @resolverMimeType.
  ///
  /// In en, this message translates to:
  /// **'MIME: {mimeType}'**
  String resolverMimeType(Object mimeType);

  /// No description provided for @resolverHeader.
  ///
  /// In en, this message translates to:
  /// **'Header {name}: {value}'**
  String resolverHeader(Object name, Object value);

  /// No description provided for @resolverUsed.
  ///
  /// In en, this message translates to:
  /// **'Resolved by: {resolverName}'**
  String resolverUsed(Object resolverName);

  /// No description provided for @openPlayer.
  ///
  /// In en, this message translates to:
  /// **'Open player'**
  String get openPlayer;

  /// No description provided for @playerTitle.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get playerTitle;

  /// No description provided for @playerEpisodeTitle.
  ///
  /// In en, this message translates to:
  /// **'{animeTitle} - Episode {episodeNumber}'**
  String playerEpisodeTitle(Object animeTitle, Object episodeNumber);

  /// No description provided for @playerLoading.
  ///
  /// In en, this message translates to:
  /// **'Opening playback...'**
  String get playerLoading;

  /// No description provided for @playerCandidatePosition.
  ///
  /// In en, this message translates to:
  /// **'Candidate {current} of {total}'**
  String playerCandidatePosition(Object current, Object total);

  /// No description provided for @playerCurrentStream.
  ///
  /// In en, this message translates to:
  /// **'Current stream: {url}'**
  String playerCurrentStream(Object url);

  /// No description provided for @playerPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playerPlay;

  /// No description provided for @playerPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get playerPause;

  /// No description provided for @playerNoPlayableStream.
  ///
  /// In en, this message translates to:
  /// **'No playable stream was available.'**
  String get playerNoPlayableStream;

  /// No description provided for @playerUnsupportedStream.
  ///
  /// In en, this message translates to:
  /// **'The selected stream is not supported by this player.'**
  String get playerUnsupportedStream;

  /// No description provided for @playerOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Player failed to open the selected stream.'**
  String get playerOpenFailed;

  /// No description provided for @playerOpenTimeout.
  ///
  /// In en, this message translates to:
  /// **'Playback opening timed out.'**
  String get playerOpenTimeout;

  /// No description provided for @playerBufferingTimeout.
  ///
  /// In en, this message translates to:
  /// **'Buffering took too long. Trying fallback if available.'**
  String get playerBufferingTimeout;

  /// No description provided for @playerNetworkFailure.
  ///
  /// In en, this message translates to:
  /// **'Network failure while opening playback.'**
  String get playerNetworkFailure;

  /// No description provided for @playerCandidateFailedTryingFallback.
  ///
  /// In en, this message translates to:
  /// **'This stream failed. Trying another candidate.'**
  String get playerCandidateFailedTryingFallback;

  /// No description provided for @playerAllCandidatesFailed.
  ///
  /// In en, this message translates to:
  /// **'All stream candidates failed.'**
  String get playerAllCandidatesFailed;

  /// No description provided for @playerPlaybackErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'A playback error occurred.'**
  String get playerPlaybackErrorGeneric;

  /// No description provided for @playerPlaybackError.
  ///
  /// In en, this message translates to:
  /// **'Playback error: {reason}'**
  String playerPlaybackError(Object reason);

  /// No description provided for @jkanimeServerLinksLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading JKAnime server links...'**
  String get jkanimeServerLinksLoading;

  /// No description provided for @jkanimeServerLinksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No servers found for this episode in JKAnime.'**
  String get jkanimeServerLinksEmpty;

  /// No description provided for @jkanimeServerLinksTitle.
  ///
  /// In en, this message translates to:
  /// **'{animeTitle} | Episode {episodeNumber} servers'**
  String jkanimeServerLinksTitle(Object animeTitle, Object episodeNumber);

  /// No description provided for @jkanimeEpisodesTitle.
  ///
  /// In en, this message translates to:
  /// **'JKAnime episodes | {animeTitle}'**
  String jkanimeEpisodesTitle(Object animeTitle);

  /// No description provided for @animeListEpisodesShort.
  ///
  /// In en, this message translates to:
  /// **'{count} eps'**
  String animeListEpisodesShort(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
