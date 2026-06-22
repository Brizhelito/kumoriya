import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../anime_catalog/application/models/episode_playback.dart';
import '../../anime_catalog/application/models/resolved_server_link_result.dart';
import '../../anime_catalog/application/models/source_availability.dart';
import '../../anime_catalog/presentation/providers/anime_catalog_providers.dart';
import '../../downloads/presentation/download_providers.dart';

/// Immutable context needed to navigate between episodes.
class EpisodeContext {
  const EpisodeContext({
    required this.anilistId,
    required this.currentEpisodeNumber,
    this.totalEpisodes,
    this.nextAiringEpisodeNumber,
  });

  final int anilistId;
  final double currentEpisodeNumber;
  final int? totalEpisodes;
  final double? nextAiringEpisodeNumber;
}

/// Result of an episode navigation attempt.
sealed class EpisodeNavigationResult {
  const EpisodeNavigationResult();
}

/// Episode is ready to play — resolved stream or offline file.
class EpisodeReady extends EpisodeNavigationResult {
  const EpisodeReady({
    required this.episodeNumber,
    required this.resolved,
    required this.sourcePluginId,
    required this.serverName,
    this.episodeTitle,
    this.audioPreference,
  });

  final int episodeNumber;
  final ResolvedServerLinkResult resolved;
  final String sourcePluginId;
  final String serverName;
  final String? episodeTitle;
  final PlaybackAudioPreference? audioPreference;
}

/// Episode is available offline (downloaded).
class EpisodeOffline extends EpisodeNavigationResult {
  const EpisodeOffline({
    required this.episodeNumber,
    required this.localPath,
    required this.resolved,
    this.episodeTitle,
  });

  final int episodeNumber;
  final String localPath;
  final ResolvedServerLinkResult resolved;
  final String? episodeTitle;
}

/// Episode is not available (no sources, not downloaded, or not aired).
class EpisodeUnavailable extends EpisodeNavigationResult {
  const EpisodeUnavailable({this.reason});

  final String? reason;
}

/// UI-agnostic controller for episode navigation.
///
/// Handles: canGoNext/canGoPrevious checks, offline download lookup,
/// source availability resolution, and stream resolution.
///
/// Does NOT handle: UI navigation, loaders, server pickers, or player state.
class EpisodeNavigationController {
  EpisodeNavigationController({required this.ref});

  final Ref ref;

  /// Whether a next episode exists and has aired.
  bool canGoNext(EpisodeContext context) {
    final total = context.totalEpisodes;
    if (total == null) return false;
    if (context.currentEpisodeNumber >= total) return false;

    final nextAiring = context.nextAiringEpisodeNumber;
    if (nextAiring != null) {
      final nextEpisode = context.currentEpisodeNumber + 1;
      return nextEpisode < nextAiring;
    }

    return true;
  }

  /// Whether a previous episode exists.
  bool canGoPrevious(EpisodeContext context) {
    return context.currentEpisodeNumber > 1;
  }

  /// Resolves the next episode.
  Future<EpisodeNavigationResult> goToNext(EpisodeContext context) {
    final target = (context.currentEpisodeNumber + 1).round();
    return _resolveEpisode(context, target);
  }

  /// Resolves the previous episode.
  Future<EpisodeNavigationResult> goToPrevious(EpisodeContext context) {
    final target = (context.currentEpisodeNumber - 1).round();
    if (target <= 0) {
      return Future.value(
        const EpisodeUnavailable(reason: 'No previous episode'),
      );
    }
    return _resolveEpisode(context, target);
  }

  /// Resolves an arbitrary episode by number.
  Future<EpisodeNavigationResult> goToEpisode(
    EpisodeContext context,
    double episodeNumber,
  ) {
    final target = episodeNumber.round();
    if (target <= 0) {
      return Future.value(
        const EpisodeUnavailable(reason: 'Invalid episode number'),
      );
    }
    return _resolveEpisode(context, target);
  }

  Future<EpisodeNavigationResult> _resolveEpisode(
    EpisodeContext context,
    int targetEpisode,
  ) async {
    // 1. Check offline downloads first.
    final offlineResult = await _checkDownloadedEpisode(
      context.anilistId,
      targetEpisode,
    );
    if (offlineResult != null) return offlineResult;

    // 2. Resolve via source availability.
    return _resolveViaSources(context, targetEpisode);
  }

  Future<EpisodeOffline?> _checkDownloadedEpisode(
    int anilistId,
    int episodeNumber,
  ) async {
    final downloadManager = ref.read(downloadManagerProvider);
    final task = await downloadManager.findTaskByEpisode(
      anilistId,
      episodeNumber.toDouble(),
    );
    if (task == null ||
        task.status != DownloadStatus.completed ||
        task.filePath == null ||
        task.filePath!.trim().isEmpty) {
      return null;
    }

    final file = File(task.filePath!);
    if (!await file.exists()) return null;

    return EpisodeOffline(
      episodeNumber: episodeNumber,
      localPath: file.path,
      episodeTitle: task.episodeTitle,
      resolved: ResolvedServerLinkResult(
        resolverId: 'offline',
        resolverName: 'Offline',
        streams: const <ResolvedStream>[],
      ),
    );
  }

  Future<EpisodeNavigationResult> _resolveViaSources(
    EpisodeContext context,
    int targetEpisode,
  ) async {
    // Fetch source availability summary.
    final summaryResult = await ref.read(
      sourceAvailabilitySummaryProvider(context.anilistId).future,
    );
    final summary = summaryResult.fold(
      onFailure: (_) => null,
      onSuccess: (value) => value,
    );
    if (summary == null) {
      return const EpisodeUnavailable(reason: 'No source availability');
    }

    // Use the playback use case to resolve the episode.
    final decision = await ref
        .read(startEpisodePlaybackUseCaseProvider)
        .call(
          anilistId: context.anilistId,
          episodeNumber: targetEpisode.toDouble(),
          availabilitySummary: summary,
        );

    switch (decision.type) {
      case EpisodePlaybackDecisionType.direct:
        final launch = decision.launch;
        if (launch == null) {
          return const EpisodeUnavailable(reason: 'No direct stream available');
        }
        return EpisodeReady(
          episodeNumber: targetEpisode,
          resolved: launch.resolved,
          sourcePluginId: launch.option.sourcePluginId,
          serverName: launch.option.serverLink.serverName,
          episodeTitle: launch.option.sourceEpisode.title.trim().isEmpty
              ? null
              : launch.option.sourceEpisode.title.trim(),
          audioPreference: switch (launch.option.audioKind) {
            SourceAudioKind.sub => PlaybackAudioPreference.sub,
            SourceAudioKind.dub => PlaybackAudioPreference.dub,
            null => null,
          },
        );
      case EpisodePlaybackDecisionType.selection:
        // Multiple sources available — UI must show picker.
        return const EpisodeUnavailable(
          reason: 'Multiple sources available — show server picker',
        );
      case EpisodePlaybackDecisionType.unavailable:
        return const EpisodeUnavailable(reason: 'Episode not available');
    }
  }
}

/// Riverpod provider for the episode navigation controller.
final episodeNavigationControllerProvider =
    Provider<EpisodeNavigationController>((ref) {
      return EpisodeNavigationController(ref: ref);
    });
