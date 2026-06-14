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

  /// No description provided for @genericLoadFailure.
  ///
  /// In en, this message translates to:
  /// **'Something didn\'t load. Try again.'**
  String get genericLoadFailure;

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

  /// No description provided for @errorServiceUnavailableAnilist.
  ///
  /// In en, this message translates to:
  /// **'AniList is temporarily unavailable. Check back in a moment.'**
  String get errorServiceUnavailableAnilist;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offlineBanner;

  /// No description provided for @anilistDownBanner.
  ///
  /// In en, this message translates to:
  /// **'AniList is down'**
  String get anilistDownBanner;

  /// No description provided for @errorRateLimitedAnilist.
  ///
  /// In en, this message translates to:
  /// **'AniList is rate-limiting requests right now. Please wait a moment and retry.'**
  String get errorRateLimitedAnilist;

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

  /// No description provided for @homeSeasonHubSection.
  ///
  /// In en, this message translates to:
  /// **'Seasons'**
  String get homeSeasonHubSection;

  /// No description provided for @homeSeasonHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore this season'**
  String get homeSeasonHubTitle;

  /// No description provided for @homeSeasonHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See the most trending shows, upcoming premieres, and the community\'s top picks.'**
  String get homeSeasonHubSubtitle;

  /// No description provided for @trendingPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trendingPageTitle;

  /// No description provided for @trendingPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Full AniList ranking sorted by current trend momentum.'**
  String get trendingPageSubtitle;

  /// No description provided for @seasonHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Seasonal'**
  String get seasonHubTitle;

  /// No description provided for @seasonHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch seasons to see what is trending now, what is still upcoming, and what the community is backing the most.'**
  String get seasonHubSubtitle;

  /// No description provided for @seasonHubLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading season...'**
  String get seasonHubLoading;

  /// No description provided for @seasonHubCarryoverNote.
  ///
  /// In en, this message translates to:
  /// **'Includes shows that started in the previous season and are still releasing during this one.'**
  String get seasonHubCarryoverNote;

  /// No description provided for @seasonHubInSeasonSection.
  ///
  /// In en, this message translates to:
  /// **'Now airing'**
  String get seasonHubInSeasonSection;

  /// No description provided for @seasonHubUpcomingSection.
  ///
  /// In en, this message translates to:
  /// **'Upcoming releases'**
  String get seasonHubUpcomingSection;

  /// No description provided for @seasonHubRecommendedSection.
  ///
  /// In en, this message translates to:
  /// **'Community picks'**
  String get seasonHubRecommendedSection;

  /// No description provided for @seasonHubInSeasonEmpty.
  ///
  /// In en, this message translates to:
  /// **'No anime are airing for this season.'**
  String get seasonHubInSeasonEmpty;

  /// No description provided for @seasonHubUpcomingEmpty.
  ///
  /// In en, this message translates to:
  /// **'No confirmed premieres for this season yet.'**
  String get seasonHubUpcomingEmpty;

  /// No description provided for @seasonHubRecommendedEmpty.
  ///
  /// In en, this message translates to:
  /// **'There is not enough community signal to recommend this season yet.'**
  String get seasonHubRecommendedEmpty;

  /// No description provided for @seasonWinter.
  ///
  /// In en, this message translates to:
  /// **'Winter'**
  String get seasonWinter;

  /// No description provided for @seasonSpring.
  ///
  /// In en, this message translates to:
  /// **'Spring'**
  String get seasonSpring;

  /// No description provided for @seasonSummer.
  ///
  /// In en, this message translates to:
  /// **'Summer'**
  String get seasonSummer;

  /// No description provided for @seasonFall.
  ///
  /// In en, this message translates to:
  /// **'Fall'**
  String get seasonFall;

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

  /// No description provided for @notificationNewEpisode.
  ///
  /// In en, this message translates to:
  /// **'Episode {episodeNumber} is now available'**
  String notificationNewEpisode(int episodeNumber);

  /// No description provided for @notificationNewEpisodeWithTitle.
  ///
  /// In en, this message translates to:
  /// **'Episode {episodeNumber} - {episodeTitle} is now available'**
  String notificationNewEpisodeWithTitle(
    int episodeNumber,
    Object episodeTitle,
  );

  /// No description provided for @viewEpisodeList.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
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

  /// No description provided for @jkanimeLinkTypeStream.
  ///
  /// In en, this message translates to:
  /// **'STREAM'**
  String get jkanimeLinkTypeStream;

  /// No description provided for @jkanimeLinkTypeDownload.
  ///
  /// In en, this message translates to:
  /// **'DOWNLOAD'**
  String get jkanimeLinkTypeDownload;

  /// No description provided for @jkanimeDownloadOnly.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get jkanimeDownloadOnly;

  /// No description provided for @jkanimeDetectedHost.
  ///
  /// In en, this message translates to:
  /// **'Host: {host}'**
  String jkanimeDetectedHost(Object host);

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

  /// No description provided for @historyProgressUpTo.
  ///
  /// In en, this message translates to:
  /// **'Up to EP {episode} / {total}'**
  String historyProgressUpTo(int episode, int total);

  /// No description provided for @historyProgressLastWatched.
  ///
  /// In en, this message translates to:
  /// **'Last watched EP {episode}'**
  String historyProgressLastWatched(int episode);

  /// No description provided for @episodePlaying.
  ///
  /// In en, this message translates to:
  /// **'PLAYING'**
  String get episodePlaying;

  /// No description provided for @continueWatching.
  ///
  /// In en, this message translates to:
  /// **'Continue Watching'**
  String get continueWatching;

  /// No description provided for @continueWatchingHint.
  ///
  /// In en, this message translates to:
  /// **'Jump back in where you left off.'**
  String get continueWatchingHint;

  /// No description provided for @continueWatchingResumeAction.
  ///
  /// In en, this message translates to:
  /// **'Resume now'**
  String get continueWatchingResumeAction;

  /// No description provided for @continueWatchingEpisode.
  ///
  /// In en, this message translates to:
  /// **'Episode {episode}'**
  String continueWatchingEpisode(Object episode);

  /// No description provided for @sourceAvailabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Source availability'**
  String get sourceAvailabilityTitle;

  /// No description provided for @sourceAvailabilityChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking where you can watch...'**
  String get sourceAvailabilityChecking;

  /// No description provided for @sourceAvailabilityNone.
  ///
  /// In en, this message translates to:
  /// **'No source status is available yet.'**
  String get sourceAvailabilityNone;

  /// No description provided for @sourceOpenRecommended.
  ///
  /// In en, this message translates to:
  /// **'Open recommended source: {sourceName}'**
  String sourceOpenRecommended(Object sourceName);

  /// No description provided for @sourceRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended fallback order selected: {sourceName}'**
  String sourceRecommended(Object sourceName);

  /// No description provided for @sourceRecommendedShort.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get sourceRecommendedShort;

  /// No description provided for @sourceChoosePrompt.
  ///
  /// In en, this message translates to:
  /// **'Other matched sources:'**
  String get sourceChoosePrompt;

  /// No description provided for @sourceAvailableEpisodes.
  ///
  /// In en, this message translates to:
  /// **'{count} source episodes available'**
  String sourceAvailableEpisodes(int count);

  /// No description provided for @sourceNotAvailableNoMatch.
  ///
  /// In en, this message translates to:
  /// **'{sourceName}: no reliable AniList match.'**
  String sourceNotAvailableNoMatch(Object sourceName);

  /// No description provided for @sourceNotAvailableAmbiguous.
  ///
  /// In en, this message translates to:
  /// **'{sourceName}: ambiguous title match, skipped safely.'**
  String sourceNotAvailableAmbiguous(Object sourceName);

  /// No description provided for @sourceNotAvailableNoEpisodes.
  ///
  /// In en, this message translates to:
  /// **'{sourceName}: matched, but no episodes were found.'**
  String sourceNotAvailableNoEpisodes(Object sourceName);

  /// No description provided for @sourceUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'{sourceName}: source check failed.'**
  String sourceUnavailableError(Object sourceName);

  /// No description provided for @sourceViewEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get sourceViewEpisodes;

  /// No description provided for @sourceEpisodesTitle.
  ///
  /// In en, this message translates to:
  /// **'{sourceName} episodes | {animeTitle}'**
  String sourceEpisodesTitle(Object sourceName, Object animeTitle);

  /// No description provided for @sourceServerLinksLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading {sourceName} server links...'**
  String sourceServerLinksLoading(Object sourceName);

  /// No description provided for @sourceServerLinksTitle.
  ///
  /// In en, this message translates to:
  /// **'{sourceName} | {animeTitle} Episode {episodeNumber} servers'**
  String sourceServerLinksTitle(
    Object sourceName,
    Object animeTitle,
    Object episodeNumber,
  );

  /// No description provided for @sourceDetectedHost.
  ///
  /// In en, this message translates to:
  /// **'Host: {host}'**
  String sourceDetectedHost(Object host);

  /// No description provided for @detailSynopsisTitle.
  ///
  /// In en, this message translates to:
  /// **'Synopsis'**
  String get detailSynopsisTitle;

  /// No description provided for @detailDiscoverPrompt.
  ///
  /// In en, this message translates to:
  /// **'See what\'s ready before you pick an episode.'**
  String get detailDiscoverPrompt;

  /// No description provided for @detailPlaybackNotReady.
  ///
  /// In en, this message translates to:
  /// **'This anime is not ready to play right now.'**
  String get detailPlaybackNotReady;

  /// No description provided for @detailCheckingSources.
  ///
  /// In en, this message translates to:
  /// **'Checking sources...'**
  String get detailCheckingSources;

  /// No description provided for @detailPlaybackHint.
  ///
  /// In en, this message translates to:
  /// **'We\'ll reuse your last working source and server when possible.'**
  String get detailPlaybackHint;

  /// No description provided for @detailContinueEpisode.
  ///
  /// In en, this message translates to:
  /// **'Continue from episode {episode}'**
  String detailContinueEpisode(Object episode);

  /// No description provided for @detailContinueBadge.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get detailContinueBadge;

  /// No description provided for @detailPlaybackSources.
  ///
  /// In en, this message translates to:
  /// **'Ready in {count} sources'**
  String detailPlaybackSources(int count);

  /// No description provided for @homeHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Find something fast and start watching sooner.'**
  String get homeHeroTitle;

  /// No description provided for @homeHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search AniList, check real source availability, and jump into playback with fewer steps.'**
  String get homeHeroSubtitle;

  /// No description provided for @homeSearchAction.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get homeSearchAction;

  /// No description provided for @homeTrendingSection.
  ///
  /// In en, this message translates to:
  /// **'Trending now'**
  String get homeTrendingSection;

  /// No description provided for @homeTrendingHint.
  ///
  /// In en, this message translates to:
  /// **'Open any title to see if it\'s actually ready to watch.'**
  String get homeTrendingHint;

  /// No description provided for @searchHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Search by title'**
  String get searchHeroTitle;

  /// No description provided for @searchPromptShort.
  ///
  /// In en, this message translates to:
  /// **'Search a title to see matching anime.'**
  String get searchPromptShort;

  /// No description provided for @timeAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String timeAgoMinutes(int count);

  /// No description provided for @timeAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String timeAgoHours(int count);

  /// No description provided for @timeAgoDays.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String timeAgoDays(int count);

  /// No description provided for @playbackPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing playback...'**
  String get playbackPreparing;

  /// No description provided for @playbackOpeningSelectedServer.
  ///
  /// In en, this message translates to:
  /// **'Opening selected server...'**
  String get playbackOpeningSelectedServer;

  /// No description provided for @serverPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a server'**
  String get serverPickerTitle;

  /// No description provided for @serverPickerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only servers that can actually open are shown here.'**
  String get serverPickerSubtitle;

  /// No description provided for @serverPickerRememberSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Remember this selection'**
  String get serverPickerRememberSelectionTitle;

  /// No description provided for @serverPickerRememberSelectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use this source and server first next time if they are still available.'**
  String get serverPickerRememberSelectionSubtitle;

  /// No description provided for @serverPickerAllSources.
  ///
  /// In en, this message translates to:
  /// **'All sources'**
  String get serverPickerAllSources;

  /// No description provided for @serverPickerSourceFilter.
  ///
  /// In en, this message translates to:
  /// **'{sourceName} {count}'**
  String serverPickerSourceFilter(Object sourceName, Object count);

  /// No description provided for @serverPickerSourceOptionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} options'**
  String serverPickerSourceOptionCount(Object count);

  /// No description provided for @serverPickerCurrentRemembered.
  ///
  /// In en, this message translates to:
  /// **'Remembered now: {sourceName} / {serverName}'**
  String serverPickerCurrentRemembered(Object sourceName, Object serverName);

  /// No description provided for @serverPickerUnknownSource.
  ///
  /// In en, this message translates to:
  /// **'Unknown source'**
  String get serverPickerUnknownSource;

  /// No description provided for @serverPickerUnknownServer.
  ///
  /// In en, this message translates to:
  /// **'Unknown server'**
  String get serverPickerUnknownServer;

  /// No description provided for @serverOptionLastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last used'**
  String get serverOptionLastUsed;

  /// No description provided for @serverOptionRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get serverOptionRecommended;

  /// No description provided for @episodeAutoplayFailed.
  ///
  /// In en, this message translates to:
  /// **'That shortcut didn\'t open. Choose another server.'**
  String get episodeAutoplayFailed;

  /// No description provided for @episodePlaybackUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This episode is not ready to play right now.'**
  String get episodePlaybackUnavailable;

  /// No description provided for @episodeSelectedServerFailed.
  ///
  /// In en, this message translates to:
  /// **'That server is not available right now.'**
  String get episodeSelectedServerFailed;

  /// No description provided for @episodeLockedLabel.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get episodeLockedLabel;

  /// No description provided for @episodePlayNowLabel.
  ///
  /// In en, this message translates to:
  /// **'Play now'**
  String get episodePlayNowLabel;

  /// No description provided for @episodeListUsingPreference.
  ///
  /// In en, this message translates to:
  /// **'Tap an episode and Kumoriya will try your best source first.'**
  String get episodeListUsingPreference;

  /// No description provided for @episodeListUsingRememberedSource.
  ///
  /// In en, this message translates to:
  /// **'We\'ll start with {sourceName} {serverName} when it\'s still available.'**
  String episodeListUsingRememberedSource(Object sourceName, Object serverName);

  /// No description provided for @playerSourceSummary.
  ///
  /// In en, this message translates to:
  /// **'Playing from {serverName} via {resolverName}'**
  String playerSourceSummary(Object serverName, Object resolverName);

  /// No description provided for @playerAudioPreference.
  ///
  /// In en, this message translates to:
  /// **'Audio: {value}'**
  String playerAudioPreference(Object value);

  /// No description provided for @myListHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get myListHistory;

  /// No description provided for @myListFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get myListFavorites;

  /// No description provided for @myListSubscribed.
  ///
  /// In en, this message translates to:
  /// **'Subscribed'**
  String get myListSubscribed;

  /// No description provided for @myListDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get myListDownloads;

  /// No description provided for @myListHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Your watch history'**
  String get myListHistoryHint;

  /// No description provided for @myListFavoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet. Tap the heart on any anime to save it.'**
  String get myListFavoritesEmpty;

  /// No description provided for @myListSubscribedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No subscriptions yet. Subscribe to an anime to get notified of new episodes.'**
  String get myListSubscribedEmpty;

  /// No description provided for @myListDownloadsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No downloads yet. Download episodes from the episode list.'**
  String get myListDownloadsEmpty;

  /// No description provided for @addFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addFavorite;

  /// No description provided for @removeFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFavorite;

  /// No description provided for @subscribe.
  ///
  /// In en, this message translates to:
  /// **'Notify new episodes'**
  String get subscribe;

  /// No description provided for @unsubscribe.
  ///
  /// In en, this message translates to:
  /// **'Stop notifications'**
  String get unsubscribe;

  /// No description provided for @favoriteAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to favorites'**
  String get favoriteAdded;

  /// No description provided for @favoriteRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed from favorites'**
  String get favoriteRemoved;

  /// No description provided for @subscribedLabel.
  ///
  /// In en, this message translates to:
  /// **'Subscribed'**
  String get subscribedLabel;

  /// No description provided for @unsubscribedLabel.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribed'**
  String get unsubscribedLabel;

  /// No description provided for @downloadEpisode.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadEpisode;

  /// No description provided for @downloadAll.
  ///
  /// In en, this message translates to:
  /// **'Download All'**
  String get downloadAll;

  /// No description provided for @downloadQueued.
  ///
  /// In en, this message translates to:
  /// **'Download queued'**
  String get downloadQueued;

  /// No description provided for @downloadAllQueued.
  ///
  /// In en, this message translates to:
  /// **'All episodes queued for download'**
  String get downloadAllQueued;

  /// No description provided for @downloadSourceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No downloads available from this source. Choose another source.'**
  String get downloadSourceUnavailable;

  /// No description provided for @downloadInProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get downloadInProgress;

  /// No description provided for @downloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloadComplete;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailed;

  /// No description provided for @downloadFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Downloaded file not found — it may have been deleted.'**
  String get downloadFileNotFound;

  /// No description provided for @downloadPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get downloadPaused;

  /// No description provided for @downloadPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get downloadPending;

  /// No description provided for @downloadCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get downloadCancel;

  /// No description provided for @downloadClearQueue.
  ///
  /// In en, this message translates to:
  /// **'Clear queue'**
  String get downloadClearQueue;

  /// No description provided for @downloadClearQueueConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear queue?'**
  String get downloadClearQueueConfirmTitle;

  /// No description provided for @downloadClearQueueConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will remove all pending and failed downloads from the queue. This action cannot be undone.'**
  String get downloadClearQueueConfirmMessage;

  /// No description provided for @downloadRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get downloadRetry;

  /// No description provided for @downloadDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get downloadDelete;

  /// No description provided for @downloadPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get downloadPause;

  /// No description provided for @downloadResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get downloadResume;

  /// No description provided for @downloadFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Download folder'**
  String get downloadFolderTitle;

  /// No description provided for @downloadFolderDescription.
  ///
  /// In en, this message translates to:
  /// **'New episode downloads will be saved in this location.'**
  String get downloadFolderDescription;

  /// No description provided for @downloadFolderDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get downloadFolderDefault;

  /// No description provided for @downloadFolderCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get downloadFolderCustom;

  /// No description provided for @downloadFolderChange.
  ///
  /// In en, this message translates to:
  /// **'Change folder'**
  String get downloadFolderChange;

  /// No description provided for @downloadFolderReset.
  ///
  /// In en, this message translates to:
  /// **'Use default folder'**
  String get downloadFolderReset;

  /// No description provided for @downloadFolderSaved.
  ///
  /// In en, this message translates to:
  /// **'Download folder updated.'**
  String get downloadFolderSaved;

  /// No description provided for @downloadFolderResetDone.
  ///
  /// In en, this message translates to:
  /// **'Download folder reset to default.'**
  String get downloadFolderResetDone;

  /// No description provided for @downloadFolderSelectionCancelled.
  ///
  /// In en, this message translates to:
  /// **'Folder selection cancelled.'**
  String get downloadFolderSelectionCancelled;

  /// No description provided for @downloadFolderPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Storage permission was not granted for an external download folder.'**
  String get downloadFolderPermissionDenied;

  /// No description provided for @autoDownload.
  ///
  /// In en, this message translates to:
  /// **'Auto-download new episodes'**
  String get autoDownload;

  /// No description provided for @autoDownloadEnabled.
  ///
  /// In en, this message translates to:
  /// **'Auto-download enabled'**
  String get autoDownloadEnabled;

  /// No description provided for @autoDownloadDisabled.
  ///
  /// In en, this message translates to:
  /// **'Auto-download disabled'**
  String get autoDownloadDisabled;

  /// No description provided for @autoDownloadAudioPreference.
  ///
  /// In en, this message translates to:
  /// **'Audio preference'**
  String get autoDownloadAudioPreference;

  /// No description provided for @autoDownloadAudioAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get autoDownloadAudioAny;

  /// No description provided for @autoDownloadAudioSub.
  ///
  /// In en, this message translates to:
  /// **'SUB'**
  String get autoDownloadAudioSub;

  /// No description provided for @autoDownloadAudioDub.
  ///
  /// In en, this message translates to:
  /// **'DUB'**
  String get autoDownloadAudioDub;

  /// No description provided for @downloadAllChooseAudio.
  ///
  /// In en, this message translates to:
  /// **'Choose audio type'**
  String get downloadAllChooseAudio;

  /// No description provided for @downloadHlsNotSupported.
  ///
  /// In en, this message translates to:
  /// **'HLS streams cannot be downloaded'**
  String get downloadHlsNotSupported;

  /// No description provided for @downloadSelectQuality.
  ///
  /// In en, this message translates to:
  /// **'Select quality'**
  String get downloadSelectQuality;

  /// No description provided for @downloadSelectServer.
  ///
  /// In en, this message translates to:
  /// **'Select server'**
  String get downloadSelectServer;

  /// No description provided for @playEpisode.
  ///
  /// In en, this message translates to:
  /// **'Play episode'**
  String get playEpisode;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get navDownloads;

  /// No description provided for @universeAnime.
  ///
  /// In en, this message translates to:
  /// **'Anime'**
  String get universeAnime;

  /// No description provided for @universeManga.
  ///
  /// In en, this message translates to:
  /// **'Manga'**
  String get universeManga;

  /// No description provided for @universeSwitchLabel.
  ///
  /// In en, this message translates to:
  /// **'Switch universe'**
  String get universeSwitchLabel;

  /// No description provided for @mangaHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Manga Home'**
  String get mangaHomeTitle;

  /// No description provided for @mangaSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Manga Search'**
  String get mangaSearchTitle;

  /// No description provided for @mangaLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Manga Library'**
  String get mangaLibraryTitle;

  /// No description provided for @mangaDownloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Manga Downloads'**
  String get mangaDownloadsTitle;

  /// No description provided for @mangaComingSoonSlice8.
  ///
  /// In en, this message translates to:
  /// **'Discovery and details land in the next slice. Switch back to anime in the meantime.'**
  String get mangaComingSoonSlice8;

  /// No description provided for @mangaComingSoonSlice10.
  ///
  /// In en, this message translates to:
  /// **'Your manga library will live here once Slice 10 lands.'**
  String get mangaComingSoonSlice10;

  /// No description provided for @mangaLibraryHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reading history yet.'**
  String get mangaLibraryHistoryEmpty;

  /// No description provided for @mangaLibraryFavoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet. Tap the heart on any manga to save it.'**
  String get mangaLibraryFavoritesEmpty;

  /// No description provided for @mangaLibrarySubscribedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No subscriptions yet. Subscribe to a manga to get notified of new chapters.'**
  String get mangaLibrarySubscribedEmpty;

  /// No description provided for @mangaLibraryHistoryChapterLine.
  ///
  /// In en, this message translates to:
  /// **'Last read: Ch. {number}'**
  String mangaLibraryHistoryChapterLine(String number);

  /// No description provided for @mangaDetailAddFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get mangaDetailAddFavorite;

  /// No description provided for @mangaDetailRemoveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get mangaDetailRemoveFavorite;

  /// No description provided for @mangaDetailSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Notify new chapters'**
  String get mangaDetailSubscribe;

  /// No description provided for @mangaDetailUnsubscribe.
  ///
  /// In en, this message translates to:
  /// **'Stop notifying'**
  String get mangaDetailUnsubscribe;

  /// No description provided for @libraryFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get libraryFilterAll;

  /// No description provided for @mangaComingSoonSlice11.
  ///
  /// In en, this message translates to:
  /// **'Manga downloads (CBZ) arrive in Slice 11.'**
  String get mangaComingSoonSlice11;

  /// No description provided for @mangaHomeFeaturedTag.
  ///
  /// In en, this message translates to:
  /// **'FEATURED'**
  String get mangaHomeFeaturedTag;

  /// No description provided for @mangaHomeReadAction.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get mangaHomeReadAction;

  /// No description provided for @mangaHomeTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending now'**
  String get mangaHomeTrending;

  /// No description provided for @mangaHomePopular.
  ///
  /// In en, this message translates to:
  /// **'Popular all time'**
  String get mangaHomePopular;

  /// No description provided for @mangaHomeLatest.
  ///
  /// In en, this message translates to:
  /// **'Recently updated'**
  String get mangaHomeLatest;

  /// No description provided for @mangaHomeTopRated.
  ///
  /// In en, this message translates to:
  /// **'Top rated'**
  String get mangaHomeTopRated;

  /// No description provided for @mangaHomeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No manga to show yet. Pull to refresh once you are online.'**
  String get mangaHomeEmpty;

  /// No description provided for @mangaHomeError.
  ///
  /// In en, this message translates to:
  /// **'Could not load manga'**
  String get mangaHomeError;

  /// No description provided for @mangaHomeRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get mangaHomeRetry;

  /// No description provided for @mangaSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search manga, manhwa, manhua…'**
  String get mangaSearchHint;

  /// No description provided for @mangaSearchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Find your next read'**
  String get mangaSearchEmptyTitle;

  /// No description provided for @mangaSearchEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Type a title — AniList covers manga, manhwa, manhua, and one-shots.'**
  String get mangaSearchEmptyHint;

  /// No description provided for @mangaSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get mangaSearchNoResults;

  /// No description provided for @mangaCardChapterCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 chapter} other{{count} chapters}}'**
  String mangaCardChapterCountLabel(int count);

  /// No description provided for @mangaDetailSynopsis.
  ///
  /// In en, this message translates to:
  /// **'Synopsis'**
  String get mangaDetailSynopsis;

  /// No description provided for @mangaDetailNoSynopsis.
  ///
  /// In en, this message translates to:
  /// **'No synopsis available.'**
  String get mangaDetailNoSynopsis;

  /// No description provided for @mangaDetailGenres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get mangaDetailGenres;

  /// No description provided for @mangaDetailChapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get mangaDetailChapters;

  /// No description provided for @mangaDetailNoChaptersInLanguage.
  ///
  /// In en, this message translates to:
  /// **'No chapters available in your language.'**
  String get mangaDetailNoChaptersInLanguage;

  /// No description provided for @mangaDetailReaderComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Reader coming in Slice 9'**
  String get mangaDetailReaderComingSoon;

  /// No description provided for @mangaDetailVolumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Vol. {number}'**
  String mangaDetailVolumeLabel(int number);

  /// No description provided for @mangaDetailChapterLabel.
  ///
  /// In en, this message translates to:
  /// **'Ch. {number}'**
  String mangaDetailChapterLabel(String number);

  /// No description provided for @mangaDetailExternalChaptersTitle.
  ///
  /// In en, this message translates to:
  /// **'Official external chapters'**
  String get mangaDetailExternalChaptersTitle;

  /// No description provided for @mangaDetailExternalChaptersHint.
  ///
  /// In en, this message translates to:
  /// **'Hosted by publishers (MangaPlus, Viz, …). Opens in your browser; not playable in-app.'**
  String get mangaDetailExternalChaptersHint;

  /// No description provided for @mangaDetailOpenExternal.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get mangaDetailOpenExternal;

  /// No description provided for @mangaDetailOpenExternalFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the external link.'**
  String get mangaDetailOpenExternalFailed;

  /// No description provided for @mangaDetailScanlatorLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get mangaDetailScanlatorLabel;

  /// No description provided for @mangaDetailScanlatorAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get mangaDetailScanlatorAuto;

  /// No description provided for @mangaDetailScanlatorAutoHint.
  ///
  /// In en, this message translates to:
  /// **'Pick the most complete release per chapter.'**
  String get mangaDetailScanlatorAutoHint;

  /// No description provided for @mangaDetailScanlatorPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a scanlator'**
  String get mangaDetailScanlatorPickerTitle;

  /// No description provided for @mangaDetailScanlatorChapterCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 chapter} other{{count} chapters}}'**
  String mangaDetailScanlatorChapterCount(int count);

  /// No description provided for @mangaDetailScanlatorLastReleaseToday.
  ///
  /// In en, this message translates to:
  /// **'Last release today'**
  String get mangaDetailScanlatorLastReleaseToday;

  /// No description provided for @mangaDetailScanlatorLastReleaseDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{Last release 1 day ago} other{Last release {days} days ago}}'**
  String mangaDetailScanlatorLastReleaseDays(int days);

  /// No description provided for @mangaDetailScanlatorLastReleaseMonths.
  ///
  /// In en, this message translates to:
  /// **'{months, plural, one{Last release 1 month ago} other{Last release {months} months ago}}'**
  String mangaDetailScanlatorLastReleaseMonths(int months);

  /// No description provided for @mangaDetailSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get mangaDetailSourceLabel;

  /// No description provided for @mangaDetailSourceAuto.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get mangaDetailSourceAuto;

  /// No description provided for @mangaDetailSourceAutoHint.
  ///
  /// In en, this message translates to:
  /// **'Aggregate chapters from every available provider.'**
  String get mangaDetailSourceAutoHint;

  /// No description provided for @mangaDetailSourcePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a provider'**
  String get mangaDetailSourcePickerTitle;

  /// No description provided for @settingsPluginBaseUrlsTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugin base URLs'**
  String get settingsPluginBaseUrlsTitle;

  /// No description provided for @settingsPluginBaseUrlsDescription.
  ///
  /// In en, this message translates to:
  /// **'Override the base URL each source plugin uses. Leave empty to keep the manifest default.'**
  String get settingsPluginBaseUrlsDescription;

  /// No description provided for @settingsPluginBaseUrlsAdvancedEntry.
  ///
  /// In en, this message translates to:
  /// **'Plugin base URLs (advanced)'**
  String get settingsPluginBaseUrlsAdvancedEntry;

  /// No description provided for @settingsPluginBaseUrlsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No plugins available.'**
  String get settingsPluginBaseUrlsEmpty;

  /// No description provided for @settingsPluginBaseUrlsManifestLabel.
  ///
  /// In en, this message translates to:
  /// **'Manifest default'**
  String get settingsPluginBaseUrlsManifestLabel;

  /// No description provided for @settingsPluginBaseUrlsCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get settingsPluginBaseUrlsCurrentLabel;

  /// No description provided for @settingsPluginBaseUrlsOverrideHint.
  ///
  /// In en, this message translates to:
  /// **'https://api.example.com'**
  String get settingsPluginBaseUrlsOverrideHint;

  /// No description provided for @settingsPluginBaseUrlsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsPluginBaseUrlsSave;

  /// No description provided for @settingsPluginBaseUrlsClear.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsPluginBaseUrlsClear;

  /// No description provided for @settingsPluginBaseUrlsInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid http(s) URL.'**
  String get settingsPluginBaseUrlsInvalid;

  /// No description provided for @settingsPluginBaseUrlsSaved.
  ///
  /// In en, this message translates to:
  /// **'Override saved.'**
  String get settingsPluginBaseUrlsSaved;

  /// No description provided for @settingsPluginBaseUrlsCleared.
  ///
  /// In en, this message translates to:
  /// **'Override removed.'**
  String get settingsPluginBaseUrlsCleared;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

  /// No description provided for @calendarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Airing schedule by date'**
  String get calendarSubtitle;

  /// No description provided for @calendarNoAiring.
  ///
  /// In en, this message translates to:
  /// **'No airing anime found.'**
  String get calendarNoAiring;

  /// No description provided for @calendarUnknownSchedule.
  ///
  /// In en, this message translates to:
  /// **'Unknown schedule'**
  String get calendarUnknownSchedule;

  /// No description provided for @calendarToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarToday;

  /// No description provided for @downloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloadsTitle;

  /// No description provided for @downloadsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Offline episodes'**
  String get downloadsSubtitle;

  /// No description provided for @downloadsTabActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get downloadsTabActive;

  /// No description provided for @downloadsTabQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get downloadsTabQueue;

  /// No description provided for @downloadsTabCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get downloadsTabCompleted;

  /// No description provided for @downloadsActiveEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active downloads.'**
  String get downloadsActiveEmpty;

  /// No description provided for @downloadsQueueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No downloads queued.'**
  String get downloadsQueueEmpty;

  /// No description provided for @downloadsCompletedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No completed downloads.'**
  String get downloadsCompletedEmpty;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotificationsTitle;

  /// No description provided for @settingsNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions use system notifications for new episode alerts.'**
  String get settingsNotificationsDescription;

  /// No description provided for @settingsEnableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get settingsEnableNotifications;

  /// No description provided for @settingsOpenSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get settingsOpenSystemSettings;

  /// No description provided for @settingsStatusAllowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get settingsStatusAllowed;

  /// No description provided for @settingsStatusBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get settingsStatusBlocked;

  /// No description provided for @settingsStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get settingsStatusUnknown;

  /// No description provided for @settingsAppTitle.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsAppTitle;

  /// No description provided for @settingsThemeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeLabel;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageLabel;

  /// No description provided for @settingsVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersionLabel;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get settingsLanguageSpanish;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the app language. \'System\' follows your device setting.'**
  String get settingsLanguageDescription;

  /// No description provided for @settingsDesktopOnlyVisibleNote.
  ///
  /// In en, this message translates to:
  /// **'On Windows only desktop-relevant settings are shown.'**
  String get settingsDesktopOnlyVisibleNote;

  /// No description provided for @settingsPlaybackPreferencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Playback preferences'**
  String get settingsPlaybackPreferencesTitle;

  /// No description provided for @settingsPlaybackPreferencesDescription.
  ///
  /// In en, this message translates to:
  /// **'Clear remembered source, server, and resolver choices so playback starts fresh.'**
  String get settingsPlaybackPreferencesDescription;

  /// No description provided for @settingsPlaybackPreferencesClear.
  ///
  /// In en, this message translates to:
  /// **'Clear saved preferences'**
  String get settingsPlaybackPreferencesClear;

  /// No description provided for @settingsPlaybackPreferencesCleared.
  ///
  /// In en, this message translates to:
  /// **'Saved playback preferences cleared'**
  String get settingsPlaybackPreferencesCleared;

  /// No description provided for @playerBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get playerBack;

  /// No description provided for @playerAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get playerAudio;

  /// No description provided for @playerSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get playerSubtitles;

  /// No description provided for @playerQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get playerQuality;

  /// No description provided for @playerNextEpisode.
  ///
  /// In en, this message translates to:
  /// **'Next episode'**
  String get playerNextEpisode;

  /// No description provided for @playerPreviousEpisode.
  ///
  /// In en, this message translates to:
  /// **'Previous episode'**
  String get playerPreviousEpisode;

  /// No description provided for @playerRetry.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get playerRetry;

  /// No description provided for @playerSkipBackward.
  ///
  /// In en, this message translates to:
  /// **'-10s'**
  String get playerSkipBackward;

  /// No description provided for @playerSkipForward.
  ///
  /// In en, this message translates to:
  /// **'+10s'**
  String get playerSkipForward;

  /// No description provided for @playerUnlockRotation.
  ///
  /// In en, this message translates to:
  /// **'Unlock rotation'**
  String get playerUnlockRotation;

  /// No description provided for @playerLockRotation.
  ///
  /// In en, this message translates to:
  /// **'Lock rotation'**
  String get playerLockRotation;

  /// No description provided for @playerDisableSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get playerDisableSubtitles;

  /// No description provided for @resumeLabel.
  ///
  /// In en, this message translates to:
  /// **'RESUME'**
  String get resumeLabel;

  /// No description provided for @detailPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get detailPlay;

  /// No description provided for @detailResumeEpisode.
  ///
  /// In en, this message translates to:
  /// **'Resume EP {episode}'**
  String detailResumeEpisode(int episode);

  /// No description provided for @searchPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchPageTitle;

  /// No description provided for @homeAiringToday.
  ///
  /// In en, this message translates to:
  /// **'Airing Today'**
  String get homeAiringToday;

  /// No description provided for @myListHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No watch history yet.'**
  String get myListHistoryEmpty;

  /// No description provided for @downloadEpisodesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} episodes'**
  String downloadEpisodesCount(int count);

  /// No description provided for @downloadEpisodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Episode {episode}'**
  String downloadEpisodeLabel(int episode);

  /// No description provided for @downloadedSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloadedSourceLabel;

  /// No description provided for @downloadAllFromSource.
  ///
  /// In en, this message translates to:
  /// **'Download all from a source'**
  String get downloadAllFromSource;

  /// No description provided for @sectionSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get sectionSeeAll;

  /// No description provided for @statusAiring.
  ///
  /// In en, this message translates to:
  /// **'AIRING'**
  String get statusAiring;

  /// No description provided for @statusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'UPCOMING'**
  String get statusUpcoming;

  /// No description provided for @statusFinished.
  ///
  /// In en, this message translates to:
  /// **'FINISHED'**
  String get statusFinished;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'CANCELLED'**
  String get statusCancelled;

  /// No description provided for @statusOnHiatus.
  ///
  /// In en, this message translates to:
  /// **'ON HIATUS'**
  String get statusOnHiatus;

  /// No description provided for @statusUnknown.
  ///
  /// In en, this message translates to:
  /// **'UNKNOWN'**
  String get statusUnknown;

  /// No description provided for @settingsSubtitleTitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get settingsSubtitleTitle;

  /// No description provided for @settingsSubtitleDescription.
  ///
  /// In en, this message translates to:
  /// **'Customize subtitle appearance during playback.'**
  String get settingsSubtitleDescription;

  /// No description provided for @settingsSubtitleFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get settingsSubtitleFontSize;

  /// No description provided for @settingsSubtitleFontColor.
  ///
  /// In en, this message translates to:
  /// **'Font color'**
  String get settingsSubtitleFontColor;

  /// No description provided for @settingsSubtitleFontOpacity.
  ///
  /// In en, this message translates to:
  /// **'Font opacity'**
  String get settingsSubtitleFontOpacity;

  /// No description provided for @settingsSubtitleBgColor.
  ///
  /// In en, this message translates to:
  /// **'Background color'**
  String get settingsSubtitleBgColor;

  /// No description provided for @settingsSubtitleBgOpacity.
  ///
  /// In en, this message translates to:
  /// **'Background opacity'**
  String get settingsSubtitleBgOpacity;

  /// No description provided for @settingsSubtitleBgBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get settingsSubtitleBgBlack;

  /// No description provided for @settingsSubtitleBgDarkGray.
  ///
  /// In en, this message translates to:
  /// **'Dark gray'**
  String get settingsSubtitleBgDarkGray;

  /// No description provided for @settingsSubtitleBgNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get settingsSubtitleBgNone;

  /// No description provided for @settingsSubtitleEdgeStyle.
  ///
  /// In en, this message translates to:
  /// **'Edge style'**
  String get settingsSubtitleEdgeStyle;

  /// No description provided for @settingsSubtitleEdgeNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get settingsSubtitleEdgeNone;

  /// No description provided for @settingsSubtitleEdgeOutline.
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get settingsSubtitleEdgeOutline;

  /// No description provided for @settingsSubtitleEdgeDropShadow.
  ///
  /// In en, this message translates to:
  /// **'Drop shadow'**
  String get settingsSubtitleEdgeDropShadow;

  /// No description provided for @settingsSubtitleEdgeRaised.
  ///
  /// In en, this message translates to:
  /// **'Raised'**
  String get settingsSubtitleEdgeRaised;

  /// No description provided for @settingsSubtitleEdgeDepressed.
  ///
  /// In en, this message translates to:
  /// **'Depressed'**
  String get settingsSubtitleEdgeDepressed;

  /// No description provided for @settingsSubtitleSmall.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get settingsSubtitleSmall;

  /// No description provided for @settingsSubtitleMedium.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get settingsSubtitleMedium;

  /// No description provided for @settingsSubtitleLarge.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get settingsSubtitleLarge;

  /// No description provided for @settingsSubtitleExtraLarge.
  ///
  /// In en, this message translates to:
  /// **'XL'**
  String get settingsSubtitleExtraLarge;

  /// No description provided for @settingsSubtitleBackground.
  ///
  /// In en, this message translates to:
  /// **'Show background behind subtitles'**
  String get settingsSubtitleBackground;

  /// No description provided for @playerSubtitleStyle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle style'**
  String get playerSubtitleStyle;

  /// No description provided for @playerSubtitleStyleDescription.
  ///
  /// In en, this message translates to:
  /// **'Improve readability without leaving the player.'**
  String get playerSubtitleStyleDescription;

  /// No description provided for @playerSkipIntro.
  ///
  /// In en, this message translates to:
  /// **'Skip intro'**
  String get playerSkipIntro;

  /// No description provided for @playerSkipCredits.
  ///
  /// In en, this message translates to:
  /// **'Skip credits'**
  String get playerSkipCredits;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @sourceServerLinksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No server links available for this episode.'**
  String get sourceServerLinksEmpty;

  /// No description provided for @downloadDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete download?'**
  String get downloadDeleteConfirmTitle;

  /// No description provided for @downloadDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This downloaded episode will be permanently removed from your device.'**
  String get downloadDeleteConfirmMessage;

  /// No description provided for @cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// No description provided for @playerLockControls.
  ///
  /// In en, this message translates to:
  /// **'Lock controls'**
  String get playerLockControls;

  /// No description provided for @historyGroupToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get historyGroupToday;

  /// No description provided for @historyGroupYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get historyGroupYesterday;

  /// No description provided for @historyGroupThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get historyGroupThisWeek;

  /// No description provided for @historyGroupThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get historyGroupThisMonth;

  /// No description provided for @historyGroupOlder.
  ///
  /// In en, this message translates to:
  /// **'Older'**
  String get historyGroupOlder;

  /// No description provided for @historyDeleteEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from history?'**
  String get historyDeleteEntryTitle;

  /// No description provided for @historyDeleteEntryMessage.
  ///
  /// In en, this message translates to:
  /// **'This anime will be removed from your watch history.'**
  String get historyDeleteEntryMessage;

  /// No description provided for @historyClearAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all history?'**
  String get historyClearAllTitle;

  /// No description provided for @historyClearAllMessage.
  ///
  /// In en, this message translates to:
  /// **'Your entire watch history will be permanently deleted.'**
  String get historyClearAllMessage;

  /// No description provided for @historyClearAllAction.
  ///
  /// In en, this message translates to:
  /// **'Clear all history'**
  String get historyClearAllAction;

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// No description provided for @removeAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeAction;

  /// No description provided for @downloadViewAnimeDetails.
  ///
  /// In en, this message translates to:
  /// **'View anime details'**
  String get downloadViewAnimeDetails;

  /// No description provided for @downloadDeleteAllEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Delete all episodes'**
  String get downloadDeleteAllEpisodes;

  /// No description provided for @downloadDeleteEpisode.
  ///
  /// In en, this message translates to:
  /// **'Delete episode'**
  String get downloadDeleteEpisode;

  /// No description provided for @downloadDeleteAllConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all downloaded episodes?'**
  String get downloadDeleteAllConfirmTitle;

  /// No description provided for @downloadDeleteAllConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'All downloaded episodes for this anime will be permanently removed.'**
  String get downloadDeleteAllConfirmMessage;

  /// No description provided for @librarySortAlphabetical.
  ///
  /// In en, this message translates to:
  /// **'A-Z'**
  String get librarySortAlphabetical;

  /// No description provided for @librarySortRecentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get librarySortRecentlyAdded;

  /// No description provided for @librarySortRecentlyWatched.
  ///
  /// In en, this message translates to:
  /// **'Recently watched'**
  String get librarySortRecentlyWatched;

  /// No description provided for @libraryActionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get libraryActionSave;

  /// No description provided for @libraryActionNotify.
  ///
  /// In en, this message translates to:
  /// **'Notify'**
  String get libraryActionNotify;

  /// No description provided for @libraryActionAutoDownload.
  ///
  /// In en, this message translates to:
  /// **'Auto DL'**
  String get libraryActionAutoDownload;

  /// No description provided for @discoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discoverTitle;

  /// No description provided for @discoverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find your next anime'**
  String get discoverSubtitle;

  /// No description provided for @discoverTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending Now'**
  String get discoverTrending;

  /// No description provided for @discoverTopRated.
  ///
  /// In en, this message translates to:
  /// **'Top Rated'**
  String get discoverTopRated;

  /// No description provided for @discoverPopular.
  ///
  /// In en, this message translates to:
  /// **'Most Popular'**
  String get discoverPopular;

  /// No description provided for @discoverTopAiring.
  ///
  /// In en, this message translates to:
  /// **'Top Airing'**
  String get discoverTopAiring;

  /// No description provided for @discoverTopMovies.
  ///
  /// In en, this message translates to:
  /// **'Top Movies'**
  String get discoverTopMovies;

  /// No description provided for @discoverUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get discoverUpcoming;

  /// No description provided for @discoverGenres.
  ///
  /// In en, this message translates to:
  /// **'Browse by Genre'**
  String get discoverGenres;

  /// No description provided for @discoverCantRemember.
  ///
  /// In en, this message translates to:
  /// **'Can\'t remember the name?'**
  String get discoverCantRemember;

  /// No description provided for @discoverCantRememberSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find anime by describing what it\'s about'**
  String get discoverCantRememberSubtitle;

  /// No description provided for @discoverStartTagSearch.
  ///
  /// In en, this message translates to:
  /// **'Start tag search'**
  String get discoverStartTagSearch;

  /// No description provided for @browseResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Browse Results'**
  String get browseResultsTitle;

  /// No description provided for @browseNoResults.
  ///
  /// In en, this message translates to:
  /// **'No anime found with these filters.'**
  String get browseNoResults;

  /// No description provided for @browseFilterGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get browseFilterGenre;

  /// No description provided for @browseFilterFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get browseFilterFormat;

  /// No description provided for @browseFilterSeason.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get browseFilterSeason;

  /// No description provided for @browseFilterYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get browseFilterYear;

  /// No description provided for @browseFilterSort.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get browseFilterSort;

  /// No description provided for @browseFilterStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get browseFilterStatus;

  /// No description provided for @browseFilterTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get browseFilterTags;

  /// No description provided for @browseFilterApply.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get browseFilterApply;

  /// No description provided for @browseFilterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get browseFilterClear;

  /// No description provided for @browseSortTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get browseSortTrending;

  /// No description provided for @browseSortScore.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get browseSortScore;

  /// No description provided for @browseSortPopularity.
  ///
  /// In en, this message translates to:
  /// **'Popularity'**
  String get browseSortPopularity;

  /// No description provided for @browseSortFavourites.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get browseSortFavourites;

  /// No description provided for @browseSortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get browseSortNewest;

  /// No description provided for @browseSortTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get browseSortTitle;

  /// No description provided for @tagSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Find by Tags'**
  String get tagSearchTitle;

  /// No description provided for @tagSearchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select tags that describe the anime you\'re looking for'**
  String get tagSearchSubtitle;

  /// No description provided for @tagSearchSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get tagSearchSelectCategory;

  /// No description provided for @tagSearchSelectedTags.
  ///
  /// In en, this message translates to:
  /// **'{count} tags selected'**
  String tagSearchSelectedTags(int count);

  /// No description provided for @tagSearchFindAnime.
  ///
  /// In en, this message translates to:
  /// **'Find anime'**
  String get tagSearchFindAnime;

  /// No description provided for @tagSearchNoTags.
  ///
  /// In en, this message translates to:
  /// **'No tags selected yet'**
  String get tagSearchNoTags;

  /// No description provided for @tagSearchGuideStep1.
  ///
  /// In en, this message translates to:
  /// **'Open a category to see its tags'**
  String get tagSearchGuideStep1;

  /// No description provided for @tagSearchGuideStep2.
  ///
  /// In en, this message translates to:
  /// **'Tap tags that match what you remember'**
  String get tagSearchGuideStep2;

  /// No description provided for @tagSearchGuideStep3.
  ///
  /// In en, this message translates to:
  /// **'Press find to see matching anime'**
  String get tagSearchGuideStep3;

  /// No description provided for @tagSearchFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter tags by name...'**
  String get tagSearchFilterHint;

  /// No description provided for @browseGenreApply.
  ///
  /// In en, this message translates to:
  /// **'Apply ({count})'**
  String browseGenreApply(int count);

  /// No description provided for @formatTv.
  ///
  /// In en, this message translates to:
  /// **'TV'**
  String get formatTv;

  /// No description provided for @formatMovie.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get formatMovie;

  /// No description provided for @formatOva.
  ///
  /// In en, this message translates to:
  /// **'OVA'**
  String get formatOva;

  /// No description provided for @formatOna.
  ///
  /// In en, this message translates to:
  /// **'ONA'**
  String get formatOna;

  /// No description provided for @formatSpecial.
  ///
  /// In en, this message translates to:
  /// **'Special'**
  String get formatSpecial;

  /// No description provided for @downloadRetryAllFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry all'**
  String get downloadRetryAllFailed;

  /// No description provided for @downloadPauseAll.
  ///
  /// In en, this message translates to:
  /// **'Pause all'**
  String get downloadPauseAll;

  /// No description provided for @downloadResumeAll.
  ///
  /// In en, this message translates to:
  /// **'Resume all'**
  String get downloadResumeAll;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get profileNotSignedIn;

  /// No description provided for @profileSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get profileSignIn;

  /// No description provided for @profileLinkedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Linked Accounts'**
  String get profileLinkedAccounts;

  /// No description provided for @profileNoLinkedAccounts.
  ///
  /// In en, this message translates to:
  /// **'No linked accounts'**
  String get profileNoLinkedAccounts;

  /// No description provided for @profileCouldNotLoadAccounts.
  ///
  /// In en, this message translates to:
  /// **'Could not load accounts'**
  String get profileCouldNotLoadAccounts;

  /// No description provided for @profileActiveSessions.
  ///
  /// In en, this message translates to:
  /// **'Active Sessions'**
  String get profileActiveSessions;

  /// No description provided for @profileNoActiveSessions.
  ///
  /// In en, this message translates to:
  /// **'No active sessions'**
  String get profileNoActiveSessions;

  /// No description provided for @profileCouldNotLoadSessions.
  ///
  /// In en, this message translates to:
  /// **'Could not load sessions'**
  String get profileCouldNotLoadSessions;

  /// No description provided for @profilePasskeys.
  ///
  /// In en, this message translates to:
  /// **'Passkeys'**
  String get profilePasskeys;

  /// No description provided for @profileNoPasskeys.
  ///
  /// In en, this message translates to:
  /// **'No passkeys registered'**
  String get profileNoPasskeys;

  /// No description provided for @profileCouldNotLoadPasskeys.
  ///
  /// In en, this message translates to:
  /// **'Could not load passkeys'**
  String get profileCouldNotLoadPasskeys;

  /// No description provided for @profileSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get profileSync;

  /// No description provided for @profileSyncStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get profileSyncStatus;

  /// No description provided for @profileLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced'**
  String get profileLastSynced;

  /// No description provided for @profileLastSyncedNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get profileLastSyncedNever;

  /// No description provided for @profileSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get profileSyncNow;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get profileDeleteAccount;

  /// No description provided for @profileLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get profileLogOut;

  /// No description provided for @profileLogOutBody.
  ///
  /// In en, this message translates to:
  /// **'Your local data will be kept.'**
  String get profileLogOutBody;

  /// No description provided for @profileCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancel;

  /// No description provided for @profileDeleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account and all synced data. This cannot be undone.'**
  String get profileDeleteAccountWarning;

  /// No description provided for @profileDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get profileDelete;

  /// No description provided for @profileUnknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown device'**
  String get profileUnknownDevice;

  /// No description provided for @profileUnnamedPasskey.
  ///
  /// In en, this message translates to:
  /// **'Unnamed passkey'**
  String get profileUnnamedPasskey;

  /// No description provided for @profileUnknownProvider.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get profileUnknownProvider;

  /// No description provided for @profileNoEmail.
  ///
  /// In en, this message translates to:
  /// **'No email'**
  String get profileNoEmail;

  /// No description provided for @profileSyncIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get profileSyncIdle;

  /// No description provided for @profileSyncPushing.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get profileSyncPushing;

  /// No description provided for @profileSyncPulling.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get profileSyncPulling;

  /// No description provided for @profileSyncSuccess.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get profileSyncSuccess;

  /// No description provided for @profileSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get profileSyncFailed;

  /// No description provided for @profileTimeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get profileTimeJustNow;

  /// No description provided for @profileTimeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} {unit} ago'**
  String profileTimeMinutesAgo(int count, Object unit);

  /// No description provided for @profileTimeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} {unit} ago'**
  String profileTimeHoursAgo(int count, Object unit);

  /// No description provided for @profileTimeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} {unit} ago'**
  String profileTimeDaysAgo(int count, Object unit);

  /// No description provided for @profileTimeMinuteSingular.
  ///
  /// In en, this message translates to:
  /// **'minute'**
  String get profileTimeMinuteSingular;

  /// No description provided for @profileTimeMinutePlural.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get profileTimeMinutePlural;

  /// No description provided for @profileTimeHourSingular.
  ///
  /// In en, this message translates to:
  /// **'hour'**
  String get profileTimeHourSingular;

  /// No description provided for @profileTimeHourPlural.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get profileTimeHourPlural;

  /// No description provided for @profileTimeDaySingular.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get profileTimeDaySingular;

  /// No description provided for @profileTimeDayPlural.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get profileTimeDayPlural;

  /// No description provided for @settingsAutoDeleteWatched.
  ///
  /// In en, this message translates to:
  /// **'Auto-delete watched downloads'**
  String get settingsAutoDeleteWatched;

  /// No description provided for @settingsAutoDeleteNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get settingsAutoDeleteNever;

  /// No description provided for @settingsAutoDeleteAfterDays.
  ///
  /// In en, this message translates to:
  /// **'After {days} days'**
  String settingsAutoDeleteAfterDays(int days);

  /// No description provided for @settingsAutoDeleteImmediately.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get settingsAutoDeleteImmediately;

  /// No description provided for @settingsDownloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get settingsDownloadsTitle;

  /// No description provided for @settingsDownloadsWifiOnly.
  ///
  /// In en, this message translates to:
  /// **'WiFi-only downloads'**
  String get settingsDownloadsWifiOnly;

  /// No description provided for @settingsDownloadsWifiOnlyDescription.
  ///
  /// In en, this message translates to:
  /// **'Pause downloads when not connected to WiFi'**
  String get settingsDownloadsWifiOnlyDescription;

  /// No description provided for @onboardingNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications?'**
  String get onboardingNotificationTitle;

  /// No description provided for @onboardingNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Kumoriya can notify you when new episodes are available for your subscribed anime.'**
  String get onboardingNotificationBody;

  /// No description provided for @onboardingNotificationAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get onboardingNotificationAllow;

  /// No description provided for @onboardingNotificationSkip.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get onboardingNotificationSkip;

  /// No description provided for @profileRegisterPasskey.
  ///
  /// In en, this message translates to:
  /// **'Register new passkey'**
  String get profileRegisterPasskey;

  /// No description provided for @profilePasskeyNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Passkey name'**
  String get profilePasskeyNameTitle;

  /// No description provided for @profilePasskeyNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. My phone'**
  String get profilePasskeyNameHint;

  /// No description provided for @profilePasskeyNameContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get profilePasskeyNameContinue;

  /// No description provided for @profilePasskeyRegistered.
  ///
  /// In en, this message translates to:
  /// **'Passkey registered'**
  String get profilePasskeyRegistered;

  /// No description provided for @profilePasskeyRegisterFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not register passkey'**
  String get profilePasskeyRegisterFailed;

  /// No description provided for @profilePasskeyDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete passkey?'**
  String get profilePasskeyDeleteTitle;

  /// No description provided for @profilePasskeyDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This passkey will be removed and can no longer be used to sign in.'**
  String get profilePasskeyDeleteBody;

  /// No description provided for @profilePasskeyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Passkey deleted'**
  String get profilePasskeyDeleted;

  /// No description provided for @profilePasskeyDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete passkey'**
  String get profilePasskeyDeleteFailed;

  /// No description provided for @authLoginWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Kumoriya'**
  String get authLoginWelcomeTitle;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync your progress across devices'**
  String get authLoginSubtitle;

  /// No description provided for @authCouldNotOpenBrowser.
  ///
  /// In en, this message translates to:
  /// **'Could not open browser'**
  String get authCouldNotOpenBrowser;

  /// No description provided for @authContinueWithDiscord.
  ///
  /// In en, this message translates to:
  /// **'Continue with Discord'**
  String get authContinueWithDiscord;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueWithGoogle;

  /// No description provided for @authWaitingForBrowser.
  ///
  /// In en, this message translates to:
  /// **'Waiting for browser to return...'**
  String get authWaitingForBrowser;

  /// No description provided for @authCancelLogin.
  ///
  /// In en, this message translates to:
  /// **'Cancel login'**
  String get authCancelLogin;

  /// No description provided for @authSkipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get authSkipForNow;

  /// No description provided for @authLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get authLoginFailed;

  /// No description provided for @authGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get authGoBack;

  /// No description provided for @authConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get authConnecting;

  /// No description provided for @authMayTakeSeconds.
  ///
  /// In en, this message translates to:
  /// **'This may take a few seconds'**
  String get authMayTakeSeconds;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'New update'**
  String get updateAvailableTitle;

  /// No description provided for @updateWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s new:'**
  String get updateWhatsNew;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update...'**
  String get updateDownloading;

  /// No description provided for @updateInstallingWindows.
  ///
  /// In en, this message translates to:
  /// **'Installing... the app will close.'**
  String get updateInstallingWindows;

  /// No description provided for @updateOpeningInstaller.
  ///
  /// In en, this message translates to:
  /// **'Opening installer...'**
  String get updateOpeningInstaller;

  /// No description provided for @updateClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get updateClose;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateNow;

  /// No description provided for @updateInstallerOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open installer: {error}'**
  String updateInstallerOpenFailed(Object error);

  /// No description provided for @updateReleaseNotesAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get updateReleaseNotesAdded;

  /// No description provided for @updateReleaseNotesChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed'**
  String get updateReleaseNotesChanged;

  /// No description provided for @updateReleaseNotesFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get updateReleaseNotesFixed;

  /// No description provided for @updateGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get updateGotIt;

  /// No description provided for @partyTitle.
  ///
  /// In en, this message translates to:
  /// **'Watch Party'**
  String get partyTitle;

  /// No description provided for @partyOpenBrowseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open party browse'**
  String get partyOpenBrowseTooltip;

  /// No description provided for @partyViewDebugLogsTooltip.
  ///
  /// In en, this message translates to:
  /// **'View party debug logs'**
  String get partyViewDebugLogsTooltip;

  /// No description provided for @partyRemovedByHost.
  ///
  /// In en, this message translates to:
  /// **'You were removed from the party by the host.'**
  String get partyRemovedByHost;

  /// No description provided for @partyRemovedWithReason.
  ///
  /// In en, this message translates to:
  /// **'You were removed from the party: {reason}'**
  String partyRemovedWithReason(Object reason);

  /// No description provided for @partyDebugLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Party Debug Logs'**
  String get partyDebugLogsTitle;

  /// No description provided for @partyClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get partyClose;

  /// No description provided for @partyCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get partyCopy;

  /// No description provided for @partyLogsCopied.
  ///
  /// In en, this message translates to:
  /// **'Logs copied to clipboard'**
  String get partyLogsCopied;

  /// No description provided for @partyWatchTogetherTitle.
  ///
  /// In en, this message translates to:
  /// **'Watch together with friends'**
  String get partyWatchTogetherTitle;

  /// No description provided for @partyInviteIntro.
  ///
  /// In en, this message translates to:
  /// **'Create a room or join with an invite code. Up to 4 people can watch in sync via P2P.'**
  String get partyInviteIntro;

  /// No description provided for @partyInviteCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get partyInviteCodeLabel;

  /// No description provided for @partyJoin.
  ///
  /// In en, this message translates to:
  /// **'Join Party'**
  String get partyJoin;

  /// No description provided for @partyStartRoomForAnime.
  ///
  /// In en, this message translates to:
  /// **'Or start a room for {animeTitle}'**
  String partyStartRoomForAnime(Object animeTitle);

  /// No description provided for @partyStartRoomFallbackAnime.
  ///
  /// In en, this message translates to:
  /// **'this anime'**
  String get partyStartRoomFallbackAnime;

  /// No description provided for @partyCreateRoom.
  ///
  /// In en, this message translates to:
  /// **'Create Room'**
  String get partyCreateRoom;

  /// No description provided for @partyOpenAnimeToCreate.
  ///
  /// In en, this message translates to:
  /// **'Open an anime page to create a room'**
  String get partyOpenAnimeToCreate;

  /// No description provided for @partyNowWatching.
  ///
  /// In en, this message translates to:
  /// **'Now Watching'**
  String get partyNowWatching;

  /// No description provided for @partyEpisodeNumber.
  ///
  /// In en, this message translates to:
  /// **'Episode {episodeNumber}'**
  String partyEpisodeNumber(int episodeNumber);

  /// No description provided for @partyChangeAnime.
  ///
  /// In en, this message translates to:
  /// **'Change Anime'**
  String get partyChangeAnime;

  /// No description provided for @partyChangeEpisode.
  ///
  /// In en, this message translates to:
  /// **'Change Ep.'**
  String get partyChangeEpisode;

  /// No description provided for @partyInviteCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite code copied!'**
  String get partyInviteCodeCopied;

  /// No description provided for @partyShareInviteLinkTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share invite link'**
  String get partyShareInviteLinkTooltip;

  /// No description provided for @partyInviteLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite link copied!'**
  String get partyInviteLinkCopied;

  /// No description provided for @partyShareInviteSubject.
  ///
  /// In en, this message translates to:
  /// **'Join my Kumoriya watch party'**
  String get partyShareInviteSubject;

  /// No description provided for @partyShareInviteMessage.
  ///
  /// In en, this message translates to:
  /// **'Join my Kumoriya watch party for {title}: {link}'**
  String partyShareInviteMessage(String title, String link);

  /// No description provided for @partyMembersCount.
  ///
  /// In en, this message translates to:
  /// **'Members ({current}/{max})'**
  String partyMembersCount(int current, int max);

  /// No description provided for @partyChangeEpisodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Episode'**
  String get partyChangeEpisodeTitle;

  /// No description provided for @partyEpisodeNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Episode number'**
  String get partyEpisodeNumberLabel;

  /// No description provided for @partyApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get partyApply;

  /// No description provided for @partyReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get partyReady;

  /// No description provided for @partyReadyConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Ready!'**
  String get partyReadyConfirmed;

  /// No description provided for @partyStartWatching.
  ///
  /// In en, this message translates to:
  /// **'Start Watching'**
  String get partyStartWatching;

  /// No description provided for @partyWaitingForEveryone.
  ///
  /// In en, this message translates to:
  /// **'Waiting for everyone...'**
  String get partyWaitingForEveryone;

  /// No description provided for @partyWaitingForHost.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the host to start...'**
  String get partyWaitingForHost;

  /// No description provided for @partyTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get partyTryAgain;

  /// No description provided for @partyHostActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Host actions'**
  String get partyHostActionsTooltip;

  /// No description provided for @partyHostControls.
  ///
  /// In en, this message translates to:
  /// **'Host Controls'**
  String get partyHostControls;

  /// No description provided for @partyMakeHost.
  ///
  /// In en, this message translates to:
  /// **'Make host'**
  String get partyMakeHost;

  /// No description provided for @partyMemberDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Member is disconnected'**
  String get partyMemberDisconnected;

  /// No description provided for @partyRemoveFromParty.
  ///
  /// In en, this message translates to:
  /// **'Remove from party'**
  String get partyRemoveFromParty;

  /// No description provided for @partyRemoveMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove member?'**
  String get partyRemoveMemberTitle;

  /// No description provided for @partyRemoveMemberBody.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" from the party? They will be disconnected immediately.'**
  String partyRemoveMemberBody(Object name);

  /// No description provided for @partyRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get partyRemove;

  /// No description provided for @partyTransferHostTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer host?'**
  String get partyTransferHostTitle;

  /// No description provided for @partyTransferHostBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will take over as host. You will keep watching but lose host controls.'**
  String partyTransferHostBody(Object name);

  /// No description provided for @partyTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get partyTransfer;

  /// No description provided for @partyPreparingStage.
  ///
  /// In en, this message translates to:
  /// **'Preparing the party stage...'**
  String get partyPreparingStage;

  /// No description provided for @partyCouldNotLoadAnime.
  ///
  /// In en, this message translates to:
  /// **'Could not load this anime for the party.'**
  String get partyCouldNotLoadAnime;

  /// No description provided for @partyBrowseModeBanner.
  ///
  /// In en, this message translates to:
  /// **'Watch Party mode: browse together, then return to the lobby to confirm the next move.'**
  String get partyBrowseModeBanner;

  /// No description provided for @partyEpisodeModeBanner.
  ///
  /// In en, this message translates to:
  /// **'Watch Party mode: choose the episode together, then return to the lobby if the host needs to change the room target.'**
  String get partyEpisodeModeBanner;

  /// No description provided for @partyHostSourceMissing.
  ///
  /// In en, this message translates to:
  /// **'The host picked a source you do not have installed.'**
  String get partyHostSourceMissing;

  /// No description provided for @partyHostEpisodeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'That episode is not available on your installed sources yet.'**
  String get partyHostEpisodeUnavailable;

  /// No description provided for @partyHostServerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The host server is not available locally. Pick another one.'**
  String get partyHostServerUnavailable;

  /// No description provided for @partyHostResolverFailed.
  ///
  /// In en, this message translates to:
  /// **'The shared stream could not be resolved here. Pick another server.'**
  String get partyHostResolverFailed;

  /// No description provided for @partyEpisodeCta.
  ///
  /// In en, this message translates to:
  /// **'Watch Party Ep. {episodeNumber}'**
  String partyEpisodeCta(int episodeNumber);

  /// No description provided for @partyStartWithParty.
  ///
  /// In en, this message translates to:
  /// **'Start with Party'**
  String get partyStartWithParty;

  /// No description provided for @partyOnlyHostCanSwitchAnime.
  ///
  /// In en, this message translates to:
  /// **'Only the host can switch the party anime.'**
  String get partyOnlyHostCanSwitchAnime;

  /// No description provided for @partySwitchedToAnime.
  ///
  /// In en, this message translates to:
  /// **'Party switched to \"{animeTitle}\".'**
  String partySwitchedToAnime(Object animeTitle);

  /// No description provided for @partyNoPlayableSourcesReady.
  ///
  /// In en, this message translates to:
  /// **'No playable sources are ready yet.'**
  String get partyNoPlayableSourcesReady;

  /// No description provided for @partyGettingRoomStreamReady.
  ///
  /// In en, this message translates to:
  /// **'Getting the room stream ready...'**
  String get partyGettingRoomStreamReady;

  /// No description provided for @partyLoadingEpisodeBoard.
  ///
  /// In en, this message translates to:
  /// **'Loading the party episode board...'**
  String get partyLoadingEpisodeBoard;

  /// No description provided for @partyCouldNotLoadEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Could not load party episodes.'**
  String get partyCouldNotLoadEpisodes;

  /// No description provided for @partyHostChoosesNextEpisode.
  ///
  /// In en, this message translates to:
  /// **'The host chooses the next party episode.'**
  String get partyHostChoosesNextEpisode;

  /// No description provided for @partyMovedToEpisode.
  ///
  /// In en, this message translates to:
  /// **'Party moved to episode {episodeNumber}.'**
  String partyMovedToEpisode(int episodeNumber);

  /// No description provided for @partyOpeningEpisode.
  ///
  /// In en, this message translates to:
  /// **'Opening the party episode...'**
  String get partyOpeningEpisode;

  /// No description provided for @partyBackToLobbyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back to party lobby'**
  String get partyBackToLobbyTooltip;

  /// No description provided for @partyEpisodesTitle.
  ///
  /// In en, this message translates to:
  /// **'Party Episodes'**
  String get partyEpisodesTitle;

  /// No description provided for @partyLockedToEpisode.
  ///
  /// In en, this message translates to:
  /// **'The host locked the party to episode {episodeNumber}.'**
  String partyLockedToEpisode(int episodeNumber);

  /// No description provided for @partyActiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Party active'**
  String get partyActiveTooltip;

  /// No description provided for @partySetForPartyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Set for party'**
  String get partySetForPartyTooltip;

  /// No description provided for @partyChangeAnimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Party Anime'**
  String get partyChangeAnimeTitle;

  /// No description provided for @partyChangeAnimeBody.
  ///
  /// In en, this message translates to:
  /// **'Switch the party to \"{animeTitle}\"?\nAll members will be redirected.'**
  String partyChangeAnimeBody(Object animeTitle);

  /// No description provided for @partySwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get partySwitch;

  /// No description provided for @partyLobbyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Party Lobby'**
  String get partyLobbyTooltip;

  /// No description provided for @partyChooseEpisode.
  ///
  /// In en, this message translates to:
  /// **'Choose Party Episode'**
  String get partyChooseEpisode;

  /// No description provided for @partyPreviewEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Preview Episodes'**
  String get partyPreviewEpisodes;

  /// No description provided for @partyOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening...'**
  String get partyOpening;

  /// No description provided for @partyWatchCurrentEpisode.
  ///
  /// In en, this message translates to:
  /// **'Watch Current Episode'**
  String get partyWatchCurrentEpisode;

  /// No description provided for @partyHostChoosesAnime.
  ///
  /// In en, this message translates to:
  /// **'Host Chooses Anime'**
  String get partyHostChoosesAnime;

  /// No description provided for @partyMaybeNext.
  ///
  /// In en, this message translates to:
  /// **'Maybe next in the party'**
  String get partyMaybeNext;

  /// No description provided for @partyChooseRoomNext.
  ///
  /// In en, this message translates to:
  /// **'Choose what the room should watch next.'**
  String get partyChooseRoomNext;

  /// No description provided for @partyRoomCode.
  ///
  /// In en, this message translates to:
  /// **'Room code {code}'**
  String partyRoomCode(Object code);

  /// No description provided for @partyInRoomCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in room'**
  String partyInRoomCount(int count);

  /// No description provided for @partyReadyCount.
  ///
  /// In en, this message translates to:
  /// **'{count} ready'**
  String partyReadyCount(int count);

  /// No description provided for @partyConnectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} connected'**
  String partyConnectedCount(int count);

  /// No description provided for @partyEpisodeCount.
  ///
  /// In en, this message translates to:
  /// **'{count} eps'**
  String partyEpisodeCount(int count);

  /// No description provided for @partyRoomOnEpisode.
  ///
  /// In en, this message translates to:
  /// **'Room on ep {episodeNumber}'**
  String partyRoomOnEpisode(int episodeNumber);

  /// No description provided for @partyIntentCurrentTitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s line up the next episode'**
  String get partyIntentCurrentTitle;

  /// No description provided for @partyIntentCurrentHost.
  ///
  /// In en, this message translates to:
  /// **'Keep the room moving: pick the episode, then launch together.'**
  String get partyIntentCurrentHost;

  /// No description provided for @partyIntentCurrentMember.
  ///
  /// In en, this message translates to:
  /// **'You are browsing the active room anime. Once the host chooses, everyone follows together.'**
  String get partyIntentCurrentMember;

  /// No description provided for @partyIntentOtherTitle.
  ///
  /// In en, this message translates to:
  /// **'This feels like a good room pick'**
  String get partyIntentOtherTitle;

  /// No description provided for @partyIntentOtherHost.
  ///
  /// In en, this message translates to:
  /// **'Switch the room here if the party wants to watch \"{animeTitle}\" instead.'**
  String partyIntentOtherHost(Object animeTitle);

  /// No description provided for @partyIntentOtherMember.
  ///
  /// In en, this message translates to:
  /// **'You can browse alternatives, but only the host can switch the room anime.'**
  String get partyIntentOtherMember;

  /// No description provided for @partyRoomReadySources.
  ///
  /// In en, this message translates to:
  /// **'Room-ready sources'**
  String get partyRoomReadySources;

  /// No description provided for @partyNeedPlayableSource.
  ///
  /// In en, this message translates to:
  /// **'We still need a playable source before everyone can watch together.'**
  String get partyNeedPlayableSource;

  /// No description provided for @partyWhoIsHere.
  ///
  /// In en, this message translates to:
  /// **'Who is on the couch'**
  String get partyWhoIsHere;

  /// No description provided for @partyYouSuffix.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get partyYouSuffix;

  /// No description provided for @partyEpisodesHostSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick the episode everyone will watch next.'**
  String get partyEpisodesHostSubtitle;

  /// No description provided for @partyEpisodesMemberSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow the host and join when the room episode is ready.'**
  String get partyEpisodesMemberSubtitle;

  /// No description provided for @partyOnlineCount.
  ///
  /// In en, this message translates to:
  /// **'{count} online'**
  String partyOnlineCount(int count);

  /// No description provided for @partyNoEpisodesYet.
  ///
  /// In en, this message translates to:
  /// **'No episodes are available yet.'**
  String get partyNoEpisodesYet;

  /// No description provided for @partyRoomPick.
  ///
  /// In en, this message translates to:
  /// **'Room Pick'**
  String get partyRoomPick;

  /// No description provided for @partyTapToQueue.
  ///
  /// In en, this message translates to:
  /// **'Tap to Queue'**
  String get partyTapToQueue;

  /// No description provided for @partyHostDecides.
  ///
  /// In en, this message translates to:
  /// **'Host decides'**
  String get partyHostDecides;

  /// No description provided for @partyWatchTogether.
  ///
  /// In en, this message translates to:
  /// **'Watch together'**
  String get partyWatchTogether;

  /// No description provided for @partyWaitingOnSource.
  ///
  /// In en, this message translates to:
  /// **'Waiting on source'**
  String get partyWaitingOnSource;

  /// No description provided for @partyLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get partyLocked;

  /// No description provided for @partyRoomEpisodeReady.
  ///
  /// In en, this message translates to:
  /// **'This is the room episode. Everyone can launch from here.'**
  String get partyRoomEpisodeReady;

  /// No description provided for @partyRoomEpisodeNoSource.
  ///
  /// In en, this message translates to:
  /// **'This is the room episode, but no source is ready yet.'**
  String get partyRoomEpisodeNoSource;

  /// No description provided for @partyTapToMoveEpisode.
  ///
  /// In en, this message translates to:
  /// **'Tap to move the room to episode {episodeNumber}.'**
  String partyTapToMoveEpisode(int episodeNumber);

  /// No description provided for @partyOnlyHostChangesEpisode.
  ///
  /// In en, this message translates to:
  /// **'Only the host can change the party episode.'**
  String get partyOnlyHostChangesEpisode;

  /// No description provided for @partyExitTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave Watch Party?'**
  String get partyExitTitle;

  /// No description provided for @partyExitBody.
  ///
  /// In en, this message translates to:
  /// **'If you leave now, you\'ll need a new invite code to rejoin.'**
  String get partyExitBody;

  /// No description provided for @partyExitStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get partyExitStay;

  /// No description provided for @partyExitLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave Party'**
  String get partyExitLeave;

  /// No description provided for @partyPlayerExitTitle.
  ///
  /// In en, this message translates to:
  /// **'Watching with Party'**
  String get partyPlayerExitTitle;

  /// No description provided for @partyPlayerExitBackToParty.
  ///
  /// In en, this message translates to:
  /// **'Back to Party'**
  String get partyPlayerExitBackToParty;

  /// No description provided for @partyPlayerExitBackToPartyDesc.
  ///
  /// In en, this message translates to:
  /// **'Return to browse and members list'**
  String get partyPlayerExitBackToPartyDesc;

  /// No description provided for @partyPlayerExitLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave Party'**
  String get partyPlayerExitLeave;

  /// No description provided for @partyPlayerExitLeaveDesc.
  ///
  /// In en, this message translates to:
  /// **'Disconnect and return home'**
  String get partyPlayerExitLeaveDesc;

  /// No description provided for @partyPlayerExitCancel.
  ///
  /// In en, this message translates to:
  /// **'Keep Watching'**
  String get partyPlayerExitCancel;

  /// No description provided for @partyBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Watch Party Active'**
  String get partyBannerTitle;

  /// No description provided for @partyBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{animeTitle} · Ep {episodeNumber}'**
  String partyBannerSubtitle(Object animeTitle, int episodeNumber);

  /// No description provided for @partyBannerRejoin.
  ///
  /// In en, this message translates to:
  /// **'Rejoin'**
  String get partyBannerRejoin;

  /// No description provided for @partyEnterPlayer.
  ///
  /// In en, this message translates to:
  /// **'Enter Player'**
  String get partyEnterPlayer;

  /// No description provided for @partyIdleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start or join a Watch Party to watch together.'**
  String get partyIdleSubtitle;

  /// No description provided for @partyOrDivider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get partyOrDivider;

  /// No description provided for @partyUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get partyUnknownError;

  /// No description provided for @partyAvatarFallback.
  ///
  /// In en, this message translates to:
  /// **'?'**
  String get partyAvatarFallback;

  /// No description provided for @partyEpisodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Episode {number}'**
  String partyEpisodeLabel(int number);

  /// No description provided for @partyWaitingForOneMember.
  ///
  /// In en, this message translates to:
  /// **'Waiting for 1 member to join…'**
  String get partyWaitingForOneMember;

  /// No description provided for @partyWaitingForMembers.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {count} members to join…'**
  String partyWaitingForMembers(int count);

  /// No description provided for @partyHostPaused.
  ///
  /// In en, this message translates to:
  /// **'The host paused'**
  String get partyHostPaused;

  /// No description provided for @partyPlaybackLaunchFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start playback. Please try again.'**
  String get partyPlaybackLaunchFailed;
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
