import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/filemoon_resolver_error.dart';

final class FilemoonResolverPlugin implements ResolverPlugin {
  FilemoonResolverPlugin({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const Set<String> _supportedHosts = <String>{
    'filemoon.sx',
    'filemoon.to',
    'filemoon.nl',
    'filemoon.in',
    'filemoon.link',
    'kerapoxy.cc',
    'bysekoze.com',
    'f75s.com',
  };

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.filemoon',
    displayName: 'Filemoon Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>[
      'filemoon.sx',
      'filemoon.to',
      'filemoon.nl',
      'filemoon.in',
      'filemoon.link',
      'kerapoxy.cc',
      'bysekoze.com',
      'f75s.com',
    ],
    baseUrls: <String>['https://filemoon.sx/e/'],
  );

  @override
  int get priority => 105;

  @override
  bool supports(Uri url) {
    if (!url.hasScheme || url.host.isEmpty) {
      return false;
    }

    final host = url.host.toLowerCase();
    final hostSupported = _supportedHosts.any(
      (supportedHost) =>
          host == supportedHost || host.endsWith('.$supportedHost'),
    );
    if (!hostSupported) {
      return false;
    }

    return url.path.startsWith('/e/') || url.path.startsWith('/d/');
  }

  @override
  Future<Result<List<ResolvedStream>, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        FilemoonUnsupportedHostError(
          message: 'Unsupported Filemoon host/path for URL: $url',
        ),
      );
    }

    final pathSegments = url.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    if (pathSegments.length < 2) {
      return const Failure(
        FilemoonMalformedLinkError(
          message: 'Filemoon URL does not contain required embed identifier.',
        ),
      );
    }

    try {
      final response = await _httpClient
          .get(url, headers: _requestHeaders(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return Failure(
          FilemoonTransportError(
            message:
                'Filemoon request failed with status ${response.statusCode}.',
          ),
        );
      }

      final streams = _extractStreams(response.body, resolverUrl: url);
      if (streams.isEmpty) {
        if (_isDynamicHost(url.host)) {
          final dynamicResult = await _resolveDynamicByseFlow(
            url,
            httpClient: _httpClient,
          );
          if (dynamicResult != null) {
            return dynamicResult;
          }
        }

        if (_isUnavailablePayload(response.body)) {
          return Failure(
            FilemoonTransportError(
              message:
                  'Filemoon host responded but reported source unavailable for this video.',
            ),
          );
        }

        if (_hasStreamHints(response.body)) {
          return const Failure(
            FilemoonInconsistentPayloadError(
              message:
                  'Filemoon payload includes stream hints but no valid candidates were extracted.',
            ),
          );
        }
        return const Failure(
          FilemoonParseError(
            message:
                'No stream candidates were extracted from Filemoon payload.',
          ),
        );
      }

      return Success(streams);
    } catch (error) {
      return Failure(
        FilemoonTransportError(
          message: 'Filemoon resolve request failed: $error',
        ),
      );
    }
  }
}

Future<Result<List<ResolvedStream>, KumoriyaError>?> _resolveDynamicByseFlow(
  Uri sourceUrl, {
  http.Client? httpClient,
}) async {
  final client = httpClient;
  if (client == null) {
    return null;
  }

  final code = _extractVideoCode(sourceUrl);
  if (code == null) {
    return null;
  }

  final detailsUri = sourceUrl.replace(
    path: '/api/videos/$code/embed/details',
    query: null,
    fragment: null,
  );

  try {
    final detailsResponse = await client
        .get(detailsUri, headers: _requestHeaders(sourceUrl))
        .timeout(const Duration(seconds: 15));

    if (detailsResponse.statusCode != 200) {
      return null;
    }

    final decoded = _decodeDetails(detailsResponse.body);
    if (decoded == null) {
      return null;
    }

    final errorMessage = decoded['error'];
    if (errorMessage is String && errorMessage.trim().isNotEmpty) {
      return Failure(
        FilemoonTransportError(
          message: 'Filemoon details endpoint rejected request: $errorMessage',
        ),
      );
    }

    final embedFrameRaw = decoded['embed_frame_url'];
    if (embedFrameRaw is! String || embedFrameRaw.trim().isEmpty) {
      return null;
    }

    final embedFrameUrl = Uri.tryParse(embedFrameRaw.trim());
    if (embedFrameUrl == null) {
      return null;
    }

    return await _resolveFromEmbedFrame(
      client: client,
      sourceUrl: sourceUrl,
      embedFrameUrl: embedFrameUrl,
    );
  } catch (_) {
    return null;
  }
}

Future<Result<List<ResolvedStream>, KumoriyaError>?> _resolveFromEmbedFrame({
  required http.Client client,
  required Uri sourceUrl,
  required Uri embedFrameUrl,
}) async {
  Future<Result<List<ResolvedStream>, KumoriyaError>?> fetchAndExtract(
    Uri targetUrl, {
    required Uri refererUrl,
  }) async {
    final response = await client
        .get(
          targetUrl,
          headers: _requestHeaders(targetUrl, referer: refererUrl),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      return null;
    }

    final streams = _extractStreams(response.body, resolverUrl: targetUrl);
    if (streams.isNotEmpty) {
      return Success(streams);
    }

    if (_isUnavailablePayload(response.body)) {
      return Failure(
        FilemoonTransportError(
          message:
              'Filemoon embed host responded with an unavailable/source-blocked payload.',
        ),
      );
    }

    return null;
  }

  final directResult = await fetchAndExtract(
    embedFrameUrl,
    refererUrl: sourceUrl,
  );
  if (directResult != null) {
    return directResult;
  }

  final code = _extractVideoCode(embedFrameUrl);
  if (code == null) {
    return null;
  }

  final canonicalEmbedUrl = embedFrameUrl.replace(
    path: '/e/$code',
    query: null,
    fragment: null,
  );

  if (canonicalEmbedUrl.toString() == embedFrameUrl.toString()) {
    return null;
  }

  return fetchAndExtract(canonicalEmbedUrl, refererUrl: embedFrameUrl);
}

Map<String, dynamic>? _decodeDetails(String payload) {
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {
    return null;
  }
  return null;
}

String? _extractVideoCode(Uri url) {
  final segments = url.pathSegments
      .where((segment) => segment.trim().isNotEmpty)
      .toList(growable: false);
  if (segments.length < 2) {
    return null;
  }
  return segments.last.trim();
}

Map<String, String> _requestHeaders(Uri url, {Uri? referer}) {
  final origin = '${url.scheme}://${url.host}';
  return <String, String>{
    'Referer': referer?.toString() ?? '$origin/',
    'Origin': origin,
  };
}

List<ResolvedStream> _extractStreams(
  String payload, {
  required Uri resolverUrl,
}) {
  final normalized = payload
      .replaceAll(r'\/', '/')
      .replaceAll('&amp;', '&')
      .replaceAll(r'\u0026', '&')
      .replaceAll(r'\x2F', '/');

  final streams = <ResolvedStream>[];
  final seen = <String>{};

  final sourceWithLabelPattern = RegExp(
    r'''\{[^{}]{0,200}?file\s*:\s*(?:"([^"]+)"|'([^']+)')[^{}]{0,200}?(?:label\s*:\s*(?:"([^"]+)"|'([^']+)'))?[^{}]{0,200}?\}''',
    caseSensitive: false,
    multiLine: true,
  );

  for (final match in sourceWithLabelPattern.allMatches(normalized)) {
    final file = (match.group(1) ?? match.group(2))?.trim();
    final label = (match.group(3) ?? match.group(4))?.trim();
    if (file == null || file.isEmpty) {
      continue;
    }

    final uri = _toAbsoluteUri(file, resolverUrl);
    if (uri == null || !_isPlayableUri(uri)) {
      continue;
    }

    final key = uri.toString();
    if (seen.add(key)) {
      streams.add(_toResolvedStream(uri, resolverUrl, explicitLabel: label));
    }
  }

  final keyedPattern = RegExp(
    r'''(?:file|src|source|hls)\s*[:=]\s*(?:"([^"]+)"|'([^']+)')''',
    caseSensitive: false,
    multiLine: true,
  );
  for (final match in keyedPattern.allMatches(normalized)) {
    final raw = (match.group(1) ?? match.group(2))?.trim();
    if (raw == null || raw.isEmpty) {
      continue;
    }

    final uri = _toAbsoluteUri(raw, resolverUrl);
    if (uri == null || !_isPlayableUri(uri)) {
      continue;
    }

    final key = uri.toString();
    if (seen.add(key)) {
      streams.add(_toResolvedStream(uri, resolverUrl));
    }
  }

  final directPattern = RegExp(
    r'''https?:\/\/[\w\-._~:/?#\[\]@!$&'()*+,;=%]+''',
    caseSensitive: false,
    multiLine: true,
  );
  for (final match in directPattern.allMatches(normalized)) {
    final raw = match.group(0)?.trim();
    if (raw == null || raw.isEmpty) {
      continue;
    }

    final uri = Uri.tryParse(raw);
    if (uri == null || !_isPlayableUri(uri)) {
      continue;
    }

    final key = uri.toString();
    if (seen.add(key)) {
      streams.add(_toResolvedStream(uri, resolverUrl));
    }
  }

  return streams;
}

Uri? _toAbsoluteUri(String raw, Uri baseUri) {
  final direct = Uri.tryParse(raw);
  if (direct == null) {
    return null;
  }

  if (direct.hasScheme && direct.host.isNotEmpty) {
    return direct;
  }

  if (raw.startsWith('//')) {
    return Uri.tryParse('${baseUri.scheme}:$raw');
  }

  if (raw.startsWith('/')) {
    return baseUri.replace(path: raw, query: null, fragment: null);
  }

  return null;
}

bool _isPlayableUri(Uri uri) {
  if (!uri.hasScheme || uri.host.isEmpty) {
    return false;
  }

  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return false;
  }

  final value = uri.toString().toLowerCase();
  return value.contains('.m3u8') ||
      value.contains('.mp4') ||
      value.contains('/hls/');
}

bool _hasStreamHints(String payload) {
  return RegExp(
    r'''(sources|file\s*:|hls|master\.m3u8|\.mp4)''',
    caseSensitive: false,
    multiLine: true,
  ).hasMatch(payload);
}

bool _isDynamicHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'bysekoze.com' ||
      normalized.endsWith('.bysekoze.com') ||
      normalized == 'f75s.com' ||
      normalized.endsWith('.f75s.com');
}

bool _isUnavailablePayload(String payload) {
  return RegExp(
    r'''(video source is unavailable|embedding from this domain is not allowed|we can\'t find the video)''',
    caseSensitive: false,
    multiLine: true,
  ).hasMatch(payload);
}

ResolvedStream _toResolvedStream(
  Uri url,
  Uri resolverUrl, {
  String? explicitLabel,
}) {
  final lower = url.toString().toLowerCase();
  final isHls = lower.contains('.m3u8') || lower.contains('/hls/');
  final mimeType = isHls
      ? 'application/vnd.apple.mpegurl'
      : (lower.contains('.mp4') ? 'video/mp4' : null);

  return ResolvedStream(
    url: url,
    qualityLabel: explicitLabel?.isNotEmpty == true
        ? explicitLabel
        : _inferQuality(url),
    mimeType: mimeType,
    isHls: isHls,
    headers: _requestHeaders(resolverUrl),
  );
}

String _inferQuality(Uri url) {
  final match = RegExp(
    r'(2160|1440|1080|720|480|360)p',
  ).firstMatch(url.toString().toLowerCase());
  if (match != null) {
    return '${match.group(1)}p';
  }
  if (url.toString().toLowerCase().contains('.m3u8')) {
    return 'auto';
  }
  return 'unknown';
}
