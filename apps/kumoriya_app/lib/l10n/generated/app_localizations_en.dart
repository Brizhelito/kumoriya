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
  String get continueWatching => 'Continue Watching';

  @override
  String get continueWatchingHint => 'Jump back in where you left off.';

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
}
