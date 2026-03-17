import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;

/// Downloads an HLS stream by parsing the m3u8 playlist, downloading each
/// .ts segment sequentially, and concatenating them into a single file.
class HlsSegmentDownloader {
  HlsSegmentDownloader({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Downloads the HLS stream at [masterUrl] to [outputPath].
  ///
  /// [headers] are applied to every HTTP request (referer, origin, etc.).
  /// [onProgress] is called after each segment with (downloaded, total) counts.
  /// Returns when complete. Throws on failure.
  /// If [cancelSignal] completes, download stops early.
  Future<void> download({
    required Uri masterUrl,
    required String outputPath,
    Map<String, String> headers = const <String, String>{},
    void Function(int downloadedSegments, int totalSegments)? onProgress,
    Future<void>? cancelSignal,
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
      // It's already a media playlist.
      mediaContent = masterContent;
      mediaBaseUrl = masterUrl;
    }

    // 3. Parse segment URLs.
    final segmentUrls = _parseSegments(mediaContent, mediaBaseUrl);
    if (segmentUrls.isEmpty) {
      throw const HttpException('No segments found in HLS playlist');
    }
    _log('Found ${segmentUrls.length} segments');

    // 4. Download segments and concatenate.
    final outputFile = File(outputPath);
    final sink = outputFile.openWrite();
    var downloaded = 0;

    try {
      for (final segmentUrl in segmentUrls) {
        if (cancelSignal != null) {
          // Check if cancelled.
          final cancelled = Completer<bool>();
          cancelSignal.then((_) {
            if (!cancelled.isCompleted) cancelled.complete(true);
          });
          // Give a tiny window to check.
          await Future<void>.delayed(Duration.zero);
          if (cancelled.isCompleted) break;
        }

        final segmentData = await _fetchSegment(segmentUrl, headers);
        sink.add(segmentData);
        downloaded++;
        onProgress?.call(downloaded, segmentUrls.length);
      }
    } finally {
      await sink.close();
    }

    _log('HLS download complete: $downloaded/${segmentUrls.length} segments');
  }

  /// Fetches a playlist text file.
  Future<String> _fetchPlaylist(Uri url, Map<String, String> headers) async {
    final request = http.Request('GET', url)..headers.addAll(headers);
    final response = await _httpClient.send(request);
    if (response.statusCode != 200) {
      throw HttpException('Playlist fetch failed: HTTP ${response.statusCode}');
    }
    return response.stream.bytesToString();
  }

  /// Fetches a single segment as bytes.
  Future<List<int>> _fetchSegment(Uri url, Map<String, String> headers) async {
    final request = http.Request('GET', url)..headers.addAll(headers);
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
