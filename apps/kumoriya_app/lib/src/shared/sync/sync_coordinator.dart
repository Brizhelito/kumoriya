import 'dart:async';
import 'dart:developer' as developer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:kumoriya_sync/kumoriya_sync.dart';

/// Thin wrapper around [Connectivity] so tests can inject a fake without
/// pulling in the platform plugin.
abstract class ConnectivityProbe {
  Stream<bool> get onConnected;
  Future<bool> get isConnected;
}

final class PluginConnectivityProbe implements ConnectivityProbe {
  PluginConnectivityProbe([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Stream<bool> get onConnected =>
      _connectivity.onConnectivityChanged.map(_hasNetwork);

  @override
  Future<bool> get isConnected async =>
      _hasNetwork(await _connectivity.checkConnectivity());

  static bool _hasNetwork(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }
}

/// Schedules a one-off expedited push job when the app goes to background
/// with pending queue entries. Platform-agnostic seam so tests can stub it.
typedef SchedulePushJob = Future<void> Function();

/// Orchestrates push-to-server with six event triggers:
/// 1. Local write (debounced)
/// 2. App resumed
/// 3. App paused (delegates to [schedulePushJob])
/// 4. Connectivity regained
/// 5. Pre-logout flush (blocking with timeout)
/// 6. Manual trigger (button / periodic worker)
///
/// Safety invariants:
/// - Single push in flight at any time (lock).
/// - Skips push when offline to avoid incrementing queue retryCount spuriously.
/// - Exponential backoff on failures; manual/resume triggers bypass backoff.
/// - No-op when not authenticated.
final class SyncCoordinator {
  SyncCoordinator({
    required SyncService syncService,
    required SyncQueueStore queueStore,
    required bool Function() isAuthenticated,
    required Future<DateTime?> Function() loadLastSyncAt,
    required Future<void> Function(DateTime) saveLastSyncAt,
    required void Function() onDataRefreshed,
    required ConnectivityProbe connectivity,
    SchedulePushJob? schedulePushJob,
    Duration debounceWindow = const Duration(milliseconds: 500),
    Duration resumeFullSyncThreshold = const Duration(hours: 6),
    Duration resumePullMinInterval = const Duration(seconds: 30),
    Duration foregroundPullInterval = const Duration(minutes: 30),
    Duration preLogoutTimeout = const Duration(seconds: 5),
    List<Duration> backoffSteps = const <Duration>[
      Duration(seconds: 30),
      Duration(minutes: 2),
      Duration(minutes: 5),
      Duration(minutes: 15),
    ],
  }) : _syncService = syncService,
       _queueStore = queueStore,
       _isAuthenticated = isAuthenticated,
       _loadLastSyncAt = loadLastSyncAt,
       _saveLastSyncAt = saveLastSyncAt,
       _onDataRefreshed = onDataRefreshed,
       _connectivity = connectivity,
       _schedulePushJob = schedulePushJob,
       _debounceWindow = debounceWindow,
       _resumeFullSyncThreshold = resumeFullSyncThreshold,
       _resumePullMinInterval = resumePullMinInterval,
       _foregroundPullInterval = foregroundPullInterval,
       _preLogoutTimeout = preLogoutTimeout,
       _backoffSteps = backoffSteps {
    _connectivitySubscription = _connectivity.onConnected.listen((connected) {
      if (connected && _wasOffline) {
        _wasOffline = false;
        notifyConnectivityRegained();
      } else if (!connected) {
        _wasOffline = true;
      }
    });
  }

  final SyncService _syncService;
  final SyncQueueStore _queueStore;
  final bool Function() _isAuthenticated;
  final Future<DateTime?> Function() _loadLastSyncAt;
  final Future<void> Function(DateTime) _saveLastSyncAt;
  final void Function() _onDataRefreshed;
  final ConnectivityProbe _connectivity;
  final SchedulePushJob? _schedulePushJob;
  final Duration _debounceWindow;
  final Duration _resumeFullSyncThreshold;
  final Duration _resumePullMinInterval;
  final Duration _foregroundPullInterval;
  final Duration _preLogoutTimeout;
  final List<Duration> _backoffSteps;

  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _debounceTimer;
  Timer? _backoffTimer;
  Timer? _foregroundPullTimer;
  bool _pushing = false;
  bool _pulling = false;
  bool _dirty = false;
  int _consecutiveFailures = 0;
  bool _wasOffline = false;
  DateTime? _lastPullAt;

  /// Called by SyncAware stores right after an enqueue. Debounces by
  /// [_debounceWindow] so a burst of writes collapses into one push.
  void notifyLocalWrite() {
    if (!_isAuthenticated()) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceWindow, () {
      unawaited(_runPush(bypassBackoff: false));
    });
  }

  /// Called when the app returns to foreground.
  ///
  /// Always pulls remote changes (debounced by [_resumePullMinInterval] so
  /// rapid background/foreground cycles do not spam the API). Additionally,
  /// if the local queue has pending entries, triggers a push; and if the
  /// last successful sync is older than [_resumeFullSyncThreshold] forces a
  /// `fullSync` to recover from any missed server state.
  Future<void> notifyAppResumed() async {
    if (!_isAuthenticated()) return;

    final last = await _loadLastSyncAt();
    final stale = last == null ||
        DateTime.now().difference(last) > _resumeFullSyncThreshold;

    if (stale) {
      await _runPush(bypassBackoff: true, fullSync: true);
      _startForegroundPullTimer();
      return;
    }

    // Pull remote changes if we have not pulled very recently.
    final pullRecent = _lastPullAt != null &&
        DateTime.now().difference(_lastPullAt!) < _resumePullMinInterval;
    if (!pullRecent) {
      await _runPull(bypassBackoff: true);
    }

    if (await _hasPendingEntries()) {
      await _runPush(bypassBackoff: true);
    }
    _startForegroundPullTimer();
  }

  /// Called when the app goes to background. Delegates to the platform
  /// scheduler (WorkManager on Android) so a push can still happen if
  /// the OS kills the process.
  Future<void> notifyAppPaused() async {
    if (!_isAuthenticated()) return;
    if (_schedulePushJob == null) return;
    final hasPending = await _hasPendingEntries();
    if (!hasPending) return;
    try {
      await _schedulePushJob();
    } catch (e, st) {
      developer.log(
        'SyncCoordinator: schedulePushJob failed: $e',
        name: 'SyncCoordinator',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Called from the connectivity listener when network transitions
  /// back from offline to online. If there are pending entries, push.
  void notifyConnectivityRegained() {
    if (!_isAuthenticated()) return;
    unawaited(_runPush(bypassBackoff: true));
  }

  /// Blocking push used right before logout wipes local data. Capped at
  /// [_preLogoutTimeout] so a broken network does not block sign-out.
  Future<void> flushBeforeLogout() async {
    if (!_isAuthenticated()) return;
    try {
      await _syncService
          .pushPending()
          .timeout(_preLogoutTimeout);
    } catch (e, st) {
      developer.log(
        'SyncCoordinator: flushBeforeLogout timed out or failed: $e',
        name: 'SyncCoordinator',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Explicit user-initiated or worker-initiated trigger. Always full-sync
  /// and bypasses backoff.
  Future<void> triggerManual() async {
    if (!_isAuthenticated()) return;
    await _runPush(bypassBackoff: true, fullSync: true);
  }

  /// Pull-only trigger, intended for remote-change notifications (e.g. FCM
  /// silent push in a future slice) or foreground periodic refresh.
  Future<void> triggerPull() async {
    if (!_isAuthenticated()) return;
    await _runPull(bypassBackoff: true);
  }

  /// Invoked by the periodic WorkManager task (runs in a detached
  /// isolate). Direct [pushPending] bypass of the coordinator lock is
  /// acceptable because the worker owns its own isolate and the main
  /// isolate's lock does not reach it.
  Future<void> runWorkerPush() async {
    if (!_isAuthenticated()) return;
    await _runPush(bypassBackoff: true);
  }

  Future<void> dispose() async {
    _debounceTimer?.cancel();
    _backoffTimer?.cancel();
    _foregroundPullTimer?.cancel();
    await _connectivitySubscription?.cancel();
  }

  void _startForegroundPullTimer() {
    _foregroundPullTimer?.cancel();
    _foregroundPullTimer = Timer.periodic(_foregroundPullInterval, (_) {
      unawaited(_runPull(bypassBackoff: true));
    });
  }

  Future<void> _runPull({required bool bypassBackoff}) async {
    if (_pulling) return;
    if (!bypassBackoff && _backoffTimer != null && _backoffTimer!.isActive) {
      return;
    }
    // Claim the lock synchronously before any await so concurrent callers
    // cannot sneak past the guard during the connectivity probe.
    _pulling = true;
    try {
      if (!await _connectivity.isConnected) {
        _wasOffline = true;
        return;
      }
      final since = (await _loadLastSyncAt()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final result = await _syncService.pullSince(since);
      result.fold<void>(
        onSuccess: (_) {
          _lastPullAt = DateTime.now();
        },
        onFailure: (_) {},
      );
      final last = await _syncService.getLastSyncAt();
      final time = last.fold<DateTime?>(
        onSuccess: (t) => t,
        onFailure: (_) => null,
      );
      if (time != null) {
        await _saveLastSyncAt(time);
      }
      if (result.isSuccess) {
        _onDataRefreshed();
      }
    } catch (e, st) {
      developer.log(
        'SyncCoordinator: pull failed: $e',
        name: 'SyncCoordinator',
        error: e,
        stackTrace: st,
      );
    } finally {
      _pulling = false;
    }
  }

  Future<void> _runPush({
    required bool bypassBackoff,
    bool fullSync = false,
  }) async {
    if (_pushing) {
      _dirty = true;
      return;
    }
    if (!bypassBackoff && _backoffTimer != null && _backoffTimer!.isActive) {
      _dirty = true;
      return;
    }
    // Claim the lock synchronously before any await so concurrent callers
    // cannot sneak past the guard during the connectivity probe.
    _pushing = true;
    _dirty = false;
    try {
      if (!await _connectivity.isConnected) {
        _wasOffline = true;
        return;
      }
      final bool ok = fullSync
          ? (await _syncService.fullSync()).isSuccess
          : (await _syncService.pushPending()).isSuccess;

      if (ok) {
        _consecutiveFailures = 0;
        _backoffTimer?.cancel();
        _backoffTimer = null;
        if (fullSync) {
          final last = await _syncService.getLastSyncAt();
          final time = last.fold<DateTime?>(
            onSuccess: (t) => t,
            onFailure: (_) => null,
          );
          if (time != null) await _saveLastSyncAt(time);
          _onDataRefreshed();
        }
      } else {
        _consecutiveFailures++;
        _armBackoff();
      }
    } catch (e, st) {
      developer.log(
        'SyncCoordinator: unexpected push error: $e',
        name: 'SyncCoordinator',
        error: e,
        stackTrace: st,
      );
      _consecutiveFailures++;
      _armBackoff();
    } finally {
      _pushing = false;
      if (_dirty) {
        _dirty = false;
        unawaited(_runPush(bypassBackoff: false));
      }
    }
  }

  void _armBackoff() {
    final idx =
        (_consecutiveFailures - 1).clamp(0, _backoffSteps.length - 1);
    final wait = _backoffSteps[idx];
    _backoffTimer?.cancel();
    _backoffTimer = Timer(wait, () {
      if (_dirty) {
        _dirty = false;
        unawaited(_runPush(bypassBackoff: false));
      }
    });
  }

  Future<bool> _hasPendingEntries() async {
    final r = await _queueStore.getPendingEntries();
    return r.fold(
      onSuccess: (list) => list.isNotEmpty,
      onFailure: (_) => false,
    );
  }
}
