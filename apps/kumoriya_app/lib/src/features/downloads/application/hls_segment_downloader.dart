import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;

/// Browser-like User-Agent to avoid Cloudflare bot-detection 403 blocks.
const _browserUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

/// Downloads an HLS stream by parsing the m3u8 playlist, downloading
/// .ts segments with parallelism, and concatenating them into a single file.
class HlsSegmentDownloader {
  HlsSegmentDownloader({http.Client? httpClient, this.parallelSegments = 8})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Number of segments to download in parallel.
  final int parallelSegments;

  /// Downloads the HLS stream at [masterUrl] to [outputPath].
  ///
  /// [headers] are applied to every HTTP request (referer, origin, etc.).
  /// [onProgress] is called after each segment with (downloadedBytes, totalSegments).
  /// Since HLS total size is unknown upfront, totalSegments is passed so the
  /// caller can compute a segment-based fraction. downloadedBytes tracks the
  /// actual byte count written so far for display purposes.
  /// Returns `true` if the stream uses fMP4 segments (has `#EXT-X-MAP`),
  /// `false` for classic MPEG-TS segments.
  /// If [cancelCompleter] is completed, download stops early.
  Future<bool> download({
    required Uri masterUrl,
    required String outputPath,
    Map<String, String> headers = const <String, String>{},
    void Function(
      int downloadedBytes,
      int downloadedSegments,
      int totalSegments,
    )?
    onProgress,
    Completer<void>? cancelCompleter,
  }) async {
    _log('Starting HLS download: $masterUrl');

    // 1. Fetch the master/variant playlist.
    final masterContent = await _fetchPlaylist(masterUrl, headers);

    // 2. Check if it's a master playlist (contains variant streams) or
    //    already a media playlist (contains segments).
    final variantUrl = _pickBestVariant(masterContent, masterUrl);
    final String mediaContent;
    final Uri mediaBaseUrl;

    if (variantUrl != null) {
      _log('Found variant playlist: $variantUrl');
      mediaContent = await _fetchPlaylist(variantUrl, headers);
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
        final initData = await _fetchSegment(initUri, headers);
        sink.add(initData);
        downloadedBytes += initData.length;
        _log('Init segment written (${initData.length} bytes)');
      }

      // Sliding-window pipeline: keep [parallelSegments] fetches in-flight at
      // all times, writing completed segments to disk in order. This maximises
      // throughput without buffering an entire batch in memory.
      final totalCount = segmentUrls.length;
      final pending = <int, Future<List<int>>>{};
      var nextToLaunch = 0;
      var nextToWrite = 0;

      // Seed the pipeline.
      while (nextToLaunch < totalCount && pending.length < parallelSegments) {
        pending[nextToLaunch] = _fetchSegment(
          segmentUrls[nextToLaunch],
          headers,
        );
        nextToLaunch++;
      }

      while (nextToWrite < totalCount) {
        if (cancelCompleter?.isCompleted == true) break;

        final data = await pending.remove(nextToWrite)!;
        sink.add(data);
        downloadedSegments++;
        downloadedBytes += data.length;
        nextToWrite++;

        onProgress?.call(downloadedBytes, downloadedSegments, totalCount);

        // Launch next segment to keep the pipeline full.
        if (nextToLaunch < totalCount) {
          pending[nextToLaunch] = _fetchSegment(
            segmentUrls[nextToLaunch],
            headers,
          );
          nextToLaunch++;
        }
      }
    } finally {
      await sink.close();
    }

    _log(
      'HLS download complete: $downloadedSegments/${segmentUrls.length} segments ($downloadedBytes bytes)',
    );
    return isFmp4;
  }

  /// Fetches a playlist text file.
  Future<String> _fetchPlaylist(Uri url, Map<String, String> headers) async {
    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..headers.putIfAbsent('User-Agent', () => _browserUserAgent);
    final response = await _httpClient.send(request);
    if (response.statusCode != 200) {
      throw HttpException('Playlist fetch failed: HTTP ${response.statusCode}');
    }
    return response.stream.bytesToString();
  }

  /// Fetches a single segment as bytes.
  Future<List<int>> _fetchSegment(Uri url, Map<String, String> headers) async {
    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..headers.putIfAbsent('User-Agent', () => _browserUserAgent);
    final response = await _httpClient.send(request);
    if (response.statusCode != 200) {
      throw HttpException('Segment fetch failed: HTTP ${response.statusCode}');
    }
    return response.stream.toBytes();
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
      final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
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
      final match = RegExp(r'URI="([^"]+)"').firstMatch(trimmed);
      if (match != null) return _resolveUrl(match.group(1)!, baseUrl);
    }
    return null;
  }

  /// Parses segment URLs from a media playlist.
  List<Uri> _parseSegments(String content, Uri baseUrl) {
    final segments = <Uri>[];
    final lines = content.split('\n');

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
