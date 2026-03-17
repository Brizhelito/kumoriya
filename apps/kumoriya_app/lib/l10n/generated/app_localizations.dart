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
