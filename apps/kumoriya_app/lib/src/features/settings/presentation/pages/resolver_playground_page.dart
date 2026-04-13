import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../anime_catalog/application/services/resolver_registry.dart';
import '../../../anime_catalog/presentation/providers/anime_catalog_providers.dart';

// ─── Data models ────────────────────────────────────────────────────────────

enum ProbeStatus { waiting, resolving, fetching, success, failed, timeout }

class ResolverProbeResult {
  ResolverProbeResult({
    required this.serverName,
    required this.serverUrl,
    required this.detectedHost,
    required this.resolverName,
  });

  final String serverName;
  final String serverUrl;
  final String detectedHost;
  final String resolverName;

  ProbeStatus status = ProbeStatus.waiting;
  String? resolvedUrl;
  bool? isHls;
  String? qualityLabel;
  Map<String, String> resolvedHeaders = const {};
  int? httpStatusCode;
  int bytesDownloaded = 0;
  Duration? resolveDuration;
  Duration? fetchDuration;
  String? errorMessage;
  DateTime startedAt = DateTime.now();

  String get statusLabel => switch (status) {
    ProbeStatus.waiting => 'WAITING',
    ProbeStatus.resolving => 'RESOLVING…',
    ProbeStatus.fetching => 'FETCHING…',
    ProbeStatus.success => 'OK',
    ProbeStatus.failed => 'FAILED',
    ProbeStatus.timeout => 'TIMEOUT',
  };

  Map<String, dynamic> toAuditJson() => {
    'server_name': serverName,
    'server_url': serverUrl,
    'detected_host': detectedHost,
    'resolver_name': resolverName,
    'status': statusLabel,
    'resolved_url': resolvedUrl,
    'is_hls': isHls,
    'quality_label': qualityLabel,
    'resolved_headers': resolvedHeaders,
    'http_status_code': httpStatusCode,
    'bytes_downloaded': bytesDownloaded,
    'resolve_duration_ms': resolveDuration?.inMilliseconds,
    'fetch_duration_ms': fetchDuration?.inMilliseconds,
    'error': errorMessage,
    'started_at': startedAt.toIso8601String(),
  };
}

class EpisodeProbeSession {
  EpisodeProbeSession({
    required this.episodeNumber,
    required this.episodeTitle,
    required this.sourcePluginId,
  });

  final double episodeNumber;
  final String episodeTitle;
  final String sourcePluginId;
  final List<ResolverProbeResult> probes = [];
  DateTime startedAt = DateTime.now();

  Map<String, dynamic> toAuditJson() => {
    'episode_number': episodeNumber,
    'episode_title': episodeTitle,
    'source_plugin_id': sourcePluginId,
    'started_at': startedAt.toIso8601String(),
    'probes': probes.map((p) => p.toAuditJson()).toList(),
  };
}

// ─── Page ───────────────────────────────────────────────────────────────────

class ResolverPlaygroundPage extends ConsumerStatefulWidget {
  const ResolverPlaygroundPage({super.key});

  @override
  ConsumerState<ResolverPlaygroundPage> createState() =>
      _ResolverPlaygroundPageState();
}

class _ResolverPlaygroundPageState
    extends ConsumerState<ResolverPlaygroundPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<SourcePlugin> _sourcePlugins = [];
  ResolverRegistry? _registry;
  http.Client? _httpClient;

  // Search state
  bool _searching = false;
  List<SourceAnimeMatch> _searchResults = [];
  SourcePlugin? _selectedSource;

  // Episode state
  bool _loadingEpisodes = false;
  List<SourceEpisode> _episodes = [];
  SourceAnimeMatch? _selectedAnime;

  // Probe state
  bool _probing = false;
  EpisodeProbeSession? _currentSession;

  // Audit log
  final List<EpisodeProbeSession> _auditSessions = [];
  String? _lastSavedLogPath;

  // Resolve timeout matches ResolveSourceServerLinkUseCase (20s)
  static const _resolveTimeout = Duration(seconds: 20);
  // Fetch timeout is generous (CDNs can be slow)
  static const _fetchTimeout = Duration(seconds: 30);
  static const _probeFetchBytes = 512 * 1024; // 512 KB probe

  // Matches HlsSegmentDownloader._browserUserAgent (Windows desktop Chrome)
  // so the fetch phase exercises the same UA fingerprint as the real downloader.
  static const _downloaderUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sourcePlugins = ref.read(sourcePluginsProvider);
      _selectedSource = _sourcePlugins.firstOrNull;
      _registry = ref.read(resolverRegistryProvider);
      _httpClient = ref.read(resolverHttpClientProvider);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Search ──────────────────────────────────────────────────────────────

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _selectedSource == null) return;

    setState(() {
      _searching = true;
      _searchResults = [];
      _episodes = [];
      _selectedAnime = null;
      _currentSession = null;
    });

    final result = await _selectedSource!.search(
      SourceSearchQuery(query: query, page: 1, limit: 20),
    );

    if (!mounted) return;

    result.fold(
      onSuccess: (matches) {
        setState(() {
          _searchResults = matches;
          _searching = false;
        });
      },
      onFailure: (error) {
        setState(() {
          _searching = false;
        });
        _showSnack('Search failed: ${error.message}');
      },
    );
  }

  // ── Load episodes ─────────────────────────────────────────────────────

  Future<void> _loadEpisodes(SourceAnimeMatch anime) async {
    setState(() {
      _selectedAnime = anime;
      _loadingEpisodes = true;
      _episodes = [];
      _currentSession = null;
    });

    final result = await _selectedSource!.getEpisodes(anime.sourceId);

    if (!mounted) return;

    result.fold(
      onSuccess: (episodes) {
        setState(() {
          _episodes = episodes;
          _loadingEpisodes = false;
        });
      },
      onFailure: (error) {
        setState(() => _loadingEpisodes = false);
        _showSnack('Episodes failed: ${error.message}');
      },
    );
  }

  // ── Probe all resolvers for an episode ────────────────────────────────

  Future<void> _probeEpisode(SourceEpisode episode) async {
    if (_probing) return;

    setState(() {
      _probing = true;
      _currentSession = EpisodeProbeSession(
        episodeNumber: episode.number,
        episodeTitle: episode.title,
        sourcePluginId: _selectedSource!.manifest.id,
      );
    });

    _logAudit(
      '═══ PROBE SESSION: ${_selectedAnime?.title ?? "?"} '
      'EP${episode.number} [${_selectedSource!.manifest.id}] ═══',
    );

    // 1. Get server links
    final linksResult = await _selectedSource!.getEpisodeServerLinks(episode);

    if (!mounted) return;

    final links = linksResult.fold(
      onSuccess: (links) => links,
      onFailure: (error) {
        _logAudit('ERROR: getServerLinks failed: ${error.message}');
        setState(() => _probing = false);
        _showSnack('Server links failed: ${error.message}');
        return <SourceServerLink>[];
      },
    );

    if (links.isEmpty) {
      setState(() => _probing = false);
      return;
    }

    _logAudit('Found ${links.length} server links');

    // 2. Create probe results for each server link
    for (final link in links) {
      final uri = link.initialUrl;
      final selection = _registry!.selectFor(uri);
      final resolverName = switch (selection) {
        ResolverSelected(:final resolver) => resolver.manifest.id,
        ResolverAmbiguous(:final resolvers) =>
          '${resolvers.first.manifest.id}(ambiguous×${resolvers.length})',
        ResolverNotFound() => 'NOT_FOUND',
      };

      _currentSession!.probes.add(
        ResolverProbeResult(
          serverName: link.serverName,
          serverUrl: uri.toString(),
          detectedHost: link.detectedHost ?? uri.host,
          resolverName: resolverName,
        ),
      );
    }

    setState(() {});

    // 3. Run all probes simultaneously
    final futures = <Future<void>>[];
    for (var i = 0; i < _currentSession!.probes.length; i++) {
      futures.add(_runSingleProbe(_currentSession!.probes[i], links[i]));
    }

    await Future.wait(futures);

    if (!mounted) return;

    // 4. Log summary
    final ok = _currentSession!.probes.where(
      (p) => p.status == ProbeStatus.success,
    );
    final fail = _currentSession!.probes.where(
      (p) => p.status == ProbeStatus.failed,
    );
    final tout = _currentSession!.probes.where(
      (p) => p.status == ProbeStatus.timeout,
    );

    _logAudit(
      '═══ SUMMARY: ${ok.length} OK / ${fail.length} FAILED / '
      '${tout.length} TIMEOUT / ${_currentSession!.probes.length} TOTAL ═══',
    );

    _auditSessions.add(_currentSession!);

    setState(() => _probing = false);
  }

  Future<void> _runSingleProbe(
    ResolverProbeResult probe,
    SourceServerLink link,
  ) async {
    final uri = link.initialUrl;

    final selection = _registry!.selectFor(uri);
    if (selection is ResolverNotFound) {
      probe
        ..status = ProbeStatus.failed
        ..errorMessage = 'No resolver for host ${uri.host}';
      _logAudit('[${probe.serverName}] FAILED: no resolver for ${uri.host}');
      if (mounted) setState(() {});
      return;
    }

    final resolver = switch (selection) {
      ResolverSelected(:final resolver) => resolver,
      ResolverAmbiguous(:final resolvers) => resolvers.first,
      ResolverNotFound() => null,
    };

    if (resolver == null) return;

    // ── Phase 1: Resolve ──
    probe.status = ProbeStatus.resolving;
    probe.startedAt = DateTime.now();
    if (mounted) setState(() {});

    _logAudit(
      '[${probe.serverName}] resolving via ${resolver.manifest.id} '
      '→ ${link.initialUrl}',
    );

    final resolveStart = DateTime.now();
    Result<ResolveResult, KumoriyaError> resolveResult;
    try {
      resolveResult = await resolver.resolve(uri).timeout(_resolveTimeout);
    } on TimeoutException {
      probe
        ..status = ProbeStatus.timeout
        ..resolveDuration = DateTime.now().difference(resolveStart)
        ..errorMessage =
            'Resolve timed out after ${_resolveTimeout.inSeconds}s';
      _logAudit(
        '[${probe.serverName}] TIMEOUT: resolve took '
        '>${_resolveTimeout.inSeconds}s',
      );
      if (mounted) setState(() {});
      return;
    } catch (e) {
      probe
        ..status = ProbeStatus.failed
        ..resolveDuration = DateTime.now().difference(resolveStart)
        ..errorMessage = 'Resolve exception: $e';
      _logAudit('[${probe.serverName}] FAILED: resolve exception — $e');
      if (mounted) setState(() {});
      return;
    }

    probe.resolveDuration = DateTime.now().difference(resolveStart);

    final resolved = resolveResult.fold(
      onSuccess: (r) => r,
      onFailure: (error) {
        probe
          ..status = ProbeStatus.failed
          ..errorMessage = 'Resolve error: ${error.message}';
        _logAudit(
          '[${probe.serverName}] FAILED: ${error.code} — ${error.message} '
          '(${probe.resolveDuration!.inMilliseconds}ms)',
        );
        return null;
      },
    );

    if (resolved == null) {
      if (mounted) setState(() {});
      return;
    }

    if (resolved.streams.isEmpty) {
      probe
        ..status = ProbeStatus.failed
        ..errorMessage = 'Resolver returned 0 streams';
      _logAudit(
        '[${probe.serverName}] FAILED: 0 streams from resolver '
        '(${probe.resolveDuration!.inMilliseconds}ms)',
      );
      if (mounted) setState(() {});
      return;
    }

    // Mirror _pickStream logic from EnqueueDownloadUseCase:
    // AnimeAV1 → prefer HLS; otherwise prefer non-HLS; fallback to first.
    final sourcePluginId = _selectedSource?.manifest.id;
    final stream = _pickStream(resolved.streams, sourcePluginId);
    probe
      ..resolvedUrl = stream.url.toString()
      ..isHls = stream.isHls
      ..qualityLabel = stream.qualityLabel
      ..resolvedHeaders = stream.headers;

    _logAudit(
      '[${probe.serverName}] resolved in ${probe.resolveDuration!.inMilliseconds}ms '
      '→ ${stream.isHls ? "HLS" : "DIRECT"} '
      '${stream.qualityLabel ?? "unknown"} '
      '${stream.url.host}'
      '${resolved.streams.length > 1 ? " (+${resolved.streams.length - 1} more streams)" : ""}',
    );

    // ── Phase 2: Fetch probe bytes ──
    probe.status = ProbeStatus.fetching;
    if (mounted) setState(() {});

    final fetchStart = DateTime.now();
    try {
      if (stream.isHls) {
        await _probeHls(probe, stream);
      } else {
        await _probeDirect(probe, stream);
      }
    } on TimeoutException {
      probe
        ..status = ProbeStatus.timeout
        ..fetchDuration = DateTime.now().difference(fetchStart)
        ..errorMessage =
            'Fetch timed out after ${_fetchTimeout.inSeconds}s '
            '(got ${probe.bytesDownloaded} bytes)';
      _logAudit(
        '[${probe.serverName}] TIMEOUT: fetch — '
        '${probe.bytesDownloaded} bytes in '
        '${probe.fetchDuration!.inMilliseconds}ms',
      );
    } catch (e) {
      probe
        ..status = ProbeStatus.failed
        ..fetchDuration = DateTime.now().difference(fetchStart)
        ..errorMessage = 'Fetch error: $e';
      _logAudit(
        '[${probe.serverName}] FAILED: fetch — $e '
        '(${probe.fetchDuration?.inMilliseconds ?? 0}ms)',
      );
    }

    if (probe.status == ProbeStatus.fetching) {
      probe
        ..status = ProbeStatus.success
        ..fetchDuration = DateTime.now().difference(fetchStart);
      _logAudit(
        '[${probe.serverName}] OK: ${probe.bytesDownloaded} bytes '
        'in ${probe.fetchDuration!.inMilliseconds}ms '
        '(resolve ${probe.resolveDuration!.inMilliseconds}ms)',
      );
    }

    if (mounted) setState(() {});
  }

  // Mirrors _pickStream from EnqueueDownloadUseCase.
  ResolvedStream _pickStream(
    List<ResolvedStream> streams,
    String? sourcePluginId,
  ) {
    if (sourcePluginId == 'kumoriya.source.animeav1') {
      final hls = streams.where((s) => s.isHls).toList();
      if (hls.isNotEmpty) return hls.first;
    }
    final nonHls = streams.where((s) => !s.isHls).toList();
    if (nonHls.isNotEmpty) return nonHls.first;
    return streams.first;
  }

  Future<void> _probeHls(
    ResolverProbeResult probe,
    ResolvedStream stream,
  ) async {
    // Use the same UA + Accept-Encoding:identity as HlsSegmentDownloader
    // so the fetch exercises the real downloader's HTTP fingerprint.
    final headers = <String, String>{
      ...stream.headers,
      'User-Agent': _downloaderUserAgent,
      'Accept-Encoding': 'identity',
    };

    // NOTE: fetch uses Dart http.Client (Cronet on Android), NOT mpv.
    // The player uses mpv's own HTTP stack. This probes the downloader path.
    final client = _httpClient ?? http.Client();
    final masterReq = http.Request('GET', stream.url)..headers.addAll(headers);
    final masterResp = await client.send(masterReq).timeout(_fetchTimeout);

    probe.httpStatusCode = masterResp.statusCode;
    if (masterResp.statusCode != 200) {
      probe
        ..status = ProbeStatus.failed
        ..errorMessage = 'HLS master returned ${masterResp.statusCode}';
      return;
    }

    final masterBytes = await masterResp.stream.toBytes().timeout(
      _fetchTimeout,
    );
    probe.bytesDownloaded += masterBytes.length;

    var masterText = utf8.decode(masterBytes, allowMalformed: true);
    // Handle gzip
    if (masterBytes.length >= 2 &&
        masterBytes[0] == 0x1f &&
        masterBytes[1] == 0x8b) {
      masterText = utf8.decode(gzip.decode(masterBytes), allowMalformed: true);
    }

    _logAudit(
      '[${probe.serverName}] HLS master fetched: '
      '${masterBytes.length} bytes, '
      '${masterText.split('\n').length} lines',
    );

    final lines = masterText.split('\n');

    // Distinguish master playlist (has #EXT-X-STREAM-INF) from media
    // playlist (has #EXTINF or #EXT-X-TARGETDURATION). This mirrors
    // HlsSegmentDownloader._parseVariants which only returns entries
    // preceded by #EXT-X-STREAM-INF.
    final isMaster = lines.any(
      (l) => l.trimLeft().startsWith('#EXT-X-STREAM-INF'),
    );

    String mediaText;
    Uri mediaBaseUrl;

    if (isMaster) {
      // Find the highest-bandwidth variant URL.
      String? variantUrl;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
          variantUrl = trimmed;
          // Don't break — take the last variant (typically highest BW
          // since playlists list lowest first).
        }
      }
      if (variantUrl == null) {
        probe
          ..status = ProbeStatus.failed
          ..errorMessage = 'Master playlist has no variant URLs';
        return;
      }

      final variantUri = Uri.parse(
        stream.url.resolve(variantUrl).toString(),
      );
      _logAudit('[${probe.serverName}] fetching variant: $variantUri');

      final mediaReq = http.Request('GET', variantUri)
        ..headers.addAll(headers);
      final mediaResp = await client.send(mediaReq).timeout(_fetchTimeout);

      if (mediaResp.statusCode != 200) {
        probe
          ..status = ProbeStatus.failed
          ..errorMessage = 'HLS variant returned ${mediaResp.statusCode}';
        return;
      }

      final mediaBytes = await mediaResp.stream
          .toBytes()
          .timeout(_fetchTimeout);
      probe.bytesDownloaded += mediaBytes.length;

      mediaText = utf8.decode(mediaBytes, allowMalformed: true);
      if (mediaBytes.length >= 2 &&
          mediaBytes[0] == 0x1f &&
          mediaBytes[1] == 0x8b) {
        mediaText = utf8.decode(
          gzip.decode(mediaBytes),
          allowMalformed: true,
        );
      }
      mediaBaseUrl = variantUri;

      _logAudit(
        '[${probe.serverName}] HLS media fetched: '
        '${mediaBytes.length} bytes, '
        '${mediaText.split('\n').length} lines',
      );
    } else {
      // Already a media playlist (Zilla, single-variant sources, etc.)
      mediaText = masterText;
      mediaBaseUrl = stream.url;
      _logAudit('[${probe.serverName}] HLS is a direct media playlist');
    }

    // ── Fetch init segment (EXT-X-MAP) and first real segment ──
    final mediaLines = mediaText.split('\n');

    for (final line in mediaLines) {
      final mapMatch = RegExp(r'URI="([^"]+)"').firstMatch(line);
      if (mapMatch != null) {
        final initUri = Uri.parse(
          mediaBaseUrl.resolve(mapMatch.group(1)!).toString(),
        );
        await _fetchProbeBytes(probe, initUri, headers, client);
        break;
      }
    }

    for (final line in mediaLines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
        final segUri = Uri.parse(
          mediaBaseUrl.resolve(trimmed).toString(),
        );
        await _fetchProbeBytes(probe, segUri, headers, client);
        break;
      }
    }
  }

  Future<void> _probeDirect(
    ResolverProbeResult probe,
    ResolvedStream stream,
  ) async {
    // Matches HlsSegmentDownloader direct fetch headers.
    final headers = <String, String>{
      ...stream.headers,
      'User-Agent': _downloaderUserAgent,
      'Accept-Encoding': 'identity',
      // Request only first ~512KB via Range to keep probe lightweight
      'Range': 'bytes=0-${_probeFetchBytes - 1}',
    };

    final client = _httpClient ?? http.Client();
    await _fetchProbeBytes(probe, stream.url, headers, client);
  }

  Future<void> _fetchProbeBytes(
    ResolverProbeResult probe,
    Uri url,
    Map<String, String> headers,
    http.Client client,
  ) async {
    final req = http.Request('GET', url)..headers.addAll(headers);
    final resp = await client.send(req).timeout(_fetchTimeout);

    probe.httpStatusCode ??= resp.statusCode;
    if (resp.statusCode != 200 && resp.statusCode != 206) {
      final shortPath = url.path.length > 40
          ? url.path.substring(0, 40)
          : url.path;
      probe
        ..status = ProbeStatus.failed
        ..errorMessage = 'HTTP ${resp.statusCode} on ${url.host}$shortPath';
      return;
    }

    // Read up to _probeFetchBytes
    var total = 0;
    await for (final chunk in resp.stream.timeout(_fetchTimeout)) {
      total += chunk.length;
      probe.bytesDownloaded += chunk.length;
      if (total >= _probeFetchBytes) break;
    }
  }

  // ── Audit logging ─────────────────────────────────────────────────────

  void _logAudit(String message) {
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    final line = '[$ts] $message';
    debugPrint('[resolver.playground] $line');
  }

  Future<String?> _saveAuditLog() async {
    if (_auditSessions.isEmpty) {
      _showSnack('No sessions to export');
      return null;
    }

    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .substring(0, 19);
    final file = File('${dir.path}/resolver_audit_$ts.json');

    final payload = {
      'audit_version': 1,
      'platform': Platform.operatingSystem,
      'timestamp': DateTime.now().toIso8601String(),
      'anime_title': _selectedAnime?.title,
      'source_plugin': _selectedSource?.manifest.id,
      'sessions': _auditSessions.map((s) => s.toAuditJson()).toList(),
    };

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );

    _lastSavedLogPath = file.path;

    _logAudit('AUDIT LOG SAVED → ${file.path}');

    return file.path;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      appBar: AppBar(
        title: const Text('Resolver Playground'),
        actions: [
          if (_auditSessions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save_alt_rounded),
              tooltip: 'Export audit log',
              onPressed: () async {
                final path = await _saveAuditLog();
                if (path != null && mounted) {
                  _showSnack('Saved: $path');
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: KumoriyaColors.surface,
      child: Column(
        children: [
          // Source selector
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _sourcePlugins.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final plugin = _sourcePlugins[index];
                final selected = plugin == _selectedSource;
                return ChoiceChip(
                  label: Text(plugin.manifest.displayName),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedSource = plugin;
                      _searchResults = [];
                      _episodes = [];
                      _selectedAnime = null;
                    });
                  },
                  selectedColor: KumoriyaColors.primary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : KumoriyaColors.textMuted,
                    fontSize: 12,
                  ),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Search field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search anime…',
                    hintStyle: const TextStyle(color: KumoriyaColors.textMuted),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: KumoriyaColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _searching ? null : _search,
                icon: _searching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: KumoriyaColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // Probing view
    if (_currentSession != null) {
      return _buildProbeView();
    }

    // Episode list
    if (_episodes.isNotEmpty) {
      return _buildEpisodeList();
    }

    // Search results
    if (_searchResults.isNotEmpty) {
      return _buildSearchResults();
    }

    // Loading states
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadingEpisodes) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Text(
        'Search for an anime to begin probing',
        style: TextStyle(color: KumoriyaColors.textMuted),
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final anime = _searchResults[index];
        return Card(
          color: KumoriyaColors.surface,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(
              anime.title,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${anime.format} ${anime.releaseYear ?? ""} '
              '• ${anime.totalEpisodes ?? "?"} eps',
              style: const TextStyle(
                color: KumoriyaColors.textMuted,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: KumoriyaColors.textMuted,
            ),
            onTap: () => _loadEpisodes(anime),
          ),
        );
      },
    );
  }

  Widget _buildEpisodeList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedAnime?.title ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _episodes = [];
                    _selectedAnime = null;
                  });
                },
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back'),
                style: TextButton.styleFrom(
                  foregroundColor: KumoriyaColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _episodes.length,
            itemBuilder: (context, index) {
              final ep = _episodes[index];
              return Card(
                color: KumoriyaColors.surface,
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  dense: true,
                  title: Text(
                    'EP ${ep.number % 1 == 0 ? ep.number.toInt() : ep.number}${ep.title.isNotEmpty ? " — ${ep.title}" : ""}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: _probing ? null : () => _probeEpisode(ep),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Probe', style: TextStyle(fontSize: 12)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProbeView() {
    final session = _currentSession;
    if (session == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with anime + episode info
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedAnime?.title ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'EP ${session.episodeNumber} — ${session.episodeTitle}',
                      style: const TextStyle(
                        color: KumoriyaColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_probing)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.save_alt_rounded, size: 20),
                      color: KumoriyaColors.accentSky,
                      tooltip: 'Save log',
                      onPressed: () async {
                        final path = await _saveAuditLog();
                        if (path != null && mounted) {
                          _showSnack('Saved: $path');
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20),
                      color: KumoriyaColors.textMuted,
                      tooltip: 'Back to episodes',
                      onPressed: () {
                        setState(() {
                          _currentSession = null;
                        });
                      },
                    ),
                  ],
                ),
              if (_probing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),

        // Summary bar
        _buildSummaryBar(session),

        // Probe cards
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: session.probes.length,
            itemBuilder: (context, index) {
              return _ProbeCard(probe: session.probes[index]);
            },
          ),
        ),

        // Log path hint
        if (_lastSavedLogPath != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: GestureDetector(
              onTap: () {
                if (_lastSavedLogPath != null) {
                  Clipboard.setData(ClipboardData(text: _lastSavedLogPath!));
                  _showSnack('Path copied');
                }
              },
              child: Text(
                'Last saved: $_lastSavedLogPath (tap to copy)',
                style: const TextStyle(
                  color: KumoriyaColors.textMuted,
                  fontSize: 10,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryBar(EpisodeProbeSession session) {
    final ok = session.probes
        .where((p) => p.status == ProbeStatus.success)
        .length;
    final fail = session.probes
        .where((p) => p.status == ProbeStatus.failed)
        .length;
    final tout = session.probes
        .where((p) => p.status == ProbeStatus.timeout)
        .length;
    final active = session.probes
        .where(
          (p) =>
              p.status == ProbeStatus.resolving ||
              p.status == ProbeStatus.fetching,
        )
        .length;
    final total = session.probes.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: KumoriyaColors.surface,
      child: Row(
        children: [
          _SummaryChip(label: '$ok OK', color: KumoriyaColors.statusSuccess),
          const SizedBox(width: 8),
          _SummaryChip(label: '$fail FAIL', color: KumoriyaColors.statusDanger),
          const SizedBox(width: 8),
          _SummaryChip(
            label: '$tout TMOUT',
            color: KumoriyaColors.statusWarning,
          ),
          const SizedBox(width: 8),
          if (active > 0) ...[
            _SummaryChip(
              label: '$active ACTIVE',
              color: KumoriyaColors.accentSky,
            ),
            const SizedBox(width: 8),
          ],
          const Spacer(),
          Text(
            '$total total',
            style: const TextStyle(
              color: KumoriyaColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Probe card widget ──────────────────────────────────────────────────────

class _ProbeCard extends StatelessWidget {
  const _ProbeCard({required this.probe});

  final ResolverProbeResult probe;

  Color get _statusColor => switch (probe.status) {
    ProbeStatus.success => KumoriyaColors.statusSuccess,
    ProbeStatus.failed => KumoriyaColors.statusDanger,
    ProbeStatus.timeout => KumoriyaColors.statusWarning,
    ProbeStatus.resolving || ProbeStatus.fetching => KumoriyaColors.accentSky,
    ProbeStatus.waiting => KumoriyaColors.textMuted,
  };

  IconData get _statusIcon => switch (probe.status) {
    ProbeStatus.success => Icons.check_circle_rounded,
    ProbeStatus.failed => Icons.cancel_rounded,
    ProbeStatus.timeout => Icons.timer_off_rounded,
    ProbeStatus.resolving ||
    ProbeStatus.fetching => Icons.hourglass_top_rounded,
    ProbeStatus.waiting => Icons.pending_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      color: KumoriyaColors.surface,
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: server name + status
            Row(
              children: [
                Icon(_statusIcon, color: _statusColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    probe.serverName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    probe.statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Row 2: resolver + host
            _DetailRow(label: 'Resolver', value: probe.resolverName),
            _DetailRow(label: 'Host', value: probe.detectedHost),
            if (probe.isHls != null)
              _DetailRow(label: 'Type', value: probe.isHls! ? 'HLS' : 'Direct'),
            if (probe.qualityLabel != null)
              _DetailRow(label: 'Quality', value: probe.qualityLabel!),
            if (probe.resolveDuration != null)
              _DetailRow(
                label: 'Resolve',
                value: '${probe.resolveDuration!.inMilliseconds}ms',
              ),
            if (probe.fetchDuration != null)
              _DetailRow(
                label: 'Fetch',
                value: '${probe.fetchDuration!.inMilliseconds}ms',
              ),
            if (probe.bytesDownloaded > 0)
              _DetailRow(
                label: 'Bytes',
                value: _formatBytes(probe.bytesDownloaded),
              ),
            if (probe.httpStatusCode != null)
              _DetailRow(label: 'HTTP', value: '${probe.httpStatusCode}'),
            if (probe.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  probe.errorMessage!,
                  style: TextStyle(
                    color: KumoriyaColors.statusDanger.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                color: KumoriyaColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: KumoriyaColors.textSecondary,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
