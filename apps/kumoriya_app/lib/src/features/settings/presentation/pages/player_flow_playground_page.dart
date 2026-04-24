import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../anime_catalog/application/services/resolver_registry.dart';
import '../../../anime_catalog/presentation/providers/anime_catalog_providers.dart';
import '../../../player/application/models/player_session_state.dart';
import '../../../player/application/services/playback_engine.dart';
import '../../../player/application/services/player_session_orchestrator.dart';
import '../../../player/infrastructure/exoplayer_playback_engine.dart';
import '../../../player/infrastructure/kumoriya_exoplayer_engine.dart';
import '../../../player/infrastructure/media_kit_playback_engine.dart';

/// Which playback engine implementation to use when opening probe streams.
enum PlaybackEngineKind {
  mediaKit,
  exoPlayer,
  kumoriyaExoPlayer;

  String get label => switch (this) {
    PlaybackEngineKind.mediaKit => 'media_kit',
    PlaybackEngineKind.exoPlayer => 'video_player',
    PlaybackEngineKind.kumoriyaExoPlayer => 'kumoriya_exoplayer',
  };
}

// ─── Data models ────────────────────────────────────────────────────────────

enum PlayerProbeStatus {
  waiting,
  resolving,
  opening,
  observing,
  success,
  inconclusive,
  failed,
  timeout,
}

class PlayerProbeResult {
  PlayerProbeResult({
    required this.serverName,
    required this.serverUrl,
    required this.detectedHost,
    required this.resolverName,
    this.engine = PlaybackEngineKind.mediaKit,
  });

  final String serverName;
  final String serverUrl;
  final String detectedHost;
  final String resolverName;
  final PlaybackEngineKind engine;

  PlayerProbeStatus status = PlayerProbeStatus.waiting;

  // Resolve phase metrics.
  Duration? resolveDuration;
  String? resolvedUrl;
  bool? isHls;
  String? qualityLabel;
  int streamCount = 0;

  // Open phase metrics.
  Duration? openDuration;
  Duration? firstPlayingDuration;

  // Observation window metrics.
  int bufferingEvents = 0;
  Duration bufferingTotal = Duration.zero;
  int segmentsFetched = 0;
  int crossHostMisses = 0;
  int tcpConnects = 0;
  Set<String> observedHosts = <String>{};
  Duration finalPosition = Duration.zero;
  Duration? firstProgressAt;

  // Final state.
  String? errorCode;
  String? errorMessage;
  DateTime startedAt = DateTime.now();
  List<String> logs = <String>[];

  String get statusLabel => switch (status) {
    PlayerProbeStatus.waiting => 'WAITING',
    PlayerProbeStatus.resolving => 'RESOLVING…',
    PlayerProbeStatus.opening => 'OPENING…',
    PlayerProbeStatus.observing => 'OBSERVING…',
    PlayerProbeStatus.success => 'OK',
    PlayerProbeStatus.inconclusive => 'INCONCLUSIVE',
    PlayerProbeStatus.failed => 'FAILED',
    PlayerProbeStatus.timeout => 'TIMEOUT',
  };

  Map<String, dynamic> toAuditJson() => <String, dynamic>{
    'server_name': serverName,
    'server_url': serverUrl,
    'detected_host': detectedHost,
    'resolver_name': resolverName,
    'engine': engine.label,
    'status': statusLabel,
    'resolved_url': resolvedUrl,
    'is_hls': isHls,
    'quality_label': qualityLabel,
    'stream_count': streamCount,
    'resolve_ms': resolveDuration?.inMilliseconds,
    'open_ms': openDuration?.inMilliseconds,
    'first_playing_ms': firstPlayingDuration?.inMilliseconds,
    'buffering_events': bufferingEvents,
    'buffering_total_ms': bufferingTotal.inMilliseconds,
    'segments_fetched': segmentsFetched,
    'cross_host_misses': crossHostMisses,
    'tcp_connects': tcpConnects,
    'observed_hosts': observedHosts.toList(),
    'final_position_ms': finalPosition.inMilliseconds,
    'first_progress_ms': firstProgressAt?.inMilliseconds,
    'error_code': errorCode,
    'error_message': errorMessage,
    'started_at': startedAt.toIso8601String(),
    'logs': logs,
  };
}

class PlayerFlowSession {
  PlayerFlowSession({
    required this.episodeNumber,
    required this.episodeTitle,
    required this.sourcePluginId,
    required this.animeTitle,
  });

  final double episodeNumber;
  final String episodeTitle;
  final String sourcePluginId;
  final String animeTitle;
  final List<PlayerProbeResult> probes = <PlayerProbeResult>[];
  DateTime startedAt = DateTime.now();

  Map<String, dynamic> toAuditJson() => <String, dynamic>{
    'anime_title': animeTitle,
    'episode_number': episodeNumber,
    'episode_title': episodeTitle,
    'source_plugin_id': sourcePluginId,
    'started_at': startedAt.toIso8601String(),
    'probes': probes.map((PlayerProbeResult p) => p.toAuditJson()).toList(),
  };
}

// ─── Page ───────────────────────────────────────────────────────────────────

/// Runs the full resolve → player.open → first-frame → observe pipeline for
/// every server exposed by a source plugin for a given episode.  Each probe
/// uses a fresh [MediaKitPlaybackEngine] + [PlayerSessionOrchestrator] pair to
/// guarantee isolation, then the page collects structured metrics and native
/// logs so failures can be diagnosed without leaving the device.
class PlayerFlowPlaygroundPage extends ConsumerStatefulWidget {
  const PlayerFlowPlaygroundPage({super.key});

  @override
  ConsumerState<PlayerFlowPlaygroundPage> createState() =>
      _PlayerFlowPlaygroundPageState();
}

class _PlayerFlowPlaygroundPageState
    extends ConsumerState<PlayerFlowPlaygroundPage> {
  static const Duration _resolveTimeout = Duration(seconds: 20);
  // Under kumoriya_exoplayer (Media3 native) every healthy source opens
  // in <5 s on the moto g72 baseline. Tightening the cap turns "slow but
  // eventually works" media_kit behaviour into an explicit timeout so the
  // exo vs media_kit comparison in the playground is honest. We only gate
  // the OPENING phase (controller.open → first buffering event) at 5 s;
  // the follow-up observation window stays generous to collect evidence
  // on the slow engine.
  static const Duration _openTimeout = Duration(seconds: 5);
  static const Duration _observationWindow = Duration(seconds: 30);
  // Zilla's media_kit cold-start is ~43 s (ffmpeg reconnect loop on
  // segments served without Content-Length); anime_nexus loopback proxy
  // pre-warm is ~18 s. 70 s leaves headroom for both on the slow engine.
  // Healthy candidates exit early as soon as they cross the success
  // threshold, so this cap is only paid when a candidate is genuinely
  // slow (or dead).
  static const Duration _extendedObservationWindow = Duration(seconds: 70);

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<SourcePlugin> _sourcePlugins = <SourcePlugin>[];
  ResolverRegistry? _registry;

  // Search state.
  bool _searching = false;
  List<SourceAnimeMatch> _searchResults = <SourceAnimeMatch>[];
  SourcePlugin? _selectedSource;

  // Episode state.
  bool _loadingEpisodes = false;
  List<SourceEpisode> _episodes = <SourceEpisode>[];
  SourceAnimeMatch? _selectedAnime;

  // Probe state.
  bool _probing = false;
  String? _cancelReason;
  PlayerFlowSession? _currentSession;
  final List<PlayerFlowSession> _history = <PlayerFlowSession>[];
  String? _lastSavedLogPath;

  // Active probe runtime.
  PlaybackEngine? _engine;
  PlayerSessionOrchestrator? _orchestrator;
  final List<StreamSubscription<dynamic>> _activeSubs =
      <StreamSubscription<dynamic>>[];

  // Selected engine for the next probe run. Defaults to media_kit (current
  // behaviour). Toggling to ExoPlayer activates the Android-native fast path
  // for AV1 streaming.
  PlaybackEngineKind _selectedEngine = PlaybackEngineKind.mediaKit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sourcePlugins = ref.read(sourcePluginsProvider);
      _selectedSource = _sourcePlugins.firstOrNull;
      _registry = ref.read(resolverRegistryProvider);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    unawaited(_disposeProbeRuntime());
    super.dispose();
  }

  // ── Search ────────────────────────────────────────────────────────────

  Future<void> _search() async {
    final String query = _searchController.text.trim();
    if (query.isEmpty || _selectedSource == null) return;

    setState(() {
      _searching = true;
      _searchResults = <SourceAnimeMatch>[];
      _episodes = <SourceEpisode>[];
      _selectedAnime = null;
      _currentSession = null;
    });

    final Result<List<SourceAnimeMatch>, KumoriyaError> result =
        await _selectedSource!.search(
          SourceSearchQuery(query: query, page: 1, limit: 20),
        );
    if (!mounted) return;

    result.fold(
      onSuccess: (List<SourceAnimeMatch> matches) {
        setState(() {
          _searchResults = matches;
          _searching = false;
        });
      },
      onFailure: (KumoriyaError error) {
        setState(() => _searching = false);
        _snack('Search failed: ${error.message}');
      },
    );
  }

  Future<void> _loadEpisodes(SourceAnimeMatch match) async {
    setState(() {
      _loadingEpisodes = true;
      _episodes = <SourceEpisode>[];
      _selectedAnime = match;
      _currentSession = null;
    });

    final Result<List<SourceEpisode>, KumoriyaError> episodesResult =
        await _selectedSource!.getEpisodes(match.sourceId);
    if (!mounted) return;

    episodesResult.fold(
      onSuccess: (List<SourceEpisode> episodes) {
        setState(() {
          _episodes = episodes;
          _loadingEpisodes = false;
        });
      },
      onFailure: (KumoriyaError error) {
        setState(() => _loadingEpisodes = false);
        _snack('Episodes failed: ${error.message}');
      },
    );
  }

  // ── Probe loop ────────────────────────────────────────────────────────

  Future<void> _probeEpisode(SourceEpisode episode) async {
    if (_probing) return;
    final SourcePlugin? source = _selectedSource;
    final ResolverRegistry? registry = _registry;
    final SourceAnimeMatch? anime = _selectedAnime;
    if (source == null || registry == null || anime == null) return;

    setState(() {
      _probing = true;
      _cancelReason = null;
    });
    await _runSessionForSource(
      source: source,
      anime: anime,
      episode: episode,
      registry: registry,
    );
    if (!mounted) return;
    setState(() => _probing = false);
  }

  /// Iterates over every registered source plugin, searches for the same query
  /// + resolves an episode with matching `number`, then runs a full probe
  /// session on it.  Each source gets its own [PlayerFlowSession] appended to
  /// [_history] so the aggregate export reflects cross-source coverage.
  Future<void> _probeAllSourcesForEpisode(SourceEpisode refEpisode) async {
    if (_probing) return;
    final ResolverRegistry? registry = _registry;
    if (registry == null) return;
    final String query = _searchController.text.trim();
    if (query.isEmpty) {
      _snack('Escribe el título para buscar en cada source.');
      return;
    }
    final double targetNumber = refEpisode.number;

    setState(() {
      _probing = true;
      _cancelReason = null;
    });

    for (final SourcePlugin source in _sourcePlugins) {
      if (!_probing) break;

      // ── 1. Search each source with the same query. ────────────────────
      final Result<List<SourceAnimeMatch>, KumoriyaError> searchResult =
          await source.search(
            SourceSearchQuery(query: query, page: 1, limit: 10),
          );
      final List<SourceAnimeMatch>? matches = searchResult.fold(
        onSuccess: (List<SourceAnimeMatch> m) => m,
        onFailure: (KumoriyaError error) {
          _history.add(
            _errorSession(
              source: source,
              animeTitle: query,
              episodeNumber: targetNumber,
              episodeTitle: refEpisode.title,
              code: 'playground.search_failed',
              message: error.message,
            ),
          );
          return null;
        },
      );
      if (!mounted) return;
      if (matches == null) continue;
      if (matches.isEmpty) {
        _history.add(
          _errorSession(
            source: source,
            animeTitle: query,
            episodeNumber: targetNumber,
            episodeTitle: refEpisode.title,
            code: 'playground.no_match',
            message: 'Sin resultados en ${source.manifest.id}',
          ),
        );
        continue;
      }

      final SourceAnimeMatch bestMatch = matches.first;

      // ── 2. Fetch episodes & find matching number. ─────────────────────
      final Result<List<SourceEpisode>, KumoriyaError> episodesResult =
          await source.getEpisodes(bestMatch.sourceId);
      if (!mounted) return;
      final List<SourceEpisode>? episodes = episodesResult.fold(
        onSuccess: (List<SourceEpisode> e) => e,
        onFailure: (KumoriyaError error) {
          _history.add(
            _errorSession(
              source: source,
              animeTitle: bestMatch.title,
              episodeNumber: targetNumber,
              episodeTitle: refEpisode.title,
              code: 'playground.episodes_failed',
              message: error.message,
            ),
          );
          return null;
        },
      );
      if (episodes == null) continue;
      SourceEpisode? matched;
      for (final SourceEpisode e in episodes) {
        if ((e.number - targetNumber).abs() < 0.01) {
          matched = e;
          break;
        }
      }
      if (matched == null) {
        _history.add(
          _errorSession(
            source: source,
            animeTitle: bestMatch.title,
            episodeNumber: targetNumber,
            episodeTitle: refEpisode.title,
            code: 'playground.episode_number_missing',
            message:
                'Episodio $targetNumber no encontrado (tiene ${episodes.length})',
          ),
        );
        continue;
      }

      // ── 3. Run session on the matched episode. ────────────────────────
      await _runSessionForSource(
        source: source,
        anime: bestMatch,
        episode: matched,
        registry: registry,
      );
      if (!mounted) return;
    }

    setState(() => _probing = false);
  }

  Future<void> _runSessionForSource({
    required SourcePlugin source,
    required SourceAnimeMatch anime,
    required SourceEpisode episode,
    required ResolverRegistry registry,
  }) async {
    final Result<List<SourceServerLink>, KumoriyaError> linksResult =
        await source.getEpisodeServerLinks(episode);
    if (!mounted) return;

    final List<SourceServerLink>? links = linksResult.fold(
      onSuccess: (List<SourceServerLink> l) => l,
      onFailure: (KumoriyaError error) {
        _history.add(
          _errorSession(
            source: source,
            animeTitle: anime.title,
            episodeNumber: episode.number,
            episodeTitle: episode.title,
            code: 'playground.server_list_failed',
            message: error.message,
          ),
        );
        return null;
      },
    );
    if (links == null) return;
    if (links.isEmpty) {
      _history.add(
        _errorSession(
          source: source,
          animeTitle: anime.title,
          episodeNumber: episode.number,
          episodeTitle: episode.title,
          code: 'playground.no_servers',
          message: 'Episodio sin servers expuestos',
        ),
      );
      return;
    }

    final PlayerFlowSession session = PlayerFlowSession(
      episodeNumber: episode.number,
      episodeTitle: episode.title,
      sourcePluginId: source.manifest.id,
      animeTitle: anime.title,
    );
    for (final SourceServerLink link in links) {
      final ResolverSelection selection = registry.selectFor(link.initialUrl);
      final String resolverName = switch (selection) {
        ResolverSelected(:final ResolverPlugin resolver) =>
          resolver.manifest.id,
        ResolverAmbiguous(:final List<ResolverPlugin> resolvers) =>
          '${resolvers.first.manifest.id}(ambiguous×${resolvers.length})',
        ResolverNotFound() => 'NOT_FOUND',
      };
      session.probes.add(
        PlayerProbeResult(
          serverName: link.serverName,
          serverUrl: link.initialUrl.toString(),
          detectedHost: link.detectedHost ?? link.initialUrl.host,
          resolverName: resolverName,
          engine: _selectedEngine,
        ),
      );
    }
    setState(() => _currentSession = session);

    for (int i = 0; i < session.probes.length && _probing; i++) {
      await _runSingleProbe(session.probes[i], links[i], registry);
      if (!mounted) return;
      setState(() {});
    }

    _history.add(session);
  }

  PlayerFlowSession _errorSession({
    required SourcePlugin source,
    required String animeTitle,
    required double episodeNumber,
    required String episodeTitle,
    required String code,
    required String message,
  }) {
    final PlayerFlowSession session = PlayerFlowSession(
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
      sourcePluginId: source.manifest.id,
      animeTitle: animeTitle,
    );
    session.probes.add(
      PlayerProbeResult(
          serverName: '(source skipped)',
          serverUrl: '',
          detectedHost: '',
          resolverName: source.manifest.id,
        )
        ..status = PlayerProbeStatus.failed
        ..errorCode = code
        ..errorMessage = message,
    );
    return session;
  }

  Future<void> _runSingleProbe(
    PlayerProbeResult probe,
    SourceServerLink link,
    ResolverRegistry registry,
  ) async {
    final Uri uri = link.initialUrl;
    probe.startedAt = DateTime.now();

    final ResolverSelection selection = registry.selectFor(uri);
    if (selection is ResolverNotFound) {
      probe
        ..status = PlayerProbeStatus.failed
        ..errorCode = 'playground.no_resolver'
        ..errorMessage = 'No resolver for host ${uri.host}';
      probe.logs.add('no resolver for host ${uri.host}');
      return;
    }
    final ResolverPlugin? resolver = switch (selection) {
      ResolverSelected(:final ResolverPlugin resolver) => resolver,
      ResolverAmbiguous(:final List<ResolverPlugin> resolvers) =>
        resolvers.first,
      ResolverNotFound() => null,
    };
    if (resolver == null) return;

    // ── Phase 1: resolve ────────────────────────────────────────────────
    probe.status = PlayerProbeStatus.resolving;
    if (mounted) setState(() {});
    final DateTime resolveStart = DateTime.now();
    Result<ResolveResult, KumoriyaError> resolveResult;
    try {
      resolveResult = await resolver.resolve(uri).timeout(_resolveTimeout);
    } on TimeoutException {
      probe
        ..status = PlayerProbeStatus.timeout
        ..resolveDuration = DateTime.now().difference(resolveStart)
        ..errorCode = 'playground.resolve_timeout'
        ..errorMessage =
            'Resolve timed out after ${_resolveTimeout.inSeconds}s';
      return;
    } catch (error) {
      probe
        ..status = PlayerProbeStatus.failed
        ..resolveDuration = DateTime.now().difference(resolveStart)
        ..errorCode = 'playground.resolve_exception'
        ..errorMessage = 'Resolve exception: $error';
      return;
    }
    probe.resolveDuration = DateTime.now().difference(resolveStart);

    final ResolveResult? resolved = resolveResult.fold(
      onSuccess: (ResolveResult r) => r,
      onFailure: (KumoriyaError error) {
        probe
          ..status = PlayerProbeStatus.failed
          ..errorCode = error.code
          ..errorMessage = error.message;
        return null;
      },
    );
    if (resolved == null) return;
    if (resolved.streams.isEmpty) {
      probe
        ..status = PlayerProbeStatus.failed
        ..errorCode = 'playground.no_streams'
        ..errorMessage = 'Resolver returned 0 streams';
      return;
    }

    final ResolvedStream first = resolved.streams.first;
    probe
      ..resolvedUrl = first.url.toString()
      ..isHls = first.isHls
      ..qualityLabel = first.qualityLabel
      ..streamCount = resolved.streams.length;

    // ── Phase 2: open player ────────────────────────────────────────────
    probe.status = PlayerProbeStatus.opening;
    if (mounted) setState(() {});
    await _disposeProbeRuntime();

    final PlaybackEngine engine = switch (probe.engine) {
      PlaybackEngineKind.mediaKit => MediaKitPlaybackEngine(
        onDebugLog: (String message) => _onEngineLog(probe, message),
      ),
      PlaybackEngineKind.exoPlayer => ExoPlayerPlaybackEngine(),
      PlaybackEngineKind.kumoriyaExoPlayer => KumoriyaExoPlayerEngine(
        onDebugLog: (String message) => _onEngineLog(probe, message),
      ),
    };
    probe.logs.add('engine=${probe.engine.label}');
    final PlayerSessionOrchestrator orchestrator = PlayerSessionOrchestrator(
      playbackEngine: engine,
      onDebugLog: (String message) => probe.logs.add('orch: $message'),
    );
    _engine = engine;
    _orchestrator = orchestrator;

    final Completer<_OpenOutcome> openCompleter = Completer<_OpenOutcome>();
    final DateTime openStart = DateTime.now();

    // Attach buffering + position listeners BEFORE orchestrator.start() so
    // early emissions (the engine streams are broadcast — positions emitted
    // before a subscriber attaches are dropped) are not lost. This makes a
    // real difference for candidates whose first-frame decode arrives
    // concurrently with or slightly ahead of the state=playing transition.
    DateTime? lastBufferingAt;
    _activeSubs.add(
      engine.bufferingStream.listen((bool buffering) {
        if (buffering) {
          probe.bufferingEvents += 1;
          lastBufferingAt = DateTime.now();
        } else if (lastBufferingAt != null) {
          probe.bufferingTotal += DateTime.now().difference(lastBufferingAt!);
          lastBufferingAt = null;
        }
      }),
    );

    final Completer<void> progressCompleter = Completer<void>();
    _activeSubs.add(
      orchestrator.positionStream.listen((Duration pos) {
        probe.finalPosition = pos;
        if (probe.firstProgressAt == null &&
            pos > const Duration(milliseconds: 250)) {
          probe.firstProgressAt = DateTime.now().difference(openStart);
        }
        // Early-exit signal: real playback crossed the success threshold.
        if (!progressCompleter.isCompleted &&
            (pos > const Duration(seconds: 1) || probe.segmentsFetched >= 2)) {
          progressCompleter.complete();
        }
      }),
    );

    _activeSubs.add(
      orchestrator.states.listen((PlayerSessionState state) {
        if (openCompleter.isCompleted) return;
        if (state.status == PlayerSessionStatus.playing) {
          openCompleter.complete(const _OpenOutcome.success());
        } else if (state.status == PlayerSessionStatus.error) {
          openCompleter.complete(
            _OpenOutcome.failed(
              'player.error',
              state.errorMessage ?? 'playback error',
            ),
          );
        }
      }),
    );

    final Result<ResolvedStream, KumoriyaError> startResult = await orchestrator
        .start(streamCandidates: resolved.streams);
    if (startResult is Failure<ResolvedStream, KumoriyaError>) {
      probe
        ..status = PlayerProbeStatus.failed
        ..openDuration = DateTime.now().difference(openStart)
        ..errorCode = startResult.error.code
        ..errorMessage = startResult.error.message;
      await _disposeProbeRuntime();
      return;
    }

    _OpenOutcome outcome;
    try {
      outcome = await openCompleter.future.timeout(_openTimeout);
    } on TimeoutException {
      probe
        ..status = PlayerProbeStatus.timeout
        ..openDuration = DateTime.now().difference(openStart)
        ..errorCode = 'playground.open_timeout'
        ..errorMessage = 'Open timed out after ${_openTimeout.inSeconds}s';
      await _disposeProbeRuntime();
      return;
    }

    probe.openDuration = DateTime.now().difference(openStart);
    probe.firstPlayingDuration = probe.openDuration;

    if (outcome.isFailure) {
      probe
        ..status = PlayerProbeStatus.failed
        ..errorCode = outcome.errorCode
        ..errorMessage = outcome.errorMessage;
      await _disposeProbeRuntime();
      return;
    }

    // ── Phase 3: observe ────────────────────────────────────────────────
    probe.status = PlayerProbeStatus.observing;
    if (mounted) setState(() {});

    // Some resolvers have long cold-start latency that eats most of the
    // 20 s default window, making it impossible to distinguish "slow but
    // progressing" from "truly stalled":
    //   - anime_nexus: ~18 s in proxy manifest rewrite + segment pre-warm.
    //   - zilla: segments served without Content-Length, so ffmpeg's
    //     reconnect loop wastes ~7 s per init/segment before playback
    //     actually advances.
    // Give them a longer cap so the stall watchdog (9 s) can also fire
    // and exercise candidate fallback if they really are wedged.
    final bool needsExtendedWindow =
        probe.resolverName == 'kumoriya.resolver.anime_nexus' ||
        probe.resolverName == 'kumoriya.resolver.zilla';
    final Duration observationWindow = needsExtendedWindow
        ? _extendedObservationWindow
        : _observationWindow;

    // Race the cap against real progress — healthy streams exit as soon
    // as they cross the success threshold (>1 s played or >=2 segments),
    // so probe-all sweeps finish quickly for the common OK case while
    // still giving stalled candidates the full cap.
    await Future.any(<Future<void>>[
      Future<void>.delayed(observationWindow),
      progressCompleter.future,
    ]);

    // Close any still-open buffering window.
    if (lastBufferingAt != null) {
      probe.bufferingTotal += DateTime.now().difference(lastBufferingAt!);
    }

    // Verdict: `playing=true` alone is insufficient. Require real evidence
    // of progress: position advanced OR segments actually fetched.
    final bool hasProgress =
        probe.finalPosition > const Duration(seconds: 1) ||
        probe.segmentsFetched >= 2;
    probe.status = hasProgress
        ? PlayerProbeStatus.success
        : PlayerProbeStatus.inconclusive;
    if (!hasProgress) {
      probe.errorCode ??= 'playground.no_progress';
      probe.errorMessage ??=
          'playing=true pero position=${probe.finalPosition.inMilliseconds}ms '
          'segs=${probe.segmentsFetched} tras ${observationWindow.inSeconds}s';
    }
    await _disposeProbeRuntime();
  }

  void _onEngineLog(PlayerProbeResult probe, String message) {
    probe.logs.add(message);
    if (probe.logs.length > 1500) {
      // Keep the tail — we care about the observation window and failures.
      probe.logs.removeRange(0, probe.logs.length - 1500);
    }

    // Lightweight tallies — avoid regex to keep the hot path cheap.
    // Count both Transport Stream (.ts) and fragmented MP4 (.m4s, .mp4)
    // segment fetches. anime_nexus streams are fMP4 over HLS and were
    // previously under-counted.
    if (message.contains('hls: Opening') &&
        (message.contains('.ts') ||
            message.contains('.m4s') ||
            message.contains('/segment/'))) {
      probe.segmentsFetched += 1;
    }
    if (message.contains('Cannot reuse HTTP connection')) {
      probe.crossHostMisses += 1;
    }
    if (message.contains('tcp: Starting connection attempt to ')) {
      probe.tcpConnects += 1;
      final int hostStart = message.indexOf('attempt to ');
      if (hostStart > 0) {
        final String tail = message.substring(hostStart + 'attempt to '.length);
        final int spaceIdx = tail.indexOf(' ');
        if (spaceIdx > 0) {
          probe.observedHosts.add(tail.substring(0, spaceIdx));
        }
      }
    }
  }

  Future<void> _disposeProbeRuntime() async {
    for (final StreamSubscription<dynamic> sub in _activeSubs) {
      await sub.cancel();
    }
    _activeSubs.clear();
    final PlayerSessionOrchestrator? orch = _orchestrator;
    _orchestrator = null;
    _engine = null;
    if (orch != null) {
      await orch.dispose();
    }
  }

  Future<void> _cancelProbe() async {
    setState(() {
      _probing = false;
      _cancelReason = 'user_cancelled';
    });
    await _disposeProbeRuntime();
  }

  // ── Export helpers ────────────────────────────────────────────────────

  Future<void> _copyJson() async {
    final PlayerFlowSession? session = _currentSession;
    if (session == null) return;
    final String json = const JsonEncoder.withIndent(
      '  ',
    ).convert(session.toAuditJson());
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    _snack('Audit JSON copied.');
  }

  Map<String, dynamic> _historyJsonPayload() {
    // De-dupe: if _currentSession is already present in _history, don't double it.
    final List<PlayerFlowSession> sessions = <PlayerFlowSession>[
      ..._history,
      if (_currentSession != null && !_history.contains(_currentSession))
        _currentSession!,
    ];
    return <String, dynamic>{
      'exported_at': DateTime.now().toIso8601String(),
      'session_count': sessions.length,
      'sessions': sessions
          .map((PlayerFlowSession s) => s.toAuditJson())
          .toList(),
    };
  }

  Future<void> _copyHistoryJson() async {
    if (_history.isEmpty && _currentSession == null) return;
    final String json = const JsonEncoder.withIndent(
      '  ',
    ).convert(_historyJsonPayload());
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    _snack('Historial JSON copiado.');
  }

  Future<void> _saveHistoryJson() async {
    if (_history.isEmpty && _currentSession == null) return;
    try {
      Directory? base;
      if (Platform.isAndroid) {
        base = await getExternalStorageDirectory();
      }
      base ??= await getApplicationDocumentsDirectory();
      final Directory dir = Directory(
        '${base.path}${Platform.pathSeparator}player_flow_playground',
      );
      if (!await dir.exists()) await dir.create(recursive: true);
      final DateTime now = DateTime.now();
      final String stamp =
          '${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}';
      final File file = File(
        '${dir.path}${Platform.pathSeparator}player_flow_history_$stamp.json',
      );
      final String json = const JsonEncoder.withIndent(
        '  ',
      ).convert(_historyJsonPayload());
      await file.writeAsString(json, flush: true);
      setState(() => _lastSavedLogPath = file.path);
      if (!mounted) return;
      _snack('Historial: ${file.path}', durationSeconds: 5);
    } catch (error) {
      if (!mounted) return;
      _snack('Save history failed: $error');
    }
  }

  Future<void> _saveJson() async {
    final PlayerFlowSession? session = _currentSession;
    if (session == null) return;
    try {
      // On Android prefer external app storage — accessible via
      // `adb pull /sdcard/Android/data/<pkg>/files/player_flow_playground/…`
      // without `run-as`, which simplifies log collection from host.
      Directory? base;
      if (Platform.isAndroid) {
        base = await getExternalStorageDirectory();
      }
      base ??= await getApplicationDocumentsDirectory();
      final Directory dir = Directory(
        '${base.path}${Platform.pathSeparator}player_flow_playground',
      );
      if (!await dir.exists()) await dir.create(recursive: true);
      final DateTime now = DateTime.now();
      final String stamp =
          '${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}';
      final File file = File(
        '${dir.path}${Platform.pathSeparator}player_flow_$stamp.json',
      );
      final String json = const JsonEncoder.withIndent(
        '  ',
      ).convert(session.toAuditJson());
      await file.writeAsString(json, flush: true);
      setState(() => _lastSavedLogPath = file.path);
      if (!mounted) return;
      _snack('Saved: ${file.path}', durationSeconds: 5);
    } catch (error) {
      if (!mounted) return;
      _snack('Save failed: $error');
    }
  }

  void _snack(String message, {int durationSeconds = 3}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: durationSeconds),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      appBar: AppBar(
        title: Text(
          _history.isEmpty
              ? 'Player Flow Playground'
              : 'Player Flow · ${_history.length} sesiones',
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Copy JSON (sesión actual)',
            onPressed: _currentSession == null ? null : _copyJson,
            icon: const Icon(Icons.content_copy_rounded),
          ),
          IconButton(
            tooltip: 'Save JSON (sesión actual)',
            onPressed: _currentSession == null ? null : _saveJson,
            icon: const Icon(Icons.save_alt_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Historial',
            icon: const Icon(Icons.history_rounded),
            enabled: _history.isNotEmpty || _currentSession != null,
            onSelected: (String value) async {
              switch (value) {
                case 'copy':
                  await _copyHistoryJson();
                case 'save':
                  await _saveHistoryJson();
                case 'clear':
                  setState(() {
                    _history.clear();
                    _lastSavedLogPath = null;
                  });
              }
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'copy',
                child: ListTile(
                  leading: Icon(Icons.content_copy_rounded),
                  title: Text('Copiar historial'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'save',
                child: ListTile(
                  leading: Icon(Icons.save_alt_rounded),
                  title: Text('Guardar historial'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Limpiar historial'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildVideoPeek(),
              const SizedBox(height: 12),
              _buildSourceSelector(),
              const SizedBox(height: 8),
              _buildEngineSelector(),
              const SizedBox(height: 8),
              _buildSearchField(),
              if (_searching)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 8),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPeek() {
    final PlaybackEngine? engine = _engine;
    Widget child;
    if (engine is MediaKitPlaybackEngine) {
      child = Video(
        controller: engine.videoController,
        controls: NoVideoControls,
      );
    } else if (engine is KumoriyaExoPlayerEngine) {
      final int? id = engine.textureId;
      child = id == null
          ? const Center(
              child: Text(
                'kumoriya_exoplayer calentando…',
                style: TextStyle(color: KumoriyaColors.textMuted),
              ),
            )
          : Texture(textureId: id);
    } else if (engine is ExoPlayerPlaybackEngine) {
      // ExoPlayer preview is skipped in the playground — metrics-only.
      child = const Center(
        child: Text(
          'video_player activo (sin vista previa en el playground)',
          style: TextStyle(color: KumoriyaColors.textMuted),
        ),
      );
    } else {
      child = const Center(
        child: Text(
          'Video aparecerá aquí durante las pruebas',
          style: TextStyle(color: KumoriyaColors.textMuted),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 180,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Colors.black),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSourceSelector() {
    return Row(
      children: <Widget>[
        const Text(
          'Source:',
          style: TextStyle(color: KumoriyaColors.textMuted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<SourcePlugin>(
            value: _selectedSource,
            isExpanded: true,
            items: _sourcePlugins
                .map(
                  (SourcePlugin s) => DropdownMenuItem<SourcePlugin>(
                    value: s,
                    child: Text('${s.manifest.displayName} (${s.manifest.id})'),
                  ),
                )
                .toList(),
            onChanged: (SourcePlugin? value) {
              setState(() {
                _selectedSource = value;
                _searchResults = <SourceAnimeMatch>[];
                _episodes = <SourceEpisode>[];
                _selectedAnime = null;
                _currentSession = null;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEngineSelector() {
    return Row(
      children: <Widget>[
        const Text(
          'Engine:',
          style: TextStyle(color: KumoriyaColors.textMuted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SegmentedButton<PlaybackEngineKind>(
            segments: PlaybackEngineKind.values
                .map(
                  (PlaybackEngineKind k) => ButtonSegment<PlaybackEngineKind>(
                    value: k,
                    label: Text(k.label),
                  ),
                )
                .toList(),
            selected: <PlaybackEngineKind>{_selectedEngine},
            onSelectionChanged: _probing
                ? null
                : (Set<PlaybackEngineKind> s) {
                    setState(() => _selectedEngine = s.first);
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _searchController,
            enabled: !_probing,
            decoration: const InputDecoration(
              hintText: 'Buscar anime…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _search(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _probing ? null : _search,
          icon: const Icon(Icons.search_rounded),
          label: const Text('Buscar'),
        ),
      ],
    );
  }

  Widget _buildBody() {
    final PlayerFlowSession? session = _currentSession;
    if (session != null) {
      return _buildSessionView(session);
    }
    if (_selectedAnime != null) {
      return _buildEpisodePicker();
    }
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'Elige source, busca un anime y selecciona un episodio.',
          style: TextStyle(color: KumoriyaColors.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      itemCount: _searchResults.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, int index) {
        final SourceAnimeMatch match = _searchResults[index];
        return ListTile(
          title: Text(
            match.title,
            style: const TextStyle(color: KumoriyaColors.textPrimary),
          ),
          subtitle: Text(
            match.sourceId,
            style: const TextStyle(color: KumoriyaColors.textMuted),
          ),
          onTap: () => _loadEpisodes(match),
        );
      },
    );
  }

  Widget _buildEpisodePicker() {
    if (_loadingEpisodes) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_episodes.isEmpty) {
      return const Center(
        child: Text(
          'Sin episodios.',
          style: TextStyle(color: KumoriyaColors.textMuted),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            _selectedAnime!.title,
            style: const TextStyle(
              color: KumoriyaColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _episodes.length,
            itemBuilder: (_, int index) {
              final SourceEpisode ep = _episodes[index];
              return ListTile(
                dense: true,
                leading: Text(
                  'EP ${ep.number.toStringAsFixed(ep.number.truncateToDouble() == ep.number ? 0 : 1)}',
                  style: const TextStyle(
                    color: KumoriyaColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                title: Text(
                  ep.title.isEmpty ? '—' : ep.title,
                  style: const TextStyle(color: KumoriyaColors.textPrimary),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Probar este source',
                      onPressed: _probing ? null : () => _probeEpisode(ep),
                      icon: const Icon(Icons.play_circle_fill_rounded),
                    ),
                    IconButton(
                      tooltip: 'Probar TODOS los sources',
                      onPressed: _probing
                          ? null
                          : () => _probeAllSourcesForEpisode(ep),
                      icon: const Icon(Icons.travel_explore_rounded),
                    ),
                  ],
                ),
                onTap: _probing ? null : () => _probeEpisode(ep),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSessionView(PlayerFlowSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'EP ${session.episodeNumber.toStringAsFixed(session.episodeNumber.truncateToDouble() == session.episodeNumber ? 0 : 1)} · ${session.animeTitle}',
                style: const TextStyle(
                  color: KumoriyaColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_probing)
              TextButton.icon(
                onPressed: _cancelProbe,
                icon: const Icon(Icons.stop_circle_rounded),
                label: const Text('Cancelar'),
              )
            else
              TextButton.icon(
                onPressed: () => setState(() {
                  _currentSession = null;
                }),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Volver'),
              ),
          ],
        ),
        if (_cancelReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Cancelado: $_cancelReason',
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ),
        if (_lastSavedLogPath != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Guardado: $_lastSavedLogPath',
              style: const TextStyle(
                color: KumoriyaColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            itemCount: session.probes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, int index) {
              return _ProbeCard(probe: session.probes[index]);
            },
          ),
        ),
      ],
    );
  }
}

// ─── Probe card ─────────────────────────────────────────────────────────────

class _ProbeCard extends StatefulWidget {
  const _ProbeCard({required this.probe});

  final PlayerProbeResult probe;

  @override
  State<_ProbeCard> createState() => _ProbeCardState();
}

class _ProbeCardState extends State<_ProbeCard> {
  bool _expanded = false;

  Color _statusColor() {
    switch (widget.probe.status) {
      case PlayerProbeStatus.success:
        return Colors.greenAccent;
      case PlayerProbeStatus.inconclusive:
        return Colors.amberAccent;
      case PlayerProbeStatus.failed:
      case PlayerProbeStatus.timeout:
        return Colors.redAccent;
      case PlayerProbeStatus.waiting:
        return KumoriyaColors.textMuted;
      default:
        return Colors.orangeAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final PlayerProbeResult p = widget.probe;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KumoriyaColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KumoriyaColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    p.serverName,
                    style: const TextStyle(
                      color: KumoriyaColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  p.statusLabel,
                  style: TextStyle(
                    color: _statusColor(),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'resolver=${p.resolverName} · host=${p.detectedHost}',
              style: const TextStyle(
                color: KumoriyaColors.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: <Widget>[
                _metric('resolve', _ms(p.resolveDuration)),
                _metric('open', _ms(p.openDuration)),
                _metric('streams', '${p.streamCount}'),
                if (p.qualityLabel != null) _metric('q', p.qualityLabel!),
                if (p.isHls != null) _metric('hls', p.isHls! ? 'yes' : 'no'),
                _metric('buf#', '${p.bufferingEvents}'),
                _metric('bufMs', '${p.bufferingTotal.inMilliseconds}'),
                _metric('segs', '${p.segmentsFetched}'),
                _metric('conns', '${p.tcpConnects}'),
                _metric('miss', '${p.crossHostMisses}'),
                _metric('hosts', '${p.observedHosts.length}'),
              ],
            ),
            if (p.errorMessage != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                '${p.errorCode ?? "error"}: ${p.errorMessage!}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            if (p.resolvedUrl != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                p.resolvedUrl!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: KumoriyaColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
            if (p.logs.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Row(
                  children: <Widget>[
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                      color: KumoriyaColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'logs (${p.logs.length})',
                      style: const TextStyle(
                        color: KumoriyaColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (_expanded)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      p.logs.length > 200
                          ? p.logs.sublist(p.logs.length - 200).join('\n')
                          : p.logs.join('\n'),
                      style: const TextStyle(
                        color: KumoriyaColors.textMuted,
                        fontSize: 10,
                        fontFamily: 'monospace',
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Text(
      '$label=$value',
      style: const TextStyle(
        color: KumoriyaColors.textPrimary,
        fontSize: 12,
        fontFamily: 'monospace',
      ),
    );
  }

  String _ms(Duration? d) => d == null ? '—' : '${d.inMilliseconds}ms';
}

// ─── Helpers ────────────────────────────────────────────────────────────────

class _OpenOutcome {
  const _OpenOutcome.success()
    : isFailure = false,
      errorCode = null,
      errorMessage = null;
  const _OpenOutcome.failed(this.errorCode, this.errorMessage)
    : isFailure = true;

  final bool isFailure;
  final String? errorCode;
  final String? errorMessage;
}
