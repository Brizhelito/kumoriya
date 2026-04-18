import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const bool kPlayerPerfProbeEnabled = bool.fromEnvironment(
  'PLAYER_PERF_PROBE',
  defaultValue: false,
);

final class PlayerPerformanceProbe {
  PlayerPerformanceProbe._();

  static final PlayerPerformanceProbe instance = PlayerPerformanceProbe._();

  VoidCallback? _removeTimingsCallback;
  bool _sessionActive = false;
  String _label = 'player';
  DateTime _sessionStartedAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _totalFrames = 0;
  int _slowFrames16ms = 0;
  int _slowFrames33ms = 0;
  int _worstFrameMs = 0;
  int _buildCount = 0;
  int _positionEvents = 0;
  int _positionSetStates = 0;
  int _durationEvents = 0;
  int _trackEvents = 0;
  int _sessionStateEvents = 0;
  int _playingEvents = 0;
  int _totalBuildMicros = 0;
  int _totalRasterMicros = 0;

  bool get isEnabled => kPlayerPerfProbeEnabled;

  void startSession({required String label}) {
    if (!isEnabled || _sessionActive) {
      return;
    }
    _sessionActive = true;
    _label = label;
    _sessionStartedAt = DateTime.now();
    _resetCounters();
    final callback = _onTimings;
    WidgetsBinding.instance.addTimingsCallback(callback);
    _removeTimingsCallback = () {
      WidgetsBinding.instance.removeTimingsCallback(callback);
    };
    _log('session_start label=$label');
  }

  void finishSession({String reason = 'completed'}) {
    if (!isEnabled || !_sessionActive) {
      return;
    }
    _log(_summaryLine(reason: reason));
    _removeTimingsCallback?.call();
    _removeTimingsCallback = null;
    _sessionActive = false;
  }

  void recordBuild() {
    if (_sessionActive) {
      _buildCount += 1;
    }
  }

  void recordPositionEvent({required bool triggeredSetState}) {
    if (!_sessionActive) {
      return;
    }
    _positionEvents += 1;
    if (triggeredSetState) {
      _positionSetStates += 1;
    }
  }

  void recordDurationEvent() {
    if (_sessionActive) {
      _durationEvents += 1;
    }
  }

  void recordTrackEvent() {
    if (_sessionActive) {
      _trackEvents += 1;
    }
  }

  void recordSessionStateEvent() {
    if (_sessionActive) {
      _sessionStateEvents += 1;
    }
  }

  void recordPlayingEvent() {
    if (_sessionActive) {
      _playingEvents += 1;
    }
  }

  void checkpoint(String name) {
    if (_sessionActive) {
      _log('checkpoint name=$name uptimeMs=${_uptimeMs()}');
    }
  }

  String snapshotLine({required String reason}) {
    return _summaryLine(reason: reason);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_sessionActive) {
      return;
    }
    for (final timing in timings) {
      _totalFrames += 1;
      final buildMicros = timing.buildDuration.inMicroseconds;
      final rasterMicros = timing.rasterDuration.inMicroseconds;
      final totalMs = (buildMicros + rasterMicros) ~/ 1000;
      _totalBuildMicros += buildMicros;
      _totalRasterMicros += rasterMicros;
      if (totalMs > _worstFrameMs) {
        _worstFrameMs = totalMs;
      }
      if (totalMs > 16) {
        _slowFrames16ms += 1;
      }
      if (totalMs > 33) {
        _slowFrames33ms += 1;
      }
    }
  }

  String _summaryLine({required String reason}) {
    final totalFrames = _totalFrames;
    final avgBuildMs = totalFrames == 0
        ? 0.0
        : _totalBuildMicros / totalFrames / 1000.0;
    final avgRasterMs = totalFrames == 0
        ? 0.0
        : _totalRasterMicros / totalFrames / 1000.0;
    final slow16Pct = totalFrames == 0
        ? 0.0
        : (_slowFrames16ms * 100.0) / totalFrames;
    final slow33Pct = totalFrames == 0
        ? 0.0
        : (_slowFrames33ms * 100.0) / totalFrames;
    return '[PlayerPerf] '
        'label=$_label '
        'reason=$reason '
        'uptimeMs=${_uptimeMs()} '
        'frames=$totalFrames '
        'avgBuildMs=${avgBuildMs.toStringAsFixed(2)} '
        'avgRasterMs=${avgRasterMs.toStringAsFixed(2)} '
        'slow16=$_slowFrames16ms/${slow16Pct.toStringAsFixed(1)}% '
        'slow33=$_slowFrames33ms/${slow33Pct.toStringAsFixed(1)}% '
        'worstFrameMs=$_worstFrameMs '
        'builds=$_buildCount '
        'positionEvents=$_positionEvents '
        'positionSetStates=$_positionSetStates '
        'durationEvents=$_durationEvents '
        'trackEvents=$_trackEvents '
        'sessionStateEvents=$_sessionStateEvents '
        'playingEvents=$_playingEvents';
  }

  int _uptimeMs() =>
      DateTime.now().difference(_sessionStartedAt).inMilliseconds;

  void _resetCounters() {
    _totalFrames = 0;
    _slowFrames16ms = 0;
    _slowFrames33ms = 0;
    _worstFrameMs = 0;
    _buildCount = 0;
    _positionEvents = 0;
    _positionSetStates = 0;
    _durationEvents = 0;
    _trackEvents = 0;
    _sessionStateEvents = 0;
    _playingEvents = 0;
    _totalBuildMicros = 0;
    _totalRasterMicros = 0;
  }

  void _log(String message) {
    debugPrintSynchronously(message);
  }
}
