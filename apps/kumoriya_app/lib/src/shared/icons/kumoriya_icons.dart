import 'package:flutter/material.dart';

/// Shared icon registry so icon-set migrations (for example Tabler) stay local.
abstract final class KumoriyaIcons {
  // Navigation
  static const IconData navHome = Icons.home_outlined;
  static const IconData navHomeActive = Icons.home_rounded;
  static const IconData navSearch = Icons.search_rounded;
  static const IconData navSearchActive = Icons.search_rounded;
  static const IconData navCalendar = Icons.calendar_today_outlined;
  static const IconData navCalendarActive = Icons.calendar_today_rounded;
  static const IconData navLibrary = Icons.video_library_outlined;
  static const IconData navLibraryActive = Icons.video_library_rounded;
  static const IconData navDownloads = Icons.download_outlined;
  static const IconData navDownloadsActive = Icons.download_rounded;
  static const IconData navSettings = Icons.settings_outlined;
  static const IconData navSettingsActive = Icons.settings_rounded;

  // Common/state
  static const IconData search = Icons.search_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData refresh = Icons.refresh_rounded;
  static const IconData error = Icons.error_outline_rounded;
  static const IconData history = Icons.history_rounded;
  static const IconData favoriteOutline = Icons.favorite_border_rounded;
  static const IconData notifications = Icons.notifications_none_rounded;
  static const IconData notificationsActive =
      Icons.notifications_active_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData sync = Icons.sync_rounded;
  static const IconData bugReport = Icons.bug_report_rounded;

  // Player
  static const IconData playerBack = Icons.arrow_back_rounded;
  static const IconData playerNextEpisode = Icons.skip_next_rounded;
  static const IconData playerPreviousEpisode = Icons.skip_previous_rounded;
  static const IconData playerAudio = Icons.audiotrack_rounded;
  static const IconData playerSubtitle = Icons.subtitles_rounded;
  static const IconData playerQuality = Icons.hd_rounded;
  static const IconData playerPlay = Icons.play_arrow_rounded;
  static const IconData playerPause = Icons.pause_rounded;
  static const IconData playerSeekBack10 = Icons.replay_10_rounded;
  static const IconData playerSeekForward10 = Icons.forward_10_rounded;
  static const IconData playerFullscreen = Icons.fullscreen_rounded;
  static const IconData playerFullscreenExit = Icons.fullscreen_exit_rounded;
}
