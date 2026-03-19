import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;

/// Browser-like User-Agent to avoid Cloudflare bot-detection 403 blocks.
const _browserUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

/// Pre-compiled patterns for playlist parsing — avoids RegExp construction
/// per call in hot loops.
final _bandwidthRe = RegExp(r'BANDWIDTH=(\d+)');
final _mapUriRe = RegExp(r'URI="([^"]+)"');

/// Downloads an HLS stream by parsing the m3u8 playlist, downloading
/// .ts segments with parallelism, and concatenating them into a single file.
class HlsSegmentDownloader {
  HlsSegmentDownloader({
    http.Client? httpClient,
    this.parallelSegments = 12,
    this.maxRetries = 3,
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Number of segments to download in parallel.
  final int parallelSegments;
  final int maxRetries;

  /// Downloads the HLS stream at [masterUrl] to [outputPath].
  ///
  /// [headers] are applied to every HTTP request (referer, origin, etc.).
  /// [onProgress] is called after each segment with (downloadedBytes, totalSegments).
  /// Since HLS total size is unknown upfront, totalSegments is passed so the
  /// caller can compute a segment-based fraction. downloadedBytes tracks the
  /// actual byte count written so far for display purposes.
  /// Returns an object describing whether the stream used fMP4 segments and
  /// the best known total byte count.
  /// If [cancelCompleter] is completed, download stops early.
  Future<HlsDownloadResult> download({
    required Uri masterUrl,
    required String outputPath,
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

    // 1. Fetch the master/variant playlist.
    final masterContent = await _fetchPlaylistWithRetry(masterUrl, headers);

    // 2. Check if it's a master playlist (contains variant streams) or
    //    already a media playlist (contains segments).
    final variantUrl = _pickBestVariant(masterContent, masterUrl);
    final String mediaContent;
    final Uri mediaBaseUrl;

    if (variantUrl != null) {
      _log('Found variant playlist: $variantUrl');
      mediaContent = await _fetchPlaylistWithRetry(variantUrl, headers);
      mediaBaseUrl = variantUrl;
    } else {
      mediaContent = masterContent;
      mediaBaseUrl = masterUrl;
    }

    // 3. Parse init segment (fMP4 streams use #EXT-X-MAP for a moov box).
    final initUri = _parseMapUri(mediaContent, mediaBaseUrl);
    final isFmp4 = initUri != null;
    if (isFmp4) _log('fMP4 stream detected, init segment: $initUri');

    // 4. Parse segment URLs.
    final segmentUrls = _parseSegments(mediaContent, mediaBaseUrl);
    if (segmentUrls.isEmpty) {
      throw const HttpException('No segments found in HLS playlist');
    }
    _log('Found ${segmentUrls.length} segments');

    // 5. Download init segment first (required for fMP4 — contains moov box).
    //    Without it, the concatenated media segments are unplayable.
    final outputFile = File(outputPath);
    final sink = outputFile.openWrite();
    var downloadedSegments = 0;
    var downloadedBytes = 0;

    try {
      if (initUri != null) {
        final initData = await _fetchSegmentWithRetry(initUri, headers);
        sink.add(initData);
        downloadedBytes += initData.length;
        _log('Init segment written (${initData.length} bytes)');
      }

      // Event-driven pipeline: keeps [parallelSegments] fetches truly
      // in-flight at all times. When any fetch finishes, a replacement
      // launches immediately — independent of write order. Segments are
      // still written sequentially for correct concatenation.
      final totalCount = segmentUrls.length;
      final completedData = <int, List<int>>{};
      Object? pipelineError;
      var nextToLaunch = 0;
      var nextToWrite = 0;
      var activeFetches = 0;
      final doneSignals = StreamController<void>();

      Future<void> fetchOne(int index) async {
        activeFetches++;
        try {
          final data = await _fetchSegmentWithRetry(
            segmentUrls[index],
            headers,
          );
          if (cancelCompleter?.isCompleted != true) {
            completedData[index] = data;
          }
        } catch (e) {
          pipelineError ??= e;
        } finally {
          activeFetches--;
          if (!doneSignals.isClosed) doneSignals.add(null);
        }
      }

      void fillPool() {
        while (nextToLaunch < totalCount &&
            activeFetches < parallelSegments &&
            completedData.length <= parallelSegments * 3) {
          unawaited(fetchOne(nextToLaunch++));
        }
      }

      // Seed the pipeline.
      fillPool();

      final events = StreamIterator(doneSignals.stream);

      while (nextToWrite < totalCount) {
        if (cancelCompleter?.isCompleted == true) break;
        if (pipelineError != null) break;

        // Write all completed segments available in order.
        // Batch writes and emit progress only once for the burst to reduce
        // callback overhead when many segments complete simultaneously.
        var batchWrites = 0;
        while (true) {
          final data = completedData.remove(nextToWrite);
          if (data == null) break;
          sink.add(data);
          downloadedSegments++;
          downloadedBytes += data.length;
          nextToWrite++;
          batchWrites++;
        }

        if (batchWrites > 0) {
          final dynamicEstimate = downloadedSegments > 0
              ? (downloadedBytes / downloadedSegments * totalCount).round()
              : 0;

          onProgress?.call(
            downloadedBytes,
            downloadedSegments,
            totalCount,
            dynamicEstimate,
          );

          // Periodic flush to bound IOSink memory on mobile.
          // Flush after burst writes rather than using a separate timer
          // since segments arrive in bursts naturally.
          if (downloadedSegments % 20 == 0) {
            await sink.flush();
          }
        }

        if (nextToWrite >= totalCount) break;

        // Refill pool after writes.
        fillPool();

        // Wait for the next fetch completion signal.
        if (!await events.moveNext()) break;
      }

      await events.cancel();
      await doneSignals.close();
      if (pipelineError != null) throw pipelineError!;
    } finally {
      await sink.close();
    }

    _log(
      'HLS download complete: $downloadedSegments/${segmentUrls.length} segments ($downloadedBytes bytes)',
    );
    return HlsDownloadResult(isFmp4: isFmp4, totalBytes: downloadedBytes);
  }

  /// Fetches a playlist text file with a connection timeout.
  Future<String> _fetchPlaylist(Uri url, Map<String, String> headers) async {
    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..headers.putIfAbsent('User-Agent', () => _browserUserAgent);
    final response = await _httpClient
        .send(request)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw HttpException('Playlist fetch failed: HTTP ${response.statusCode}');
    }
    return response.stream.bytesToString();
  }

  /// Fetches a single segment as bytes with a timeout.
  Future<List<int>> _fetchSegment(Uri url, Map<String, String> headers) async {
    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..headers.putIfAbsent('User-Agent', () => _browserUserAgent)
      // Request raw bytes — segments are already encoded media data, auto-
      // decompression by the HTTP layer wastes CPU and can corrupt binary data.
      ..headers.putIfAbsent('Accept-Encoding', () => 'identity');
    final response = await _httpClient
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException('Segment fetch failed: HTTP ${response.statusCode}');
    }
    return response.stream.toBytes();
  }

  Future<String> _fetchPlaylistWithRetry(
    Uri url,
    Map<String, String> headers,
  ) async {
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await _fetchPlaylist(url, headers);
      } catch (_) {
        if (attempt == maxRetries) rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
    }
    // Unreachable when maxRetries >= 1, but satisfies the type system.
    throw const HttpException('Playlist fetch failed');
  }

  Future<List<int>> _fetchSegmentWithRetry(
    Uri url,
    Map<String, String> headers,
  ) async {
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await _fetchSegment(url, headers);
      } catch (_) {
        if (attempt == maxRetries) rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 150 * attempt));
    }
    throw const HttpException('Segment fetch failed');
  }

  /// Picks the highest-bandwidth variant from a master playlist.
  /// Returns null if this is already a media playlist.
  Uri? _pickBestVariant(String content, Uri baseUrl) {
    if (!content.contains('#EXT-X-STREAM-INF')) return null;

    final lines = content.split('\n');
    int? bestBandwidth;
    String? bestUrl;

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

        if (bestBandwidth == null || (bw != null && bw > bestBandwidth)) {
          bestBandwidth = bw ?? 0;
          bestUrl = uriLine;
        }
        break;
      }
    }

    if (bestUrl == null) return null;
    return _resolveUrl(bestUrl, baseUrl);
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
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Uri.parse(url);
    }
    return baseUrl.resolve(url);
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
