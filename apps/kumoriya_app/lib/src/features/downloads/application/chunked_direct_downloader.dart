import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Progress callback for chunked downloads.
///
/// [downloadedBytes] – aggregate bytes received across all chunks.
/// [totalBytes]      – total file size (from probe).
/// [bytesPerSecond]  – current aggregate throughput.
typedef ChunkedProgressCallback =
    void Function(int downloadedBytes, int totalBytes, int bytesPerSecond);

/// Result of a chunked download probe.
class _ProbeResult {
  const _ProbeResult({required this.totalBytes, required this.supportsRanges});
  final int totalBytes;
  final bool supportsRanges;
}

/// A single chunk range to download.
class _ChunkSpec {
  _ChunkSpec({
    required this.index,
    required this.start,
    required this.end,
    required this.tempFile,
  });

  final int index;
  final int start;
  final int end;
  final File tempFile;
  int downloadedBytes = 0;
}

const _browserUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

/// Minimum file size to enable chunked parallel download (2 MB).
/// Below this threshold single-connection is fine.
const _minChunkedSizeBytes = 2 * 1024 * 1024;

/// Minimum chunk size to avoid creating too many tiny requests (512 KB).
const _minChunkSizeBytes = 512 * 1024;

/// Downloads a direct (non-HLS) file using parallel HTTP Range requests.
///
/// If the server does not support Range requests or the file is too small,
/// returns `false` so the caller can fall back to single-connection download.
class ChunkedDirectDownloader {
  ChunkedDirectDownloader({required http.Client httpClient, int? maxChunks})
    : _httpClient = httpClient,
      _maxChunks = maxChunks ?? _platformDefaultChunks();

  final http.Client _httpClient;
  final int _maxChunks;

  static int _platformDefaultChunks() {
    if (Platform.isAndroid) return 6;
    if (Platform.isWindows) return 8;
    return 4;
  }

  /// Probes the server to check Range support and file size.
  ///
  /// Returns `null` if the probe fails or chunked download is not advisable.
  Future<_ProbeResult?> _probe(Uri url, Map<String, String> headers) async {
    try {
      final request = http.Request('HEAD', url);
      request.headers.addAll(headers);
      request.headers.putIfAbsent('User-Agent', () => _browserUserAgent);

      final response = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 8));
      await response.stream.drain<void>();

      if (response.statusCode != 200) return null;

      final acceptRanges = response.headers['accept-ranges'] ?? '';
      final supportsRanges = acceptRanges.toLowerCase().contains('bytes');

      final contentLength = int.tryParse(
        response.headers['content-length'] ?? '',
      );
      if (contentLength == null || contentLength <= 0) return null;

      return _ProbeResult(
        totalBytes: contentLength,
        supportsRanges: supportsRanges,
      );
    } catch (_) {
      return null;
    }
  }

  /// Attempts a chunked parallel download.
  ///
  /// Returns `true` if the download completed successfully via chunks.
  /// Returns `false` if chunked download is not possible (server doesn't
  /// support Range, file too small, etc.) — caller should fall back to
  /// single-connection download.
  ///
  /// Throws on actual download errors (network, disk, etc.).
  Future<bool> tryDownload({
    required Uri url,
    required String outputPath,
    required Map<String, String> headers,
    required Completer<void> cancelCompleter,
    ChunkedProgressCallback? onProgress,
  }) async {
    // Step 1: Probe the server.
    final probe = await _probe(url, headers);
    if (probe == null || !probe.supportsRanges) return false;
    if (probe.totalBytes < _minChunkedSizeBytes) return false;

    // Step 2: Calculate chunk boundaries.
    final totalBytes = probe.totalBytes;
    final numChunks = min(_maxChunks, max(1, totalBytes ~/ _minChunkSizeBytes));
    if (numChunks <= 1) return false;

    final chunkSize = totalBytes ~/ numChunks;
    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);

    final chunks = <_ChunkSpec>[];
    for (var i = 0; i < numChunks; i++) {
      final start = i * chunkSize;
      final end = (i == numChunks - 1)
          ? totalBytes - 1
          : (start + chunkSize - 1);
      chunks.add(
        _ChunkSpec(
          index: i,
          start: start,
          end: end,
          tempFile: File('$outputPath.chunk$i'),
        ),
      );
    }

    // Step 3: Resume — check existing chunk progress.
    for (final chunk in chunks) {
      if (await chunk.tempFile.exists()) {
        final existingBytes = await chunk.tempFile.length();
        final expectedSize = chunk.end - chunk.start + 1;
        if (existingBytes >= expectedSize) {
          // Chunk already complete.
          chunk.downloadedBytes = expectedSize;
        } else {
          chunk.downloadedBytes = existingBytes;
        }
      }
    }

    // Step 4: Download incomplete chunks in parallel.
    final sw = Stopwatch()..start();
    var lastProgressMs = 0;
    var lastSpeedMs = 0;
    var bytesAtLastSample = _aggregateDownloaded(chunks);
    var currentSpeed = 0;

    void emitProgress() {
      final elapsedMs = sw.elapsedMilliseconds;
      final downloaded = _aggregateDownloaded(chunks);

      if (elapsedMs - lastSpeedMs >= 1000) {
        final delta = downloaded - bytesAtLastSample;
        currentSpeed = (delta * 1000 / max(1, elapsedMs - lastSpeedMs)).round();
        bytesAtLastSample = downloaded;
        lastSpeedMs = elapsedMs;
      }

      if (elapsedMs - lastProgressMs >= 500) {
        lastProgressMs = elapsedMs;
        onProgress?.call(downloaded, totalBytes, currentSpeed);
      }
    }

    final pendingChunks = chunks
        .where((c) => c.downloadedBytes < (c.end - c.start + 1))
        .toList();

    if (pendingChunks.isEmpty) {
      // All chunks already downloaded — go straight to concatenation.
    } else {
      // Progress timer — emits progress at fixed intervals regardless of
      // which chunk notifies.
      final progressTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => emitProgress(),
      );

      try {
        final futures = <Future<void>>[];
        for (final chunk in pendingChunks) {
          futures.add(
            _downloadChunk(
              chunk: chunk,
              url: url,
              headers: headers,
              cancelCompleter: cancelCompleter,
            ),
          );
        }
        await Future.wait(futures);
      } finally {
        progressTimer.cancel();
      }

      if (cancelCompleter.isCompleted) {
        return true; // cancelled — caller handles cleanup
      }
    }

    // Step 5: Concatenate chunks into the final file.
    final sink = outputFile.openWrite(mode: FileMode.write);
    try {
      for (final chunk in chunks) {
        await sink.addStream(chunk.tempFile.openRead());
      }
    } finally {
      await sink.close();
    }

    // Step 6: Cleanup chunk files.
    for (final chunk in chunks) {
      try {
        await chunk.tempFile.delete();
      } catch (_) {
        // Best-effort cleanup.
      }
    }

    // Final progress emission.
    onProgress?.call(totalBytes, totalBytes, currentSpeed);

    return true;
  }

  Future<void> _downloadChunk({
    required _ChunkSpec chunk,
    required Uri url,
    required Map<String, String> headers,
    required Completer<void> cancelCompleter,
  }) async {
    final expectedSize = chunk.end - chunk.start + 1;
    if (chunk.downloadedBytes >= expectedSize) return;

    final rangeStart = chunk.start + chunk.downloadedBytes;
    final request = http.Request('GET', url);
    request.headers.addAll(headers);
    request.headers.putIfAbsent('User-Agent', () => _browserUserAgent);
    request.headers.putIfAbsent('Accept-Encoding', () => 'identity');
    request.headers['Range'] = 'bytes=$rangeStart-${chunk.end}';

    const maxRetries = 3;
    Object? lastError;

    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final retryRequest = http.Request('GET', url);
        retryRequest.headers.addAll(request.headers);
        final adjustedStart = chunk.start + chunk.downloadedBytes;
        retryRequest.headers['Range'] = 'bytes=$adjustedStart-${chunk.end}';

        final response = await _httpClient
            .send(retryRequest)
            .timeout(const Duration(seconds: 15));

        if (response.statusCode != 206 && response.statusCode != 200) {
          await response.stream.drain<void>();
          throw HttpException(
            'Chunk ${chunk.index} got HTTP ${response.statusCode}',
          );
        }

        final append = chunk.downloadedBytes > 0;
        final sink = chunk.tempFile.openWrite(
          mode: append ? FileMode.append : FileMode.write,
        );
        var lastFlushMs = 0;
        final csw = Stopwatch()..start();

        try {
          await for (final data in response.stream) {
            if (cancelCompleter.isCompleted) return;

            sink.add(data);
            chunk.downloadedBytes += data.length;

            // Periodic flush to prevent unbounded IOSink buffering.
            final elapsed = csw.elapsedMilliseconds;
            if (elapsed - lastFlushMs >= 2000) {
              lastFlushMs = elapsed;
              await sink.flush();
            }
          }
        } finally {
          await sink.close();
        }

        // Chunk downloaded successfully.
        return;
      } catch (error) {
        lastError = error;
        if (cancelCompleter.isCompleted) return;
        if (attempt < maxRetries) {
          await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
        }
      }
    }

    throw lastError ?? HttpException('Chunk ${chunk.index} download failed');
  }

  int _aggregateDownloaded(List<_ChunkSpec> chunks) {
    var total = 0;
    for (final c in chunks) {
      total += c.downloadedBytes;
    }
    return total;
  }
}
