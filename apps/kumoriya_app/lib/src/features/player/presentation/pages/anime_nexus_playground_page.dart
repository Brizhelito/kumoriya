import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_resolver_anime_nexus/kumoriya_resolver_anime_nexus.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../shared/theme/kumoriya_theme.dart';
import '../../application/models/player_session_state.dart';
import '../../application/services/player_session_orchestrator.dart';
import '../../infrastructure/media_kit_playback_engine.dart';

class AnimeNexusPlaygroundPage extends StatefulWidget {
  const AnimeNexusPlaygroundPage({super.key});

  @override
  State<AnimeNexusPlaygroundPage> createState() =>
      _AnimeNexusPlaygroundPageState();
}

class _AnimeNexusPlaygroundPageState extends State<AnimeNexusPlaygroundPage> {
  static const _defaultWatchUrl =
      'https://anime.nexus/watch/019cdcfe-dc32-7328-9747-0e6ef96dbd06/'
      'episode-10-c9b0cd86068190028be1';

  late final AnimeNexusResolverPlugin _resolver;
  final TextEditingController _watchUrlController = TextEditingController(
    text: _defaultWatchUrl,
  );
  final ScrollController _logScrollController = ScrollController();

  MediaKitPlaybackEngine? _engine;
  PlayerSessionOrchestrator? _orchestrator;
  StreamSubscription<PlayerSessionState>? _sessionSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<bool>? _bufferingSubscription;

  PlayerSessionState _state = const PlayerSessionState.idle();
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;
  DateTime _lastTimelineLogTime = DateTime(0);
  bool _forceSoftwareVideoOutput =
      defaultTargetPlatform == TargetPlatform.windows;
  bool _isResolving = false;
  bool _isScrubbing = false;
  double? _scrubPositionMs;
  String? _resolveError;
  List<ResolvedStream> _resolvedStreams = const <ResolvedStream>[];
  final List<String> _logs = <String>[];

  @override
  void initState() {
    super.initState();
    _resolver = AnimeNexusResolverPlugin(
      onDebugLog: (message) => _appendLog(message),
    );
    _installRuntime();
  }

  @override
  void dispose() {
    _watchUrlController.dispose();
    _logScrollController.dispose();
    unawaited(_disposeRuntime());
    super.dispose();
  }

  Future<void> _installRuntime() async {
    await _installRuntimeWithCurrentPreference();
  }

  Future<void> _installRuntimeWithCurrentPreference() async {
    await _disposeRuntime();
    final engine = MediaKitPlaybackEngine(
      onDebugLog: (message) => _appendLog(message),
      forceSoftwareVideoOutput: _forceSoftwareVideoOutput,
      onVideoOutputFallbackRequested: _handleVideoOutputFallback,
    );
    final orchestrator = PlayerSessionOrchestrator(
      playbackEngine: engine,
      onDebugLog: (message) => _appendLog(message),
    );
    _sessionSubscription = orchestrator.states.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() => _state = state);
    });
    _positionSubscription = orchestrator.positionStream.listen((position) {
      if (!mounted) {
        _currentPosition = position;
        return;
      }
      final orch = _orchestrator;
      final orchManaged = orch?.isManagedTimeline ?? false;
      final orchBase = orch?.timelineBase ?? Duration.zero;
      final now = DateTime.now();
      if (now.difference(_lastTimelineLogTime) > const Duration(seconds: 1)) {
        _lastTimelineLogTime = now;
        _appendLog(
          'timelineDomain ui-received managed=$orchManaged '
          'base=${orchBase.inMilliseconds}ms '
          'position=${position.inMilliseconds}ms '
          'duration=${_currentDuration.inMilliseconds}ms',
        );
      }
      setState(() => _currentPosition = position);
    });
    _durationSubscription = orchestrator.durationStream.listen((duration) {
      if (duration <= Duration.zero) {
        return;
      }
      if (!mounted) {
        _currentDuration = duration;
        return;
      }
      final orch = _orchestrator;
      final orchManaged = orch?.isManagedTimeline ?? false;
      final orchBase = orch?.timelineBase ?? Duration.zero;
      final now = DateTime.now();
      if (now.difference(_lastTimelineLogTime) > const Duration(seconds: 1)) {
        _lastTimelineLogTime = now;
        _appendLog(
          'timelineDomain ui-received managed=$orchManaged '
          'base=${orchBase.inMilliseconds}ms '
          'position=${_currentPosition.inMilliseconds}ms '
          'duration=${duration.inMilliseconds}ms',
        );
      }
      setState(() => _currentDuration = duration);
    });
    _playingSubscription = engine.playingStream.listen((playing) {
      if (!mounted) {
        _isPlaying = playing;
        return;
      }
      setState(() => _isPlaying = playing);
    });
    _bufferingSubscription = engine.bufferingStream.listen((buffering) {
      if (!mounted) {
        _isBuffering = buffering;
        return;
      }
      setState(() => _isBuffering = buffering);
    });

    if (!mounted) {
      await orchestrator.dispose();
      return;
    }

    setState(() {
      _engine = engine;
      _orchestrator = orchestrator;
      _state = const PlayerSessionState.idle();
      _currentPosition = Duration.zero;
      _currentDuration = Duration.zero;
      _isPlaying = false;
      _isBuffering = false;
      _isScrubbing = false;
      _scrubPositionMs = null;
    });
    _appendLog('timelineDomain ui-reset managed=false base=0');
    _appendPlaygroundLog('runtime reset');
  }

  Future<void> _disposeRuntime() async {
    await _sessionSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _playingSubscription?.cancel();
    await _bufferingSubscription?.cancel();
    _sessionSubscription = null;
    _positionSubscription = null;
    _durationSubscription = null;
    _playingSubscription = null;
    _bufferingSubscription = null;

    final orchestrator = _orchestrator;
    _orchestrator = null;
    _engine = null;
    if (orchestrator != null) {
      await orchestrator.dispose();
    }
  }

  Future<void> _resolveAndPlay() async {
    final raw = _watchUrlController.text.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || raw.isEmpty) {
      setState(() => _resolveError = 'Invalid Anime Nexus watch URL.');
      return;
    }

    setState(() {
      _isResolving = true;
      _resolveError = null;
      _resolvedStreams = const <ResolvedStream>[];
      _logs.clear();
    });
    _appendPlaygroundLog('resolve start url=$uri');

    _forceSoftwareVideoOutput = false;
    await _installRuntimeWithCurrentPreference();

    final result = await _resolver.resolve(uri);
    if (!mounted) {
      return;
    }

    await result.fold(
      onFailure: (error) async {
        _appendPlaygroundLog(
          'resolve failure code=${error.code} message=${error.message}',
        );
        setState(() {
          _resolveError = '${error.code}: ${error.message}';
          _isResolving = false;
        });
      },
      onSuccess: (streams) async {
        _appendPlaygroundLog(
          'resolve success streams=${streams.length} '
          'urls=${streams.map((stream) => stream.url).join(' | ')}',
        );
        setState(() {
          _resolvedStreams = streams;
          _isResolving = false;
        });
        final orchestrator = _orchestrator;
        if (orchestrator == null) {
          setState(() {
            _resolveError = 'Playback runtime was not available.';
          });
          return;
        }
        final startResult = await orchestrator.start(streamCandidates: streams);
        if (!mounted || _orchestrator != orchestrator) {
          return;
        }
        startResult.fold(
          onFailure: (error) {
            _appendPlaygroundLog(
              'playback start failure code=${error.code} '
              'message=${error.message}',
            );
            setState(() {
              _resolveError = '${error.code}: ${error.message}';
            });
          },
          onSuccess: (stream) {
            _appendPlaygroundLog(
              'playback start success url=${stream.url} '
              'hls=${stream.isHls} quality=${stream.qualityLabel}',
            );
          },
        );
      },
    );
  }

  Future<void> _retryPlayback() async {
    final orchestrator = _orchestrator;
    if (orchestrator == null) {
      return;
    }
    _appendPlaygroundLog('retry requested');
    final result = await orchestrator.retry();
    if (!mounted) {
      return;
    }
    result.fold(
      onFailure: (error) {
        _appendPlaygroundLog(
          'retry failure code=${error.code} message=${error.message}',
        );
        setState(() => _resolveError = '${error.code}: ${error.message}');
      },
      onSuccess: (stream) {
        _appendPlaygroundLog('retry success url=${stream.url}');
        setState(() => _resolveError = null);
      },
    );
  }

  Future<void> _handleVideoOutputFallback(String reason) async {
    if (_forceSoftwareVideoOutput || _resolvedStreams.isEmpty) {
      return;
    }
    _appendPlaygroundLog('video output fallback requested reason=$reason');
    _forceSoftwareVideoOutput = true;
    await _installRuntimeWithCurrentPreference();
    final orchestrator = _orchestrator;
    if (orchestrator == null || !mounted) {
      return;
    }
    final resumePosition = _currentPosition > Duration.zero
        ? _currentPosition
        : null;
    final result = await orchestrator.start(
      streamCandidates: _resolvedStreams,
      initialPosition: resumePosition,
    );
    if (!mounted || _orchestrator != orchestrator) {
      return;
    }
    result.fold(
      onFailure: (error) {
        _appendPlaygroundLog(
          'video output fallback start failure code=${error.code} message=${error.message}',
        );
        setState(() => _resolveError = '${error.code}: ${error.message}');
      },
      onSuccess: (stream) {
        _appendPlaygroundLog(
          'video output fallback start success url=${stream.url} position=$resumePosition',
        );
      },
    );
  }

  Future<void> _togglePlayPause() async {
    final orchestrator = _orchestrator;
    if (orchestrator == null) {
      return;
    }
    _appendPlaygroundLog('toggle play/pause requested');
    await orchestrator.togglePlayPause();
  }

  Future<void> _seekRelative(Duration delta) async {
    final target = _currentPosition + delta;
    final bounded = target < Duration.zero ? Duration.zero : target;
    await _seekTo(bounded);
  }

  Future<void> _seekTo(Duration position) async {
    final orchestrator = _orchestrator;
    if (orchestrator == null) {
      return;
    }
    _appendPlaygroundLog('seek requested target=$position');
    await orchestrator.seekTo(position);
  }

  String get _statusLabel {
    return switch (_state.status) {
      PlayerSessionStatus.idle => 'idle',
      PlayerSessionStatus.opening => 'opening',
      PlayerSessionStatus.buffering => 'buffering',
      PlayerSessionStatus.fallbacking => 'fallbacking',
      PlayerSessionStatus.playing => 'playing',
      PlayerSessionStatus.paused => 'paused',
      PlayerSessionStatus.error => 'error',
    };
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
    // Pass 5: Defensive validation - clamp to max if position > duration
    // This prevents visual inconsistency during transient states
    if (value > _sliderMaxMs) {
      _appendLog(
        'timelineUi defensive-clamp value=${value.toStringAsFixed(0)}ms '
        'max=${_sliderMaxMs.toStringAsFixed(0)}ms '
        'position=$_currentPosition duration=$_currentDuration',
      );
      return _sliderMaxMs;
    }
    return value;
  }

  void _appendPlaygroundLog(String message) {
    final formatted =
        '[playground ${DateTime.now().toIso8601String()}] $message';
    _appendLog(formatted);
  }

  void _appendLog(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _logs.add(message);
      if (_logs.length > 5000) {
        _logs.removeAt(0);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_logScrollController.hasClients) {
        return;
      }
      _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _copyLog() async {
    final text = _logs.join('\n');
    if (text.trim().isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Runtime log is empty.')));
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Runtime log copied.')));
  }

  Future<void> _saveLogToFile() async {
    final text = _logs.join('\n');
    if (text.trim().isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Runtime log is empty.')));
      return;
    }

    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final logsDir = Directory(
        '${baseDir.path}${Platform.pathSeparator}anime_nexus_logs',
      );
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      final now = DateTime.now();
      final stamp =
          '${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}';
      final file = File(
        '${logsDir.path}${Platform.pathSeparator}anime_nexus_runtime_$stamp.log',
      );

      await file.writeAsString(text, flush: true);
      _appendPlaygroundLog('log exported path=${file.path}');

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Runtime log saved: ${file.path}'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (error) {
      _appendPlaygroundLog('log export failed error=$error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save runtime log: $error')),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    final selectedStream = _state.selectedStream;

    // Compute effective values once for slider + labels + logs
    final effectivePositionMs = _sliderValueMs;
    final effectiveDurationMs = _sliderMaxMs;
    final effectivePosition = _effectiveSliderPosition;
    final effectiveDuration = _currentDuration;
    final remainingDuration = effectiveDuration - effectivePosition;
    final clampedRemaining = remainingDuration > Duration.zero
        ? remainingDuration
        : Duration.zero;

    final leftLabel = _formatDuration(effectivePosition);
    final rightLabel = _formatDuration(clampedRemaining);

    // Log timeline UI mapping before render
    final orch = _orchestrator;
    final orchManaged = orch?.isManagedTimeline ?? false;
    final orchBase = orch?.timelineBase ?? Duration.zero;
    if (effectiveDuration > Duration.zero) {
      final now = DateTime.now();
      if (now.difference(_lastTimelineLogTime) > const Duration(seconds: 1)) {
        _lastTimelineLogTime = now;
        _appendLog(
          'timelineDomain ui-render managed=$orchManaged '
          'sliderValue=${effectivePositionMs.toStringAsFixed(0)}ms '
          'sliderMax=${effectiveDurationMs.toStringAsFixed(0)}ms '
          'left=$leftLabel right=$rightLabel',
        );
      }
      // Defensive invariant: if orchestrator says managed=false, the UI must
      // not behave as if managed=true.  Since the UI derives everything from
      // the orchestrator's streams, this should never fire.
      if (!orchManaged && orchBase > Duration.zero) {
        _appendLog(
          'timelineDomain invariant-broken '
          'orchManaged=false but orchBase=${orchBase.inMilliseconds}ms',
        );
      }
    }

    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      appBar: AppBar(
        title: const Text('Anime Nexus Playground'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Save log to file',
            onPressed: _saveLogToFile,
            icon: const Icon(Icons.save_alt_rounded),
          ),
          IconButton(
            tooltip: 'Copy log',
            onPressed: _copyLog,
            icon: const Icon(Icons.content_copy_rounded),
          ),
          if (kDebugMode)
            IconButton(
              tooltip: 'Reset runtime',
              onPressed: _installRuntime,
              icon: const Icon(Icons.restart_alt_rounded),
            ),
        ],
      ),
      body: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Real runtime lab for Anime Nexus seek/recover.',
                        style: TextStyle(
                          color: KumoriyaColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _watchUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Anime Nexus watch URL',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: _isResolving ? null : _resolveAndPlay,
                            icon: const Icon(Icons.play_circle_fill_rounded),
                            label: Text(
                              _isResolving ? 'Resolving...' : 'Resolve & Play',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _resolvedStreams.isEmpty
                                ? null
                                : _retryPlayback,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _resolvedStreams.isEmpty
                                ? null
                                : _togglePlayPause,
                            icon: Icon(
                              _isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            label: Text(_isPlaying ? 'Pause' : 'Play'),
                          ),
                        ],
                      ),
                      if (_resolveError != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          _resolveError!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      children: <Widget>[
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                color: Colors.black,
                              ),
                              child: engine == null
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : Video(
                                      controller: engine.videoController,
                                      controls: NoVideoControls,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Slider(
                          value: _sliderValueMs,
                          max: _sliderMaxMs,
                          onChanged: _currentDuration > Duration.zero
                              ? (value) {
                                  setState(() {
                                    _isScrubbing = true;
                                    _scrubPositionMs = value;
                                  });
                                }
                              : null,
                          onChangeEnd: _currentDuration > Duration.zero
                              ? (value) {
                                  final target = Duration(
                                    milliseconds: value.round(),
                                  );
                                  setState(() {
                                    _currentPosition = target;
                                    _isScrubbing = false;
                                    _scrubPositionMs = null;
                                  });
                                  unawaited(_seekTo(target));
                                }
                              : null,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              leftLabel,
                              style: const TextStyle(
                                color: KumoriyaColors.textPrimary,
                              ),
                            ),
                            Text(
                              rightLabel,
                              style: const TextStyle(
                                color: KumoriyaColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            OutlinedButton(
                              onPressed: _resolvedStreams.isEmpty
                                  ? null
                                  : () => _seekTo(const Duration(seconds: 30)),
                              child: const Text('00:30'),
                            ),
                            OutlinedButton(
                              onPressed: _resolvedStreams.isEmpty
                                  ? null
                                  : () => _seekTo(const Duration(minutes: 5)),
                              child: const Text('05:00'),
                            ),
                            OutlinedButton(
                              onPressed: _resolvedStreams.isEmpty
                                  ? null
                                  : () => _seekTo(
                                      const Duration(minutes: 18, seconds: 30),
                                    ),
                              child: const Text('18:30'),
                            ),
                            OutlinedButton(
                              onPressed: _resolvedStreams.isEmpty
                                  ? null
                                  : () => _seekRelative(
                                      const Duration(seconds: -30),
                                    ),
                              child: const Text('-30s'),
                            ),
                            OutlinedButton(
                              onPressed: _resolvedStreams.isEmpty
                                  ? null
                                  : () => _seekRelative(
                                      const Duration(seconds: 30),
                                    ),
                              child: const Text('+30s'),
                            ),
                            OutlinedButton(
                              onPressed: _resolvedStreams.isEmpty
                                  ? null
                                  : () => _seekRelative(
                                      const Duration(minutes: 5),
                                    ),
                              child: const Text('+5m'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 380,
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: KumoriyaColors.borderSubtle),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _StatusRow(label: 'Status', value: _statusLabel),
                      _StatusRow(
                        label: 'Playing',
                        value: _isPlaying ? 'yes' : 'no',
                      ),
                      _StatusRow(
                        label: 'Buffering',
                        value: _isBuffering ? 'yes' : 'no',
                      ),
                      _StatusRow(
                        label: 'Candidates',
                        value: _resolvedStreams.length.toString(),
                      ),
                      _StatusRow(
                        label: 'Selected',
                        value:
                            selectedStream?.qualityLabel ??
                            selectedStream?.url.toString() ??
                            'none',
                      ),
                      _StatusRow(
                        label: 'Candidate index',
                        value:
                            '${_state.currentCandidateIndex + 1}/${_state.totalCandidates}',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: KumoriyaColors.borderSubtle),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    'Runtime log',
                    style: TextStyle(
                      color: KumoriyaColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _logScrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SelectableText(
                          _logs[index],
                          style: const TextStyle(
                            color: KumoriyaColors.textMuted,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: KumoriyaColors.textDisabled,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: KumoriyaColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
