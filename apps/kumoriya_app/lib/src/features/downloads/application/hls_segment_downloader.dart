import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:path/path.dart' as p;

import 'download_debug_logger.dart';
import 'hls_download_engine.dart';

typedef HlsRequestSender =
    Future<http.StreamedResponse> Function(
      http.BaseRequest request, {
      required Duration timeout,
    });

/// Browser-like User-Agent to avoid Cloudflare bot-detection 403 blocks.
const _browserUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

final _bandwidthRe = RegExp(r'BANDWIDTH=(\d+)');
final _mapUriRe = RegExp(r'URI="([^"]+)"');
final _targetDurationRe = RegExp(r'#EXT-X-TARGETDURATION:(\d+)');

/// Orchestrates HLS downloads with per-segment persistence and Isolate-based
/// I/O for zero UI jank.
///
/// ## Architecture
/// 1. **Playlist parsing** runs on the main isolate (fast for typical playlists).
/// 2. **Segment state** is persisted to [HlsSegmentStore] — enables
///    pause/resume at individual segment granularity.
/// 3. **HTTP downloads + file writes** run in a separate Isolate via
///    [HlsDownloadEngine] — the main thread only receives progress messages.
/// 4. **Concatenation** of completed segment files into the final output
///    runs via [Isolate.run] to avoid blocking the UI thread.
///
/// ## Connection reuse
/// A single [http.Client] lives inside the worker isolate for the entire
/// download session, reusing TCP connections across all segment fetches
/// (IDM-style connection pooling with minimal TCP handshake overhead).
///
/// ## Controlled concurrency
/// The engine maintains a pool of N concurrent segment fetches (configurable
/// via [parallelSegments]). When any fetch completes, the next pending
/// segment starts immediately — keeping the pool saturated at all times.
///
/// ## Resumability
/// On resume, completed segments are loaded from the DB, verified on disk,
/// and skipped. Only pending/failed segments are re-downloaded. Segment files
/// are stored individually so partial downloads don't corrupt completed work.
class HlsSegmentDownloader {
  HlsSegmentDownloader({
    http.Client? httpClient,
    HlsRequestSender? sendRequest,
    this.parallelSegments = 32,
    this.maxRetries = 3,
    this.playlistRequestTimeout = const Duration(seconds: 15),
    this.playlistBodyTimeout = const Duration(seconds: 15),
    this.segmentRequestTimeout = const Duration(seconds: 30),
    this.segmentBodyTimeout = const Duration(seconds: 30),
    HlsSegmentStore? segmentStore,
  }) : _httpClient = httpClient ?? http.Client(),
       _usesInjectedTransport = sendRequest != null {
    _sendRequest =
        sendRequest ??
        (http.BaseRequest request, {required Duration timeout}) =>
            _httpClient.send(request).timeout(timeout);
    _segmentStore = segmentStore;
  }

  final http.Client _httpClient;
  final bool _usesInjectedTransport;
  late final HlsRequestSender _sendRequest;
  HlsSegmentStore? _segmentStore;
  HlsDownloadEngine? _engine;

  /// Number of segments to download in parallel (pool size).
  final int parallelSegments;
  final int maxRetries;
  final Duration playlistRequestTimeout;
  final Duration playlistBodyTimeout;
  final Duration segmentRequestTimeout;
  final Duration segmentBodyTimeout;

  /// Downloads the HLS stream at [masterUrl] to [outputPath].
  ///
  /// [taskId] — parent DownloadTask.id, used as FK for segment persistence.
  /// [headers] are applied to every HTTP request (referer, origin, etc.).
  /// [onProgress] is called after each segment with (downloadedBytes,
  ///   downloadedSegments, totalSegments, estimatedTotalBytes).
  /// [cancelCompleter] — complete to request cancellation.
  ///
  /// Returns an [HlsDownloadResult] describing stream format and byte count.
  Future<HlsDownloadResult> download({
    required Uri masterUrl,
    required String outputPath,
    String? taskId,
    Map<String, String> headers = const <String, String>{},
    void Function(
      int downloadedBytes,
      int downloadedSegments,
      int totalSegments,
      int totalBytes,
    )?
    onProgress,
    Completer<void>? cancelCompleter,
  }) async {
    _log('Starting HLS download: $masterUrl');
    await dlLog.log('HLS', 'fetchPlaylist master=$masterUrl headers=$headers');

    // ── 1. Fetch and parse the m3u8 playlist ───────────────────────────
    final masterContent = await _fetchPlaylistWithRetry(masterUrl, headers);
    final variants = _parseVariants(masterContent, masterUrl);
    await dlLog.log(
      'HLS',
      _summarizePlaylistForLog(
        label: 'master playlist',
        content: masterContent,
        variantCount: variants.length,
      ),
    );
    await dlLog.log('HLS', 'parsed ${variants.length} variants: $variants');

    if (variants.isEmpty) {
      return _downloadResolvedPlaylist(
        mediaContent: masterContent,
        mediaBaseUrl: masterUrl,
        outputPath: outputPath,
        taskId: taskId,
        headers: headers,
        onProgress: onProgress,
        cancelCompleter: cancelCompleter,
      );
    }

    Object? lastError;
    for (final variant in variants) {
      if (cancelCompleter?.isCompleted == true) {
        throw const HttpException('HLS download cancelled');
      }
      try {
        _log('Trying variant: $variant');
        await dlLog.log('HLS', 'fetching variant: $variant');
        final mediaContent = await _fetchPlaylistWithRetry(variant, headers);
        await dlLog.log(
          'HLS',
          _summarizePlaylistForLog(
            label: 'media playlist',
            content: mediaContent,
            segmentCount: _countPlaylistSegments(mediaContent),
          ),
        );
        return await _downloadResolvedPlaylist(
          mediaContent: mediaContent,
          mediaBaseUrl: variant,
          outputPath: outputPath,
          taskId: taskId,
          headers: headers,
          onProgress: onProgress,
          cancelCompleter: cancelCompleter,
        );
      } catch (e, stack) {
        if (cancelCompleter?.isCompleted == true) {
          throw const HttpException('HLS download cancelled');
        }
        lastError = e;
        _log('Variant failed: $variant error=$e');
        await dlLog.error('HLS', 'variant FAILED: $variant', e, stack);
        if (_shouldAbortRemainingVariantsAfterFailure(variant, e)) {
          rethrow;
        }
      }
    }

    throw HttpException('All HLS variants failed: $lastError');
  }

  Future<HlsDownloadResult> _downloadResolvedPlaylist({
    required String mediaContent,
    required Uri mediaBaseUrl,
    required String outputPath,
    required String? taskId,
    required Map<String, String> headers,
    required void Function(
      int downloadedBytes,
      int downloadedSegments,
      int totalSegments,
      int totalBytes,
    )?
    onProgress,
    required Completer<void>? cancelCompleter,
  }) async {
    // ── 2. Parse segments and init segment ─────────────────────────────
    final initUri = _parseMapUri(mediaContent, mediaBaseUrl);
    final isFmp4 = initUri != null;
    final segmentUrls = _parseSegments(mediaContent, mediaBaseUrl);
    if (segmentUrls.isEmpty) {
      throw const HttpException('No segments found in HLS playlist');
    }
    _log('Parsed ${segmentUrls.length} segments (fMP4=$isFmp4)');

    // ── 3. Prepare segment directory and per-segment state ─────────────
    final segmentsDir = '${outputPath}_segments';
    await Directory(segmentsDir).create(recursive: true);

    final initSegmentPath = isFmp4 ? p.join(segmentsDir, '_init.mp4') : null;

    // Build segment descriptors — resume-aware: completed segments get
    // skip=true so the worker isolate does not re-download them.
    final segmentInfos = <HlsSegmentInfo>[];
    List<HlsSegment>? persisted;

    if (taskId != null && _segmentStore != null) {
      final result = await _segmentStore!.getSegmentsForTask(taskId);
      persisted = result.fold(
        onSuccess: (segs) => segs.isNotEmpty ? segs : null,
        onFailure: (_) => null,
      );
    }

    if (persisted != null && persisted.length == segmentUrls.length) {
      // ── Resume path ──
      final completed = persisted
          .where((s) => s.status == HlsSegmentStatus.completed)
          .length;
      _log('Resuming: $completed/${persisted.length} segments completed');

      for (final seg in persisted) {
        final isCompleted =
            seg.status == HlsSegmentStatus.completed &&
            seg.localPath != null &&
            File(seg.localPath!).existsSync();
        segmentInfos.add(
          HlsDownloadEngine.createSegmentInfo(
            index: seg.segmentIndex,
            url: seg.url,
            localPath:
                seg.localPath ??
                p.join(
                  segmentsDir,
                  'seg_${seg.segmentIndex.toString().padLeft(5, '0')}.ts',
                ),
            skip: isCompleted,
          ),
        );
      }
    } else {
      // ── Fresh download path ──
      final newSegments = <HlsSegment>[];
      for (var i = 0; i < segmentUrls.length; i++) {
        final localPath = p.join(
          segmentsDir,
          'seg_${i.toString().padLeft(5, '0')}.ts',
        );
        final segId = taskId != null ? '$taskId:seg:$i' : 'anon:seg:$i';
        newSegments.add(
          HlsSegment(
            id: segId,
            downloadTaskId: taskId ?? '',
            segmentIndex: i,
            url: segmentUrls[i].toString(),
            status: HlsSegmentStatus.pending,
            localPath: localPath,
          ),
        );
        segmentInfos.add(
          HlsDownloadEngine.createSegmentInfo(
            index: i,
            url: segmentUrls[i].toString(),
            localPath: localPath,
          ),
        );
      }

      // Persist segment manifest to DB.
      if (taskId != null && _segmentStore != null) {
        await _segmentStore!.deleteSegmentsForTask(taskId);
        await _segmentStore!.insertSegments(newSegments);
        _log('Persisted ${newSegments.length} segment records');
      }
    }

    var exactTotalBytes = 0;
    final exactTotalBytesFuture =
        _probeExactTotalBytes(
              headers: headers,
              initUri: initUri,
              segmentUrls: segmentUrls,
            )
            .then((value) {
              exactTotalBytes = value;
            })
            .catchError((_) {
              // Best-effort only. Download startup must not wait on size probing.
            });

    if (_usesInjectedTransport) {
      return _downloadWithInjectedTransport(
        segmentInfos: segmentInfos,
        segmentUrls: segmentUrls,
        segmentsDir: segmentsDir,
        outputPath: outputPath,
        taskId: taskId,
        headers: headers,
        initUri: initUri,
        initSegmentPath: initSegmentPath,
        exactTotalBytes: exactTotalBytes,
        onProgress: onProgress,
        cancelCompleter: cancelCompleter,
      );
    }

    // ── 4. Launch the Isolate-based download engine ────────────────────
    final resultCompleter = Completer<HlsDownloadResult>();

    _engine = HlsDownloadEngine(
      maxConcurrent: parallelSegments,
      maxRetries: maxRetries,
    );

    // Forward cancel requests to the engine.
    cancelCompleter?.future.then((_) => _engine?.pause());

    await _engine!.start(
      segments: segmentInfos,
      headers: headers,
      segmentsDir: segmentsDir,
      initSegmentUrl: initUri?.toString(),
      initSegmentPath: initSegmentPath,

      onProgress: (progress) {
        onProgress?.call(
          progress.downloadedBytes,
          progress.completedSegments,
          progress.totalSegments,
          exactTotalBytes > 0 ? exactTotalBytes : progress.estimatedTotalBytes,
        );
      },

      onSegmentDone: (done) {
        // Persist segment completion (non-blocking, fire-and-forget).
        if (taskId != null && _segmentStore != null) {
          unawaited(
            _segmentStore!.updateSegment(
              HlsSegment(
                id: '$taskId:seg:${done.segmentIndex}',
                downloadTaskId: taskId,
                segmentIndex: done.segmentIndex,
                url: segmentInfos[done.segmentIndex].url,
                status: HlsSegmentStatus.completed,
                localPath: done.localPath,
                byteSize: done.byteSize,
              ),
            ),
          );
        }
      },

      onSegmentFailed: (failed) {
        if (taskId != null && _segmentStore != null) {
          unawaited(
            _segmentStore!.updateSegment(
              HlsSegment(
                id: '$taskId:seg:${failed.segmentIndex}',
                downloadTaskId: taskId,
                segmentIndex: failed.segmentIndex,
                url: segmentInfos[failed.segmentIndex].url,
                status: HlsSegmentStatus.failed,
              ),
            ),
          );
        }
      },

      onDone: (result) async {
        if (result.failedCount > 0) {
          resultCompleter.completeError(
            HttpException(
              '${result.failedCount} HLS segments failed to download',
            ),
          );
          return;
        }

        // ── 5. Concatenate segments → final file (in isolate) ────────
        try {
          final totalBytes = await _concatenateSegments(
            segmentsDir: segmentsDir,
            outputPath: outputPath,
            totalSegments: segmentUrls.length,
            initSegmentPath: initSegmentPath,
          );

          // Clean up segment files + DB records.
          await _cleanupSegmentDir(segmentsDir);
          if (taskId != null && _segmentStore != null) {
            await _segmentStore!.deleteSegmentsForTask(taskId);
          }

          resultCompleter.complete(
            HlsDownloadResult(isFmp4: isFmp4, totalBytes: totalBytes),
          );
        } catch (e) {
          resultCompleter.completeError(e);
        }
      },

      onError: (error) {
        resultCompleter.completeError(HttpException(error.message));
      },

      onStopped: () {
        if (cancelCompleter?.isCompleted == true) {
          resultCompleter.completeError(
            const HttpException('HLS download cancelled'),
          );
        } else {
          resultCompleter.completeError(
            const HttpException('HLS download paused'),
          );
        }
      },
    );

    unawaited(exactTotalBytesFuture);

    return resultCompleter.future;
  }

  Future<HlsDownloadResult> _downloadWithInjectedTransport({
    required List<HlsSegmentInfo> segmentInfos,
    required List<Uri> segmentUrls,
    required String segmentsDir,
    required String outputPath,
    required String? taskId,
    required Map<String, String> headers,
    required Uri? initUri,
    required String? initSegmentPath,
    required int exactTotalBytes,
    required void Function(
      int downloadedBytes,
      int downloadedSegments,
      int totalSegments,
      int totalBytes,
    )?
    onProgress,
    required Completer<void>? cancelCompleter,
  }) async {
    var downloadedBytes = 0;
    var completedSegments = 0;

    if (initUri != null && initSegmentPath != null) {
      final initBytes = await _fetchBinaryWithRetry(initUri, headers);
      await File(initSegmentPath).writeAsBytes(initBytes, flush: true);
      downloadedBytes += initBytes.length;
    }

    for (final segment in segmentInfos) {
      if (cancelCompleter?.isCompleted == true) {
        throw const HttpException('HLS download cancelled');
      }

      if (segment.skip) {
        final existingFile = File(segment.localPath);
        if (await existingFile.exists()) {
          downloadedBytes += await existingFile.length();
        }
        completedSegments++;
      } else {
        final bytes = await _fetchBinaryWithRetry(
          Uri.parse(segment.url),
          headers,
        );
        await File(segment.localPath).writeAsBytes(bytes, flush: true);
        downloadedBytes += bytes.length;
        completedSegments++;

        if (taskId != null && _segmentStore != null) {
          await _segmentStore!.updateSegment(
            HlsSegment(
              id: '$taskId:seg:${segment.index}',
              downloadTaskId: taskId,
              segmentIndex: segment.index,
              url: segment.url,
              status: HlsSegmentStatus.completed,
              localPath: segment.localPath,
              byteSize: bytes.length,
            ),
          );
        }
      }

      onProgress?.call(
        downloadedBytes,
        completedSegments,
        segmentInfos.length,
        exactTotalBytes > 0 ? exactTotalBytes : downloadedBytes,
      );
    }

    final totalBytes = await _concatenateSegments(
      segmentsDir: segmentsDir,
      outputPath: outputPath,
      totalSegments: segmentUrls.length,
      initSegmentPath: initSegmentPath,
    );

    await _cleanupSegmentDir(segmentsDir);
    if (taskId != null && _segmentStore != null) {
      await _segmentStore!.deleteSegmentsForTask(taskId);
    }

    return HlsDownloadResult(
      isFmp4: initSegmentPath != null,
      totalBytes: totalBytes,
    );
  }

  Future<int> _probeExactTotalBytes({
    required Map<String, String> headers,
    required Uri? initUri,
    required List<Uri> segmentUrls,
  }) async {
    final targets = <Uri>[...segmentUrls];
    if (initUri != null) {
      targets.insert(0, initUri);
    }
    if (targets.isEmpty) {
      return 0;
    }

    const maxParallelProbes = 4;
    var nextIndex = 0;
    var totalBytes = 0;

    Future<void> probeOne(Uri url) async {
      final bytes = await _probeContentLength(url, headers);
      if (bytes > 0) {
        totalBytes += bytes;
      }
    }

    Future<void> worker() async {
      while (true) {
        final currentIndex = nextIndex;
        if (currentIndex >= targets.length) {
          return;
        }
        nextIndex++;
        try {
          await probeOne(targets[currentIndex]);
        } catch (_) {
          // Best-effort only. If a server hides length metadata, fall back
          // to runtime estimation from completed segments.
        }
      }
    }

    final workerCount = targets.length < maxParallelProbes
        ? targets.length
        : maxParallelProbes;
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return totalBytes;
  }

  Future<int> _probeContentLength(Uri url, Map<String, String> headers) async {
    final headRequest = http.Request('HEAD', url)
      ..headers.addAll(headers)
      ..headers.putIfAbsent('User-Agent', () => _browserUserAgent)
      ..headers.putIfAbsent('Accept-Encoding', () => 'identity');
    try {
      final response = await _sendRequest(
        headRequest,
        timeout: const Duration(seconds: 5),
      );
      final contentLength = _extractResponseLength(response);
      await response.stream.drain<void>();
      if (contentLength > 0) {
        return contentLength;
      }
    } catch (_) {
      // Fall back to a tiny range request below.
    }

    final rangeRequest = http.Request('GET', url)
      ..headers.addAll(headers)
      ..headers.putIfAbsent('User-Agent', () => _browserUserAgent)
      ..headers.putIfAbsent('Accept-Encoding', () => 'identity')
      ..headers['Range'] = 'bytes=0-0';
    final response = await _sendRequest(
      rangeRequest,
      timeout: const Duration(seconds: 5),
    );
    final contentLength = _extractResponseLength(response);
    await response.stream.drain<void>();
    return contentLength;
  }

  int _extractResponseLength(http.StreamedResponse response) {
    final contentRange = response.headers['content-range'];
    if (contentRange != null) {
      final slash = contentRange.lastIndexOf('/');
      if (slash >= 0 && slash + 1 < contentRange.length) {
        final total = int.tryParse(contentRange.substring(slash + 1));
        if (total != null && total > 0) {
          return total;
        }
      }
    }
    final headerLength = int.tryParse(response.headers['content-length'] ?? '');
    if (headerLength != null && headerLength > 0) {
      return headerLength;
    }
    return response.contentLength ?? 0;
  }

  // ─── Concatenation (runs in separate isolate) ───────────────────────

  /// Concatenates individual segment files into the final output file.
  /// Runs via [Isolate.run] so file I/O doesn't block the main thread.
  Future<int> _concatenateSegments({
    required String segmentsDir,
    required String outputPath,
    required int totalSegments,
    String? initSegmentPath,
  }) async {
    return Isolate.run(() async {
      final sink = File(outputPath).openWrite();
      var totalBytes = 0;

      try {
        // fMP4 init segment (moov box) must come first.
        if (initSegmentPath != null) {
          final initFile = File(initSegmentPath);
          if (initFile.existsSync()) {
            final stream = initFile.openRead();
            await for (final chunk in stream) {
              sink.add(chunk);
              totalBytes += chunk.length;
            }
          }
        }

        // Segments in index order — correct for playback.
        for (var i = 0; i < totalSegments; i++) {
          final segPath =
              '$segmentsDir${Platform.pathSeparator}'
              'seg_${i.toString().padLeft(5, '0')}.ts';
          final segFile = File(segPath);
          if (segFile.existsSync()) {
            final stream = segFile.openRead();
            await for (final chunk in stream) {
              sink.add(chunk);
              totalBytes += chunk.length;
            }
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      return totalBytes;
    });
  }

  Future<void> _cleanupSegmentDir(String segmentsDir) async {
    try {
      final dir = Directory(segmentsDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      _log('Warning: failed to clean up segments dir: $e');
    }
  }

  // ─── Playlist fetching (runs on main isolate) ────────────────────────

  /// Fetches a playlist text file with a connection timeout.
  Future<String> _fetchPlaylist(Uri url, Map<String, String> headers) async {
    final request = http.Request('GET', url)
      ..persistentConnection = !_shouldDisableHlsConnectionReuse(url)
      ..headers.addAll(headers)
      ..headers.putIfAbsent('User-Agent', () => _browserUserAgent)
      ..headers.putIfAbsent('Accept-Encoding', () => 'identity');
    if (!request.persistentConnection) {
      request.headers['Connection'] = 'close';
    }
    final response = await _sendRequest(
      request,
      timeout: playlistRequestTimeout,
    );
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} fetching HLS playlist');
    }
    await dlLog.log(
      'HLS',
      'playlist response status=${response.statusCode} url=$url',
    );
    List<int> bytes;
    final bodyTimeout = _effectivePlaylistBodyTimeout(url);
    try {
      bytes = await response.stream.toBytes().timeout(bodyTimeout);
    } on TimeoutException {
      throw TimeoutException(
        'Timed out reading HLS playlist body from $url',
        bodyTimeout,
      );
    }
    await dlLog.dumpBytes('HLS', 'playlist raw bytes from $url', bytes);

    // StreamWish CDN (and others) may return gzip-compressed m3u8 even when
    // the client didn't ask for it. Detect via the gzip magic number and
    // decompress before decoding to text.
    if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      await dlLog.log(
        'HLS',
        'detected gzip-compressed playlist, decompressing',
      );
      bytes = gzip.decode(bytes);
    }

    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<String> _fetchPlaylistWithRetry(
    Uri url,
    Map<String, String> headers,
  ) async {
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await _fetchPlaylist(url, headers);
      } catch (error) {
        if (_shouldFailFastPlaylistError(error)) {
          rethrow;
        }
        if (attempt == maxRetries) rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
    }
    // Unreachable when maxRetries >= 1, but satisfies the type system.
    throw const HttpException('Playlist fetch failed');
  }

  Future<List<int>> _fetchBinary(Uri url, Map<String, String> headers) async {
    final request = http.Request('GET', url)
      ..persistentConnection = !_shouldDisableHlsConnectionReuse(url)
      ..headers.addAll(headers)
      ..headers.putIfAbsent('User-Agent', () => _browserUserAgent)
      ..headers.putIfAbsent('Accept-Encoding', () => 'identity');
    if (!request.persistentConnection) {
      request.headers['Connection'] = 'close';
    }
    final response = await _sendRequest(
      request,
      timeout: segmentRequestTimeout,
    );
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} fetching HLS segment');
    }
    try {
      return await response.stream.toBytes().timeout(segmentBodyTimeout);
    } on TimeoutException {
      throw TimeoutException(
        'Timed out reading HLS segment body from $url',
        segmentBodyTimeout,
      );
    }
  }

  Future<List<int>> _fetchBinaryWithRetry(
    Uri url,
    Map<String, String> headers,
  ) async {
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await _fetchBinary(url, headers);
      } catch (error) {
        if (_shouldFailFastSegmentError(error)) {
          rethrow;
        }
        if (attempt == maxRetries) rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
    }
    throw const HttpException('Segment fetch failed');
  }

  // ─── Playlist parsing ───────────────────────────────────────────────
  List<Uri> _parseVariants(String content, Uri baseUrl) {
    if (!content.contains('#EXT-X-STREAM-INF')) {
      return const <Uri>[];
    }

    final lines = content.split('\n');
    final variants = <_HlsVariantCandidate>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF')) continue;

      // Parse bandwidth.
      final bwMatch = _bandwidthRe.firstMatch(line);
      final bw = bwMatch != null ? int.tryParse(bwMatch.group(1)!) : null;

      // Next non-empty, non-comment line is the URI.
      for (var j = i + 1; j < lines.length; j++) {
        final uriLine = lines[j].trim();
        if (uriLine.isEmpty || uriLine.startsWith('#')) continue;
        variants.add(
          _HlsVariantCandidate(
            url: _resolveUrl(uriLine, baseUrl),
            bandwidth: bw ?? 0,
          ),
        );
        break;
      }
    }

    variants.sort((a, b) => b.bandwidth.compareTo(a.bandwidth));
    final seen = <String>{};
    return variants
        .where((candidate) => seen.add(candidate.url.toString()))
        .map((candidate) => candidate.url)
        .toList(growable: false);
  }

  /// Parses the `#EXT-X-MAP:URI="..."` init segment URL, if present.
  /// fMP4 HLS streams require this initialization segment (contains moov box).
  Uri? _parseMapUri(String content, Uri baseUrl) {
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('#EXT-X-MAP')) continue;
      final match = _mapUriRe.firstMatch(trimmed);
      if (match != null) return _resolveUrl(match.group(1)!, baseUrl);
    }
    return null;
  }

  /// Parses segment URLs from a media playlist.
  List<Uri> _parseSegments(String content, Uri baseUrl) {
    final lines = content.split('\n');
    final segments = <Uri>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      segments.add(_resolveUrl(trimmed, baseUrl));
    }

    return segments;
  }

  /// Resolves a possibly-relative URL against a base URL.
  Uri _resolveUrl(String url, Uri baseUrl) {
    try {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return Uri.parse(url);
      }
      return baseUrl.resolve(url);
    } catch (e, stack) {
      dlLog.error(
        'HLS',
        'Uri.parse FAILED for line="$url" base=$baseUrl',
        e,
        stack,
      );
      rethrow;
    }
  }

  bool _shouldDisableHlsConnectionReuse(Uri url) {
    final host = url.host.toLowerCase();
    return Platform.isAndroid && _isProblematicPremilkywayHost(host);
  }

  Duration _effectivePlaylistBodyTimeout(Uri url) {
    if (_isProblematicPremilkywayHost(url.host)) {
      const aggressivePremilkywayTimeout = Duration(seconds: 6);
      if (playlistBodyTimeout > aggressivePremilkywayTimeout) {
        return aggressivePremilkywayTimeout;
      }
    }
    return playlistBodyTimeout;
  }

  bool _shouldAbortRemainingVariantsAfterFailure(Uri variant, Object error) {
    return error is TimeoutException &&
        _isProblematicPremilkywayHost(variant.host);
  }

  String _summarizePlaylistForLog({
    required String label,
    required String content,
    int? variantCount,
    int? segmentCount,
  }) {
    final lineCount = content.split('\n').length;
    final targetDuration = _targetDurationRe.firstMatch(content)?.group(1);
    final previewLines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(6)
        .join(' | ');

    final metrics = <String>[
      '$label (${content.length} chars, $lineCount lines)',
      if (variantCount != null) 'variants=$variantCount',
      if (segmentCount != null) 'segments=$segmentCount',
      if (targetDuration != null) 'targetDuration=${targetDuration}s',
      'preview=$previewLines',
    ];

    return metrics.join(' ');
  }

  int _countPlaylistSegments(String content) {
    var count = 0;
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }
      count++;
    }
    return count;
  }

  bool _isProblematicPremilkywayHost(String host) {
    final normalizedHost = host.toLowerCase();
    return normalizedHost == 'premilkyway.com' ||
        normalizedHost.endsWith('.premilkyway.com');
  }

  bool _shouldFailFastPlaylistError(Object error) {
    // TimeoutException is retryable — don't fail-fast on transient timeouts.
    return false;
  }

  bool _shouldFailFastSegmentError(Object error) {
    // TimeoutException is retryable — don't fail-fast on transient timeouts.
    return false;
  }

  void _log(String message) {
    developer.log(message, name: 'HlsSegmentDownloader');
  }
}

class HlsDownloadResult {
  const HlsDownloadResult({required this.isFmp4, required this.totalBytes});

  final bool isFmp4;
  final int totalBytes;
}

class _HlsVariantCandidate {
  const _HlsVariantCandidate({required this.url, required this.bandwidth});

  final Uri url;
  final int bandwidth;
}
