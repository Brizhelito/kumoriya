import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_exoplayer/kumoriya_exoplayer.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:path_provider/path_provider.dart';

import '../../../anime_catalog/application/services/resolver_registry.dart';
import '../../../anime_catalog/presentation/providers/anime_catalog_providers.dart';

/// Mini smoke playground for the native `kumoriya_exoplayer` plugin.
///
/// Exercises the controller against the Fase 1 gate targets:
///   1. Zilla (source + resolver)
///   2. anime_nexus (source + resolver)
///   3. Streamwish (resolver, reached via any source that exposes it)
/// plus a "manual URL" fallback for quick smoke probes.
///
/// Independent of `PlaybackEngine` / `PlayerSessionOrchestrator` on purpose:
/// this page only validates the plugin API surface and the Kotlin ↔ Dart
/// event pipeline end to end.
class KumoriyaExoPlayerPlaygroundPage extends ConsumerStatefulWidget {
  const KumoriyaExoPlayerPlaygroundPage({super.key});

  @override
  ConsumerState<KumoriyaExoPlayerPlaygroundPage> createState() =>
      _KumoriyaExoPlayerPlaygroundPageState();
}

class _KumoriyaExoPlayerPlaygroundPageState
    extends ConsumerState<KumoriyaExoPlayerPlaygroundPage> {
  static const List<_Preset> _manualPresets = <_Preset>[
    _Preset(
      label: 'BigBuckBunny (MP4 720p)',
      url:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    ),
    _Preset(
      label: 'Apple HLS bipbop 16x9',
      url:
          'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8',
    ),
    _Preset(
      label: 'DASH Envivio',
      url: 'https://dash.akamaized.net/envivio/EnvivioDash3/manifest.mpd',
    ),
  ];

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _manualUrlController = TextEditingController(
    text: _manualPresets.first.url,
  );
  final TextEditingController _nexusWatchController = TextEditingController();

  List<SourcePlugin> _sources = <SourcePlugin>[];
  ResolverRegistry? _registry;
  SourcePlugin? _selectedSource;

  bool _searching = false;
  List<SourceAnimeMatch> _searchResults = <SourceAnimeMatch>[];
  SourceAnimeMatch? _selectedAnime;

  bool _loadingEpisodes = false;
  List<SourceEpisode> _episodes = <SourceEpisode>[];
  SourceEpisode? _selectedEpisode;

  bool _loadingServers = false;
  List<SourceServerLink> _servers = <SourceServerLink>[];

  bool _resolving = false;
  String? _resolvingServer;

  // Native player state.
  KumoriyaExoPlayerController? _controller;
  final List<StreamSubscription<Object?>> _subs =
      <StreamSubscription<Object?>>[];
  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  double _speed = 1.0;
  String? _lastError;
  String? _activeStreamLabel;

  /// Ring buffer of every log line received since the page was opened. Kept
  /// generous (10k entries) so a full bootstrap + WS handshake + segment
  /// failure trail fits without rolling, and can be exported verbatim for
  /// offline diagnostics.
  static const int _logCapacity = 10000;
  final List<String> _log = <String>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sources = ref.read(sourcePluginsProvider);
      _registry = ref.read(resolverRegistryProvider);
      _selectedSource = _sources.firstOrNull;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _manualUrlController.dispose();
    _nexusWatchController.dispose();
    unawaited(_teardownController());
    super.dispose();
  }

  bool get _androidOnly => Platform.isAndroid;

  void _append(String line) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, '${DateTime.now().toIso8601String()}  $line');
      if (_log.length > _logCapacity) {
        _log.removeRange(_logCapacity, _log.length);
      }
    });
  }

  /// Returns the log as a single string in chronological order (oldest first)
  /// so it's readable when pasted or opened in an editor. The in-memory list
  /// stores newest-first to keep the UI fast.
  String _logAsText() {
    final buffer = StringBuffer();
    for (int i = _log.length - 1; i >= 0; i--) {
      buffer.writeln(_log[i]);
    }
    return buffer.toString();
  }

  Future<void> _copyLog() async {
    if (_log.isEmpty) {
      _snack('Log vacío.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: _logAsText()));
    if (!mounted) return;
    _snack('Log copiado (${_log.length} líneas).');
  }

  Future<void> _saveLog() async {
    if (_log.isEmpty) {
      _snack('Log vacío.');
      return;
    }
    try {
      Directory? base;
      if (Platform.isAndroid) {
        base = await getExternalStorageDirectory();
      }
      base ??= await getApplicationDocumentsDirectory();
      final dir = Directory(
        '${base.path}${Platform.pathSeparator}kumoriya_exoplayer_playground',
      );
      if (!await dir.exists()) await dir.create(recursive: true);
      final now = DateTime.now();
      final stamp =
          '${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}';
      final file = File(
        '${dir.path}${Platform.pathSeparator}kxplayer_log_$stamp.txt',
      );
      await file.writeAsString(_logAsText(), flush: true);
      if (!mounted) return;
      _snack('Log guardado: ${file.path}');
      // Also copy the path so `adb pull` is a single clipboard away.
      await Clipboard.setData(ClipboardData(text: file.path));
    } catch (e) {
      if (!mounted) return;
      _snack('Error guardando log: $e');
    }
  }

  void _clearLog() {
    setState(() => _log.clear());
    _snack('Log limpiado.');
  }

  void _snack(String msg) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  // ── Source search ─────────────────────────────────────────────────────

  Future<void> _search() async {
    final source = _selectedSource;
    final query = _searchController.text.trim();
    if (source == null || query.isEmpty) return;
    setState(() {
      _searching = true;
      _searchResults = <SourceAnimeMatch>[];
      _episodes = <SourceEpisode>[];
      _servers = <SourceServerLink>[];
      _selectedAnime = null;
      _selectedEpisode = null;
    });
    _append('search "$query" in ${source.manifest.id}…');
    final result = await source.search(
      SourceSearchQuery(query: query, page: 1, limit: 20),
    );
    if (!mounted) return;
    result.fold(
      onSuccess: (m) {
        _append('search → ${m.length} matches');
        setState(() {
          _searchResults = m;
          _searching = false;
        });
      },
      onFailure: (e) {
        _append('search → ERROR ${e.code} ${e.message}');
        setState(() => _searching = false);
      },
    );
  }

  Future<void> _loadEpisodes(SourceAnimeMatch anime) async {
    final source = _selectedSource;
    if (source == null) return;
    setState(() {
      _loadingEpisodes = true;
      _selectedAnime = anime;
      _episodes = <SourceEpisode>[];
      _servers = <SourceServerLink>[];
      _selectedEpisode = null;
    });
    _append('episodes of ${anime.title}…');
    final result = await source.getEpisodes(anime.sourceId);
    if (!mounted) return;
    result.fold(
      onSuccess: (e) {
        _append('episodes → ${e.length}');
        setState(() {
          _episodes = e;
          _loadingEpisodes = false;
        });
      },
      onFailure: (e) {
        _append('episodes → ERROR ${e.code} ${e.message}');
        setState(() => _loadingEpisodes = false);
      },
    );
  }

  Future<void> _loadServers(SourceEpisode episode) async {
    final source = _selectedSource;
    if (source == null) return;
    setState(() {
      _loadingServers = true;
      _selectedEpisode = episode;
      _servers = <SourceServerLink>[];
    });
    _append('servers for ep ${episode.number} ${episode.title}…');
    final result = await source.getEpisodeServerLinks(episode);
    if (!mounted) return;
    result.fold(
      onSuccess: (l) {
        _append('servers → ${l.length}');
        setState(() {
          _servers = l;
          _loadingServers = false;
        });
      },
      onFailure: (e) {
        _append('servers → ERROR ${e.code} ${e.message}');
        setState(() => _loadingServers = false);
      },
    );
  }

  // ── Probe a server: resolve → controller.open ─────────────────────────

  Future<void> _probeServer(SourceServerLink link) async {
    final registry = _registry;
    if (registry == null) return;
    final selection = registry.selectFor(link.initialUrl);
    final resolver = switch (selection) {
      ResolverSelected(:final resolver) => resolver,
      ResolverAmbiguous(:final resolvers) => resolvers.first,
      ResolverNotFound() => null,
    };
    if (resolver == null) {
      _append('resolver: NOT_FOUND for host ${link.initialUrl.host}');
      return;
    }

    setState(() {
      _resolving = true;
      _resolvingServer = link.serverName;
    });
    _append(
      'probe ${link.serverName} host=${link.detectedHost ?? link.initialUrl.host} '
      'resolver=${resolver.manifest.id}',
    );
    final sw = Stopwatch()..start();
    final result = await resolver.resolve(link.initialUrl);
    sw.stop();
    if (!mounted) return;

    final resolved = result.fold(
      onSuccess: (r) => r,
      onFailure: (e) {
        _append('resolve → ERROR ${e.code} ${e.message} in ${sw.elapsed}');
        return null;
      },
    );
    if (resolved == null) {
      setState(() {
        _resolving = false;
        _resolvingServer = null;
      });
      return;
    }
    if (resolved.streams.isEmpty) {
      _append('resolve → OK pero 0 streams');
      setState(() {
        _resolving = false;
        _resolvingServer = null;
      });
      return;
    }

    final stream = resolved.streams.first;
    _append(
      'resolve → OK in ${sw.elapsed} '
      'streams=${resolved.streams.length} quality=${stream.qualityLabel} '
      'isHls=${stream.isHls} headers=${stream.headers.keys.toList()}',
    );

    await _openOnController(
      url: stream.url.toString(),
      headers: stream.headers,
      label: '${resolver.manifest.id} · ${stream.qualityLabel ?? '—'}',
    );
    setState(() {
      _resolving = false;
      _resolvingServer = null;
    });
  }

  // ── Controller lifecycle ──────────────────────────────────────────────

  Future<KumoriyaExoPlayerController> _ensureController() async {
    final existing = _controller;
    if (existing != null && !existing.isDisposed) return existing;
    _append('controller.create()…');
    final controller = await KumoriyaExoPlayerController.create();
    _append('controller.create() → textureId=${controller.textureId}');
    _bindController(controller);
    if (mounted) setState(() => _controller = controller);
    return controller;
  }

  void _bindController(KumoriyaExoPlayerController controller) {
    _subs.addAll(<StreamSubscription<Object?>>[
      controller.playingStream.listen((v) {
        _append('evt playing=$v');
        if (mounted) setState(() => _isPlaying = v);
      }),
      controller.bufferingStream.listen((v) {
        _append('evt buffering=$v');
        if (mounted) setState(() => _isBuffering = v);
      }),
      controller.positionStream.listen((v) {
        if (mounted) setState(() => _position = v);
      }),
      controller.durationStream.listen((v) {
        _append('evt duration=${v.inMilliseconds}ms');
        if (mounted) setState(() => _duration = v);
      }),
      controller.completedStream.listen((_) => _append('evt completed')),
      controller.errorStream.listen((e) {
        _append('evt error code=${e.code} msg=${e.message}');
        if (mounted) setState(() => _lastError = '${e.code}: ${e.message}');
      }),
      controller.logStream.listen(_append),
    ]);
  }

  Future<void> _openNexusWatch() async {
    final url = _nexusWatchController.text.trim();
    if (url.isEmpty) {
      _append('nexus → URL vacía');
      return;
    }
    if (!url.contains('anime.nexus/watch/')) {
      _append('nexus → URL no parece watch de anime.nexus');
      return;
    }
    try {
      final controller = await _ensureController();
      _append('nexus.openAnimeNexus($url)…');
      final sw = Stopwatch()..start();
      await controller.openAnimeNexus(url);
      sw.stop();
      _append('nexus.open → ok in ${sw.elapsed}');
      await controller.play();
      if (!mounted) return;
      setState(() {
        _activeStreamLabel = 'anime.nexus native';
        _lastError = null;
      });
    } catch (e, st) {
      _append('nexus.open → ERROR $e');
      debugPrint('nexus open error: $e\n$st');
      if (mounted) setState(() => _lastError = e.toString());
    }
  }

  Future<void> _openOnController({
    required String url,
    required Map<String, String> headers,
    required String label,
  }) async {
    try {
      final controller = await _ensureController();
      _append('controller.open($url)…');
      await controller.open(url, headers: headers);
      await controller.play();
      if (!mounted) return;
      setState(() {
        _activeStreamLabel = label;
        _lastError = null;
      });
    } catch (e, st) {
      _append('controller.open → ERROR $e');
      debugPrint('open error: $e\n$st');
      if (mounted) setState(() => _lastError = e.toString());
    }
  }

  Future<void> _teardownController() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isDisposed) {
      try {
        await controller.dispose();
      } catch (_) {
        // ignore
      }
    }
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _isBuffering = false;
        _position = Duration.zero;
        _duration = Duration.zero;
        _activeStreamLabel = null;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('kumoriya_exoplayer playground'),
        actions: [
          IconButton(
            tooltip: 'Copiar log',
            onPressed: _log.isEmpty ? null : _copyLog,
            icon: const Icon(Icons.copy_all_rounded),
          ),
          IconButton(
            tooltip: 'Guardar log a disco',
            onPressed: _log.isEmpty ? null : _saveLog,
            icon: const Icon(Icons.save_alt_rounded),
          ),
          IconButton(
            tooltip: 'Limpiar log',
            onPressed: _log.isEmpty ? null : _clearLog,
            icon: const Icon(Icons.clear_all_rounded),
          ),
          IconButton(
            tooltip: 'Dispose player',
            onPressed: _controller == null ? null : _teardownController,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: !_androidOnly
          ? const _NonAndroidNotice()
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _TextureBox(controller: _controller),
                  const SizedBox(height: 8),
                  _StatusLine(
                    controller: _controller,
                    isPlaying: _isPlaying,
                    isBuffering: _isBuffering,
                    position: _position,
                    duration: _duration,
                    volume: _volume,
                    speed: _speed,
                    lastError: _lastError,
                    activeStreamLabel: _activeStreamLabel,
                  ),
                  const SizedBox(height: 8),
                  _PlayerControls(
                    controller: _controller,
                    onPlay: () => _controller?.play(),
                    onPause: () => _controller?.pause(),
                    onSeekBack: () => _controller?.seekTo(
                      _position - const Duration(seconds: 10),
                    ),
                    onSeekFwd: () => _controller?.seekTo(
                      _position + const Duration(seconds: 10),
                    ),
                    volume: _volume,
                    onVolume: (v) {
                      setState(() => _volume = v);
                      _controller?.setVolume(v);
                    },
                    speed: _speed,
                    onSpeed: (v) {
                      setState(() => _speed = v);
                      _controller?.setPlaybackSpeed(v);
                    },
                  ),
                  const Divider(height: 24),
                  _SectionHeader('Source → resolver → controller'),
                  _SourcePicker(
                    sources: _sources,
                    selected: _selectedSource,
                    onChanged: (s) => setState(() => _selectedSource = s),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Buscar anime',
                            isDense: true,
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _searching ? null : _search,
                        child: _searching
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Buscar'),
                      ),
                    ],
                  ),
                  if (_searchResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _MatchList(
                      matches: _searchResults,
                      selected: _selectedAnime,
                      onSelect: _loadEpisodes,
                    ),
                  ],
                  if (_loadingEpisodes)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    ),
                  if (_episodes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _EpisodeStrip(
                      episodes: _episodes,
                      selected: _selectedEpisode,
                      onSelect: _loadServers,
                    ),
                  ],
                  if (_loadingServers)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    ),
                  if (_servers.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _ServerList(
                      servers: _servers,
                      resolving: _resolving,
                      resolvingServer: _resolvingServer,
                      onProbe: _probeServer,
                      registry: _registry,
                    ),
                  ],
                  const Divider(height: 24),
                  _SectionHeader('anime.nexus nativo (Fase 2)'),
                  TextField(
                    controller: _nexusWatchController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'https://anime.nexus/watch/<uuid>/<slug>',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.url,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _resolving ? null : _openNexusWatch,
                        icon: const Icon(Icons.rocket_launch_rounded),
                        label: const Text('open vía nativo'),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'bootstrap + WS + signing en Kotlin, sin proxy Dart.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _SectionHeader('Manual URL'),
                  TextField(
                    controller: _manualUrlController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'URL directa',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.url,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in _manualPresets)
                        ActionChip(
                          label: Text(p.label),
                          onPressed: () => _manualUrlController.text = p.url,
                        ),
                      FilledButton.icon(
                        onPressed: _resolving
                            ? null
                            : () {
                                final url = _manualUrlController.text.trim();
                                if (url.isEmpty) return;
                                _openOnController(
                                  url: url,
                                  headers: const <String, String>{},
                                  label: 'manual',
                                );
                              },
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        label: const Text('open manual'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionHeader('Event log'),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _log
                          .map(
                            (l) => Text(
                              l,
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Widgets ─────────────────────────────────────────────────────────────

class _Preset {
  const _Preset({required this.label, required this.url});
  final String label;
  final String url;
}

class _NonAndroidNotice extends StatelessWidget {
  const _NonAndroidNotice();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Text(
      'kumoriya_exoplayer es solo para Android. '
      'En esta plataforma no hay implementación nativa.',
    ),
  );
}

class _TextureBox extends StatelessWidget {
  const _TextureBox({required this.controller});
  final KumoriyaExoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: controller == null
            ? const Center(
                child: Text(
                  'sin player — usá un server o URL manual',
                  style: TextStyle(color: Colors.white54),
                ),
              )
            : Texture(textureId: controller!.textureId),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.controller,
    required this.isPlaying,
    required this.isBuffering,
    required this.position,
    required this.duration,
    required this.volume,
    required this.speed,
    required this.lastError,
    required this.activeStreamLabel,
  });

  final KumoriyaExoPlayerController? controller;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final double volume;
  final double speed;
  final String? lastError;
  final String? activeStreamLabel;

  @override
  Widget build(BuildContext context) {
    final tid = controller?.textureId.toString() ?? '—';
    final pos = '${position.inSeconds}s / ${duration.inSeconds}s';
    return DefaultTextStyle(
      style: Theme.of(context).textTheme.bodySmall ?? const TextStyle(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('textureId=$tid  stream=${activeStreamLabel ?? '—'}'),
          Text(
            'playing=$isPlaying  buffering=$isBuffering  $pos  '
            'vol=${(volume * 100).round()}%  speed=${speed.toStringAsFixed(2)}x',
          ),
          if (lastError != null)
            Text(
              'last error: $lastError',
              style: const TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }
}

class _PlayerControls extends StatelessWidget {
  const _PlayerControls({
    required this.controller,
    required this.onPlay,
    required this.onPause,
    required this.onSeekBack,
    required this.onSeekFwd,
    required this.volume,
    required this.onVolume,
    required this.speed,
    required this.onSpeed,
  });

  final KumoriyaExoPlayerController? controller;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekFwd;
  final double volume;
  final ValueChanged<double> onVolume;
  final double speed;
  final ValueChanged<double> onSpeed;

  @override
  Widget build(BuildContext context) {
    final disabled = controller == null;
    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: disabled ? null : onPlay,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('play'),
            ),
            FilledButton.icon(
              onPressed: disabled ? null : onPause,
              icon: const Icon(Icons.pause_rounded),
              label: const Text('pause'),
            ),
            OutlinedButton.icon(
              onPressed: disabled ? null : onSeekBack,
              icon: const Icon(Icons.replay_10_rounded),
              label: const Text('-10s'),
            ),
            OutlinedButton.icon(
              onPressed: disabled ? null : onSeekFwd,
              icon: const Icon(Icons.forward_10_rounded),
              label: const Text('+10s'),
            ),
          ],
        ),
        Row(
          children: [
            const SizedBox(width: 60, child: Text('vol')),
            Expanded(
              child: Slider(value: volume.clamp(0.0, 1.0), onChanged: onVolume),
            ),
            SizedBox(
              width: 46,
              child: Text(
                '${(volume * 100).round()}%',
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        Row(
          children: [
            const SizedBox(width: 60, child: Text('speed')),
            Expanded(
              child: Slider(
                value: speed.clamp(0.5, 2.0),
                min: 0.5,
                max: 2.0,
                onChanged: onSpeed,
              ),
            ),
            SizedBox(
              width: 46,
              child: Text(
                '${speed.toStringAsFixed(2)}x',
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
  );
}

class _SourcePicker extends StatelessWidget {
  const _SourcePicker({
    required this.sources,
    required this.selected,
    required this.onChanged,
  });
  final List<SourcePlugin> sources;
  final SourcePlugin? selected;
  final ValueChanged<SourcePlugin?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<SourcePlugin>(
      initialValue: selected,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Source plugin',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      items: [
        for (final s in sources)
          DropdownMenuItem(value: s, child: Text(s.manifest.id)),
      ],
      onChanged: onChanged,
    );
  }
}

class _MatchList extends StatelessWidget {
  const _MatchList({
    required this.matches,
    required this.selected,
    required this.onSelect,
  });
  final List<SourceAnimeMatch> matches;
  final SourceAnimeMatch? selected;
  final ValueChanged<SourceAnimeMatch> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in matches)
          ChoiceChip(
            label: Text(
              m.title.length > 40 ? '${m.title.substring(0, 40)}…' : m.title,
            ),
            selected: selected?.sourceId == m.sourceId,
            onSelected: (_) => onSelect(m),
          ),
      ],
    );
  }
}

class _EpisodeStrip extends StatelessWidget {
  const _EpisodeStrip({
    required this.episodes,
    required this.selected,
    required this.onSelect,
  });
  final List<SourceEpisode> episodes;
  final SourceEpisode? selected;
  final ValueChanged<SourceEpisode> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: episodes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final e = episodes[i];
          final isSel = selected?.number == e.number;
          return ChoiceChip(
            label: Text('Ep ${e.number}'),
            selected: isSel,
            onSelected: (_) => onSelect(e),
          );
        },
      ),
    );
  }
}

class _ServerList extends StatelessWidget {
  const _ServerList({
    required this.servers,
    required this.resolving,
    required this.resolvingServer,
    required this.onProbe,
    required this.registry,
  });
  final List<SourceServerLink> servers;
  final bool resolving;
  final String? resolvingServer;
  final ValueChanged<SourceServerLink> onProbe;
  final ResolverRegistry? registry;

  @override
  Widget build(BuildContext context) {
    return Column(children: [for (final s in servers) _serverRow(s)]);
  }

  Widget _serverRow(SourceServerLink s) {
    final registry = this.registry;
    String resolverName = '—';
    if (registry != null) {
      final sel = registry.selectFor(s.initialUrl);
      resolverName = switch (sel) {
        ResolverSelected(:final resolver) => resolver.manifest.id,
        ResolverAmbiguous(:final resolvers) =>
          '${resolvers.first.manifest.id} (×${resolvers.length})',
        ResolverNotFound() => 'NO_RESOLVER',
      };
    }
    final busy = resolving && resolvingServer == s.serverName;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        '${s.serverName} · ${s.detectedHost ?? s.initialUrl.host}',
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(
        'resolver=$resolverName',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: SizedBox(
        width: 96,
        child: FilledButton(
          onPressed: (resolving && !busy) ? null : () => onProbe(s),
          child: busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('probe'),
        ),
      ),
    );
  }
}
