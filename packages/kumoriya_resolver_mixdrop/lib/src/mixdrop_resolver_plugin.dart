import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/mixdrop_resolver_error.dart';

final class MixdropResolverPlugin implements ResolverPlugin {
  MixdropResolverPlugin({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const Set<String> _supportedHosts = <String>{
    'mixdrop.co',
    'mixdrop.to',
    'mxdrop.to',
    'mixdrop.is',
    'mixdrop.ag',
    'mixdrop.top',
    'mixdrop.my',
    'm1xdrop.bz',
    'mdbekjwqa.pw',
  };

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.mixdrop',
    displayName: 'MixDrop Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>[
      'mixdrop.co',
      'mixdrop.to',
      'mxdrop.to',
      'mixdrop.is',
      'mixdrop.ag',
      'mixdrop.top',
      'mixdrop.my',
      'm1xdrop.bz',
      'mdbekjwqa.pw',
    ],
    baseUrls: <String>['https://mixdrop.co/e/'],
  );

  @override
  int get priority => 104;

  @override
  bool supports(Uri url) {
    if (!url.hasScheme || url.host.isEmpty) {
      return false;
    }

    final host = url.host.toLowerCase();
    final hostSupported = _isSupportedHost(host, _supportedHosts);
    if (!hostSupported) {
      return false;
    }

    return url.path.startsWith('/e/') || url.path.startsWith('/f/');
  }

  @override
  Future<Result<List<ResolvedStream>, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        MixdropUnsupportedHostError(
          message: 'Unsupported MixDrop host/path for URL: $url',
        ),
      );
    }

    final segments = url.pathSegments
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (segments.length < 2) {
      return const Failure(
        MixdropMalformedLinkError(
          message: 'MixDrop URL does not contain embed id.',
        ),
      );
    }

    try {
      final request = http.Request('GET', url)..headers.addAll(_headers(url));
      final response = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 15));
      final effectiveEmbedUrl = switch (response) {
        http.BaseResponseWithUrl responseWithUrl => responseWithUrl.url,
        _ => url,
      };

      if (response.statusCode != 200) {
        return Failure(
          MixdropTransportError(
            message:
                'MixDrop request failed with status ${response.statusCode}.',
          ),
        );
      }

      final payload = await response.stream.bytesToString();
      final streams = _extractStreams(payload, baseUrl: effectiveEmbedUrl);
      if (streams.isEmpty) {
        if (_hasHints(payload)) {
          return const Failure(
            MixdropInconsistentPayloadError(
              message:
                  'MixDrop payload has stream hints but no valid candidates.',
            ),
          );
        }
        return const Failure(
          MixdropParseError(
            message: 'No stream candidates extracted from MixDrop payload.',
          ),
        );
      }

      return Success(streams);
    } catch (error) {
      return Failure(
        MixdropTransportError(
          message: 'MixDrop resolve request failed: $error',
        ),
      );
    }
  }
}

const String _defaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36';

bool _isSupportedHost(String host, Set<String> knownHosts) {
  if (knownHosts.any((supported) => host == supported)) {
    return true;
  }

  if (knownHosts.any((supported) => host.endsWith('.$supported'))) {
    return true;
  }

  return false;
}

Map<String, String> _headers(Uri url) {
  final origin = '${url.scheme}://${url.host}';
  return <String, String>{
    'Referer': '$origin/',
    'Origin': origin,
    'User-Agent': _defaultUserAgent,
  };
}

Map<String, String> _playbackHeaders(Uri embedUrl) {
  final referer = '${embedUrl.scheme}://${embedUrl.host}/';
  return <String, String>{
    'Referer': referer,
    'User-Agent': _defaultUserAgent,
    'Range': 'bytes=0-',
    'Accept-Encoding': 'identity;q=1, *;q=0',
  };
}

List<ResolvedStream> _extractStreams(String payload, {required Uri baseUrl}) {
  final extractionPayload = _buildExtractionPayload(payload);
  final normalized = extractionPayload
      .replaceAll(r'\/', '/')
      .replaceAll('&amp;', '&')
      .replaceAll(r'\u0026', '&');

  final candidates = <String>{};

  final mdCorePattern = RegExp(
    r'''(?:MDCore\.wurl|wurl)\s*=\s*(?:"([^"]+)"|'([^']+)')''',
    caseSensitive: false,
    multiLine: true,
  );
  for (final m in mdCorePattern.allMatches(normalized)) {
    final raw = (m.group(1) ?? m.group(2))?.trim();
    if (raw != null && raw.isNotEmpty) {
      candidates.add(raw);
    }
  }

  final keyedPattern = RegExp(
    r'''(?:file|src|source|hls)\s*[:=]\s*(?:"([^"]+)"|'([^']+)')''',
    caseSensitive: false,
    multiLine: true,
  );
  for (final m in keyedPattern.allMatches(normalized)) {
    final raw = (m.group(1) ?? m.group(2))?.trim();
    if (raw != null && raw.isNotEmpty) {
      candidates.add(raw);
    }
  }

  final directPattern = RegExp(
    r'''https?:\/\/[\w\-._~:/?#\[\]@!$&'()*+,;=%]+''',
    caseSensitive: false,
    multiLine: true,
  );
  for (final m in directPattern.allMatches(normalized)) {
    final raw = m.group(0)?.trim();
    if (raw != null && raw.isNotEmpty) {
      candidates.add(raw);
    }
  }

  final streams = <ResolvedStream>[];
  final seen = <String>{};
  for (final raw in candidates) {
    final uri = _toAbsolute(raw, baseUrl);
    if (uri == null || !_isPlayable(uri)) {
      continue;
    }

    if (seen.add(uri.toString())) {
      streams.add(_toResolved(uri, baseUrl));
    }
  }

  return streams;
}

String _buildExtractionPayload(String payload) {
  final parts = <String>[payload];
  for (final unpacked in _unpackDeanEdwardsPayloads(payload)) {
    if (unpacked.trim().isNotEmpty) {
      parts.add(unpacked);
    }
  }
  return parts.join('\n');
}

List<String> _unpackDeanEdwardsPayloads(String payload) {
  final pattern = RegExp(
    r"""eval\(function\(p,a,c,k,e,d\)\{[\s\S]*?return p\}\('([\s\S]*?)',\s*(\d+),\s*(\d+),\s*'([\s\S]*?)'\.split\('\|'\)""",
    caseSensitive: false,
    multiLine: true,
  );

  final unpacked = <String>[];
  for (final match in pattern.allMatches(payload)) {
    final rawPacked = match.group(1);
    final rawBase = match.group(2);
    final rawCount = match.group(3);
    final rawDictionary = match.group(4);
    if (rawPacked == null ||
        rawBase == null ||
        rawCount == null ||
        rawDictionary == null) {
      continue;
    }

    final base = int.tryParse(rawBase);
    final count = int.tryParse(rawCount);
    if (base == null || count == null || base < 2 || base > 36 || count <= 0) {
      continue;
    }

    final tokens = rawDictionary.split('|');
    var decoded = rawPacked.replaceAll(r'\/', '/');
    for (var i = count - 1; i >= 0; i--) {
      if (i >= tokens.length) {
        continue;
      }
      final replacement = tokens[i];
      if (replacement.isEmpty) {
        continue;
      }
      final key = i.toRadixString(base);
      decoded = decoded.replaceAll(
        RegExp(r'\b' + RegExp.escape(key) + r'\b'),
        replacement,
      );
    }

    if (decoded.trim().isNotEmpty) {
      unpacked.add(decoded);
    }
  }
  return unpacked;
}

Uri? _toAbsolute(String raw, Uri baseUrl) {
  final parsed = Uri.tryParse(raw);
  if (parsed == null) {
    return null;
  }

  if (parsed.hasScheme && parsed.host.isNotEmpty) {
    return parsed;
  }

  if (raw.startsWith('//')) {
    return Uri.tryParse('${baseUrl.scheme}:$raw');
  }

  if (raw.startsWith('/')) {
    return baseUrl.replace(path: raw, query: null, fragment: null);
  }

  return null;
}

bool _isPlayable(Uri uri) {
  if (!uri.hasScheme || uri.host.isEmpty) {
    return false;
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return false;
  }

  final path = uri.path.toLowerCase();
  if (path.contains('.m3u8') ||
      path.contains('.mp4') ||
      path.contains('/video/')) {
    return true;
  }

  final host = uri.host.toLowerCase();
  if (host.endsWith('.mxcontent.net') && uri.pathSegments.length >= 2) {
    return true;
  }

  return false;
}

bool _hasHints(String payload) {
  return RegExp(
    r'''(wurl|MDCore|source|sources|\.mp4|\.m3u8)''',
    caseSensitive: false,
    multiLine: true,
  ).hasMatch(payload);
}

ResolvedStream _toResolved(Uri uri, Uri baseUrl) {
  final value = uri.toString().toLowerCase();
  final isHls = value.contains('.m3u8');
  final mimeType = isHls
      ? 'application/vnd.apple.mpegurl'
      : (value.contains('.mp4') ? 'video/mp4' : null);

  return ResolvedStream(
    url: uri,
    qualityLabel: _inferQuality(uri),
    mimeType: mimeType,
    isHls: isHls,
    headers: _playbackHeaders(baseUrl),
  );
}

String _inferQuality(Uri uri) {
  final match = RegExp(
    r'(2160|1440|1080|720|480|360)p',
  ).firstMatch(uri.toString().toLowerCase());
  if (match != null) {
    return '${match.group(1)}p';
  }
  if (uri.toString().toLowerCase().contains('.m3u8')) {
    return 'auto';
  }
  return 'unknown';
}
