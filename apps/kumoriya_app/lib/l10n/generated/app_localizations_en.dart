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
  String get genericLoadFailure => 'Something didn\'t load. Try again.';

  @override
  String unexpectedStateError(Object error) {
    return 'Unexpected state error: $error';
  }

  @override
  String get errorTransportAnilist =>
      'Could not reach AniList. Check your connection and retry.';

  @override
  String get errorServiceUnavailableAnilist =>
      'AniList is temporarily unavailable. Check back in a moment.';

  @override
  String get offlineBanner => 'Offline';

  @override
  String get anilistDownBanner => 'AniList is down';

  @override
  String get errorRateLimitedAnilist =>
      'AniList is rate-limiting requests right now. Please wait a moment and retry.';

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
  String get homeSeasonHubSection => 'Seasons';

  @override
  String get homeSeasonHubTitle => 'Explore this season';

  @override
  String get homeSeasonHubSubtitle =>
      'See the most trending shows, upcoming premieres, and the community\'s top picks.';

  @override
  String get trendingPageTitle => 'Trending';

  @override
  String get trendingPageSubtitle =>
      'Full AniList ranking sorted by current trend momentum.';

  @override
  String get seasonHubTitle => 'Seasonal';

  @override
  String get seasonHubSubtitle =>
      'Switch seasons to see what is trending now, what is still upcoming, and what the community is backing the most.';

  @override
  String get seasonHubLoading => 'Loading season...';

  @override
  String get seasonHubCarryoverNote =>
      'Includes shows that started in the previous season and are still releasing during this one.';

  @override
  String get seasonHubInSeasonSection => 'Now airing';

  @override
  String get seasonHubUpcomingSection => 'Upcoming releases';

  @override
  String get seasonHubRecommendedSection => 'Community picks';

  @override
  String get seasonHubInSeasonEmpty => 'No anime are airing for this season.';

  @override
  String get seasonHubUpcomingEmpty =>
      'No confirmed premieres for this season yet.';

  @override
  String get seasonHubRecommendedEmpty =>
      'There is not enough community signal to recommend this season yet.';

  @override
  String get seasonWinter => 'Winter';

  @override
  String get seasonSpring => 'Spring';

  @override
  String get seasonSummer => 'Summer';

  @override
  String get seasonFall => 'Fall';

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
  String notificationNewEpisode(int episodeNumber) {
    return 'Episode $episodeNumber is now available';
  }

  @override
  String notificationNewEpisodeWithTitle(
    int episodeNumber,
    Object episodeTitle,
  ) {
    return 'Episode $episodeNumber - $episodeTitle is now available';
  }

  @override
  String get viewEpisodeList => 'Episodes';

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
  String get resolverAmbiguousSelection =>
      'More than one resolver matches this link with the same priority.';

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
  String resolverUsed(Object resolverName) {
    return 'Resolved by: $resolverName';
  }

  @override
  String get openPlayer => 'Open player';

  @override
  String get playerTitle => 'Player';

  @override
  String playerEpisodeTitle(Object animeTitle, Object episodeNumber) {
    return '$animeTitle - Episode $episodeNumber';
  }

  @override
  String get playerLoading => 'Opening playback...';

  @override
  String playerCandidatePosition(Object current, Object total) {
    return 'Candidate $current of $total';
  }

  @override
  String playerCurrentStream(Object url) {
    return 'Current stream: $url';
  }

  @override
  String get playerPlay => 'Play';

  @override
  String get playerPause => 'Pause';

  @override
  String get playerNoPlayableStream => 'No playable stream was available.';

  @override
  String get playerUnsupportedStream =>
      'The selected stream is not supported by this player.';

  @override
  String get playerOpenFailed => 'Player failed to open the selected stream.';

  @override
  String get playerOpenTimeout => 'Playback opening timed out.';

  @override
  String get playerBufferingTimeout =>
      'Buffering took too long. Trying fallback if available.';

  @override
  String get playerNetworkFailure => 'Network failure while opening playback.';

  @override
  String get playerCandidateFailedTryingFallback =>
      'This stream failed. Trying another candidate.';

  @override
  String get playerAllCandidatesFailed => 'All stream candidates failed.';

  @override
  String get playerPlaybackErrorGeneric => 'A playback error occurred.';

  @override
  String playerPlaybackError(Object reason) {
    return 'Playback error: $reason';
  }

  @override
  String get jkanimeServerLinksLoading => 'Loading JKAnime server links...';

  @override
  String get jkanimeServerLinksEmpty =>
      'No servers found for this episode in JKAnime.';

  @override
  String get jkanimeLinkTypeStream => 'STREAM';

  @override
  String get jkanimeLinkTypeDownload => 'DOWNLOAD';

  @override
  String get jkanimeDownloadOnly => 'Download';

  @override
  String jkanimeDetectedHost(Object host) {
    return 'Host: $host';
  }

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

  @override
  String historyProgressUpTo(int episode, int total) {
    return 'Up to EP $episode / $total';
  }

  @override
  String historyProgressLastWatched(int episode) {
    return 'Last watched EP $episode';
  }

  @override
  String get episodePlaying => 'PLAYING';

  @override
  String get continueWatching => 'Continue Watching';

  @override
  String get continueWatchingHint => 'Jump back in where you left off.';

  @override
  String get continueWatchingResumeAction => 'Resume now';

  @override
  String continueWatchingEpisode(Object episode) {
    return 'Episode $episode';
  }

  @override
  String get sourceAvailabilityTitle => 'Source availability';

  @override
  String get sourceAvailabilityChecking => 'Checking where you can watch...';

  @override
  String get sourceAvailabilityNone => 'No source status is available yet.';

  @override
  String sourceOpenRecommended(Object sourceName) {
    return 'Open recommended source: $sourceName';
  }

  @override
  String sourceRecommended(Object sourceName) {
    return 'Recommended fallback order selected: $sourceName';
  }

  @override
  String get sourceRecommendedShort => 'Recommended';

  @override
  String get sourceChoosePrompt => 'Other matched sources:';

  @override
  String sourceAvailableEpisodes(int count) {
    return '$count source episodes available';
  }

  @override
  String sourceNotAvailableNoMatch(Object sourceName) {
    return '$sourceName: no reliable AniList match.';
  }

  @override
  String sourceNotAvailableAmbiguous(Object sourceName) {
    return '$sourceName: ambiguous title match, skipped safely.';
  }

  @override
  String sourceNotAvailableNoEpisodes(Object sourceName) {
    return '$sourceName: matched, but no episodes were found.';
  }

  @override
  String sourceUnavailableError(Object sourceName) {
    return '$sourceName: source check failed.';
  }

  @override
  String get sourceViewEpisodes => 'Episodes';

  @override
  String sourceEpisodesTitle(Object sourceName, Object animeTitle) {
    return '$sourceName episodes | $animeTitle';
  }

  @override
  String sourceServerLinksLoading(Object sourceName) {
    return 'Loading $sourceName server links...';
  }

  @override
  String sourceServerLinksTitle(
    Object sourceName,
    Object animeTitle,
    Object episodeNumber,
  ) {
    return '$sourceName | $animeTitle Episode $episodeNumber servers';
  }

  @override
  String sourceDetectedHost(Object host) {
    return 'Host: $host';
  }

  @override
  String get detailSynopsisTitle => 'Synopsis';

  @override
  String get detailDiscoverPrompt =>
      'See what\'s ready before you pick an episode.';

  @override
  String get detailPlaybackNotReady =>
      'This anime is not ready to play right now.';

  @override
  String get detailCheckingSources => 'Checking sources...';

  @override
  String get detailPlaybackHint =>
      'We\'ll reuse your last working source and server when possible.';

  @override
  String detailContinueEpisode(Object episode) {
    return 'Continue from episode $episode';
  }

  @override
  String get detailContinueBadge => 'Resume';

  @override
  String detailPlaybackSources(int count) {
    return 'Ready in $count sources';
  }

  @override
  String get homeHeroTitle => 'Find something fast and start watching sooner.';

  @override
  String get homeHeroSubtitle =>
      'Search AniList, check real source availability, and jump into playback with fewer steps.';

  @override
  String get homeSearchAction => 'Search';

  @override
  String get homeTrendingSection => 'Trending now';

  @override
  String get homeTrendingHint =>
      'Open any title to see if it\'s actually ready to watch.';

  @override
  String get searchHeroTitle => 'Search by title';

  @override
  String get searchPromptShort => 'Search a title to see matching anime.';

  @override
  String timeAgoMinutes(int count) {
    return '${count}m ago';
  }

  @override
  String timeAgoHours(int count) {
    return '${count}h ago';
  }

  @override
  String timeAgoDays(int count) {
    return '${count}d ago';
  }

  @override
  String get playbackPreparing => 'Preparing playback...';

  @override
  String get playbackOpeningSelectedServer => 'Opening selected server...';

  @override
  String get serverPickerTitle => 'Choose a server';

  @override
  String get serverPickerSubtitle =>
      'Only servers that can actually open are shown here.';

  @override
  String get serverPickerRememberSelectionTitle => 'Remember this selection';

  @override
  String get serverPickerRememberSelectionSubtitle =>
      'Use this source and server first next time if they are still available.';

  @override
  String get serverPickerAllSources => 'All sources';

  @override
  String serverPickerSourceFilter(Object sourceName, Object count) {
    return '$sourceName $count';
  }

  @override
  String serverPickerSourceOptionCount(Object count) {
    return '$count options';
  }

  @override
  String serverPickerCurrentRemembered(Object sourceName, Object serverName) {
    return 'Remembered now: $sourceName / $serverName';
  }

  @override
  String get serverPickerUnknownSource => 'Unknown source';

  @override
  String get serverPickerUnknownServer => 'Unknown server';

  @override
  String get serverOptionLastUsed => 'Last used';

  @override
  String get serverOptionRecommended => 'Recommended';

  @override
  String get episodeAutoplayFailed =>
      'That shortcut didn\'t open. Choose another server.';

  @override
  String get episodePlaybackUnavailable =>
      'This episode is not ready to play right now.';

  @override
  String get episodeSelectedServerFailed =>
      'That server is not available right now.';

  @override
  String get episodeLockedLabel => 'Unavailable';

  @override
  String get episodePlayNowLabel => 'Play now';

  @override
  String get episodeListUsingPreference =>
      'Tap an episode and Kumoriya will try your best source first.';

  @override
  String episodeListUsingRememberedSource(
    Object sourceName,
    Object serverName,
  ) {
    return 'We\'ll start with $sourceName $serverName when it\'s still available.';
  }

  @override
  String playerSourceSummary(Object serverName, Object resolverName) {
    return 'Playing from $serverName via $resolverName';
  }

  @override
  String playerAudioPreference(Object value) {
    return 'Audio: $value';
  }

  @override
  String get myListHistory => 'History';

  @override
  String get myListFavorites => 'Favorites';

  @override
  String get myListSubscribed => 'Subscribed';

  @override
  String get myListDownloads => 'Downloads';

  @override
  String get myListHistoryHint => 'Your watch history';

  @override
  String get myListFavoritesEmpty =>
      'No favorites yet. Tap the heart on any anime to save it.';

  @override
  String get myListSubscribedEmpty =>
      'No subscriptions yet. Subscribe to an anime to get notified of new episodes.';

  @override
  String get myListDownloadsEmpty =>
      'No downloads yet. Download episodes from the episode list.';

  @override
  String get addFavorite => 'Add to favorites';

  @override
  String get removeFavorite => 'Remove from favorites';

  @override
  String get subscribe => 'Notify new episodes';

  @override
  String get unsubscribe => 'Stop notifications';

  @override
  String get favoriteAdded => 'Added to favorites';

  @override
  String get favoriteRemoved => 'Removed from favorites';

  @override
  String get subscribedLabel => 'Subscribed';

  @override
  String get unsubscribedLabel => 'Unsubscribed';

  @override
  String get downloadEpisode => 'Download';

  @override
  String get downloadAll => 'Download All';

  @override
  String get downloadQueued => 'Download queued';

  @override
  String get downloadAllQueued => 'All episodes queued for download';

  @override
  String get downloadSourceUnavailable =>
      'No downloads available from this source. Choose another source.';

  @override
  String get downloadInProgress => 'Downloading...';

  @override
  String get downloadComplete => 'Downloaded';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get downloadFileNotFound =>
      'Downloaded file not found — it may have been deleted.';

  @override
  String get downloadPaused => 'Paused';

  @override
  String get downloadPending => 'Pending';

  @override
  String get downloadCancel => 'Cancel';

  @override
  String get downloadClearQueue => 'Clear queue';

  @override
  String get downloadClearQueueConfirmTitle => 'Clear queue?';

  @override
  String get downloadClearQueueConfirmMessage =>
      'This will remove all pending and failed downloads from the queue. This action cannot be undone.';

  @override
  String get downloadRetry => 'Retry';

  @override
  String get downloadDelete => 'Delete';

  @override
  String get downloadPause => 'Pause';

  @override
  String get downloadResume => 'Resume';

  @override
  String get downloadFolderTitle => 'Download folder';

  @override
  String get downloadFolderDescription =>
      'New episode downloads will be saved in this location.';

  @override
  String get downloadFolderDefault => 'Default';

  @override
  String get downloadFolderCustom => 'Custom';

  @override
  String get downloadFolderChange => 'Change folder';

  @override
  String get downloadFolderReset => 'Use default folder';

  @override
  String get downloadFolderSaved => 'Download folder updated.';

  @override
  String get downloadFolderResetDone => 'Download folder reset to default.';

  @override
  String get downloadFolderSelectionCancelled => 'Folder selection cancelled.';

  @override
  String get downloadFolderPermissionDenied =>
      'Storage permission was not granted for an external download folder.';

  @override
  String get autoDownload => 'Auto-download new episodes';

  @override
  String get autoDownloadEnabled => 'Auto-download enabled';

  @override
  String get autoDownloadDisabled => 'Auto-download disabled';

  @override
  String get autoDownloadAudioPreference => 'Audio preference';

  @override
  String get autoDownloadAudioAny => 'Any';

  @override
  String get autoDownloadAudioSub => 'SUB';

  @override
  String get autoDownloadAudioDub => 'DUB';

  @override
  String get downloadAllChooseAudio => 'Choose audio type';

  @override
  String get downloadHlsNotSupported => 'HLS streams cannot be downloaded';

  @override
  String get downloadSelectQuality => 'Select quality';

  @override
  String get downloadSelectServer => 'Select server';

  @override
  String get playEpisode => 'Play episode';

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navLibrary => 'Library';

  @override
  String get navDownloads => 'Downloads';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get calendarSubtitle => 'Airing schedule by date';

  @override
  String get calendarNoAiring => 'No airing anime found.';

  @override
  String get calendarUnknownSchedule => 'Unknown schedule';

  @override
  String get calendarToday => 'Today';

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String get downloadsSubtitle => 'Offline episodes';

  @override
  String get downloadsTabActive => 'Active';

  @override
  String get downloadsTabQueue => 'Queue';

  @override
  String get downloadsTabCompleted => 'Completed';

  @override
  String get downloadsActiveEmpty => 'No active downloads.';

  @override
  String get downloadsQueueEmpty => 'No downloads queued.';

  @override
  String get downloadsCompletedEmpty => 'No completed downloads.';

  @override
  String get libraryTitle => 'Library';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsNotificationsTitle => 'Notifications';

  @override
  String get settingsNotificationsDescription =>
      'Subscriptions use system notifications for new episode alerts.';

  @override
  String get settingsEnableNotifications => 'Enable notifications';

  @override
  String get settingsOpenSystemSettings => 'Open system settings';

  @override
  String get settingsStatusAllowed => 'Allowed';

  @override
  String get settingsStatusBlocked => 'Blocked';

  @override
  String get settingsStatusUnknown => 'Unknown';

  @override
  String get settingsAppTitle => 'App';

  @override
  String get settingsThemeLabel => 'Theme';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get settingsVersionLabel => 'Version';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageSpanish => 'Spanish';

  @override
  String get settingsDesktopOnlyVisibleNote =>
      'On Windows only desktop-relevant settings are shown.';

  @override
  String get settingsPlaybackPreferencesTitle => 'Playback preferences';

  @override
  String get settingsPlaybackPreferencesDescription =>
      'Clear remembered source, server, and resolver choices so playback starts fresh.';

  @override
  String get settingsPlaybackPreferencesClear => 'Clear saved preferences';

  @override
  String get settingsPlaybackPreferencesCleared =>
      'Saved playback preferences cleared';

  @override
  String get playerBack => 'Back';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerSubtitles => 'Subtitles';

  @override
  String get playerQuality => 'Quality';

  @override
  String get playerNextEpisode => 'Next episode';

  @override
  String get playerPreviousEpisode => 'Previous episode';

  @override
  String get playerRetry => 'RETRY';

  @override
  String get playerSkipBackward => '-10s';

  @override
  String get playerSkipForward => '+10s';

  @override
  String get playerUnlockRotation => 'Unlock rotation';

  @override
  String get playerLockRotation => 'Lock rotation';

  @override
  String get playerDisableSubtitles => 'Disable';

  @override
  String get resumeLabel => 'RESUME';

  @override
  String get detailPlay => 'Play';

  @override
  String detailResumeEpisode(int episode) {
    return 'Resume EP $episode';
  }

  @override
  String get searchPageTitle => 'Search';

  @override
  String get homeAiringToday => 'Airing Today';

  @override
  String get myListHistoryEmpty => 'No watch history yet.';

  @override
  String downloadEpisodesCount(int count) {
    return '$count episodes';
  }

  @override
  String downloadEpisodeLabel(int episode) {
    return 'Episode $episode';
  }

  @override
  String get downloadedSourceLabel => 'Downloaded';

  @override
  String get downloadAllFromSource => 'Download all from a source';

  @override
  String get sectionSeeAll => 'See all';

  @override
  String get statusAiring => 'AIRING';

  @override
  String get statusUpcoming => 'UPCOMING';

  @override
  String get statusFinished => 'FINISHED';

  @override
  String get statusCancelled => 'CANCELLED';

  @override
  String get statusOnHiatus => 'ON HIATUS';

  @override
  String get statusUnknown => 'UNKNOWN';

  @override
  String get settingsSubtitleTitle => 'Subtitles';

  @override
  String get settingsSubtitleDescription =>
      'Customize subtitle appearance during playback.';

  @override
  String get settingsSubtitleFontSize => 'Font size';

  @override
  String get settingsSubtitleFontColor => 'Font color';

  @override
  String get settingsSubtitleFontOpacity => 'Font opacity';

  @override
  String get settingsSubtitleBgColor => 'Background color';

  @override
  String get settingsSubtitleBgOpacity => 'Background opacity';

  @override
  String get settingsSubtitleBgBlack => 'Black';

  @override
  String get settingsSubtitleBgDarkGray => 'Dark gray';

  @override
  String get settingsSubtitleBgNone => 'None';

  @override
  String get settingsSubtitleEdgeStyle => 'Edge style';

  @override
  String get settingsSubtitleEdgeNone => 'None';

  @override
  String get settingsSubtitleEdgeOutline => 'Outline';

  @override
  String get settingsSubtitleEdgeDropShadow => 'Drop shadow';

  @override
  String get settingsSubtitleEdgeRaised => 'Raised';

  @override
  String get settingsSubtitleEdgeDepressed => 'Depressed';

  @override
  String get settingsSubtitleSmall => 'S';

  @override
  String get settingsSubtitleMedium => 'M';

  @override
  String get settingsSubtitleLarge => 'L';

  @override
  String get settingsSubtitleExtraLarge => 'XL';

  @override
  String get settingsSubtitleBackground => 'Show background behind subtitles';

  @override
  String get playerSubtitleStyle => 'Subtitle style';

  @override
  String get playerSubtitleStyleDescription =>
      'Improve readability without leaving the player.';

  @override
  String get playerSkipIntro => 'Skip intro';

  @override
  String get playerSkipCredits => 'Skip credits';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get sourceServerLinksEmpty =>
      'No server links available for this episode.';

  @override
  String get downloadDeleteConfirmTitle => 'Delete download?';

  @override
  String get downloadDeleteConfirmMessage =>
      'This downloaded episode will be permanently removed from your device.';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get playerLockControls => 'Lock controls';

  @override
  String get historyGroupToday => 'Today';

  @override
  String get historyGroupYesterday => 'Yesterday';

  @override
  String get historyGroupThisWeek => 'This Week';

  @override
  String get historyGroupThisMonth => 'This Month';

  @override
  String get historyGroupOlder => 'Older';

  @override
  String get historyDeleteEntryTitle => 'Remove from history?';

  @override
  String get historyDeleteEntryMessage =>
      'This anime will be removed from your watch history.';

  @override
  String get historyClearAllTitle => 'Clear all history?';

  @override
  String get historyClearAllMessage =>
      'Your entire watch history will be permanently deleted.';

  @override
  String get historyClearAllAction => 'Clear all history';

  @override
  String get deleteAction => 'Delete';

  @override
  String get removeAction => 'Remove';

  @override
  String get downloadViewAnimeDetails => 'View anime details';

  @override
  String get downloadDeleteAllEpisodes => 'Delete all episodes';

  @override
  String get downloadDeleteEpisode => 'Delete episode';

  @override
  String get downloadDeleteAllConfirmTitle => 'Delete all downloaded episodes?';

  @override
  String get downloadDeleteAllConfirmMessage =>
      'All downloaded episodes for this anime will be permanently removed.';

  @override
  String get librarySortAlphabetical => 'A-Z';

  @override
  String get librarySortRecentlyAdded => 'Recently added';

  @override
  String get librarySortRecentlyWatched => 'Recently watched';

  @override
  String get libraryActionSave => 'Save';

  @override
  String get libraryActionNotify => 'Notify';

  @override
  String get libraryActionAutoDownload => 'Auto DL';

  @override
  String get discoverTitle => 'Discover';

  @override
  String get discoverSubtitle => 'Find your next anime';

  @override
  String get discoverTrending => 'Trending Now';

  @override
  String get discoverTopRated => 'Top Rated';

  @override
  String get discoverPopular => 'Most Popular';

  @override
  String get discoverGenres => 'Browse by Genre';

  @override
  String get discoverCantRemember => 'Can\'t remember the name?';

  @override
  String get discoverCantRememberSubtitle =>
      'Find anime by describing what it\'s about';

  @override
  String get discoverStartTagSearch => 'Start tag search';

  @override
  String get browseResultsTitle => 'Browse Results';

  @override
  String get browseNoResults => 'No anime found with these filters.';

  @override
  String get browseFilterGenre => 'Genre';

  @override
  String get browseFilterFormat => 'Format';

  @override
  String get browseFilterSeason => 'Season';

  @override
  String get browseFilterYear => 'Year';

  @override
  String get browseFilterSort => 'Sort by';

  @override
  String get browseFilterStatus => 'Status';

  @override
  String get browseFilterTags => 'Tags';

  @override
  String get browseFilterApply => 'Apply filters';

  @override
  String get browseFilterClear => 'Clear filters';

  @override
  String get browseSortTrending => 'Trending';

  @override
  String get browseSortScore => 'Score';

  @override
  String get browseSortPopularity => 'Popularity';

  @override
  String get browseSortFavourites => 'Favourites';

  @override
  String get browseSortNewest => 'Newest';

  @override
  String get browseSortTitle => 'Title';

  @override
  String get tagSearchTitle => 'Find by Tags';

  @override
  String get tagSearchSubtitle =>
      'Select tags that describe the anime you\'re looking for';

  @override
  String get tagSearchSelectCategory => 'Select a category';

  @override
  String tagSearchSelectedTags(int count) {
    return '$count tags selected';
  }

  @override
  String get tagSearchFindAnime => 'Find anime';

  @override
  String get tagSearchNoTags => 'No tags selected yet';

  @override
  String get tagSearchGuideStep1 => 'Open a category to see its tags';

  @override
  String get tagSearchGuideStep2 => 'Tap tags that match what you remember';

  @override
  String get tagSearchGuideStep3 => 'Press find to see matching anime';

  @override
  String get tagSearchFilterHint => 'Filter tags by name...';

  @override
  String browseGenreApply(int count) {
    return 'Apply ($count)';
  }

  @override
  String get formatTv => 'TV';

  @override
  String get formatMovie => 'Movie';

  @override
  String get formatOva => 'OVA';

  @override
  String get formatOna => 'ONA';

  @override
  String get formatSpecial => 'Special';

  @override
  String get downloadRetryAllFailed => 'Retry all';

  @override
  String get downloadPauseAll => 'Pause all';

  @override
  String get downloadResumeAll => 'Resume all';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileNotSignedIn => 'Not signed in';

  @override
  String get profileSignIn => 'Sign In';

  @override
  String get profileLinkedAccounts => 'Linked Accounts';

  @override
  String get profileNoLinkedAccounts => 'No linked accounts';

  @override
  String get profileCouldNotLoadAccounts => 'Could not load accounts';

  @override
  String get profileActiveSessions => 'Active Sessions';

  @override
  String get profileNoActiveSessions => 'No active sessions';

  @override
  String get profileCouldNotLoadSessions => 'Could not load sessions';

  @override
  String get profilePasskeys => 'Passkeys';

  @override
  String get profileNoPasskeys => 'No passkeys registered';

  @override
  String get profileCouldNotLoadPasskeys => 'Could not load passkeys';

  @override
  String get profileSync => 'Sync';

  @override
  String get profileSyncStatus => 'Status';

  @override
  String get profileLastSynced => 'Last synced';

  @override
  String get profileLastSyncedNever => 'Never';

  @override
  String get profileSyncNow => 'Sync now';

  @override
  String get profileDeleteAccount => 'Delete Account';

  @override
  String get profileLogOut => 'Log out';

  @override
  String get profileLogOutBody => 'Your local data will be kept.';

  @override
  String get profileCancel => 'Cancel';

  @override
  String get profileDeleteAccountWarning =>
      'This will permanently delete your account and all synced data. This cannot be undone.';

  @override
  String get profileDelete => 'Delete';

  @override
  String get profileUnknownDevice => 'Unknown device';

  @override
  String get profileUnnamedPasskey => 'Unnamed passkey';

  @override
  String get profileUnknownProvider => 'Unknown';

  @override
  String get profileNoEmail => 'No email';

  @override
  String get settingsAutoDeleteWatched => 'Auto-delete watched downloads';

  @override
  String get settingsAutoDeleteNever => 'Never';

  @override
  String settingsAutoDeleteAfterDays(int days) {
    return 'After $days days';
  }

  @override
  String get settingsAutoDeleteImmediately => 'Immediately';
}
