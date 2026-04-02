import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as ioc;

/// Browser-like User-Agent to avoid Cloudflare bot-detection 403 blocks.
const _browserUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

// ---------------------------------------------------------------------------
// Messages: main → worker
// ---------------------------------------------------------------------------

/// Initial configuration sent when launching the worker isolate.
final class _WorkerConfig {
  const _WorkerConfig({
    required this.sendPort,
    required this.segments,
    required this.headers,
    required this.segmentsDir,
    required this.maxConcurrent,
    required this.maxRetries,
    required this.initSegmentUrl,
    required this.initSegmentPath,
  });

  final SendPort sendPort;
  final List<HlsSegmentInfo> segments;
  final Map<String, String> headers;
  final String segmentsDir;
  final int maxConcurrent;
  final int maxRetries;
  final String? initSegmentUrl;
  final String? initSegmentPath;
}

/// Lightweight segment descriptor sent across isolate boundary.
final class HlsSegmentInfo {
  const HlsSegmentInfo({
    required this.index,
    required this.url,
    required this.localPath,
    this.skip = false,
  });

  final int index;
  final String url;
  final String localPath;

  /// True when the segment is already completed on disk — worker skips it.
  final bool skip;
}

/// Command sent from main to tell the worker to stop.
enum _WorkerCommand { pause, cancel }

// ---------------------------------------------------------------------------
// Messages: worker → main
// ---------------------------------------------------------------------------

/// Progress update emitted periodically from the worker.
final class HlsWorkerProgress {
  const HlsWorkerProgress({
    required this.completedSegments,
    required this.totalSegments,
    required this.downloadedBytes,
    required this.estimatedTotalBytes,
    required this.bytesPerSecond,
    required this.activeConcurrency,
  });

  final int completedSegments;
  final int totalSegments;
  final int downloadedBytes;
  final int estimatedTotalBytes;
  final int bytesPerSecond;

  /// Current number of parallel slots the adaptive controller is using.
  final int activeConcurrency;
}

/// Notification that a specific segment finished downloading.
final class HlsSegmentDone {
  const HlsSegmentDone({
    required this.segmentIndex,
    required this.localPath,
    required this.byteSize,
  });

  final int segmentIndex;
  final String localPath;
  final int byteSize;
}

/// Notification that a specific segment failed after all retries.
final class HlsSegmentFailed {
  const HlsSegmentFailed({required this.segmentIndex, required this.error});

  final int segmentIndex;
  final String error;
}

/// Terminal message: all segments have been processed.
final class HlsWorkerDone {
  const HlsWorkerDone({
    required this.totalBytes,
    required this.isFmp4,
    required this.failedCount,
  });

  final int totalBytes;
  final bool isFmp4;
  final int failedCount;
}

/// Terminal message: worker stopped due to an unrecoverable error.
final class HlsWorkerError {
  const HlsWorkerError(this.message);
  final String message;
}

/// Terminal message: worker acknowledged pause/cancel.
final class HlsWorkerStopped {
  const HlsWorkerStopped();
}

// ---------------------------------------------------------------------------
// HlsDownloadEngine — manages the Isolate lifecycle from the main thread.
// ---------------------------------------------------------------------------

/// Orchestrates HLS segment downloads in a separate Isolate.
///
/// The engine keeps all HTTP I/O and file writes off the main thread.
/// The main thread receives structured progress messages to update DB and UI.
///
/// ## Connection reuse
/// A single [http.Client] is created inside the worker isolate and shared
/// across all concurrent segment fetches, minimizing TCP handshake overhead
/// (similar to IDM's connection pooling).
///
/// ## Concurrency
/// The worker uses a semaphore-style pool: at most [maxConcurrent] segment
/// fetches run simultaneously. When any fetch completes, the next pending
/// segment starts immediately — keeping the pool saturated.
///
/// ## Resumability
/// Segments marked as `skip: true` in [_SegmentInfo] are not re-downloaded.
/// The caller (DownloadManagerService) loads segment state from DB and
/// sets `skip` for completed segments before launching the engine.
class HlsDownloadEngine {
  HlsDownloadEngine({this.maxConcurrent = 32, this.maxRetries = 3});

  final int maxConcurrent;
  final int maxRetries;

  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _commandPort;
  StreamSubscription<dynamic>? _subscription;

  /// Starts the download worker isolate.
  ///
  /// [segments] — all segment descriptors (with `skip` flag for completed).
  /// [headers] — HTTP headers applied to every request (referer, origin…).
  /// [segmentsDir] — directory where individual segment files are saved.
  /// [initSegmentUrl] — fMP4 #EXT-X-MAP init segment URL (null for MPEG-TS).
  /// [initSegmentPath] — local path for the init segment file.
  /// [onProgress] — called periodically with aggregate progress.
  /// [onSegmentDone] — called when a single segment completes.
  /// [onSegmentFailed] — called when a segment exhausts retries.
  /// [onDone] — called when all segments are processed.
  /// [onError] — called on unrecoverable worker error.
  /// [onStopped] — called when the worker acknowledges pause/cancel.
  Future<void> start({
    required List<HlsSegmentInfo> segments,
    required Map<String, String> headers,
    required String segmentsDir,
    String? initSegmentUrl,
    String? initSegmentPath,
    void Function(HlsWorkerProgress)? onProgress,
    void Function(HlsSegmentDone)? onSegmentDone,
    void Function(HlsSegmentFailed)? onSegmentFailed,
    void Function(HlsWorkerDone)? onDone,
    void Function(HlsWorkerError)? onError,
    void Function()? onStopped,
  }) async {
    _receivePort = ReceivePort();

    _subscription = _receivePort!.listen((message) {
      if (message is SendPort) {
        _commandPort = message;
      } else if (message is HlsWorkerProgress) {
        onProgress?.call(message);
      } else if (message is HlsSegmentDone) {
        onSegmentDone?.call(message);
      } else if (message is HlsSegmentFailed) {
        onSegmentFailed?.call(message);
      } else if (message is HlsWorkerDone) {
        onDone?.call(message);
        _cleanup();
      } else if (message is HlsWorkerError) {
        onError?.call(message);
        _cleanup();
      } else if (message is HlsWorkerStopped) {
        onStopped?.call();
        _cleanup();
      }
    });

    _isolate = await Isolate.spawn(
      _workerEntryPoint,
      _WorkerConfig(
        sendPort: _receivePort!.sendPort,
        segments: segments,
        headers: headers,
        segmentsDir: segmentsDir,
        maxConcurrent: maxConcurrent,
        maxRetries: maxRetries,
        initSegmentUrl: initSegmentUrl,
        initSegmentPath: initSegmentPath,
      ),
      debugName: 'hls-download-worker',
    );
  }

  /// Request the worker to pause. It finishes in-flight segments then stops.
  void pause() {
    _commandPort?.send(_WorkerCommand.pause);
  }

  /// Request the worker to cancel. In-flight segments are abandoned.
  void cancel() {
    _commandPort?.send(_WorkerCommand.cancel);
  }

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _receivePort?.close();
    _receivePort = null;
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _isolate = null;
    _commandPort = null;
  }

  /// Force-kills the isolate without waiting for acknowledgement.
  void dispose() {
    _cleanup();
  }

  /// Creates an [HlsSegmentInfo] from caller-provided data.
  static HlsSegmentInfo createSegmentInfo({
    required int index,
    required String url,
    required String localPath,
    bool skip = false,
  }) {
    return HlsSegmentInfo(
      index: index,
      url: url,
      localPath: localPath,
      skip: skip,
    );
  }
}

// ---------------------------------------------------------------------------
// Worker isolate entry point — all HTTP + file I/O happens here.
// ---------------------------------------------------------------------------

Future<void> _workerEntryPoint(_WorkerConfig config) async {
  final mainPort = config.sendPort;

  // Bi-directional communication: send our command port to main.
  final commandPort = ReceivePort();
  mainPort.send(commandPort.sendPort);

  var paused = false;
  var cancelled = false;
  commandPort.listen((message) {
    if (message == _WorkerCommand.pause) paused = true;
    if (message == _WorkerCommand.cancel) cancelled = true;
  });

  // Single shared HTTP client — connection reuse across all segment fetches.
  // Configured for download throughput: large connection pool, no auto-
  // decompression (segments are binary media data), fast connect timeout.
  // Pool sized for the adaptive ceiling so ramp-up never blocks on connections.
  final adaptiveCeiling = Platform.isAndroid ? 24 : 96;
  final innerClient = HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = const Duration(seconds: 10)
    ..idleTimeout = const Duration(seconds: 60)
    ..maxConnectionsPerHost = adaptiveCeiling + 6;
  final httpClient = ioc.IOClient(innerClient);

  try {
    await _runDownloadPipeline(
      config: config,
      httpClient: httpClient,
      mainPort: mainPort,
      isPaused: () => paused,
      isCancelled: () => cancelled,
    );
  } catch (error) {
    mainPort.send(HlsWorkerError(error.toString()));
  } finally {
    httpClient.close();
    commandPort.close();
  }
}

Future<void> _runDownloadPipeline({
  required _WorkerConfig config,
  required http.Client httpClient,
  required SendPort mainPort,
  required bool Function() isPaused,
  required bool Function() isCancelled,
}) async {
  final segmentsDir = Directory(config.segmentsDir);
  if (!segmentsDir.existsSync()) {
    segmentsDir.createSync(recursive: true);
  }

  final isFmp4 = config.initSegmentUrl != null;

  // Download init segment first (fMP4 #EXT-X-MAP — contains moov box).
  if (config.initSegmentUrl != null && config.initSegmentPath != null) {
    final initFile = File(config.initSegmentPath!);
    if (!initFile.existsSync()) {
      final Uri initUri;
      try {
        initUri = Uri.parse(config.initSegmentUrl!);
      } catch (e) {
        throw FormatException(
          'Bad init segment URL: "${config.initSegmentUrl}" — $e',
        );
      }
      final data = await _fetchWithRetry(
        httpClient: httpClient,
        url: initUri,
        headers: config.headers,
        maxRetries: config.maxRetries,
      );
      await initFile.writeAsBytes(data, flush: true);
    }
  }

  // Filter to only segments that need downloading.
  final pending = config.segments.where((s) => !s.skip).toList();
  final totalSegments = config.segments.length;
  var completedSegments = config.segments.where((s) => s.skip).length;
  var downloadedBytes = 0;
  var failedCount = 0;

  // Sum bytes of already-completed segments for accurate progress.
  for (final seg in config.segments.where((s) => s.skip)) {
    final file = File(seg.localPath);
    if (file.existsSync()) {
      downloadedBytes += file.lengthSync();
    }
  }

  // Speed tracking.
  final sw = Stopwatch()..start();
  var lastSpeedMs = 0;
  var bytesAtLastSample = downloadedBytes;
  var currentSpeed = 0;
  var lastProgressMs = 0;

  // ── Adaptive concurrency ─────────────────────────────────────────────
  // AIMD-inspired controller: probes throughput every 2s and adjusts the
  // pool size up (additive) when bandwidth is underused, or down
  // (multiplicative) when overloading/stalling.
  var dynamicMaxConcurrent = config.maxConcurrent;
  final maxCeiling = Platform.isAndroid ? 24 : 96;
  final minFloor = Platform.isAndroid ? 4 : 8;
  var probeBytesAtLastSample = downloadedBytes;
  var lastProbeMs = 0;
  var previousThroughput = 0;
  var stallCount = 0;
  var probeStarted = false;

  int probeAndAdjust(int elapsedMs) {
    if (!probeStarted) {
      probeStarted = true;
      lastProbeMs = elapsedMs;
      probeBytesAtLastSample = downloadedBytes;
      return dynamicMaxConcurrent;
    }
    final deltaMs = elapsedMs - lastProbeMs;
    if (deltaMs < 2000) return dynamicMaxConcurrent;

    final deltaBytes = downloadedBytes - probeBytesAtLastSample;
    final throughput = deltaMs > 0 ? (deltaBytes * 1000 / deltaMs).round() : 0;
    probeBytesAtLastSample = downloadedBytes;
    lastProbeMs = elapsedMs;

    // Stall detection: < 50 KB/s for 3 consecutive probes.
    if (throughput < 50 * 1024) {
      stallCount++;
      if (stallCount >= 3) {
        dynamicMaxConcurrent = max(
          minFloor,
          (dynamicMaxConcurrent * 0.5).ceil(),
        );
        stallCount = 0;
      }
      previousThroughput = throughput;
      return dynamicMaxConcurrent;
    }
    stallCount = 0;

    if (previousThroughput == 0) {
      previousThroughput = throughput;
      dynamicMaxConcurrent = min(maxCeiling, dynamicMaxConcurrent + 2);
      return dynamicMaxConcurrent;
    }

    final relativeChange =
        (throughput - previousThroughput) / previousThroughput;
    if (relativeChange >= 0.05) {
      // Bandwidth improving — add workers.
      dynamicMaxConcurrent = min(maxCeiling, dynamicMaxConcurrent + 2);
    } else if (relativeChange < -0.15) {
      // Bandwidth dropped — back off.
      dynamicMaxConcurrent = max(
        minFloor,
        (dynamicMaxConcurrent * 0.75).ceil(),
      );
    }
    previousThroughput = throughput;
    return dynamicMaxConcurrent;
  }

  // Event-driven pool: maintains [dynamicMaxConcurrent] in-flight fetches.
  var nextToLaunch = 0;
  var activeFetches = 0;
  final doneSc = StreamController<void>();

  Future<void> fetchOne(int pendingIndex) async {
    final seg = pending[pendingIndex];
    activeFetches++;
    try {
      if (isCancelled()) return;

      final Uri segUrl;
      try {
        segUrl = Uri.parse(seg.url);
      } catch (e) {
        throw FormatException(
          'Bad segment URL at index ${seg.index}: "${seg.url}" — $e',
        );
      }

      final byteCount = await _fetchSegmentToFile(
        httpClient: httpClient,
        url: segUrl,
        headers: config.headers,
        filePath: seg.localPath,
        maxRetries: config.maxRetries,
      );

      if (isCancelled()) return;

      completedSegments++;
      downloadedBytes += byteCount;

      mainPort.send(
        HlsSegmentDone(
          segmentIndex: seg.index,
          localPath: seg.localPath,
          byteSize: byteCount,
        ),
      );
    } catch (error) {
      failedCount++;
      mainPort.send(
        HlsSegmentFailed(segmentIndex: seg.index, error: error.toString()),
      );
    } finally {
      activeFetches--;
      if (!doneSc.isClosed) doneSc.add(null);
    }
  }

  void fillPool() {
    while (nextToLaunch < pending.length &&
        activeFetches < dynamicMaxConcurrent &&
        !isPaused() &&
        !isCancelled()) {
      unawaited(fetchOne(nextToLaunch++));
    }
  }

  // Seed the pool.
  fillPool();

  if (pending.isEmpty) {
    mainPort.send(
      HlsWorkerDone(
        totalBytes: downloadedBytes,
        isFmp4: isFmp4,
        failedCount: 0,
      ),
    );
    return;
  }

  final events = StreamIterator(doneSc.stream);
  var processedCount = 0;

  while (processedCount < pending.length) {
    if (isCancelled()) {
      await events.cancel();
      await doneSc.close();
      mainPort.send(const HlsWorkerStopped());
      return;
    }

    if (isPaused() && activeFetches == 0) {
      await events.cancel();
      await doneSc.close();
      mainPort.send(const HlsWorkerStopped());
      return;
    }

    // Emit throttled progress.
    final elapsedMs = sw.elapsedMilliseconds;
    final speedDelta = elapsedMs - lastSpeedMs;
    if (speedDelta >= 1000) {
      final bytesDelta = downloadedBytes - bytesAtLastSample;
      currentSpeed = (bytesDelta * 1000 / speedDelta).round();
      bytesAtLastSample = downloadedBytes;
      lastSpeedMs = elapsedMs;
    }

    // Adaptive concurrency probe — adjust pool size based on throughput.
    dynamicMaxConcurrent = probeAndAdjust(elapsedMs);

    if (elapsedMs - lastProgressMs >= 500) {
      lastProgressMs = elapsedMs;
      // When no segments have completed yet, fall back to downloadedBytes
      // so the UI shows a non-zero total instead of 0 KB.
      final estimatedTotal = completedSegments > 0
          ? (downloadedBytes / completedSegments * totalSegments).round()
          : downloadedBytes;
      mainPort.send(
        HlsWorkerProgress(
          completedSegments: completedSegments,
          totalSegments: totalSegments,
          downloadedBytes: downloadedBytes,
          estimatedTotalBytes: estimatedTotal,
          bytesPerSecond: currentSpeed,
          activeConcurrency: dynamicMaxConcurrent,
        ),
      );
    }

    // Refill pool after completions.
    fillPool();

    // Wait for next completion signal.
    if (!await events.moveNext()) break;
    processedCount++;
  }

  await events.cancel();
  await doneSc.close();

  mainPort.send(
    HlsWorkerDone(
      totalBytes: downloadedBytes,
      isFmp4: isFmp4,
      failedCount: failedCount,
    ),
  );
}

/// Fetches raw bytes from [url] with retry and exponential backoff.
/// Used only for small payloads (init segments, playlists).
Future<List<int>> _fetchWithRetry({
  required http.Client httpClient,
  required Uri url,
  required Map<String, String> headers,
  required int maxRetries,
}) async {
  for (var attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      final request = http.Request('GET', url)
        ..persistentConnection = !_shouldDisableHlsConnectionReuse(url)
        ..headers.addAll(headers)
        ..headers.putIfAbsent('User-Agent', () => _browserUserAgent)
        ..headers.putIfAbsent('Accept-Encoding', () => 'identity');
      if (!request.persistentConnection) {
        request.headers['Connection'] = 'close';
      }

      final response = await httpClient
          .send(request)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw HttpException(
          'HTTP ${response.statusCode} fetching segment $url',
        );
      }
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        bytes.addAll(chunk);
      }
      return bytes;
    } catch (error) {
      if (_shouldFailFastHlsTransportError(error)) {
        rethrow;
      }
      if (attempt == maxRetries) rethrow;
    }
    await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
  }
  throw const HttpException('Segment fetch failed after all retries');
}

/// Streams the HTTP response for [url] directly to [filePath], returning
/// the total byte count written. Avoids buffering the entire segment in
/// memory and skips per-file fsync — the OS write-back cache handles
/// flushing efficiently for media data.
Future<int> _fetchSegmentToFile({
  required http.Client httpClient,
  required Uri url,
  required Map<String, String> headers,
  required String filePath,
  required int maxRetries,
}) async {
  for (var attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      final request = http.Request('GET', url)
        ..persistentConnection = !_shouldDisableHlsConnectionReuse(url)
        ..headers.addAll(headers)
        ..headers.putIfAbsent('User-Agent', () => _browserUserAgent)
        ..headers.putIfAbsent('Accept-Encoding', () => 'identity');
      if (!request.persistentConnection) {
        request.headers['Connection'] = 'close';
      }

      final response = await httpClient
          .send(request)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        await response.stream.drain<void>();
        throw HttpException(
          'HTTP ${response.statusCode} fetching segment $url',
        );
      }

      final file = File(filePath);
      final sink = file.openWrite();
      var byteCount = 0;
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 30),
        )) {
          sink.add(chunk);
          byteCount += chunk.length;
        }
        await sink.close();
      } catch (e) {
        await sink.close();
        if (file.existsSync()) file.deleteSync();
        rethrow;
      }
      return byteCount;
    } catch (error) {
      if (_shouldFailFastHlsTransportError(error)) {
        rethrow;
      }
      if (attempt == maxRetries) rethrow;
    }
    await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
  }
  throw const HttpException('Segment fetch failed after all retries');
}

bool _shouldDisableHlsConnectionReuse(Uri url) {
  if (!Platform.isAndroid) {
    return false;
  }

  final host = url.host.toLowerCase();
  return host == 'premilkyway.com' || host.endsWith('.premilkyway.com');
}

bool _shouldFailFastHlsTransportError(Object error) {
  return error is TimeoutException;
}
