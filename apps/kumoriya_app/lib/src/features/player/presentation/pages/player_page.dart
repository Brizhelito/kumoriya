import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/resolved_server_link_result.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/icons/kumoriya_icons.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../anime_catalog/application/models/episode_playback.dart';
import '../../../anime_catalog/application/models/source_availability.dart';
import '../../../anime_catalog/presentation/pages/episode_list_page.dart';
import '../../../anime_catalog/presentation/providers/anime_catalog_providers.dart';
import '../../../anime_catalog/presentation/providers/storage_providers.dart';
import '../../../anime_catalog/presentation/support/playback_launch_flow.dart';
import '../../../downloads/presentation/download_providers.dart';
import '../../application/models/subtitle_settings.dart';
import '../../application/models/embedded_tracks.dart';
import '../../application/models/player_diagnostics.dart';
import '../../../anime_catalog/application/services/mal_metadata_bridge_service.dart';
import '../../application/models/player_session_state.dart';
import '../../application/services/player_performance_probe.dart';
import '../../application/services/player_session_orchestrator.dart';
import '../../application/use_cases/clear_playback_preference_use_case.dart';
import '../../application/use_cases/save_playback_preference_use_case.dart';
import '../../application/use_cases/save_progress_use_case.dart';
import '../../application/services/playback_engine.dart';
import '../../infrastructure/playback_engine_factory.dart';
import '../../infrastructure/kumoriya_exoplayer_engine.dart';
import '../widgets/player_video_surface.dart';
import '../widgets/player_debug_overlay.dart';
import '../../../watch_party/application/party_session_guard.dart';
import '../../../watch_party/application/providers/party_providers.dart';
import '../../../watch_party/presentation/pages/party_anime_page.dart';
import '../../../watch_party/presentation/pages/party_episode_list_page.dart';
import '../../../watch_party/presentation/pages/party_lobby_page.dart';
import '../../../watch_party/presentation/party_route_mode.dart';
import '../../../watch_party/presentation/widgets/party_player_overlay.dart';

const bool _playerVerboseLogs = bool.fromEnvironment(
  'PLAYER_VERBOSE_LOGS',
  defaultValue: false,
);

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({
    super.key,
    required this.anilistId,
    required this.animeTitle,
    required this.episodeNumber,
    this.episodeTitle,
    required this.sourcePluginId,
    required this.serverName,
    this.persistSelection = true,
    this.preferredAudioPreference,
    this.totalEpisodes,
    this.nextAiringEpisodeNumber,
    this.routeMode = PartyRouteMode.standard,
    required this.resolved,
  });

  final int anilistId;
  final String animeTitle;
  final String episodeNumber;
  final String? episodeTitle;
  final String sourcePluginId;
  final String serverName;
  final bool persistSelection;
  final PlaybackAudioPreference? preferredAudioPreference;
  final int? totalEpisodes;
  final double? nextAiringEpisodeNumber;
  final PartyRouteMode routeMode;
  final ResolvedServerLinkResult resolved;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  PlaybackEngine? _engine;
  PlayerSessionOrchestrator? _orchestrator;
  late final SaveProgressUseCase _saveProgress;
  late final SavePlaybackPreferenceUseCase _savePlaybackPreference;
  late final ClearPlaybackPreferenceUseCase _clearPlaybackPreference;

  StreamSubscription<PlayerSessionState>? _sessionSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completionSub;
  Timer? _periodicSaveTimer;
  Future<void>? _pendingProgressFlush;
  bool _isExiting = false;
  bool _historyWrittenForSession = false;
  bool _forceSoftwareVideoOutput = false;
  bool _isWindowsFullscreen = false;
  bool? _windowsFullscreenBeforePlayback;
  bool _autoNextTriggeredByEndingResidual = false;
  bool _autoSkipEnabled = false; // TODO: persist via settings store
  List<AniSkipSegment> _aniSkipSegments = const <AniSkipSegment>[];
  Future<void>? _pendingAniSkipLoad;
  final Set<String> _autoSkippedSegments = <String>{};

  PlayerSessionState _state = const PlayerSessionState.idle();
  String? _startError;

  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  Duration? _resumePosition;
  DateTime _lastPositionSetState = DateTime(0);
  bool _isScrubbing = false;
  double? _scrubPositionMs;
  EmbeddedTracks _embeddedTracks = EmbeddedTracks.empty;
  StreamSubscription<EmbeddedTracks>? _tracksSub;
  EmbeddedAudioTrack? _activeAudioTrack;
  EmbeddedSubtitleTrack? _activeEmbeddedSubtitleTrack;
  ExternalSubtitleTrack? _activeExternalSubtitleTrack;
  bool _autoPickedSubtitle = false;
  late final String _instanceId = identityHashCode(this).toRadixString(16);
  bool _partyPlayerReadySent = false;
  bool _partyPauseHoldPending = false;

  /// Subscription to `partySessionProvider` used to detect when the party
  /// room has moved to a different anime/episode while this player is still
  /// pushed in the navigation stack below the new one. When that happens
  /// the audio of this stale page must be cut immediately so the host does
  /// not hear two episodes at once.
  ProviderSubscription<PartySessionState>? _partyRoomSub;
  bool _stalePlayerHandled = false;

  // Debounces orientation restoration so that pushReplacement to a new
  // PlayerPage can cancel it in initState, preventing a portrait flash.
  static Timer? _orientationRestoreTimer;
  static bool _suppressOrientationRestore = false;

  double get _episodeNumberDouble =>
      double.tryParse(widget.episodeNumber) ?? 0.0;

  /// Whether the current episode is known to not be the last one AND the next
  /// episode has already aired.
  /// If [totalEpisodes] is unknown we default to **false** so we do not
  /// advertise a "next" episode that may not exist (safer UX than dropping
  /// the user into an `unavailable` state). Parses the episode number as a
  /// double so fractional episodes (e.g. 7.5) do not collapse to 0 and
  /// silently disable the button.
  /// For airing anime, also checks [nextAiringEpisodeNumber] to ensure the
  /// next episode has been released.
  bool get _hasNextEpisode {
    final total = widget.totalEpisodes;
    if (total == null) return false;
    final current = double.tryParse(widget.episodeNumber) ?? 0;
    if (current >= total) return false;

    // For airing anime, verify the next episode has been released
    final nextAiring = widget.nextAiringEpisodeNumber;
    if (nextAiring != null) {
      final nextEpisode = current + 1;
      // Next episode is available only if it's before the next airing episode
      return nextEpisode < nextAiring;
    }

    // If no nextAiringEpisodeNumber, assume all episodes up to total are available
    return true;
  }

  @override
  void initState() {
    super.initState();
    // Hold a screen wakelock for the entire player lifetime. Without this,
    // Android's inactivity timer (very aggressive on MIUI / Redmi devices)
    // dims the screen to ~30 % a few seconds before the configured display
    // timeout and then sleeps. The user sees the brightness drop on its
    // own and a screen tap restores it — exactly the bug reported on the
    // Redmi Note 9. Touching the screen resets the timer, which is why
    // the controls (which the user does tap) momentarily fix it.
    unawaited(WakelockPlus.enable());
    _saveProgress = SaveProgressUseCase(
      store: ref.read(animeProgressStoreProvider),
    );
    _savePlaybackPreference = SavePlaybackPreferenceUseCase(
      store: ref.read(animeProgressStoreProvider),
    );
    _clearPlaybackPreference = ClearPlaybackPreferenceUseCase(
      store: ref.read(animeProgressStoreProvider),
    );
    _log(
      'init resolver=${widget.resolved.resolverId} server=${widget.serverName} streams=${widget.resolved.streams.map((stream) => stream.url.toString()).join(" | ")}',
    );
    unawaited(_initializeRuntimeAndStartPlayback());
    unawaited(_enterWindowsFullscreenIfSupported());
    // Cancel any pending orientation restore from a prior player page
    // (e.g. pushReplacement for next episode) to avoid portrait flash.
    _orientationRestoreTimer?.cancel();
    _orientationRestoreTimer = null;
    // Enter immersive landscape mode for video playback.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Wire party sync: listen for remote playback commands.
    // Use addPostFrameCallback to ensure the provider is fully initialized,
    // but guard with mounted since the widget may be disposed before the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _wirePartySyncCallbacks();
      _broadcastSourceSelectionIfHost();
    });

    // Detect when the party room moves on to a different anime or episode
    // while this page is still alive. That happens when a new PlayerPage is
    // pushed on top of the old one (host changing episode from the party
    // episode list, cross-anime `changeMedia`, etc.). The stale page must
    // cut audio immediately so the user does not hear two episodes at once.
    _partyRoomSub = ref.listenManual<PartySessionState>(
      partySessionProvider,
      (prev, next) => _detectStalePartyPlayer(next),
      fireImmediately: false,
    );
  }

  /// Pauses the engine and stops feeding the party sync pipeline when the
  /// active party room has moved to a different (anime, episode) pair than
  /// the one this page was launched for. Idempotent: only the first
  /// detection does work, later notifications are ignored.
  void _detectStalePartyPlayer(PartySessionState next) {
    if (_stalePlayerHandled || _isExiting) return;
    if (!next.isActive) return;
    final room = next.room;
    if (room == null) return;
    final localEp = double.tryParse(widget.episodeNumber);
    if (localEp == null) return;
    final sameAnime = room.anilistId == widget.anilistId;
    final sameEpisode =
        sameAnime && (room.episodeNumber - localEp).abs() < 0.001;
    if (sameAnime && sameEpisode) return;

    _stalePlayerHandled = true;
    _log(
      'party room moved to anilistId=${room.anilistId} '
      'ep=${room.episodeNumber}; this player is on anilistId=${widget.anilistId} '
      'ep=$localEp — cutting audio and detaching from party sync',
    );
    unawaited(_positionSub?.cancel());
    _positionSub = null;
    unawaited(_engine?.pause());
  }

  /// When a party is active and the local user is the host, announce the
  /// source/server picked for this episode so members can try to
  /// auto-resolve the same provider instead of going through their
  /// server picker manually. Non-hosts and idle sessions are no-ops.
  ///
  /// If the host just advanced to a different episode of the same anime
  /// (e.g. via the "next episode" or "previous episode" buttons, or an
  /// auto-advance residual from the AniSkip ending segment), this also
  /// emits a `change_episode` intent first so the Worker updates the room
  /// state and members navigate to the new episode. Without this the
  /// server still thinks the room is on the previous episode and members
  /// would stay watching the wrong one.
  void _broadcastSourceSelectionIfHost() {
    final session = ref.read(partySessionProvider);
    if (!session.isActive) return;
    final notifier = ref.read(partySessionProvider.notifier);
    if (!notifier.isLocalHost) return;
    final epNumber = double.tryParse(widget.episodeNumber);
    if (epNumber == null) return;

    // Propagate the host-local episode advance to the Worker so members
    // get the `episode_changed` broadcast and follow us. We only fire
    // this when the anime matches the one the room is already pointing
    // at; cross-anime changes go through `changeMedia` (initiated from
    // the lobby), not from the player.
    final room = session.room;
    if (room != null &&
        room.anilistId == widget.anilistId &&
        (room.episodeNumber - epNumber).abs() >= 0.001) {
      if (_playerVerboseLogs) {
        dev.log(
          'host episode advance roomEp=${room.episodeNumber} newEp=$epNumber '
          'anilistId=${widget.anilistId}',
          name: 'Party',
        );
      }
      notifier.changeEpisode(epNumber);
    }

    if (_playerVerboseLogs) {
      dev.log(
        'broadcasting source_selected source=${widget.sourcePluginId} '
        'server=${widget.serverName} resolver=${widget.resolved.resolverId} '
        'ep=$epNumber',
        name: 'Party',
      );
    }
    notifier.broadcastSourceSelected(
      sourcePluginId: widget.sourcePluginId,
      serverName: widget.serverName,
      resolverPluginId: widget.resolved.resolverId,
      episodeNumber: epNumber,
    );
  }

  @override
  void dispose() {
    _log('dispose');
    // Always release the screen wakelock when leaving the player so the
    // device returns to its normal display-timeout behavior.
    unawaited(WakelockPlus.disable());
    _periodicSaveTimer?.cancel();
    _partyDriftTimer?.cancel();
    _partyRoomSub?.close();
    _partyRoomSub = null;
    unawaited(_saveCurrentProgress());
    unawaited(_disposeRuntime());
    unawaited(_restoreWindowsFullscreenIfNeeded());
    _orientationRestoreTimer?.cancel();
    _orientationRestoreTimer = null;
    if (!_suppressOrientationRestore) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[]);
    }
    _suppressOrientationRestore = false;
    super.dispose();
  }

  Future<void> _installRuntime() async {
    await _disposeRuntime();
    final engine = createPlaybackEngine(
      forceSoftwareVideoOutput: _forceSoftwareVideoOutput,
      onVideoOutputFallbackRequested: _handleVideoOutputFallback,
    );
    final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

    _sessionSub = orchestrator.states.listen((next) {
      PlayerPerformanceProbe.instance.recordSessionStateEvent();
      _log(
        'session status=${next.status} index=${next.currentCandidateIndex}/${next.totalCandidates} info=${next.infoMessage} error=${next.errorMessage}',
      );
      if (mounted) {
        setState(() => _state = next);
      } else {
        _state = next;
      }
    });

    _positionSub = orchestrator.positionStream.listen((pos) {
      if (_isScrubbing || _resumePosition != null) {
        _log('position stream pos=$pos duration=$_currentDuration');
      }
      final resume = _resumePosition;
      if (resume != null && pos >= resume - const Duration(seconds: 5)) {
        _resumePosition = null;
      }
      if (!mounted) {
        _currentPosition = pos;
        _maybeAutoNextFromEndingResidual(pos);
        return;
      }
      final now = DateTime.now();
      final shouldTriggerSetState =
          now.difference(_lastPositionSetState).inMilliseconds >= 500;
      PlayerPerformanceProbe.instance.recordPositionEvent(
        triggeredSetState: shouldTriggerSetState,
      );
      if (shouldTriggerSetState) {
        _lastPositionSetState = now;
        setState(() => _currentPosition = pos);
      } else {
        _currentPosition = pos;
      }
      if (_autoSkipEnabled) {
        _maybeAutoSkipSegment();
      }
      _maybeAutoNextFromEndingResidual(pos);

      // Feed party sync engine with updated position.
      _updatePartyPlayback(positionMs: pos.inMilliseconds);
    });
    _durationSub = orchestrator.durationStream.listen((dur) {
      if (dur <= Duration.zero) {
        return;
      }
      PlayerPerformanceProbe.instance.recordDurationEvent();
      _log('duration stream dur=$dur');
      if (!mounted) {
        _currentDuration = dur;
        _maybeLoadAniSkipSegments();
        return;
      }
      setState(() => _currentDuration = dur);
      _maybeLoadAniSkipSegments();
    });

    _playingSub = engine.playingStream.listen(_onPlayingChanged);
    _tracksSub = orchestrator.embeddedTracksStream.listen((tracks) {
      PlayerPerformanceProbe.instance.recordTrackEvent();
      if (!mounted) {
        _embeddedTracks = tracks;
        return;
      }
      setState(() => _embeddedTracks = tracks);
      _maybeAutoPickSubtitle(tracks);
    });
    _completionSub = orchestrator.naturalCompletionStream.listen((_) {
      _onNaturalCompletion();
    });
    _engine = engine;
    _orchestrator = orchestrator;
  }

  Future<void> _initializeRuntimeAndStartPlayback() async {
    // Start loading resume position in parallel with runtime install
    // so the DB read overlaps with engine/orchestrator setup.
    final resumeFuture = _loadResumePosition();
    await _installRuntime();
    _resumePosition = await resumeFuture;
    await _startPlaybackFromPosition(_resumePosition);
  }

  Future<void> _disposeRuntime() async {
    await _sessionSub?.cancel();
    await _playingSub?.cancel();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _tracksSub?.cancel();
    await _completionSub?.cancel();
    _sessionSub = null;
    _playingSub = null;
    _positionSub = null;
    _durationSub = null;
    _tracksSub = null;
    _completionSub = null;
    _embeddedTracks = EmbeddedTracks.empty;
    _autoPickedSubtitle = false;
    final orchestrator = _orchestrator;
    _orchestrator = null;
    _engine = null;
    if (orchestrator != null) {
      await orchestrator.dispose();
    }
  }

  void _onPlayingChanged(bool playing) {
    PlayerPerformanceProbe.instance.recordPlayingEvent();
    _log('playing stream playing=$playing position=$_currentPosition');

    final partySession = ref.read(partySessionProvider);
    final partyNotifier = ref.read(partySessionProvider.notifier);
    final shouldPauseForParty =
        playing &&
        partySession.isActive &&
        _shouldHoldPartyPlayback(partySession);
    if (shouldPauseForParty) {
      _log(
        'playing stream hold active -> enforce party pause '
        'host=${partyNotifier.isLocalHost}',
      );
      unawaited(_enforcePartyPauseHold(force: true));
    }

    // Feed party sync engine.
    if (!shouldPauseForParty || !partyNotifier.isLocalHost) {
      _updatePartyPlayback(isPlaying: playing);
    }

    if (!playing) {
      unawaited(_saveCurrentProgress());
      unawaited(_updateWatchHistory());
    }
    if (playing) {
      if (!_historyWrittenForSession) {
        _historyWrittenForSession = true;
        unawaited(_updateWatchHistory());
      }
      _periodicSaveTimer ??= Timer.periodic(
        const Duration(seconds: 15),
        (_) => unawaited(_saveCurrentProgress()),
      );
    } else {
      _periodicSaveTimer?.cancel();
      _periodicSaveTimer = null;
    }
  }

  // ── Watch party sync hooks ──

  /// Threshold (ms) above which a position-stream jump is treated as a
  /// user-driven seek and broadcasted to other members (v2).
  static const int _partySeekDetectionMs = 2500;

  /// Minimum gap between consecutive host-seek broadcasts. Caps the cost of
  /// scrub-bar drags, which can emit dozens of detections per second.
  /// 500 ms pairs well with the Worker's `playback_intent` bucket (6/10s).
  static const Duration _partySeekThrottle = Duration(milliseconds: 500);

  /// How often the drift detector evaluates member-side playback against
  /// the projected host timeline. 30 s is long enough to keep DO request
  /// volume negligible (≤4 per 8 h party) while catching any drift big
  /// enough to matter (>2 s) well before a human notices it.
  static const Duration _partyDriftInterval = Duration(seconds: 30);

  /// Tolerance band for member drift. Below this the detector stays quiet;
  /// at or above it fires a single `resync_request` to the Worker.
  static const int _partyDriftToleranceMs = 2000;

  /// Minimum gap between consecutive `resync_request` emissions so a
  /// persistently-drifting device cannot hammer the DO.
  static const Duration _partyDriftResyncCooldown = Duration(seconds: 20);

  /// Last position seen by the host's seek detector (ms). `null` until the
  /// first position update after the player is ready.
  int? _lastHostPositionMs;

  /// Monotonic time of the last seek broadcast (host side), used to throttle
  /// scrub-bar drags into at most one intent per [_partySeekThrottle].
  DateTime? _lastPartySeekSentAt;

  /// Wall-clock reference captured from the most recent authoritative
  /// `playback_state_changed` we applied. Used by [_checkPartyDrift] to
  /// extrapolate where playback *should* be right now.
  DateTime? _partyLastAppliedAt;
  int? _partyLastAppliedPositionMs;
  bool _partyLastAppliedIsPlaying = false;

  /// Timer + cooldown for the member-side drift detector.
  Timer? _partyDriftTimer;
  DateTime? _lastResyncRequestAt;

  /// Wire the party sync engine to respond to remote playback commands.
  ///
  /// Supports both v1 (P2P via [PartySyncEngine]) and v2 (brokered realtime
  /// via [PartySessionNotifier.onSyncState]). The v2 path was previously
  /// unwired — playback events from the Worker reached the notifier but had
  /// no handler to apply them to the local player.
  void _wirePartySyncCallbacks() {
    final session = ref.read(partySessionProvider);
    if (!session.isActive) return;

    final notifier = ref.read(partySessionProvider.notifier);
    if (notifier.isLocalHost) {
      notifier.onSyncState = null;
      final syncEngine = notifier.syncEngine;
      if (syncEngine != null) {
        syncEngine.onSyncState = null;
      }
    }

    void applyRemote(bool isPlaying, int positionMs) {
      if (!mounted) return;
      final orchestrator = _orchestrator;
      if (orchestrator == null) return;

      if (_playerVerboseLogs) {
        dev.log(
          'remote sync: isPlaying=$isPlaying positionMs=$positionMs',
          name: 'Party',
        );
      }

      // Suppress local seek detection while we apply remote intent so we
      // don't echo it back to the party.
      _lastHostPositionMs = positionMs;

      // Snapshot the authoritative state so the member-side drift detector
      // can extrapolate "where should I be now?" between broadcasts.
      _partyLastAppliedAt = DateTime.now();
      _partyLastAppliedPositionMs = positionMs;
      _partyLastAppliedIsPlaying = isPlaying;

      final localPlaying = _state.status == PlayerSessionStatus.playing;
      if (isPlaying != localPlaying) {
        if (_playerVerboseLogs) {
          dev.log('remote sync: toggling play/pause', name: 'Party');
        }
        orchestrator.togglePlayPause();
      }

      final localMs = _currentPosition.inMilliseconds;
      if ((positionMs - localMs).abs() > 1500) {
        if (_playerVerboseLogs) {
          dev.log(
            'remote sync: seeking from $localMs to $positionMs',
            name: 'Party',
          );
        }
        orchestrator.seekTo(Duration(milliseconds: positionMs));
      }
    }

    // Member-side drift detector: arm the periodic check only when we are
    // NOT the host. Hosts are authoritative; they never ask for resync.
    if (!notifier.isLocalHost) {
      _partyDriftTimer?.cancel();
      _partyDriftTimer = Timer.periodic(
        _partyDriftInterval,
        (_) => _checkPartyDrift(),
      );
    }

    // v1: legacy P2P sync engine.
    final syncEngine = notifier.syncEngine;
    if (syncEngine != null && !notifier.isLocalHost) {
      if (_playerVerboseLogs) {
        dev.log(
          '_wirePartySyncCallbacks: wiring v1 sync engine (host=${syncEngine.isHost})',
          name: 'Party',
        );
      }
      syncEngine.onSyncState = applyRemote;
    } else if (!notifier.isLocalHost) {
      // v2: brokered realtime callback.
      if (_playerVerboseLogs) {
        dev.log(
          '_wirePartySyncCallbacks: wiring v2 onSyncState (host=${notifier.isLocalHost})',
          name: 'Party',
        );
      }
      notifier.onSyncState = applyRemote;
    }

    // Wire media change navigation: when the host switches anime/episode,
    // pop the player and navigate to the new anime's detail page.
    //
    // Skip the pop+push when the current player is already on the target
    // (anilistId, episode). This is the normal case for the host who just
    // pushReplacement'd into this new player page and then broadcast
    // `change_episode`: the server-side echo of `episode_changed` would
    // otherwise pop the host's own brand-new player. Members whose
    // player is on a different (older) episode still navigate normally.
    notifier.onMediaChangeNavigation =
        (int anilistId, String animeTitle, double episodeNumber) {
          if (!mounted) return;
          final localEp = double.tryParse(widget.episodeNumber);
          if (anilistId == widget.anilistId &&
              localEp != null &&
              (localEp - episodeNumber).abs() < 0.001) {
            if (_playerVerboseLogs) {
              dev.log(
                'onMediaChangeNavigation: already on target '
                'anilistId=$anilistId ep=$episodeNumber — skipping nav',
                name: 'Party',
              );
            }
            return;
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final navigator = Navigator.of(context, rootNavigator: true);
            navigator.popUntil((route) => route.isFirst);
            navigator.push(
              MaterialPageRoute<void>(
                builder: (_) => PartyAnimePage(anilistId: anilistId),
              ),
            );
          });
        };
  }

  bool _isCurrentPlayerBoundToPartyRoom(PartySessionState session) {
    final room = session.room;
    if (!session.isActive || room == null) {
      return false;
    }
    final episodeNumber = int.tryParse(widget.episodeNumber)?.toDouble();
    if (episodeNumber == null) {
      return false;
    }
    if (room.anilistId != widget.anilistId) {
      return false;
    }
    return (room.episodeNumber - episodeNumber).abs() < 0.001;
  }

  bool _shouldHoldPartyPlayback(PartySessionState session) {
    final notifier = ref.read(partySessionProvider.notifier);
    return shouldHoldPartyPlayback(
      session: session,
      isLocallyBoundToRoom: _isCurrentPlayerBoundToPartyRoom(session),
      isLocalHost: notifier.isLocalHost,
    );
  }

  Future<void> _enforcePartyPauseHold({bool force = false}) async {
    final session = ref.read(partySessionProvider);
    if (!_shouldHoldPartyPlayback(session)) {
      return;
    }
    final isPlaying = _state.status == PlayerSessionStatus.playing;
    if (!force && !isPlaying) {
      return;
    }
    // Pause directly at the engine level. The orchestrator's emitted
    // PlayerSessionStatus lags the engine's `playingStream` by one
    // microtask (state hop through `_sessionSub` + `setState`), so a
    // member whose engine just started auto-playing would otherwise
    // miss the hold when `_onPlayingChanged(true)` fires here before
    // `_state.status` transitions to `playing`. `engine.pause()` is
    // idempotent, so calling it on an already-paused player is safe.
    await _engine?.pause();
  }

  void _schedulePartyPauseHoldIfNeeded(PartySessionState session) {
    if (!_shouldHoldPartyPlayback(session) ||
        _state.status != PlayerSessionStatus.playing ||
        _partyPauseHoldPending) {
      return;
    }
    _partyPauseHoldPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _partyPauseHoldPending = false;
      if (!mounted) return;
      unawaited(_enforcePartyPauseHold());
    });
  }

  void _markPartyPlayerReadyIfNeeded() {
    if (_partyPlayerReadySent) {
      return;
    }
    final session = ref.read(partySessionProvider);
    if (!_isCurrentPlayerBoundToPartyRoom(session)) {
      return;
    }
    _partyPlayerReadySent = true;
    ref.read(partySessionProvider.notifier).toggleReady(true);
  }

  Future<void> _togglePartyAwarePlayPause() async {
    final session = ref.read(partySessionProvider);
    if (_shouldHoldPartyPlayback(session)) {
      final notifier = ref.read(partySessionProvider.notifier);
      // Two distinct hold reasons deserve distinct user-facing messages:
      // (a) everyone is waiting for all members to finish loading, or
      // (b) only the host can control playback and they haven't resumed yet.
      final waitingForReady = !partyHasAllMembersReady(session);
      final message = waitingForReady
          ? 'Waiting for everyone to load the episode.'
          : notifier.isLocalHost
          ? 'Waiting for everyone to load the episode.'
          : 'Only the host can control playback.';
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
      await _enforcePartyPauseHold(force: true);
      return;
    }
    await _orchestrator?.togglePlayPause();
  }

  /// Feed the party sync engine with local playback state changes.
  ///
  /// v1: keeps [PartySyncEngine]'s in-memory position current so its 2-second
  /// broadcast carries the host's real progress.
  ///
  /// v2: emits `play`/`pause` with the current position on explicit state
  /// changes, and uses [_detectHostSeek] on every position update to catch
  /// scrubs that happen without a play/pause transition.
  void _updatePartyPlayback({bool? isPlaying, int? positionMs}) {
    final notifier = ref.read(partySessionProvider.notifier);
    final session = ref.read(partySessionProvider);
    if (!session.isActive) return;
    if (!notifier.isLocalHost) return;

    final playing = isPlaying ?? (_state.status == PlayerSessionStatus.playing);
    final position = positionMs ?? _currentPosition.inMilliseconds;
    notifier.updatePlayback(isPlaying: playing, positionMs: position);

    if (isPlaying != null) {
      if (_playerVerboseLogs) {
        dev.log(
          'syncNow: play/pause event isPlaying=$playing positionMs=$position',
          name: 'Party',
        );
      }
      notifier.syncNow(isPlaying: playing, positionMs: position);
      _lastHostPositionMs = position;
      return;
    }

    _detectHostSeek(position);
  }

  /// Detect scrubs on the host's position stream and broadcast them as a
  /// `seek` intent so members realign. No-op for non-host users and during
  /// the natural "position advances smoothly" case.
  void _detectHostSeek(int positionMs) {
    final notifier = ref.read(partySessionProvider.notifier);
    if (!notifier.isLocalHost) return;

    final last = _lastHostPositionMs;
    if (last == null) {
      _lastHostPositionMs = positionMs;
      return;
    }

    final delta = positionMs - last;
    // Normal playback advances the position by up to a few hundred ms per
    // event; anything significantly bigger (forward or backward) is a seek.
    if (delta.abs() >= _partySeekDetectionMs) {
      final now = DateTime.now();
      final lastSent = _lastPartySeekSentAt;
      // Throttle scrub-bar drags: the position stream emits many
      // above-threshold deltas in rapid succession while the user drags.
      // Clamp to at most one seek intent per `_partySeekThrottle` and let
      // the final settle-position arrive when the user releases the bar.
      if (lastSent != null && now.difference(lastSent) < _partySeekThrottle) {
        if (_playerVerboseLogs) {
          dev.log(
            'host seek throttled: $last -> $positionMs (delta=${delta}ms)',
            name: 'Party',
          );
        }
      } else {
        if (_playerVerboseLogs) {
          dev.log(
            'host seek detected: $last -> $positionMs (delta=${delta}ms)',
            name: 'Party',
          );
        }
        notifier.seekTo(positionMs);
        _lastPartySeekSentAt = now;
      }
    }
    _lastHostPositionMs = positionMs;
  }

  /// Member-side drift detection. Compares the player's current position
  /// against the position extrapolated from the last authoritative
  /// `playback_state_changed` snapshot. When the gap exceeds the tolerance
  /// band, sends one `resync_request` — the Worker re-broadcasts the current
  /// playback, which feeds through [applyRemote] to realign us.
  ///
  /// This replaces the server-side periodic resync alarm (removed for cost):
  /// resync work is now paid only when drift actually happens, not every
  /// 10 s unconditionally.
  void _checkPartyDrift() {
    if (!mounted) return;

    final session = ref.read(partySessionProvider);
    if (!session.isActive) return;

    final notifier = ref.read(partySessionProvider.notifier);
    if (notifier.isLocalHost) return;

    // Only evaluate while the host-authoritative timeline is supposed to be
    // advancing. Paused timelines cannot drift.
    if (!_partyLastAppliedIsPlaying) return;

    final lastAt = _partyLastAppliedAt;
    final lastPos = _partyLastAppliedPositionMs;
    if (lastAt == null || lastPos == null) return;

    final elapsedMs = DateTime.now().difference(lastAt).inMilliseconds;
    final expectedMs = lastPos + elapsedMs;
    final actualMs = _currentPosition.inMilliseconds;
    final diff = (expectedMs - actualMs).abs();

    if (diff < _partyDriftToleranceMs) return;

    // Cooldown guard: one pending request at a time. Prevents a chronically
    // slow device from issuing 2 resyncs per minute forever.
    final now = DateTime.now();
    final lastReq = _lastResyncRequestAt;
    if (lastReq != null &&
        now.difference(lastReq) < _partyDriftResyncCooldown) {
      return;
    }

    if (_playerVerboseLogs) {
      dev.log(
        'member drift: expected=${expectedMs}ms actual=${actualMs}ms diff=${diff}ms → resync_request',
        name: 'Party',
      );
    }
    _lastResyncRequestAt = now;
    notifier.requestResync();
  }

  void _onNaturalCompletion() {
    if (!mounted || _isExiting) return;
    _log('naturalCompletion → auto-exit');
    unawaited(_handleExitRequested(naturalCompletion: true));
  }

  Future<void> _saveCurrentProgress() async {
    if (_currentPosition < const Duration(seconds: 5)) return;
    await _saveProgress(
      anilistId: widget.anilistId,
      episodeNumber: _episodeNumberDouble,
      position: _currentPosition,
      totalDuration: _currentDuration > Duration.zero ? _currentDuration : null,
      lastSourcePluginId: widget.sourcePluginId,
      lastServerName: widget.serverName,
      lastResolverPluginId: widget.resolved.resolverId,
    );
  }

  Future<void> _updateWatchHistory() async {
    if (_currentPosition < const Duration(seconds: 5)) return;
    final store = ref.read(animeProgressStoreProvider);
    await store.upsertWatchHistory(
      anilistId: widget.anilistId,
      episodeNumber: _episodeNumberDouble,
      positionSeconds: _currentPosition.inSeconds,
      totalDurationSeconds: _currentDuration > Duration.zero
          ? _currentDuration.inSeconds
          : null,
      lastSourcePluginId: widget.sourcePluginId,
    );
  }

  Future<void> _flushProgressAndRefresh() {
    final pending = _pendingProgressFlush;
    if (pending != null) {
      return pending;
    }

    final future = _saveCurrentProgress().whenComplete(() {
      _pendingProgressFlush = null;
    });
    _pendingProgressFlush = future;
    return future;
  }

  Future<void> _handleExitRequested({bool naturalCompletion = false}) async {
    if (_isExiting) {
      return;
    }
    _isExiting = true;
    try {
      await _flushProgressAndRefresh();
      await _updateWatchHistory();
      ref.invalidate(continueWatchingProvider);
      ref.invalidate(latestEpisodeProgressProvider(widget.anilistId));
      ref.invalidate(animeEpisodeProgressListProvider(widget.anilistId));
    } finally {
      if (mounted) {
        final navigator = Navigator.of(context, rootNavigator: true);
        if (widget.routeMode.isParty) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) => PartyLobbyPage(
                anilistId: widget.anilistId,
                animeTitle: widget.animeTitle,
              ),
            ),
            (route) => route.isFirst,
          );
        } else {
          navigator.pop(naturalCompletion);
        }
      }
      _isExiting = false;
    }
  }

  void _handleExit(BuildContext context) {
    unawaited(_handleExitRequested());
  }

  Widget _wrapWithExitGuard(Widget child) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await _handleExitRequested();
        }
      },
      child: child,
    );
  }

  Future<void> _startPlaybackFromPosition(Duration? initialPosition) async {
    final orchestrator = _orchestrator;
    if (orchestrator == null) {
      return;
    }
    _log(
      'startPlayback resumePosition=$initialPosition streams=${widget.resolved.streams.length} softwareOutput=$_forceSoftwareVideoOutput',
    );
    _autoNextTriggeredByEndingResidual = false;
    final result = await orchestrator.start(
      streamCandidates: widget.resolved.streams,
      externalSubtitles: widget.resolved.externalSubtitles,
      initialPosition: initialPosition,
    );
    if (!mounted || _orchestrator != orchestrator) return;
    result.fold(
      onFailure: (error) =>
          setState(() => _startError = mapErrorMessage(context, error)),
      onSuccess: (_) {
        _markPartyPlayerReadyIfNeeded();
        unawaited(_enforcePartyPauseHold(force: true));
        unawaited(_persistSuccessfulSelection());
      },
    );
  }

  Future<void> _retryPlayback() async {
    _log('retryPlayback');
    setState(() => _startError = null);
    final orchestrator = _orchestrator;
    if (orchestrator == null) {
      return;
    }
    final result = await orchestrator.retry();
    if (!mounted) return;
    result.fold(
      onFailure: (error) =>
          setState(() => _startError = mapErrorMessage(context, error)),
      onSuccess: (_) {
        _markPartyPlayerReadyIfNeeded();
        unawaited(_enforcePartyPauseHold(force: true));
        unawaited(_persistSuccessfulSelection());
      },
    );
  }

  Future<void> _persistSuccessfulSelection() async {
    if (!widget.persistSelection) {
      await _clearPlaybackPreference(widget.anilistId);
      return;
    }
    await _savePlaybackPreference(
      anilistId: widget.anilistId,
      sourcePluginId: widget.sourcePluginId,
      serverName: widget.serverName,
      resolverPluginId: widget.resolved.resolverId,
      preferredAudioPreference: widget.preferredAudioPreference,
    );
  }

  Future<Duration?> _loadResumePosition() async {
    final partySession = ref.read(partySessionProvider);
    if (partySession.isActive) {
      if (_isCurrentPlayerBoundToPartyRoom(partySession)) {
        return Duration(milliseconds: partySession.playback.basePositionMs);
      }
      return null;
    }
    final store = ref.read(animeProgressStoreProvider);
    final result = await store.getProgress(
      widget.anilistId,
      _episodeNumberDouble,
    );
    return result.fold(
      onFailure: (_) => null,
      onSuccess: (progress) {
        if (progress == null ||
            progress.watchState == WatchState.completed ||
            progress.position <= const Duration(seconds: 5)) {
          return null;
        }
        return progress.position;
      },
    );
  }

  Future<void> _seekTo(Duration position) async {
    _log(
      'ui seek target=$position current=$_currentPosition duration=$_currentDuration',
    );
    await _orchestrator?.seekTo(position);
  }

  Future<void> _handleVideoOutputFallback(String reason) async {
    if (_forceSoftwareVideoOutput) {
      return;
    }
    _log('video output fallback requested reason=$reason');
    _forceSoftwareVideoOutput = true;
    await _installRuntime();
    final resumePosition = _currentPosition > Duration.zero
        ? _currentPosition
        : _resumePosition;
    await _startPlaybackFromPosition(resumePosition);
  }

  Future<void> _maybeLoadAniSkipSegments() {
    final pending = _pendingAniSkipLoad;
    if (pending != null) {
      return pending;
    }
    if (_aniSkipSegments.isNotEmpty || _currentDuration <= Duration.zero) {
      return Future<void>.value();
    }

    final episodeNumber = int.tryParse(widget.episodeNumber);
    if (episodeNumber == null || episodeNumber <= 0) {
      return Future<void>.value();
    }
    final episodeLengthSeconds = _currentDuration.inSeconds;
    if (episodeLengthSeconds <= 0) {
      return Future<void>.value();
    }

    _log(
      'aniskip load start anilistId=${widget.anilistId} ep=$episodeNumber duration=${_currentDuration.inSeconds}s',
    );
    final future = ref
        .read(
          aniskipSegmentsProvider((
            anilistId: widget.anilistId,
            episodeNumber: episodeNumber,
            episodeLengthSeconds: episodeLengthSeconds,
          )).future,
        )
        .then((segments) {
          _log('aniskip loaded ${segments.length} segments');
          if (!mounted) {
            _aniSkipSegments = segments;
            return;
          }
          setState(() => _aniSkipSegments = segments);
        })
        .catchError((Object error) {
          _log('aniskip load failed: $error');
        })
        .whenComplete(() {
          _pendingAniSkipLoad = null;
        });

    _pendingAniSkipLoad = future;
    return future;
  }

  // Cache the last found segment to avoid re-scanning on consecutive calls
  // at the same position. Cleared when segments list changes.
  AniSkipSegment? _cachedActiveSegment;
  int _cachedSegmentPositionSec = -1;

  AniSkipSegment? get _activeAniSkipSegment {
    if (_aniSkipSegments.isEmpty || _currentDuration <= Duration.zero) {
      return null;
    }
    // Fast path: if position (rounded to seconds) hasn't changed, reuse cache.
    final posSec = _currentPosition.inSeconds;
    if (posSec == _cachedSegmentPositionSec && _cachedActiveSegment != null) {
      // Verify cached segment is still valid (could have exited its range).
      final seg = _cachedActiveSegment!;
      final guardStart = seg.start - const Duration(seconds: 1);
      final effectiveStart = guardStart > Duration.zero
          ? guardStart
          : Duration.zero;
      if (_currentPosition >= effectiveStart && _currentPosition < seg.end) {
        return seg;
      }
    }
    _cachedSegmentPositionSec = posSec;
    for (final segment in _aniSkipSegments) {
      final guardStart = segment.start - const Duration(seconds: 1);
      final effectiveStart = guardStart > Duration.zero
          ? guardStart
          : Duration.zero;
      if (_currentPosition >= effectiveStart &&
          _currentPosition < segment.end) {
        _cachedActiveSegment = segment;
        return segment;
      }
    }
    _cachedActiveSegment = null;
    return null;
  }

  String? get _activeAniSkipLabel {
    final segment = _activeAniSkipSegment;
    if (segment == null) {
      return null;
    }
    if (segment.kind == AniSkipSegmentKind.ending &&
        _shouldAutoAdvanceAfterEnding(segment)) {
      return context.l10n.playerNextEpisode;
    }
    return switch (segment.kind) {
      AniSkipSegmentKind.opening => context.l10n.playerSkipIntro,
      AniSkipSegmentKind.ending => context.l10n.playerSkipCredits,
    };
  }

  Future<void> _skipActiveSegment() async {
    final segment = _activeAniSkipSegment;
    if (segment == null) {
      return;
    }
    if (segment.kind == AniSkipSegmentKind.ending &&
        _shouldAutoAdvanceAfterEnding(segment)) {
      _autoNextTriggeredByEndingResidual = true;
      _log('ending skip pressed → next episode');
      await _openEpisodeSelectorFromPlayer();
      return;
    }
    final target = segment.end + const Duration(milliseconds: 300);
    final maxSeekTarget = _currentDuration > const Duration(seconds: 1)
        ? _currentDuration - const Duration(seconds: 1)
        : _currentDuration;
    final clamped = target > maxSeekTarget ? maxSeekTarget : target;
    _log('segment skip pressed kind=${segment.kind} target=$clamped');
    await _seekTo(clamped);
  }

  void _maybeAutoSkipSegment() {
    final segment = _activeAniSkipSegment;
    if (segment == null) return;

    // Only auto-skip once per segment window.
    final segmentKey = '${segment.kind}_${segment.start.inMilliseconds}';
    if (_autoSkippedSegments.contains(segmentKey)) return;
    _autoSkippedSegments.add(segmentKey);

    final target = segment.end + const Duration(milliseconds: 300);
    final maxTarget = _currentDuration > const Duration(seconds: 1)
        ? _currentDuration - const Duration(seconds: 1)
        : _currentDuration;
    final clamped = target > maxTarget ? maxTarget : target;

    _log('auto-skip segment kind=${segment.kind} target=$clamped');
    unawaited(_seekTo(clamped));

    if (mounted) {
      final label = segment.kind == AniSkipSegmentKind.opening
          ? 'Skipped Intro'
          : 'Skipped Credits';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(label),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          width: 200,
        ),
      );
    }
  }

  bool _shouldAutoAdvanceAfterEnding(AniSkipSegment ending) {
    final remainingAfterEnding = _currentDuration - ending.end;
    return remainingAfterEnding < const Duration(seconds: 10);
  }

  void _maybeAutoNextFromEndingResidual(Duration position) {
    if (_autoNextTriggeredByEndingResidual ||
        _currentDuration <= Duration.zero) {
      return;
    }

    AniSkipSegment? ending;
    for (final segment in _aniSkipSegments.reversed) {
      if (segment.kind == AniSkipSegmentKind.ending) {
        ending = segment;
        break;
      }
    }
    if (ending == null) {
      return;
    }

    if (!_shouldAutoAdvanceAfterEnding(ending)) {
      return;
    }

    if (position < ending.end) {
      return;
    }

    _autoNextTriggeredByEndingResidual = true;
    _log(
      'auto-next residual trigger ending=[${ending.start}..${ending.end}] remainingAfterEnding=${_currentDuration - ending.end} position=$position',
    );
    unawaited(_openEpisodeSelectorFromPlayer());
  }

  void _maybeAutoPickSubtitle(EmbeddedTracks tracks) {
    if (_autoPickedSubtitle) return;
    if (tracks.subtitle.isEmpty) return;
    _autoPickedSubtitle = true;

    // If Media3 already has one selected (e.g. external seeded by Kotlin),
    // adopt it for the picker and stop here.
    final preSelected = tracks.subtitle
        .cast<EmbeddedSubtitleTrack?>()
        .firstWhere((t) => t?.selected == true, orElse: () => null);
    if (preSelected != null) {
      if (mounted) {
        setState(() => _activeEmbeddedSubtitleTrack = preSelected);
      } else {
        _activeEmbeddedSubtitleTrack = preSelected;
      }
      return;
    }

    final deviceLocale = PlatformDispatcher.instance.locale;
    final primary = deviceLocale.languageCode.toLowerCase(); // 'es', 'en', ...
    // Normalise to ISO-639-1 two-letter + accept 3-letter ('spa', 'eng').
    bool matches(String? lang, String target) {
      if (lang == null) return false;
      final l = lang.toLowerCase();
      if (l == target) return true;
      if (target == 'es' && (l == 'spa' || l.startsWith('es-'))) return true;
      if (target == 'en' && (l == 'eng' || l.startsWith('en-'))) return true;
      return false;
    }

    EmbeddedSubtitleTrack? pick;
    for (final t in tracks.subtitle) {
      if (matches(t.language, primary)) {
        pick = t;
        break;
      }
    }
    if (pick == null && primary != 'en') {
      for (final t in tracks.subtitle) {
        if (matches(t.language, 'en')) {
          pick = t;
          break;
        }
      }
    }

    if (pick == null) return; // leave disabled per user preference
    if (mounted) {
      setState(() => _activeEmbeddedSubtitleTrack = pick);
    } else {
      _activeEmbeddedSubtitleTrack = pick;
    }
    final orchestrator = _orchestrator;
    if (orchestrator != null) {
      unawaited(orchestrator.selectEmbeddedSubtitleTrack(pick));
    }
  }

  Future<void> _enterWindowsFullscreenIfSupported() async {
    if (kIsWeb || !(Platform.isWindows || Platform.isLinux)) {
      return;
    }
    try {
      _windowsFullscreenBeforePlayback = await windowManager.isFullScreen();
      if (_windowsFullscreenBeforePlayback != true) {
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
        await windowManager.setFullScreen(true);
      }
      final fullScreen = await windowManager.isFullScreen();
      if (!mounted) {
        _isWindowsFullscreen = fullScreen;
        return;
      }
      setState(() => _isWindowsFullscreen = fullScreen);
    } catch (_) {}
  }

  Future<void> _restoreWindowsFullscreenIfNeeded() async {
    if (kIsWeb || !(Platform.isWindows || Platform.isLinux)) {
      return;
    }
    final before = _windowsFullscreenBeforePlayback;
    if (before == null) {
      return;
    }
    try {
      if (before != true) {
        await windowManager.setFullScreen(false);
        await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      }
    } catch (_) {}
  }

  Future<void> _toggleWindowsFullscreen() async {
    if (kIsWeb || !(Platform.isWindows || Platform.isLinux)) {
      return;
    }
    try {
      final current = await windowManager.isFullScreen();
      final target = !current;
      if (target) {
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      }
      await windowManager.setFullScreen(target);
      if (!target) {
        await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      }
      if (!mounted) {
        _isWindowsFullscreen = target;
        return;
      }
      setState(() => _isWindowsFullscreen = target);
    } catch (_) {}
  }

  Future<void> _openEpisodeSelectorFromPlayer() async {
    if (_state.status == PlayerSessionStatus.playing) {
      await _orchestrator?.togglePlayPause();
    }
    await _openAdjacentEpisode(offset: 1);
  }

  Future<void> _openPreviousEpisode() async {
    // Parse as double so fractional episodes (e.g. 7.5) still qualify for
    // the previous-episode action. Previously `int.tryParse` returned null
    // and the button became a silent no-op.
    final currentEpisode = double.tryParse(widget.episodeNumber);
    if (currentEpisode == null || currentEpisode <= 1) {
      return;
    }
    if (_state.status == PlayerSessionStatus.playing) {
      await _orchestrator?.togglePlayPause();
    }
    await _openAdjacentEpisode(offset: -1);
  }

  Future<void> _openAdjacentEpisode({required int offset}) async {
    final currentEpisode = double.tryParse(widget.episodeNumber);
    if (currentEpisode == null) {
      return;
    }
    // Snap to integer neighbour. AniList numbering is authoritative and
    // integer for the vast majority of titles; fractional episodes are
    // edge-case omake/recaps that should still transition into the next
    // canonical integer episode.
    final targetEpisode = (currentEpisode + offset).round();
    if (targetEpisode <= 0) {
      return;
    }

    final openedOffline = await _openDownloadedEpisodeIfAvailable(
      targetEpisode,
    );
    if (openedOffline || !mounted) {
      return;
    }

    final rootContext = Navigator.of(context, rootNavigator: true).context;
    // ignore: use_build_context_synchronously
    showBlockingLoader(rootContext, context.l10n.playbackPreparing);
    var loaderShown = true;

    try {
      final summaryResult = await ref.read(
        sourceAvailabilitySummaryProvider(widget.anilistId).future,
      );
      if (!mounted) {
        return;
      }
      final summary = summaryResult.fold(
        onFailure: (_) => null,
        onSuccess: (value) => value,
      );
      if (summary == null) {
        return _openEpisodeListReplacement(targetEpisode.toDouble());
      }

      // Auto-resolve when moving between adjacent episodes so next/prev
      // matches the behaviour of "continue watching". The previous explicit
      // `false` defeated auto-queue racing and always forced the server
      // picker, which felt laggy to users.
      final decision = await ref
          .read(startEpisodePlaybackUseCaseProvider)
          .call(
            anilistId: widget.anilistId,
            episodeNumber: targetEpisode.toDouble(),
            availabilitySummary: summary,
          );
      if (!mounted) {
        return;
      }

      if (loaderShown) {
        // ignore: use_build_context_synchronously
        hideBlockingLoader(rootContext);
        loaderShown = false;
      }

      switch (decision.type) {
        case EpisodePlaybackDecisionType.direct:
          final launch = decision.launch;
          if (launch == null) {
            await _openEpisodeListReplacement(targetEpisode.toDouble());
            return;
          }
          await _replaceWithResolvedPlayer(
            episodeNumber: targetEpisode,
            episodeTitle: launch.option.sourceEpisode.title.trim().isEmpty
                ? null
                : launch.option.sourceEpisode.title.trim(),
            sourcePluginId: launch.option.sourcePluginId,
            serverName: launch.option.serverLink.serverName,
            persistSelection: true,
            preferredAudioPreference: switch (launch.option.audioKind) {
              SourceAudioKind.sub => PlaybackAudioPreference.sub,
              SourceAudioKind.dub => PlaybackAudioPreference.dub,
              null => null,
            },
            resolved: launch.resolved,
          );
          return;
        case EpisodePlaybackDecisionType.selection:
          await _openAdjacentEpisodeSelection(
            episodeNumber: targetEpisode,
            decision: decision,
          );
          return;
        case EpisodePlaybackDecisionType.unavailable:
          await _openEpisodeListReplacement(targetEpisode.toDouble());
          return;
      }
    } finally {
      // The loader was pushed on the *root* navigator via
      // `showBlockingLoader` + `useRootNavigator: true`, so it outlives
      // this PlayerPage. We MUST dismiss it regardless of `mounted`:
      // when an adjacent-episode flow tears down the page mid-await
      // (auto-advance, pushReplacement, session teardown), `mounted`
      // becomes false and the loader would otherwise remain stuck as a
      // phantom modal on top of whatever screen the user lands on
      // (observed in evidence as a permanent "Preparando reproducción…"
      // overlay on Home after the episode finale).
      if (loaderShown) {
        // ignore: use_build_context_synchronously
        hideBlockingLoader(rootContext);
      }
    }
  }

  Future<void> _openAdjacentEpisodeSelection({
    required int episodeNumber,
    required EpisodePlaybackDecision decision,
  }) async {
    final preferenceResult = await ref
        .read(animeProgressStoreProvider)
        .getPlaybackPreference(widget.anilistId);
    final rememberedPreference = preferenceResult.fold(
      onFailure: (_) => null,
      onSuccess: (value) => value,
    );
    if (!mounted) return;
    var selection = await showServerPicker(
      // ignore: use_build_context_synchronously
      context,
      options: decision.options,
      autoSelectionFailed: decision.autoSelectionFailed,
      rememberedPreference: rememberedPreference,
    );
    var remaining = decision.options;

    while (selection != null && mounted) {
      // ignore: use_build_context_synchronously
      showBlockingLoader(context, context.l10n.playbackOpeningSelectedServer);
      final result = await ref
          .read(resolveSourceServerLinkUseCaseProvider)
          .call(
            selection.option.serverLink,
            preferredResolverId: selection.option.resolverId,
          );
      if (!mounted) {
        return;
      }
      hideBlockingLoader(context);

      final resolved = result.fold(
        onFailure: (_) => null,
        onSuccess: (value) => value,
      );
      if (resolved != null) {
        await _replaceWithResolvedPlayer(
          episodeNumber: episodeNumber,
          episodeTitle: selection.option.sourceEpisode.title.trim().isEmpty
              ? null
              : selection.option.sourceEpisode.title.trim(),
          sourcePluginId: selection.option.sourcePluginId,
          serverName: selection.option.serverLink.serverName,
          persistSelection: selection.rememberSelection,
          preferredAudioPreference: switch (selection.option.audioKind) {
            SourceAudioKind.sub => PlaybackAudioPreference.sub,
            SourceAudioKind.dub => PlaybackAudioPreference.dub,
            null => null,
          },
          resolved: resolved,
        );
        return;
      }

      showPlaybackMessage(context, context.l10n.episodeSelectedServerFailed);
      remaining = remaining
          .where((item) => item.optionKey != selection!.option.optionKey)
          .toList(growable: false);
      if (remaining.isEmpty) {
        await _openEpisodeListReplacement(episodeNumber.toDouble());
        return;
      }
      selection = await showServerPicker(
        context,
        options: remaining,
        autoSelectionFailed: true,
        rememberedPreference: rememberedPreference,
      );
    }
  }

  Future<bool> _openDownloadedEpisodeIfAvailable(int episodeNumber) async {
    final downloadTask = await ref
        .read(downloadManagerProvider)
        .findTaskByEpisode(widget.anilistId, episodeNumber.toDouble());
    if (downloadTask == null ||
        downloadTask.status != DownloadStatus.completed ||
        downloadTask.filePath == null ||
        downloadTask.filePath!.trim().isEmpty) {
      return false;
    }

    final file = File(downloadTask.filePath!);
    if (!await file.exists()) {
      return false;
    }

    if (!mounted) {
      return true;
    }

    _log(
      'open downloaded adjacent episode ep=$episodeNumber file=${file.path}',
    );
    await _replaceWithResolvedPlayer(
      episodeNumber: episodeNumber,
      episodeTitle: downloadTask.episodeTitle,
      sourcePluginId: downloadTask.sourcePluginId ?? 'offline',
      serverName: downloadTask.serverName ?? 'Downloaded',
      persistSelection: false,
      resolved: ResolvedServerLinkResult(
        resolverId: 'offline',
        resolverName: 'Downloaded',
        streams: <ResolvedStream>[ResolvedStream(url: file.uri)],
      ),
    );
    return true;
  }

  Future<void> _replaceWithResolvedPlayer({
    required int episodeNumber,
    required String sourcePluginId,
    required String serverName,
    required bool persistSelection,
    required ResolvedServerLinkResult resolved,
    String? episodeTitle,
    PlaybackAudioPreference? preferredAudioPreference,
  }) async {
    await _prepareForEpisodeReplacement();
    if (!mounted) {
      return;
    }
    await Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PlayerPage(
          anilistId: widget.anilistId,
          animeTitle: widget.animeTitle,
          episodeNumber: episodeNumber.toString(),
          episodeTitle: episodeTitle,
          sourcePluginId: sourcePluginId,
          serverName: serverName,
          persistSelection: persistSelection,
          preferredAudioPreference: preferredAudioPreference,
          routeMode: widget.routeMode,
          resolved: resolved,
          totalEpisodes: widget.totalEpisodes,
          nextAiringEpisodeNumber: widget.nextAiringEpisodeNumber,
        ),
      ),
    );
  }

  Future<void> _openEpisodeListReplacement(double focusedEpisodeNumber) async {
    await _prepareForEpisodeReplacement();
    if (!mounted) {
      return;
    }
    await Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => widget.routeMode.isParty
            ? PartyEpisodeListPage(
                anilistId: widget.anilistId,
                animeTitle: widget.animeTitle,
                focusedEpisodeNumber: focusedEpisodeNumber,
              )
            : EpisodeListPage(
                anilistId: widget.anilistId,
                animeTitle: widget.animeTitle,
                focusedEpisodeNumber: focusedEpisodeNumber,
              ),
      ),
    );
  }

  Future<void> _prepareForEpisodeReplacement() async {
    _isExiting = true;
    _autoNextTriggeredByEndingResidual = true;
    await _positionSub?.cancel();
    await _completionSub?.cancel();
    _positionSub = null;
    _completionSub = null;
    // Drain any in-flight progress save so the next PlayerPage instance
    // reads the freshest resume position instead of a stale one.
    final pendingFlush = _pendingProgressFlush;
    if (pendingFlush != null) {
      try {
        await pendingFlush;
      } catch (_) {
        // Errors are already surfaced by _saveCurrentProgress; swallow
        // here so the replacement is not blocked.
      }
    }
    _orientationRestoreTimer?.cancel();
    _orientationRestoreTimer = null;
    _suppressOrientationRestore = true;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  SubtitleViewConfiguration _subtitleViewConfigFor(
    PlaybackEngine? engine,
    SubtitleSettings settings,
  ) {
    if (engine is KumoriyaExoPlayerEngine) {
      return settings.toOverlayConfiguration();
    }
    return settings.toViewConfiguration();
  }

  @override
  Widget build(BuildContext context) {
    PlayerPerformanceProbe.instance.recordBuild();
    final engine = _engine;
    if (_startError != null) {
      return _wrapWithExitGuard(
        ColoredBox(
          color: Colors.black,
          child: SafeArea(
            child: Column(
              children: <Widget>[
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: KumoriyaColors.textPrimary,
                    ),
                    onPressed: () => _handleExit(context),
                  ),
                ),
                Expanded(
                  child: ErrorStateView(
                    message: _startError!,
                    onRetry: _retryPlayback,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isLoading =
        _state.status == PlayerSessionStatus.opening ||
        _state.status == PlayerSessionStatus.buffering;

    final subtitleConfig = ref.watch(
      subtitleSettingsProvider.select((s) => s.value),
    );
    final localPartyUserId = ref
        .read(partySessionProvider.notifier)
        .localUserId;
    final partyMemberLocked = ref.watch(
      partySessionProvider.select((session) {
        final room = session.room;
        final isLocalHost =
            localPartyUserId != null &&
            room != null &&
            room.hostId == localPartyUserId;
        return session.isActive && !isLocalHost;
      }),
    );
    final partyHostWaitingForReady = ref.watch(
      partySessionProvider.select((session) {
        final room = session.room;
        final isLocalHost =
            localPartyUserId != null &&
            room != null &&
            room.hostId == localPartyUserId;
        if (!session.isActive || !isLocalHost) return false;
        // Call the pure guard directly: `_shouldHoldPartyPlayback` reads
        // `ref` internally, which is forbidden inside a `.select` selector.
        return shouldHoldPartyPlayback(
          session: session,
          isLocallyBoundToRoom: _isCurrentPlayerBoundToPartyRoom(session),
          isLocalHost: isLocalHost,
        );
      }),
    );

    // ── Watch-party member lockout (Sync Prop-1) ──────────────────────────
    // When a user is in a party but NOT the host, the timeline is owned
    // by the host. Local play/pause/seek actions would only cause
    // silent desync (the Worker rejects them and re-broadcasts the
    // authoritative state seconds later). Null out the callbacks so the
    // existing widgets render the controls as disabled / non-interactive
    // without any visual restructuring. Keep non-timeline actions
    // (audio, subtitles, quality, back) alive — those are local.
    if (partyHostWaitingForReady) {
      _schedulePartyPauseHoldIfNeeded(ref.read(partySessionProvider));
    }

    return _wrapWithExitGuard(
      Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            StateTransitionSwitcher(
              stateKey: _state.status.name,
              child: _ImmersivePlayerView(
                engine: engine,
                isLoading: isLoading,
                isPlaying: _state.status == PlayerSessionStatus.playing,
                isError: _state.status == PlayerSessionStatus.error,
                animeTitle: widget.animeTitle,
                episodeNumber: widget.episodeNumber,
                currentPosition: _effectiveSliderPosition,
                totalDuration: _currentDuration,
                sliderValue: _sliderValueMs,
                sliderMax: _sliderMaxMs,
                hasMultipleAudio: _embeddedTracks.hasMultipleAudio,
                hasSubtitles:
                    _embeddedTracks.hasSubtitles ||
                    widget.resolved.externalSubtitles.isNotEmpty,
                onTogglePlayPause: partyMemberLocked || partyHostWaitingForReady
                    ? null
                    : () => unawaited(_togglePartyAwarePlayPause()),
                onSeekChanged:
                    !partyMemberLocked && _currentDuration > Duration.zero
                    ? (value) {
                        setState(() {
                          _isScrubbing = true;
                          _scrubPositionMs = value;
                        });
                      }
                    : null,
                onSeekEnd:
                    !partyMemberLocked && _currentDuration > Duration.zero
                    ? (value) {
                        final target = Duration(milliseconds: value.round());
                        setState(() {
                          _currentPosition = target;
                          _isScrubbing = false;
                          _scrubPositionMs = null;
                        });
                        unawaited(_seekTo(target));
                      }
                    : null,
                onSeekStart: partyMemberLocked
                    ? null
                    : () {
                        setState(() => _isScrubbing = true);
                      },
                onBack: () => _handleExit(context),
                onRetry: _retryPlayback,
                onOpenEpisodes: (partyMemberLocked
                    ? null
                    : (_hasNextEpisode
                          ? () => unawaited(_openEpisodeSelectorFromPlayer())
                          : null)),
                onPreviousEpisode: (partyMemberLocked
                    ? null
                    : ((int.tryParse(widget.episodeNumber) ?? 0) > 1
                          ? () => unawaited(_openPreviousEpisode())
                          : null)),
                onQuality: () => unawaited(_showQualityPicker(context)),
                onAudio: _embeddedTracks.hasMultipleAudio
                    ? () => unawaited(_showAudioTrackPicker(context))
                    : null,
                onSubtitle:
                    _embeddedTracks.hasSubtitles ||
                        widget.resolved.externalSubtitles.isNotEmpty
                    ? () => unawaited(_showSubtitleTrackPicker(context))
                    : null,
                onSkipBackward: partyMemberLocked
                    ? null
                    : () {
                        final target =
                            _currentPosition - const Duration(seconds: 10);
                        unawaited(
                          _seekTo(
                            target < Duration.zero ? Duration.zero : target,
                          ),
                        );
                      },
                onSkipForward: partyMemberLocked
                    ? null
                    : () {
                        final maxPos =
                            _currentDuration - const Duration(seconds: 1);
                        final target =
                            _currentPosition + const Duration(seconds: 10);
                        unawaited(
                          _seekTo(
                            target > maxPos && maxPos > Duration.zero
                                ? maxPos
                                : target,
                          ),
                        );
                      },
                onSeekByDelta: partyMemberLocked
                    ? null
                    : (target) => unawaited(_seekTo(target)),
                activeSkipLabel: _autoSkipEnabled ? null : _activeAniSkipLabel,
                onSkipSegment: partyMemberLocked
                    ? null
                    : () => unawaited(_skipActiveSegment()),
                autoSkipEnabled: _autoSkipEnabled,
                showFallbackSkip:
                    _aniSkipSegments.isEmpty ||
                    !_aniSkipSegments.any(
                      (s) => s.kind == AniSkipSegmentKind.opening,
                    ),
                onFallbackSkip: partyMemberLocked
                    ? null
                    : () {
                        final fallback =
                            _currentPosition + const Duration(seconds: 90);
                        final maxPos =
                            _currentDuration > const Duration(seconds: 1)
                            ? _currentDuration - const Duration(seconds: 1)
                            : _currentDuration;
                        final target = fallback > maxPos ? maxPos : fallback;
                        unawaited(_seekTo(target));
                      },
                onAutoSkipToggled: () {
                  setState(() => _autoSkipEnabled = !_autoSkipEnabled);
                },
                isWindowsFullscreen: _isWindowsFullscreen,
                onToggleWindowsFullscreen: () =>
                    unawaited(_toggleWindowsFullscreen()),
                errorMessage: _state.status == PlayerSessionStatus.error
                    ? context.l10n.playerAllCandidatesFailed
                    : null,
                formatDuration: _formatDuration,
                subtitleViewConfiguration: subtitleConfig != null
                    ? _subtitleViewConfigFor(engine, subtitleConfig)
                    : null,
                episodeTitle: widget.episodeTitle,
                onVolumeChanged: (vol) {
                  _engine?.setVolume(vol * 100);
                  try {
                    VolumeController.instance.setVolume(vol.clamp(0.0, 1.0));
                  } catch (_) {}
                  // Activate smart audio boost (dynamic normalization) when
                  // volume exceeds 100 % so the boost raises dialogue clarity
                  // instead of hard-clipping all frequencies.
                  _engine?.setSmartAudioBoost(enabled: vol > 1.0);
                },
                onBrightnessChanged: (brightness) {
                  try {
                    unawaited(
                      ScreenBrightness().setApplicationScreenBrightness(
                        brightness,
                      ),
                    );
                  } catch (_) {}
                },
                onSpeedChanged: (speed) => _engine?.setPlaybackSpeed(speed),
                diagnosticsStream: engine?.diagnosticsStream,
                seekLatencyMs: _orchestrator?.lastSeekLatencyMs,
              ),
            ),
            // Watch party overlay — only visible when a party session is active.
            const PartyPlayerOverlay(),
          ],
        ),
      ),
    );
  }

  Future<void> _showQualityPicker(BuildContext context) async {
    final orchestrator = _orchestrator;
    if (orchestrator == null) {
      return;
    }

    // Prefer the orchestrator's ranked candidate list when it carries
    // multiple entries (one stream URL per quality, e.g. resolver-driven
    // sources like JKAnime). For sources that expose a single HLS master
    // with in-manifest variants (native anime.nexus), fall back to the
    // engine's embedded video-track inventory so the user still gets a
    // usable quality picker.
    final orchestratorItems = orchestrator.qualityCandidates;
    final embeddedVariants = _embeddedTracks.video;
    final useEmbedded =
        orchestratorItems.length <= 1 && embeddedVariants.length > 1;

    if (!useEmbedded) {
      if (orchestratorItems.isEmpty) return;
      await _showPlayerSelectorSheet(
        context: context,
        title: context.l10n.playerQuality,
        icon: KumoriyaIcons.playerQuality,
        options: List<_PlayerSelectorOption>.generate(
          orchestratorItems.length,
          (index) {
            final stream = orchestratorItems[index];
            final selected =
                _state.selectedStream?.url.toString() == stream.url.toString();
            final label =
                stream.qualityLabel ??
                '${context.l10n.playerQuality} ${index + 1}';
            return _PlayerSelectorOption(
              icon: Icons.high_quality_rounded,
              title: label,
              selected: selected,
              onTap: () => unawaited(orchestrator.selectQualityByIndex(index)),
            );
          },
        ),
      );
      return;
    }

    final engine = _engine;
    if (engine == null) return;

    // Sort variants by resolution desc so the picker reads 1080p → 720p
    // → 480p from top to bottom, matching user expectations.
    final sorted = [...embeddedVariants]
      ..sort((a, b) {
        final aH = a.height ?? 0;
        final bH = b.height ?? 0;
        return bH.compareTo(aH);
      });
    final anySelected = sorted.any((t) => t.selected);
    await _showPlayerSelectorSheet(
      context: context,
      title: context.l10n.playerQuality,
      icon: KumoriyaIcons.playerQuality,
      options: <_PlayerSelectorOption>[
        _PlayerSelectorOption(
          icon: Icons.auto_awesome_rounded,
          title: 'Auto',
          // "Auto" is the active choice whenever no variant is currently
          // pinned by the user — matches Media3's ABR default.
          selected: !anySelected,
          onTap: () => unawaited(engine.clearEmbeddedVideoTrack()),
        ),
        ...sorted.map(
          (track) => _PlayerSelectorOption(
            icon: Icons.high_quality_rounded,
            title: track.displayLabel,
            subtitle: track.bitrate != null
                ? '${(track.bitrate! / 1000).round()} kbps'
                : null,
            selected: track.selected,
            onTap: () => unawaited(engine.setEmbeddedVideoTrack(track)),
          ),
        ),
      ],
    );
  }

  Future<void> _showAudioTrackPicker(BuildContext context) async {
    final orchestrator = _orchestrator;
    if (orchestrator == null) return;
    final tracks = _embeddedTracks.audio;
    if (tracks.isEmpty) return;

    final activeAudioId = _activeAudioTrack?.id;
    await _showPlayerSelectorSheet(
      context: context,
      title: context.l10n.playerAudio,
      icon: KumoriyaIcons.playerAudio,
      options: tracks
          .map(
            (track) => _PlayerSelectorOption(
              icon: Icons.graphic_eq_rounded,
              title: track.displayLabel,
              subtitle: track.language,
              selected: track.id == activeAudioId,
              onTap: () {
                setState(() => _activeAudioTrack = track);
                unawaited(orchestrator.selectEmbeddedAudioTrack(track));
              },
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _showSubtitleTrackPicker(BuildContext context) async {
    final orchestrator = _orchestrator;
    if (orchestrator == null) return;
    final embeddedTracks = _embeddedTracks.subtitle;
    final externalTracks = orchestrator.externalSubtitleTracks;

    final activeEmbeddedSubId = _activeEmbeddedSubtitleTrack?.id;
    final activeExternalSubId = _activeExternalSubtitleTrack?.id;
    await _showPlayerSelectorSheet(
      context: context,
      title: context.l10n.playerSubtitles,
      icon: KumoriyaIcons.playerSubtitle,
      options: <_PlayerSelectorOption>[
        _PlayerSelectorOption(
          icon: Icons.subtitles_off_rounded,
          title: context.l10n.playerDisableSubtitles,
          selected: activeEmbeddedSubId == null && activeExternalSubId == null,
          onTap: () {
            setState(() {
              _activeEmbeddedSubtitleTrack = null;
              _activeExternalSubtitleTrack = null;
            });
            unawaited(orchestrator.clearExternalSubtitleTrack());
            unawaited(orchestrator.clearEmbeddedSubtitleTrack());
          },
        ),
        _PlayerSelectorOption(
          icon: Icons.tune_rounded,
          title: context.l10n.playerSubtitleStyle,
          subtitle: context.l10n.playerSubtitleStyleDescription,
          selected: false,
          onTap: () => unawaited(_showSubtitleStyleSheet(context)),
        ),
        ...externalTracks.map(
          (track) => _PlayerSelectorOption(
            icon: Icons.closed_caption_rounded,
            title: track.label,
            subtitle: track.language,
            selected: track.id == activeExternalSubId,
            onTap: () {
              setState(() {
                _activeExternalSubtitleTrack = track;
                _activeEmbeddedSubtitleTrack = null;
              });
              unawaited(orchestrator.selectExternalSubtitleTrack(track));
            },
          ),
        ),
        ...embeddedTracks.map(
          (track) => _PlayerSelectorOption(
            icon: KumoriyaIcons.playerSubtitle,
            title: track.displayLabel,
            subtitle: track.language,
            selected: track.id == activeEmbeddedSubId,
            onTap: () {
              setState(() {
                _activeEmbeddedSubtitleTrack = track;
                _activeExternalSubtitleTrack = null;
              });
              unawaited(orchestrator.selectEmbeddedSubtitleTrack(track));
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showSubtitleStyleSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final settings =
                ref.watch(subtitleSettingsProvider).value ??
                const SubtitleSettings();
            final notifier = ref.read(subtitleSettingsProvider.notifier);

            Widget buildColorDot({
              required Color color,
              required bool selected,
              required VoidCallback onTap,
            }) {
              return GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? KumoriyaColors.primary
                          : KumoriyaColors.borderSubtle,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: color.computeLuminance() > 0.7
                              ? Colors.black
                              : Colors.white,
                        )
                      : null,
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: KumoriyaSpacing.md,
                  right: KumoriyaSpacing.md,
                  top: KumoriyaSpacing.md,
                  bottom:
                      MediaQuery.of(sheetContext).viewInsets.bottom +
                      KumoriyaSpacing.lg,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: KumoriyaColors.surface,
                    borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
                    border: Border.all(color: KumoriyaColors.borderMedium),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 720),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        KumoriyaSpacing.lg,
                        KumoriyaSpacing.lg,
                        KumoriyaSpacing.lg,
                        KumoriyaSpacing.xl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: KumoriyaColors.primarySurface20,
                                  borderRadius: BorderRadius.circular(
                                    KumoriyaRadius.md,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.tune_rounded,
                                  size: 18,
                                  color: KumoriyaColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: KumoriyaSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      context.l10n.playerSubtitleStyle,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      context
                                          .l10n
                                          .playerSubtitleStyleDescription,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: KumoriyaColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: KumoriyaSpacing.lg),
                          Text(
                            context.l10n.settingsSubtitleFontSize,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: KumoriyaSpacing.sm),
                          SegmentedButton<SubtitleFontSize>(
                            segments: <ButtonSegment<SubtitleFontSize>>[
                              ButtonSegment(
                                value: SubtitleFontSize.small,
                                label: Text(context.l10n.settingsSubtitleSmall),
                              ),
                              ButtonSegment(
                                value: SubtitleFontSize.medium,
                                label: Text(
                                  context.l10n.settingsSubtitleMedium,
                                ),
                              ),
                              ButtonSegment(
                                value: SubtitleFontSize.large,
                                label: Text(context.l10n.settingsSubtitleLarge),
                              ),
                              ButtonSegment(
                                value: SubtitleFontSize.extraLarge,
                                label: Text(
                                  context.l10n.settingsSubtitleExtraLarge,
                                ),
                              ),
                            ],
                            selected: <SubtitleFontSize>{settings.fontSize},
                            onSelectionChanged: (selection) {
                              notifier.save(
                                (current) =>
                                    current.copyWith(fontSize: selection.first),
                              );
                            },
                          ),
                          const SizedBox(height: KumoriyaSpacing.lg),
                          Text(
                            context.l10n.settingsSubtitleFontColor,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: KumoriyaSpacing.sm),
                          Wrap(
                            spacing: KumoriyaSpacing.sm,
                            runSpacing: KumoriyaSpacing.sm,
                            children: SubtitleFontColor.values
                                .map(
                                  (color) => buildColorDot(
                                    color: color.color,
                                    selected: settings.fontColor == color,
                                    onTap: () => notifier.save(
                                      (current) =>
                                          current.copyWith(fontColor: color),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: KumoriyaSpacing.lg),
                          Text(
                            '${context.l10n.settingsSubtitleFontOpacity} ${(settings.fontOpacity * 100).round()}%',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Slider(
                            value: settings.fontOpacity,
                            min: 0.25,
                            max: 1.0,
                            divisions: 3,
                            onChanged: (value) {
                              notifier.save(
                                (current) =>
                                    current.copyWith(fontOpacity: value),
                              );
                            },
                          ),
                          Text(
                            context.l10n.settingsSubtitleBgColor,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: KumoriyaSpacing.sm),
                          SegmentedButton<SubtitleBackgroundColor>(
                            segments: <ButtonSegment<SubtitleBackgroundColor>>[
                              ButtonSegment(
                                value: SubtitleBackgroundColor.black,
                                label: Text(
                                  context.l10n.settingsSubtitleBgBlack,
                                ),
                              ),
                              ButtonSegment(
                                value: SubtitleBackgroundColor.darkGray,
                                label: Text(
                                  context.l10n.settingsSubtitleBgDarkGray,
                                ),
                              ),
                              ButtonSegment(
                                value: SubtitleBackgroundColor.transparent,
                                label: Text(
                                  context.l10n.settingsSubtitleBgNone,
                                ),
                              ),
                            ],
                            selected: <SubtitleBackgroundColor>{
                              settings.backgroundColor,
                            },
                            onSelectionChanged: (selection) {
                              notifier.save(
                                (current) => current.copyWith(
                                  backgroundColor: selection.first,
                                ),
                              );
                            },
                          ),
                          if (settings.backgroundColor !=
                              SubtitleBackgroundColor.transparent) ...<Widget>[
                            const SizedBox(height: KumoriyaSpacing.lg),
                            Text(
                              '${context.l10n.settingsSubtitleBgOpacity} ${(settings.backgroundOpacity * 100).round()}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Slider(
                              value: settings.backgroundOpacity,
                              min: 0.0,
                              max: 1.0,
                              divisions: 4,
                              onChanged: (value) {
                                notifier.save(
                                  (current) => current.copyWith(
                                    backgroundOpacity: value,
                                  ),
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: KumoriyaSpacing.lg),
                          Text(
                            context.l10n.settingsSubtitleEdgeStyle,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: KumoriyaSpacing.sm),
                          Wrap(
                            spacing: KumoriyaSpacing.sm,
                            runSpacing: KumoriyaSpacing.sm,
                            children: SubtitleEdgeStyle.values
                                .map((style) {
                                  final label = switch (style) {
                                    SubtitleEdgeStyle.none =>
                                      context.l10n.settingsSubtitleEdgeNone,
                                    SubtitleEdgeStyle.outline =>
                                      context.l10n.settingsSubtitleEdgeOutline,
                                    SubtitleEdgeStyle.dropShadow =>
                                      context
                                          .l10n
                                          .settingsSubtitleEdgeDropShadow,
                                    SubtitleEdgeStyle.raised =>
                                      context.l10n.settingsSubtitleEdgeRaised,
                                    SubtitleEdgeStyle.depressed =>
                                      context
                                          .l10n
                                          .settingsSubtitleEdgeDepressed,
                                  };
                                  return ChoiceChip(
                                    label: Text(label),
                                    selected: settings.edgeStyle == style,
                                    onSelected: (_) {
                                      notifier.save(
                                        (current) =>
                                            current.copyWith(edgeStyle: style),
                                      );
                                    },
                                  );
                                })
                                .toList(growable: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showPlayerSelectorSheet({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<_PlayerSelectorOption> options,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _PlayerSelectorSheet(title: title, icon: icon, options: options);
      },
    );
  }

  Duration get _effectiveSliderPosition => Duration(
    milliseconds:
        (_isScrubbing
                ? (_scrubPositionMs ??
                      _currentPosition.inMilliseconds.toDouble())
                : _currentPosition.inMilliseconds.toDouble())
            .round(),
  );

  double get _sliderMaxMs {
    final durationMs = _currentDuration.inMilliseconds.toDouble();
    return durationMs > 0 ? durationMs : 1;
  }

  double get _sliderValueMs {
    final value = _effectiveSliderPosition.inMilliseconds.toDouble();
    if (value < 0) {
      return 0;
    }
    if (value > _sliderMaxMs) {
      return _sliderMaxMs;
    }
    return value;
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  void _log(String message) {
    if (!kDebugMode || !_playerVerboseLogs) {
      return;
    }
    debugPrint(
      '[player.page#$_instanceId ${DateTime.now().toIso8601String()}] $message',
    );
  }
}

class _ImmersivePlayerView extends StatefulWidget {
  const _ImmersivePlayerView({
    required this.engine,
    required this.isLoading,
    required this.isPlaying,
    required this.isError,
    required this.animeTitle,
    required this.episodeNumber,
    required this.currentPosition,
    required this.totalDuration,
    required this.sliderValue,
    required this.sliderMax,
    required this.hasMultipleAudio,
    required this.hasSubtitles,
    required this.onTogglePlayPause,
    required this.onSeekChanged,
    required this.onSeekEnd,
    required this.onSeekStart,
    required this.onBack,
    required this.onRetry,
    this.onOpenEpisodes,
    this.onPreviousEpisode,
    required this.onQuality,
    required this.onAudio,
    required this.onSubtitle,
    required this.formatDuration,
    required this.onSkipBackward,
    required this.onSkipForward,
    this.onSeekByDelta,
    required this.activeSkipLabel,
    required this.onSkipSegment,
    required this.autoSkipEnabled,
    this.onAutoSkipToggled,
    this.showFallbackSkip = false,
    this.onFallbackSkip,
    required this.isWindowsFullscreen,
    required this.onToggleWindowsFullscreen,
    this.errorMessage,
    this.subtitleViewConfiguration,
    this.episodeTitle,
    this.onVolumeChanged,
    this.onBrightnessChanged,
    this.onSpeedChanged,
    this.diagnosticsStream,
    this.seekLatencyMs,
  });

  final PlaybackEngine? engine;
  final bool isLoading;
  final bool isPlaying;
  final bool isError;
  final String animeTitle;
  final String episodeNumber;
  final String? episodeTitle;
  final Duration currentPosition;
  final Duration totalDuration;
  final double sliderValue;
  final double sliderMax;
  final bool hasMultipleAudio;
  final bool hasSubtitles;
  final VoidCallback? onTogglePlayPause;
  final ValueChanged<double>? onSeekChanged;
  final ValueChanged<double>? onSeekEnd;
  final VoidCallback? onSeekStart;
  final VoidCallback onBack;
  final VoidCallback onRetry;
  final VoidCallback? onOpenEpisodes;
  final VoidCallback? onPreviousEpisode;
  final VoidCallback onQuality;
  final VoidCallback? onAudio;
  final VoidCallback? onSubtitle;
  final VoidCallback? onSkipBackward;
  final VoidCallback? onSkipForward;
  final ValueChanged<Duration>? onSeekByDelta;
  final String? activeSkipLabel;
  final VoidCallback? onSkipSegment;
  final bool autoSkipEnabled;
  final VoidCallback? onAutoSkipToggled;
  final bool showFallbackSkip;
  final VoidCallback? onFallbackSkip;
  final bool isWindowsFullscreen;
  final VoidCallback? onToggleWindowsFullscreen;
  final String? errorMessage;
  final String Function(Duration) formatDuration;
  final SubtitleViewConfiguration? subtitleViewConfiguration;
  final ValueChanged<double>? onVolumeChanged;
  final ValueChanged<double>? onBrightnessChanged;
  final ValueChanged<double>? onSpeedChanged;
  final Stream<PlayerDiagnostics>? diagnosticsStream;
  final int? seekLatencyMs;

  @override
  State<_ImmersivePlayerView> createState() => _ImmersivePlayerViewState();
}

class _ImmersivePlayerViewState extends State<_ImmersivePlayerView>
    with TickerProviderStateMixin {
  bool _controlsVisible = true;
  Timer? _hideTimer;
  bool _seekIndicatorVisible = false;
  bool _seekIndicatorForward = true;
  Timer? _seekIndicatorTimer;

  // Accumulated seek state: taps add ±10s, commit after idle.
  int _pendingSeekSeconds = 0;
  Timer? _seekCommitTimer;
  static const Duration _seekCommitDelay = Duration(milliseconds: 800);
  bool _orientationLocked = true;
  bool _isDragSeeking = false;
  double _dragSeekAccumulatedDx = 0;
  Duration _dragSeekTargetPosition = Duration.zero;
  DateTime _lastDragSetState = DateTime(2000);
  Timer? _mouseIdleTimer;
  bool _skipButtonVisible = true;
  Timer? _skipButtonHideTimer;
  late final AnimationController _skipProgressController;
  String? _lastSkipLabel;

  // Continuous vsync pump: forces Flutter to schedule a frame every vsync
  // while the video is playing. On Linux the media_kit Video widget renders
  // through a Flutter Texture; the compositor only resamples that texture
  // when Flutter produces a frame. Without this ticker, Flutter enters idle
  // between sparse setStates (position ~2 Hz) and the video appears to stutter
  // at that same rate even though mpv decodes 24 fps cleanly.
  late final Ticker _vsyncPump;

  // Double-tap seek state
  Timer? _doubleTapTimer;
  int _lastTapZone = -1;

  // Rapid-seek state: after a double-tap seek, subsequent taps in the same
  // zone within _rapidSeekWindow keep seeking without the 200 ms wait.
  bool _inRapidSeekMode = false;
  Timer? _rapidSeekTimer;
  static const Duration _rapidSeekWindow = Duration(seconds: 1);

  // Controls lock
  bool _controlsLocked = false;

  // Volume/brightness gesture overlay state
  bool _showBrightnessOverlay = false;
  bool _showVolumeOverlay = false;
  double _brightnessLevel = 0.5;
  double _volumeLevel = 1.0;
  Timer? _overlayHideTimer;
  Offset? _verticalDragStart;
  bool _isVerticalDragBrightness = false;

  // Long-press speed state
  double _baseSpeed = 1.0;
  double _speedMultiplier = 1.0;

  // Player HUD status indicators
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  // Battery indicator (top-right HUD).
  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _batteryStateSub;
  Timer? _batteryLevelTimer;
  int? _batteryLevel;
  BatteryState _batteryState = BatteryState.unknown;

  @override
  void initState() {
    super.initState();
    _skipProgressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
      value: 1.0,
    );
    // Empty-callback ticker: its only job is to keep Flutter scheduling
    // frames every vsync so the media_kit texture gets composited at the
    // display refresh rate, not at the setState rate.
    _vsyncPump = createTicker((_) {});
    if (widget.isPlaying) {
      _vsyncPump.start();
    }
    unawaited(_initBrightness());
    unawaited(_initVolume());
    _startClockTicker();
    _startBatteryWatcher();
    _startHideTimer();
  }

  void _startBatteryWatcher() {
    // Initial fetch + periodic refresh. battery_plus does not expose a
    // level stream on every platform, so we poll at a low frequency in
    // addition to subscribing to charging-state changes.
    unawaited(_refreshBatteryLevel());
    _batteryLevelTimer?.cancel();
    _batteryLevelTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(_refreshBatteryLevel()),
    );
    try {
      _batteryStateSub = _battery.onBatteryStateChanged.listen((state) {
        if (!mounted) return;
        setState(() => _batteryState = state);
        unawaited(_refreshBatteryLevel());
      });
    } catch (_) {}
  }

  Future<void> _refreshBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      if (!mounted) return;
      setState(() => _batteryLevel = level);
    } catch (_) {}
  }

  void _startClockTicker() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  @override
  void didUpdateWidget(covariant _ImmersivePlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Start/stop the vsync pump to match playback state. Pausing stops
    // scheduling work so the app doesn't burn CPU/GPU when the user isn't
    // actively watching.
    if (widget.isPlaying && !_vsyncPump.isActive) {
      _vsyncPump.start();
    } else if (!widget.isPlaying && _vsyncPump.isActive) {
      _vsyncPump.stop();
    }
    // Track skip label changes for auto-hide behavior.
    if (widget.activeSkipLabel != null &&
        widget.activeSkipLabel != _lastSkipLabel) {
      _lastSkipLabel = widget.activeSkipLabel;
      setState(() {
        _skipButtonVisible = true;
      });
      _skipButtonHideTimer?.cancel();
      _skipProgressController.value = 1.0;
      _skipProgressController.reverse();

      _skipButtonHideTimer = Timer(const Duration(seconds: 5), () {
        _skipProgressController.stop();
        if (mounted) setState(() => _skipButtonVisible = false);
      });
    } else if (widget.activeSkipLabel == null) {
      _lastSkipLabel = null;
      _skipButtonHideTimer?.cancel();
      _skipProgressController.stop();
      _skipProgressController.value = 1.0;
      _skipButtonVisible = true;
    }
  }

  Future<void> _initBrightness() async {
    try {
      // Read the current SYSTEM brightness so the slider starts in sync
      // with the device's actual on-screen level. Reading `application`
      // returns the per-app override (often -1 if unset), which would
      // cause the slider to jump on first drag.
      final brightness = ScreenBrightness();
      final current = await brightness.system;
      if (mounted) {
        setState(() => _brightnessLevel = current);
      }
    } catch (_) {}
  }

  Future<void> _initVolume() async {
    try {
      VolumeController.instance.showSystemUI = false;
      final current = await VolumeController.instance.getVolume();
      if (mounted) {
        setState(() => _volumeLevel = current);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    _seekCommitTimer?.cancel();
    _overlayHideTimer?.cancel();
    _mouseIdleTimer?.cancel();
    _skipButtonHideTimer?.cancel();
    _clockTimer?.cancel();
    _batteryLevelTimer?.cancel();
    _batteryStateSub?.cancel();
    _skipProgressController.dispose();
    _vsyncPump.dispose();
    _doubleTapTimer?.cancel();
    _rapidSeekTimer?.cancel();
    // Always release the application-level brightness override so the
    // system brightness takes over again when leaving the player. Setting
    // it back to `_initialBrightness` would keep the override active for
    // the rest of the app session.
    try {
      unawaited(ScreenBrightness().resetApplicationScreenBrightness());
    } catch (_) {}
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_isDragSeeking) return;
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && widget.isPlaying && !_isDragSeeking) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    if (_controlsLocked) return;
    setState(() {
      _controlsVisible = !_controlsVisible;
      if (_controlsVisible) _startHideTimer();
    });
  }

  int _zoneFromPosition(Offset localPosition) {
    final width = MediaQuery.of(context).size.width;
    if (width <= 0) return 1;
    final third = width / 3;
    if (localPosition.dx < third) return 0;
    if (localPosition.dx < third * 2) return 1;
    return 2;
  }

  void _onTapUp(TapUpDetails details) {
    if (_controlsLocked) return;
    final zone = _zoneFromPosition(details.localPosition);
    _handleTapInZone(zone);
  }

  void _handleTapInZone(int zone) {
    if (_controlsLocked) return;

    // During rapid-seek mode every side tap acts like a seek button press.
    // This keeps repeated taps responsive and avoids falling back to toggle.
    if (_inRapidSeekMode && (zone == 0 || zone == 2)) {
      _rapidSeekTimer?.cancel();
      setState(() {
        _lastTapZone = zone;
      });
      _performSeekForZone(zone);
      _rapidSeekTimer = Timer(_rapidSeekWindow, _exitRapidSeekMode);
      return;
    }

    // ── Double-tap detection ──
    if (_doubleTapTimer?.isActive == true && _lastTapZone == zone) {
      _doubleTapTimer!.cancel();
      _doubleTapTimer = null;
      if (zone == 0 || zone == 2) {
        _performSeekForZone(zone);
        _enterRapidSeekMode(zone);
      } else if (zone == 1 && !kIsWeb && Platform.isWindows) {
        widget.onToggleWindowsFullscreen?.call();
      }
    } else {
      _doubleTapTimer?.cancel();
      _exitRapidSeekMode();
      setState(() {
        _lastTapZone = zone;
      });
      _doubleTapTimer = Timer(const Duration(milliseconds: 200), () {
        _doubleTapTimer = null;
        _toggleControls();
      });
    }
  }

  void _performSeekForZone(int zone) {
    if (zone == 0) {
      _accumulateSeek(-10);
      return;
    }
    if (zone == 2) {
      _accumulateSeek(10);
    }
  }

  void _accumulateSeek(int deltaSeconds) {
    _seekCommitTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    setState(() {
      _pendingSeekSeconds += deltaSeconds;
      _seekIndicatorForward = _pendingSeekSeconds >= 0;
      _seekIndicatorVisible = true;
    });
    _seekCommitTimer = Timer(_seekCommitDelay, _commitPendingSeek);
  }

  void _commitPendingSeek() {
    if (!mounted || _pendingSeekSeconds == 0) {
      _hidePendingSeekIndicator();
      return;
    }
    final delta = _pendingSeekSeconds;
    _pendingSeekSeconds = 0;
    if (delta > 0) {
      // Forward seek
      final maxPos = widget.totalDuration - const Duration(seconds: 1);
      final target = widget.currentPosition + Duration(seconds: delta);
      widget.onSeekByDelta?.call(
        target > maxPos && maxPos > Duration.zero ? maxPos : target,
      );
    } else {
      // Backward seek
      final target = widget.currentPosition + Duration(seconds: delta);
      widget.onSeekByDelta?.call(
        target < Duration.zero ? Duration.zero : target,
      );
    }
    // Hide indicator after a short delay so user sees the final value.
    _seekIndicatorTimer = Timer(const Duration(milliseconds: 400), () {
      _hidePendingSeekIndicator();
    });
  }

  void _hidePendingSeekIndicator() {
    if (!mounted) return;
    setState(() {
      _seekIndicatorVisible = false;
      _pendingSeekSeconds = 0;
    });
  }

  void _enterRapidSeekMode(int zone) {
    setState(() {
      _inRapidSeekMode = true;
      _lastTapZone = zone;
    });
    _rapidSeekTimer?.cancel();
    _rapidSeekTimer = Timer(_rapidSeekWindow, _exitRapidSeekMode);
  }

  void _exitRapidSeekMode() {
    if (mounted && _inRapidSeekMode) {
      setState(() {
        _inRapidSeekMode = false;
      });
    } else {
      _inRapidSeekMode = false;
    }
    _rapidSeekTimer?.cancel();
    _rapidSeekTimer = null;
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_controlsLocked) return;
    if (Platform.isWindows) return;
    _doubleTapTimer?.cancel();
    _doubleTapTimer = null;
    _exitRapidSeekMode();
    _hideTimer?.cancel();
    setState(() {
      _isDragSeeking = true;
      _controlsVisible = true;
      _dragSeekAccumulatedDx = 0;
      _dragSeekTargetPosition = widget.currentPosition;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_controlsLocked) return;
    if (!_isDragSeeking) return;

    _dragSeekAccumulatedDx += details.delta.dx;
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth <= 0) return;
    final ratio = _dragSeekAccumulatedDx / (screenWidth * 2.5);
    final seekDeltaMs = (ratio * widget.totalDuration.inMilliseconds).round();
    final target = Duration(
      milliseconds: (widget.currentPosition.inMilliseconds + seekDeltaMs).clamp(
        0,
        widget.totalDuration.inMilliseconds,
      ),
    );

    // Throttle setState during drag to ~15 Hz (every ~66ms) to cut rebuilds.
    _dragSeekTargetPosition = target;
    final now = DateTime.now();
    if (now.difference(_lastDragSetState).inMilliseconds >= 66) {
      _lastDragSetState = now;
      setState(() {});
    }
  }

  void _onMouseActivity() {
    if (!_controlsVisible && !_controlsLocked) {
      setState(() {
        _controlsVisible = true;
      });
    }
    _startHideTimer();
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_controlsLocked) return;
    if (!_isDragSeeking) return;

    final deltaMs =
        (_dragSeekTargetPosition - widget.currentPosition).inMilliseconds;
    setState(() {
      _isDragSeeking = false;
      _dragSeekAccumulatedDx = 0;
      _controlsVisible = false;
    });
    _hideTimer?.cancel();

    // Only seek if delta is significant (>1 second)
    if (deltaMs.abs() > 1000) {
      widget.onSeekChanged?.call(
        _dragSeekTargetPosition.inMilliseconds.toDouble(),
      );
      widget.onSeekEnd?.call(_dragSeekTargetPosition.inMilliseconds.toDouble());
    }
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (_controlsLocked) return;
    if (Platform.isWindows) return;
    _doubleTapTimer?.cancel();
    _doubleTapTimer = null;
    _exitRapidSeekMode();
    final width = MediaQuery.of(context).size.width;
    _verticalDragStart = details.localPosition;
    _isVerticalDragBrightness = details.localPosition.dx < width / 2;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_controlsLocked) return;
    if (_verticalDragStart == null) return;
    final delta = -details.delta.dy / 200;
    setState(() {
      if (_isVerticalDragBrightness) {
        _brightnessLevel = (_brightnessLevel + delta).clamp(0.0, 1.0);
        _showBrightnessOverlay = true;
        widget.onBrightnessChanged?.call(_brightnessLevel);
      } else {
        _volumeLevel = (_volumeLevel + delta).clamp(0.0, 2.0);
        _showVolumeOverlay = true;
      }
    });
    if (!_isVerticalDragBrightness) {
      widget.onVolumeChanged?.call(_volumeLevel);
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_controlsLocked) return;
    _verticalDragStart = null;
    _overlayHideTimer?.cancel();
    _overlayHideTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showBrightnessOverlay = false;
          _showVolumeOverlay = false;
        });
      }
    });
  }

  void _toggleOrientationLock() {
    setState(() {
      _orientationLocked = !_orientationLocked;
    });
    if (_orientationLocked) {
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[]);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.keyK:
        widget.onTogglePlayPause?.call();
        _startHideTimer();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _accumulateSeek(-10);
        _startHideTimer();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _accumulateSeek(10);
        _startHideTimer();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        final newVolUp = (_volumeLevel + 0.1).clamp(0.0, 2.0);
        setState(() {
          _volumeLevel = newVolUp;
          _showVolumeOverlay = true;
        });
        widget.onVolumeChanged?.call(newVolUp);
        _overlayHideTimer?.cancel();
        _overlayHideTimer = Timer(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _showVolumeOverlay = false);
        });
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        final newVolDown = (_volumeLevel - 0.1).clamp(0.0, 2.0);
        setState(() {
          _volumeLevel = newVolDown;
          _showVolumeOverlay = true;
        });
        widget.onVolumeChanged?.call(newVolDown);
        _overlayHideTimer?.cancel();
        _overlayHideTimer = Timer(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _showVolumeOverlay = false);
        });
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyM:
        final newVolMute = _volumeLevel > 0 ? 0.0 : 1.0;
        setState(() {
          _volumeLevel = newVolMute;
          _showVolumeOverlay = true;
        });
        widget.onVolumeChanged?.call(newVolMute);
        _overlayHideTimer?.cancel();
        _overlayHideTimer = Timer(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _showVolumeOverlay = false);
        });
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyF:
        widget.onToggleWindowsFullscreen?.call();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        widget.onBack.call();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatSeekDelta(Duration delta) {
    final totalSeconds = delta.inSeconds;
    final sign = totalSeconds >= 0 ? '+' : '-';
    final abs = totalSeconds.abs();
    final m = abs ~/ 60;
    final s = abs % 60;
    if (m > 0) {
      return '$sign${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$sign${s}s';
  }

  String _formatCurrentTime(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.Hm(locale).format(_currentTime);
  }

  IconData _batteryIcon(int level, BatteryState state) {
    if (state == BatteryState.charging || state == BatteryState.full) {
      return Icons.battery_charging_full_rounded;
    }
    if (level >= 95) return Icons.battery_full_rounded;
    if (level >= 85) return Icons.battery_6_bar_rounded;
    if (level >= 70) return Icons.battery_5_bar_rounded;
    if (level >= 55) return Icons.battery_4_bar_rounded;
    if (level >= 40) return Icons.battery_3_bar_rounded;
    if (level >= 25) return Icons.battery_2_bar_rounded;
    if (level >= 10) return Icons.battery_1_bar_rounded;
    return Icons.battery_alert_rounded;
  }

  Color _batteryIconColor(int level, BatteryState state) {
    if (state == BatteryState.charging || state == BatteryState.full) {
      return KumoriyaColors.accentMint;
    }
    if (level <= 15) return KumoriyaColors.accentRose;
    if (level <= 30) return KumoriyaColors.accentAmber;
    return KumoriyaColors.textSecondary;
  }

  void _showSpeedSelector(BuildContext context) {
    const speeds = <double>[0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet<double>(
      context: context,
      backgroundColor: KumoriyaColors.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Playback Speed',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: speeds
                    .map(
                      (speed) => ListTile(
                        title: Text(
                          speed == 1.0 ? '1.0x (Normal)' : '${speed}x',
                          style: TextStyle(
                            color: speed == _baseSpeed
                                ? KumoriyaColors.primary
                                : KumoriyaColors.textPrimary,
                            fontWeight: speed == _baseSpeed
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        trailing: speed == _baseSpeed
                            ? const Icon(
                                Icons.check_rounded,
                                color: KumoriyaColors.primary,
                              )
                            : null,
                        onTap: () => Navigator.of(ctx).pop(speed),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    ).then((selected) {
      if (!mounted || selected == null || selected == _baseSpeed) {
        return;
      }
      setState(() {
        _baseSpeed = selected;
        _speedMultiplier = selected;
      });
      widget.onSpeedChanged?.call(selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        onHover: (_) {
          if (Platform.isWindows) _onMouseActivity();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: _onTapUp,
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          onVerticalDragStart: _onVerticalDragStart,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          onLongPressStart: (_) {
            if (_controlsLocked) return;
            _doubleTapTimer?.cancel();
            _doubleTapTimer = null;
            _exitRapidSeekMode();
            setState(() => _speedMultiplier = 2.0);
            widget.onSpeedChanged?.call(2.0);
          },
          onLongPressEnd: (_) {
            if (_controlsLocked) return;
            setState(() => _speedMultiplier = _baseSpeed);
            widget.onSpeedChanged?.call(_baseSpeed);
          },
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Video layer
              if (widget.engine != null)
                RepaintBoundary(
                  child: IgnorePointer(
                    // Native-surface backed video. Pointer events still go to the
                    // Flutter overlay so playback controls stay interactive for
                    // every stream type and every backend (media_kit / ExoPlayer).
                    child: PlayerVideoSurface(
                      engine: widget.engine!,
                      fit: BoxFit.contain,
                      subtitleViewConfiguration:
                          widget.subtitleViewConfiguration,
                    ),
                  ),
                )
              else
                const ColoredBox(color: Colors.black),

              // Seek indicator (double-tap accumulation)
              if (_seekIndicatorVisible && !_isDragSeeking)
                Align(
                  alignment: _seekIndicatorForward
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 64),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          _seekIndicatorForward
                              ? Icons.fast_forward_rounded
                              : Icons.fast_rewind_rounded,
                          color: KumoriyaColors.textPrimary,
                          size: 36,
                          shadows: const <Shadow>[
                            Shadow(color: Color(0xCC000000), blurRadius: 8),
                            Shadow(color: Color(0x66000000), blurRadius: 24),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_pendingSeekSeconds >= 0 ? '+' : ''}${_pendingSeekSeconds}s',
                          style: Theme.of(context).textTheme.headlineSmall!
                              .copyWith(
                                color: KumoriyaColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                shadows: const <Shadow>[
                                  Shadow(
                                    color: Color(0xCC000000),
                                    blurRadius: 8,
                                  ),
                                  Shadow(
                                    color: Color(0x66000000),
                                    blurRadius: 24,
                                  ),
                                ],
                              ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Volume overlay
              if (_showVolumeOverlay)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: _VerticalSliderOverlay(
                      icon: _volumeLevel > 1.0
                          ? Icons.volume_up_rounded
                          : _volumeLevel > 0.5
                          ? Icons.volume_up_rounded
                          : _volumeLevel > 0
                          ? Icons.volume_down_rounded
                          : Icons.volume_off_rounded,
                      value: (_volumeLevel / 2.0).clamp(0.0, 1.0),
                      label: '${(_volumeLevel * 100).round()}%',
                      isBoost: _volumeLevel > 1.0,
                    ),
                  ),
                ),

              // Brightness overlay
              if (_showBrightnessOverlay)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: _VerticalSliderOverlay(
                      icon: Icons.brightness_6_rounded,
                      value: _brightnessLevel,
                      label: '${(_brightnessLevel * 100).round()}%',
                      isBoost: false,
                    ),
                  ),
                ),

              // 2× Speed badge (plain tint — no BackdropFilter: blur via
              // saveLayer collapses compositor FPS on Linux).
              if (_speedMultiplier > 1.0)
                Align(
                  alignment: Alignment.topCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 56),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC1E1629),
                          borderRadius: BorderRadius.circular(
                            KumoriyaRadius.full,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.fast_forward_rounded,
                              color: KumoriyaColors.textPrimary,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_speedMultiplier.toStringAsFixed(0)}×',
                              style: Theme.of(context).textTheme.labelLarge!
                                  .copyWith(color: KumoriyaColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Loading overlay
              if (widget.isLoading)
                Container(
                  color: KumoriyaColors.scrimLight,
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(
                    color: KumoriyaColors.textPrimary,
                  ),
                ),

              // Debug diagnostics overlay (debug builds only)
              if (kDebugMode && widget.diagnosticsStream != null)
                PlayerDebugOverlay(
                  diagnosticsStream: widget.diagnosticsStream!,
                  seekLatencyMs: widget.seekLatencyMs,
                ),

              // Error banner
              if (widget.isError && widget.errorMessage != null)
                Align(
                  alignment: Alignment.topCenter,
                  child: SafeArea(
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: KumoriyaColors.statusDanger,
                        borderRadius: BorderRadius.circular(KumoriyaRadius.md),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            widget.errorMessage!,
                            style: Theme.of(context).textTheme.bodySmall!
                                .copyWith(color: KumoriyaColors.textPrimary),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: widget.onRetry,
                            style: TextButton.styleFrom(
                              foregroundColor: KumoriyaColors.textPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: Text(context.l10n.playerRetry),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Controls overlay (animated)
              RepaintBoundary(
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        // Radial vignettes (replaces linear gradient)
                        CustomPaint(
                          size: Size.infinite,
                          painter: const _RadialVignettePainter(),
                        ),

                        // Top-left: Back + title
                        Positioned(
                          left: KumoriyaSpacing.lg,
                          top:
                              KumoriyaSpacing.md +
                              MediaQuery.of(context).padding.top,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                onPressed: widget.onBack,
                                tooltip: context.l10n.playerBack,
                                icon: Icon(
                                  KumoriyaIcons.playerBack,
                                  color: KumoriyaColors.textPrimary,
                                  size: 24,
                                  shadows: const <Shadow>[
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                iconSize: 24,
                                padding: const EdgeInsets.all(12),
                              ),
                              const SizedBox(width: KumoriyaSpacing.sm),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    widget.animeTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(
                                          color: KumoriyaColors.textMuted,
                                          shadows: const <Shadow>[
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                  ),
                                  Text(
                                    widget.episodeTitle != null
                                        ? 'EP ${widget.episodeNumber} \u2014 ${widget.episodeTitle}'
                                        : 'EP ${widget.episodeNumber}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall!
                                        .copyWith(
                                          color: KumoriyaColors.textPrimary,
                                          shadows: const <Shadow>[
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Top-right: Settings + navigation cluster
                        Positioned(
                          right: KumoriyaSpacing.lg,
                          top:
                              KumoriyaSpacing.md +
                              MediaQuery.of(context).padding.top,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: KumoriyaColors.playerControlBg,
                                  borderRadius: BorderRadius.circular(
                                    KumoriyaRadius.full,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 14,
                                      color: KumoriyaColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatCurrentTime(context),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: KumoriyaColors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (_batteryLevel != null) ...<Widget>[
                                      const SizedBox(width: 10),
                                      Icon(
                                        _batteryIcon(
                                          _batteryLevel!,
                                          _batteryState,
                                        ),
                                        size: 14,
                                        color: _batteryIconColor(
                                          _batteryLevel!,
                                          _batteryState,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_batteryLevel!}%',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: KumoriyaColors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: KumoriyaSpacing.sm),
                              // Speed pill
                              GestureDetector(
                                onTap: () => _showSpeedSelector(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: KumoriyaColors.playerControlBg,
                                    borderRadius: BorderRadius.circular(
                                      KumoriyaRadius.full,
                                    ),
                                  ),
                                  child: Text(
                                    '${_baseSpeed}x',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall!
                                        .copyWith(
                                          color: _baseSpeed != 1.0
                                              ? KumoriyaColors.accentAmber
                                              : KumoriyaColors.textPrimary,
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: KumoriyaSpacing.sm),
                              // Auto-skip toggle
                              GestureDetector(
                                onTap: widget.onAutoSkipToggled,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: KumoriyaColors.playerControlBg,
                                    borderRadius: BorderRadius.circular(
                                      KumoriyaRadius.full,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(
                                        Icons.fast_forward_rounded,
                                        size: 16,
                                        color: widget.autoSkipEnabled
                                            ? KumoriyaColors.accentAmber
                                            : KumoriyaColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Auto',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall!
                                            .copyWith(
                                              color: widget.autoSkipEnabled
                                                  ? KumoriyaColors.accentAmber
                                                  : KumoriyaColors
                                                        .textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: KumoriyaSpacing.md),
                              // Previous episode
                              if (widget.onPreviousEpisode != null)
                                IconButton(
                                  onPressed: widget.onPreviousEpisode,
                                  icon: Icon(
                                    KumoriyaIcons.playerPreviousEpisode,
                                    color: KumoriyaColors.textPrimary,
                                    size: 24,
                                    shadows: const <Shadow>[
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  iconSize: 24,
                                  padding: const EdgeInsets.all(12),
                                  tooltip: context.l10n.playerPreviousEpisode,
                                ),
                              // Next episode
                              if (widget.onOpenEpisodes != null)
                                IconButton(
                                  onPressed: widget.onOpenEpisodes,
                                  icon: Icon(
                                    KumoriyaIcons.playerNextEpisode,
                                    color: KumoriyaColors.textPrimary,
                                    size: 28,
                                    shadows: const <Shadow>[
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  iconSize: 28,
                                  padding: const EdgeInsets.all(10),
                                  tooltip: context.l10n.playerNextEpisode,
                                ),
                              const SizedBox(width: KumoriyaSpacing.md),
                              // Fullscreen / Orientation lock
                              if (Platform.isWindows)
                                IconButton(
                                  onPressed: widget.onToggleWindowsFullscreen,
                                  icon: Icon(
                                    widget.isWindowsFullscreen
                                        ? KumoriyaIcons.playerFullscreenExit
                                        : KumoriyaIcons.playerFullscreen,
                                    color: KumoriyaColors.textPrimary,
                                    size: 24,
                                    shadows: const <Shadow>[
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  iconSize: 24,
                                  padding: const EdgeInsets.all(12),
                                  tooltip: widget.isWindowsFullscreen
                                      ? 'Exit fullscreen'
                                      : 'Fullscreen',
                                )
                              else
                                IconButton(
                                  onPressed: _toggleOrientationLock,
                                  icon: Icon(
                                    _orientationLocked
                                        ? Icons.screen_lock_rotation_rounded
                                        : Icons.screen_rotation_rounded,
                                    color: KumoriyaColors.textPrimary,
                                    size: 24,
                                    shadows: const <Shadow>[
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  iconSize: 24,
                                  padding: const EdgeInsets.all(12),
                                  tooltip: _orientationLocked
                                      ? context.l10n.playerUnlockRotation
                                      : context.l10n.playerLockRotation,
                                ),
                              const SizedBox(width: KumoriyaSpacing.sm),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _controlsLocked = true;
                                    _controlsVisible = false;
                                  });
                                  _hideTimer?.cancel();
                                },
                                icon: Icon(
                                  Icons.lock_outline_rounded,
                                  color: KumoriyaColors.textPrimary,
                                  size: 24,
                                  shadows: const <Shadow>[
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                iconSize: 24,
                                padding: const EdgeInsets.all(12),
                                tooltip: context.l10n.playerLockControls,
                              ),
                            ],
                          ),
                        ),

                        // Center: Frosted glass play/pause + bare skip buttons
                        if (!_isDragSeeking)
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                // Skip back
                                SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: IconButton(
                                    onPressed: widget.onSkipBackward,
                                    tooltip: context.l10n.playerSkipBackward,
                                    icon: Icon(
                                      KumoriyaIcons.playerSeekBack10,
                                      color: KumoriyaColors.textPrimary,
                                      size: 28,
                                      shadows: const <Shadow>[
                                        Shadow(
                                          color: Color(0xCC000000),
                                          blurRadius: 8,
                                        ),
                                        Shadow(
                                          color: Color(0x66000000),
                                          blurRadius: 24,
                                        ),
                                      ],
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                const SizedBox(width: KumoriyaSpacing.xxxl),
                                // Play/pause (plain tint — no BackdropFilter).
                                Material(
                                  color: Colors.transparent,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: widget.onTogglePlayPause,
                                    splashColor: KumoriyaColors.primaryLight
                                        .withValues(alpha: 0.20),
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xCC1E1629),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.10,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          widget.isPlaying
                                              ? KumoriyaIcons.playerPause
                                              : KumoriyaIcons.playerPlay,
                                          color: KumoriyaColors.textPrimary,
                                          size: 48,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: KumoriyaSpacing.xxxl),
                                // Skip forward
                                SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: IconButton(
                                    onPressed: widget.onSkipForward,
                                    tooltip: context.l10n.playerSkipForward,
                                    icon: Icon(
                                      KumoriyaIcons.playerSeekForward10,
                                      color: KumoriyaColors.textPrimary,
                                      size: 28,
                                      shadows: const <Shadow>[
                                        Shadow(
                                          color: Color(0xCC000000),
                                          blurRadius: 8,
                                        ),
                                        Shadow(
                                          color: Color(0x66000000),
                                          blurRadius: 24,
                                        ),
                                      ],
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                // Fallback +90s skip (discrete, only when missing opening OR ending)
                                if (widget.showFallbackSkip && _controlsVisible)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: SizedBox(
                                      height: 32,
                                      child: TextButton(
                                        onPressed: widget.onFallbackSkip,
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          backgroundColor: Colors.black38,
                                          foregroundColor:
                                              KumoriyaColors.textSecondary,
                                          textStyle: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        child: const Text('+90s'),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                        // Bottom: Bare text action selectors
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 56,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              _BottomTextAction(
                                icon: KumoriyaIcons.playerQuality,
                                label: context.l10n.playerQuality,
                                onTap: widget.onQuality,
                              ),
                              if (widget.hasSubtitles) ...<Widget>[
                                const SizedBox(width: KumoriyaSpacing.xl),
                                _BottomTextAction(
                                  icon: KumoriyaIcons.playerSubtitle,
                                  label: context.l10n.playerSubtitles,
                                  onTap: widget.onSubtitle,
                                ),
                              ],
                              if (widget.hasMultipleAudio) ...<Widget>[
                                const SizedBox(width: KumoriyaSpacing.xl),
                                _BottomTextAction(
                                  icon: KumoriyaIcons.playerAudio,
                                  label: context.l10n.playerAudio,
                                  onTap: widget.onAudio,
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Bottom: Time labels
                        Positioned(
                          left: KumoriyaSpacing.lg,
                          bottom: 36,
                          child: RepaintBoundary(
                            child: Text(
                              widget.formatDuration(widget.currentPosition),
                              style: Theme.of(context).textTheme.labelSmall!
                                  .copyWith(
                                    color: KumoriyaColors.textSecondary,
                                    shadows: const <Shadow>[
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: KumoriyaSpacing.lg,
                          bottom: 36,
                          child: RepaintBoundary(
                            child: Text(
                              widget.formatDuration(widget.totalDuration),
                              style: Theme.of(context).textTheme.labelSmall!
                                  .copyWith(
                                    color: KumoriyaColors.textSecondary,
                                    shadows: const <Shadow>[
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                            ),
                          ),
                        ),

                        // Bottom: Full-bleed progress bar
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 8,
                          child: RepaintBoundary(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 5,
                                ),
                                activeTrackColor: KumoriyaColors.primary,
                                inactiveTrackColor: KumoriyaColors.textPrimary
                                    .withValues(alpha: 0.20),
                                thumbColor: KumoriyaColors.primaryLight,
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 24,
                                ),
                                overlayColor: KumoriyaColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                              child: Slider(
                                value: widget.sliderValue,
                                max: widget.sliderMax,
                                onChangeStart: (_) {
                                  _hideTimer?.cancel();
                                  widget.onSeekStart?.call();
                                },
                                onChanged: widget.onSeekChanged,
                                onChangeEnd: (value) {
                                  widget.onSeekEnd?.call(value);
                                  _startHideTimer();
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Proportional drag seek overlay (above controls)
              if (_isDragSeeking)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: KumoriyaColors.playerControlBg,
                      borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _formatDuration(_dragSeekTargetPosition),
                          style: Theme.of(context).textTheme.headlineMedium!
                              .copyWith(
                                color: KumoriyaColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatSeekDelta(
                            _dragSeekTargetPosition - widget.currentPosition,
                          ),
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(
                                color:
                                    (_dragSeekTargetPosition >=
                                        widget.currentPosition)
                                    ? KumoriyaColors.accentMint
                                    : KumoriyaColors.accentRose,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Unlock overlay for locked controls
              if (_controlsLocked)
                Positioned(
                  bottom: KumoriyaSpacing.xl,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => setState(() => _controlsLocked = false),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: KumoriyaColors.playerControlBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          color: KumoriyaColors.textPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),

              if (widget.activeSkipLabel != null &&
                  widget.onSkipSegment != null &&
                  _skipButtonVisible)
                RepaintBoundary(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 24, bottom: 92),
                        child: AnimatedSlide(
                          offset: _skipButtonVisible
                              ? Offset.zero
                              : const Offset(0.3, 0),
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          child: AnimatedOpacity(
                            opacity: _skipButtonVisible ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                KumoriyaRadius.full,
                              ),
                              child: InkWell(
                                onTap: widget.onSkipSegment,
                                borderRadius: BorderRadius.circular(
                                  KumoriyaRadius.full,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xD91E1629),
                                    borderRadius: BorderRadius.circular(
                                      KumoriyaRadius.full,
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.10,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: <Widget>[
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: AnimatedBuilder(
                                                animation:
                                                    _skipProgressController,
                                                builder: (_, _) =>
                                                    CircularProgressIndicator(
                                                      value:
                                                          _skipProgressController
                                                              .value,
                                                      strokeWidth: 2,
                                                      color: KumoriyaColors
                                                          .textPrimary
                                                          .withValues(
                                                            alpha: 0.7,
                                                          ),
                                                      backgroundColor:
                                                          KumoriyaColors
                                                              .textPrimary
                                                              .withValues(
                                                                alpha: 0.15,
                                                              ),
                                                    ),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.skip_next_rounded,
                                              color: KumoriyaColors.textPrimary,
                                              size: 14,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        widget.activeSkipLabel!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge!
                                            .copyWith(
                                              color: KumoriyaColors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerticalSliderOverlay extends StatelessWidget {
  const _VerticalSliderOverlay({
    required this.icon,
    required this.value,
    required this.label,
    required this.isBoost,
  });
  final IconData icon;
  final double value;
  final String label;
  final bool isBoost;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: KumoriyaColors.playerControlBg,
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: KumoriyaColors.textPrimary, size: 20),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: RotatedBox(
              quarterTurns: -1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(KumoriyaRadius.full),
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: KumoriyaColors.textPrimary.withValues(
                    alpha: 0.30,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isBoost
                        ? KumoriyaColors.statusWarning
                        : KumoriyaColors.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall!.copyWith(color: KumoriyaColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _RadialVignettePainter extends CustomPainter {
  const _RadialVignettePainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Top-left vignette (for back + title)
    final topLeftPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.85, -0.90),
        radius: 0.6,
        colors: <Color>[
          Colors.black.withValues(alpha: 0.55),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, topLeftPaint);

    // Center vignette (for play/pause)
    final centerPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.35,
        colors: <Color>[
          Colors.black.withValues(alpha: 0.40),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, centerPaint);

    // Bottom vignette (for progress bar + time)
    final bottomPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, 1.2),
        radius: 0.5,
        colors: <Color>[
          Colors.black.withValues(alpha: 0.60),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomTextAction extends StatelessWidget {
  const _BottomTextAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(KumoriyaRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KumoriyaSpacing.sm,
              vertical: KumoriyaSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 18, color: KumoriyaColors.textSecondary),
                const SizedBox(width: KumoriyaSpacing.xs),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium!.copyWith(
                    color: KumoriyaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerSelectorSheet extends StatelessWidget {
  const _PlayerSelectorSheet({
    required this.title,
    required this.icon,
    required this.options,
  });

  final String title;
  final IconData icon;
  final List<_PlayerSelectorOption> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KumoriyaSpacing.md,
          KumoriyaSpacing.md,
          KumoriyaSpacing.md,
          KumoriyaSpacing.lg,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: KumoriyaColors.surface,
            borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
            border: Border.all(color: KumoriyaColors.borderMedium),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: KumoriyaSpacing.sm),
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: KumoriyaColors.textDisabled,
                    borderRadius: BorderRadius.circular(KumoriyaRadius.full),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KumoriyaSpacing.lg,
                    KumoriyaSpacing.md,
                    KumoriyaSpacing.lg,
                    KumoriyaSpacing.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: KumoriyaColors.primarySurface20,
                          borderRadius: BorderRadius.circular(
                            KumoriyaRadius.md,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: KumoriyaColors.textPrimary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: KumoriyaSpacing.sm),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: KumoriyaSpacing.sm,
                      vertical: KumoriyaSpacing.sm,
                    ),
                    itemCount: options.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: KumoriyaSpacing.xs),
                    itemBuilder: (context, index) {
                      final option = options[index];
                      return Material(
                        color: option.selected
                            ? KumoriyaColors.primarySurface20
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              KumoriyaRadius.lg,
                            ),
                            side: BorderSide(
                              color: option.selected
                                  ? KumoriyaColors.primaryBorder30
                                  : Colors.transparent,
                            ),
                          ),
                          leading: Icon(option.icon),
                          title: Text(option.title),
                          subtitle: option.subtitle != null
                              ? Text(option.subtitle!)
                              : null,
                          trailing: option.selected
                              ? const Icon(Icons.check_rounded)
                              : null,
                          onTap: () {
                            Navigator.of(context).pop();
                            option.onTap();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerSelectorOption {
  const _PlayerSelectorOption({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
}
