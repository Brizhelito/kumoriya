import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/voe_resolver_error.dart';

final class VoeResolverPlugin implements ResolverPlugin {
  VoeResolverPlugin({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  static const int _maxRedirectDepth = 5;

  static const Set<String> _supportedHosts = <String>{
    'voe.sx',
    'voe.uno',
    'voe.cx',
    'voe.sh',
    'voe.network',
    'voe.su',
    'lancewhosedifficult.com',
  };

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.voe',
    displayName: 'VOE Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>[
      'voe.sx',
      'voe.uno',
      'voe.cx',
      'voe.sh',
      'voe.network',
      'voe.su',
      'lancewhosedifficult.com',
    ],
    baseUrls: <String>['https://voe.sx/e/'],
  );

  @override
  int get priority => 110;

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

    return url.path.startsWith('/e/') || url.path.startsWith('/v/');
  }

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        VoeUnsupportedHostError(
          message: 'Unsupported VOE host/path for URL: $url',
        ),
      );
    }

    final pathSegments = url.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    if (pathSegments.length < 2) {
      return const Failure(
        VoeMalformedLinkError(
          message: 'VOE URL does not contain an embed identifier.',
        ),
      );
    }

    try {
      final payloads = <_FetchedPayload>[];
      var currentUrl = _normalizeEmbedUrl(url);
      Uri? referer;
      final visitedUrls = <String>{currentUrl.toString()};
      String? redirectLimitMessage;

      for (var hop = 0; hop < _maxRedirectDepth; hop++) {
        final response = await _httpClient
            .get(currentUrl, headers: _requestHeaders(currentUrl, referer))
            .timeout(const Duration(seconds: 15));

        if (response.statusCode != 200) {
          return Failure(
            VoeTransportError(
              message:
                  'VOE request failed with status ${response.statusCode} for $currentUrl.',
            ),
          );
        }

        final extractionPayload = _buildExtractionPayload(response.body);
        payloads.add(_FetchedPayload(url: currentUrl, body: extractionPayload));

        final redirectUrl = _extractJavascriptRedirect(
          extractionPayload,
          baseUrl: currentUrl,
        );
        if (redirectUrl == null) {
          break;
        }

        final normalizedRedirect = _normalizeEmbedUrl(redirectUrl);
        final redirectKey = normalizedRedirect.toString();
        if (!visitedUrls.add(redirectKey)) {
          redirectLimitMessage =
              'VOE redirect loop detected while resolving $url at $redirectKey.';
          break;
        }

        if (hop >= _maxRedirectDepth - 1) {
          redirectLimitMessage =
              'VOE redirect depth exceeded ($_maxRedirectDepth) while resolving $url.';
          break;
        }

        referer = currentUrl;
        currentUrl = normalizedRedirect;
      }

      if (redirectLimitMessage != null) {
        return Failure(VoeRedirectLimitError(message: redirectLimitMessage));
      }

      final extractionPayload = payloads.map((item) => item.body).join('\n');
      final streams = _extractStreams(extractionPayload, payloads.last.url)
          .map((stream) => _toResolvedStream(stream, payloads.last.url))
          .toList(growable: false);

      if (streams.isEmpty) {
        final sessionGated = _isSessionGatedPayload(extractionPayload);
        final tokenGated = _isTokenGatedPayload(extractionPayload);
        final hasStreamHints = _hasStreamHints(extractionPayload);
        if (sessionGated) {
          return const Failure(
            VoeSessionGatedError(
              message:
                  'VOE payload requires session/runtime token flow not reproducible from static payload.',
            ),
          );
        }
        if (hasStreamHints || tokenGated) {
          return const Failure(
            VoeInconsistentPayloadError(
              message:
                  'VOE payload has stream hints/token flow but no valid stream URLs.',
            ),
          );
        }

        return const Failure(
          VoeParseError(
            message: 'No stream URLs were extracted from VOE payload.',
          ),
        );
      }

      return Success(ResolveResult(streams: streams));
    } catch (error) {
      return Failure(
        VoeTransportError(message: 'VOE resolve request failed: $error'),
      );
    }
  }
}

final class _FetchedPayload {
  const _FetchedPayload({required this.url, required this.body});

  final Uri url;
  final String body;
}

Map<String, String> _requestHeaders(Uri url, Uri? referer) {
  final origin = '${url.scheme}://${url.host}';
  final resolvedReferer = referer == null ? '$origin/' : referer.toString();
  return <String, String>{'Referer': resolvedReferer, 'Origin': origin};
}

Uri? _extractJavascriptRedirect(String payload, {required Uri baseUrl}) {
  final normalized = payload
      .replaceAll(r'\/', '/')
      .replaceAll('&amp;', '&')
      .replaceAll(r'\u0026', '&')
      .replaceAll(r'\x2F', '/');

  final patterns = <RegExp>[
    RegExp(
      r'''(?:window\.)?location(?:\.href)?\s*=\s*(?:["'`])([^"'`]+)(?:["'`])''',
      caseSensitive: false,
    ),
    RegExp(
      r'''location\.replace\(\s*(?:["'`])([^"'`]+)(?:["'`])\s*\)''',
      caseSensitive: false,
    ),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(normalized);
    final candidate = match?.group(1)?.trim();
    if (candidate == null || candidate.isEmpty) {
      continue;
    }

    final absolute = _toAbsoluteUri(candidate, baseUrl);
    if (absolute != null) {
      return absolute;
    }
  }

  return null;
}

List<Uri> _extractStreams(String payload, Uri resolverUrl) {
  final normalized = payload
      .replaceAll(r'\/', '/')
      .replaceAll('&amp;', '&')
      .replaceAll(r'\u0026', '&')
      .replaceAll(r'\x2F', '/');

  final rawCandidates = <String>{};

  final keyedPattern = RegExp(
    r'''(?:hls|file|src|source|url)\s*[:=]\s*(?:"([^"]+)"|'([^']+)')''',
    caseSensitive: false,
    multiLine: true,
  );
  for (final match in keyedPattern.allMatches(normalized)) {
    final value = match.group(1) ?? match.group(2);
    if (value != null && value.trim().isNotEmpty) {
      rawCandidates.add(_cleanCandidate(value));
    }
  }

  final directUrlPattern = RegExp(
    r'''https?:\/\/[\w\-._~:/?#\[\]@!$&'()*+,;=%]+''',
    caseSensitive: false,
    multiLine: true,
  );
  for (final match in directUrlPattern.allMatches(normalized)) {
    final value = match.group(0);
    if (value != null && value.trim().isNotEmpty) {
      rawCandidates.add(_cleanCandidate(value));
    }
  }

  final sourceTagPattern = RegExp(
    r'''<source[^>]+src\s*=\s*(?:"([^"]+)"|'([^']+)')''',
    caseSensitive: false,
    multiLine: true,
  );
  for (final match in sourceTagPattern.allMatches(normalized)) {
    final value = match.group(1) ?? match.group(2);
    if (value != null && value.trim().isNotEmpty) {
      rawCandidates.add(_cleanCandidate(value));
    }
  }

  rawCandidates.addAll(_extractBase64EmbeddedCandidates(normalized));

  final streams = <Uri>[];
  final seen = <String>{};

  for (final raw in rawCandidates) {
    final expandedCandidates = <String>{raw};
    if (raw.contains('%')) {
      expandedCandidates.add(Uri.decodeFull(raw));
    }

    for (final expanded in expandedCandidates) {
      final uri = _toAbsoluteUri(expanded, resolverUrl);
      if (uri == null || !_isPlayableUri(uri) || _isKnownPlaceholderUri(uri)) {
        continue;
      }

      final key = uri.toString();
      if (seen.add(key)) {
        streams.add(uri);
      }
    }
  }

  return streams;
}

Set<String> _extractBase64EmbeddedCandidates(String payload) {
  final candidates = <String>{};
  final encodedPattern = RegExp(
    r'''["']([A-Za-z0-9+/=]{24,})["']''',
    caseSensitive: false,
    multiLine: true,
  );

  for (final match in encodedPattern.allMatches(payload)) {
    final encoded = match.group(1);
    if (encoded == null || encoded.isEmpty) {
      continue;
    }

    final decoded = _tryDecodeBase64(encoded);
    if (decoded == null || decoded.isEmpty) {
      continue;
    }

    final normalizedDecoded = decoded
        .replaceAll(r'\/', '/')
        .replaceAll('&amp;', '&')
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\x2F', '/');

    final directUrlPattern = RegExp(
      r'''https?:\/\/[\w\-._~:/?#\[\]@!$&'()*+,;=%]+''',
      caseSensitive: false,
      multiLine: true,
    );
    for (final directMatch in directUrlPattern.allMatches(normalizedDecoded)) {
      final value = directMatch.group(0);
      if (value != null && value.trim().isNotEmpty) {
        candidates.add(_cleanCandidate(value));
      }
    }
  }

  return candidates;
}

String? _tryDecodeBase64(String encoded) {
  try {
    final normalized = _normalizeBase64(encoded);
    if (normalized.isEmpty) {
      return null;
    }
    final bytes = UriData.parse('data:;base64,$normalized').contentAsBytes();
    if (bytes.isEmpty) {
      return null;
    }
    return String.fromCharCodes(bytes);
  } catch (_) {
    return null;
  }
}

String _normalizeBase64(String value) {
  final clean = value.replaceAll(RegExp(r'\s+'), '');
  final remainder = clean.length % 4;
  if (remainder == 0) {
    return clean;
  }
  return clean.padRight(clean.length + (4 - remainder), '=');
}

Uri? _toAbsoluteUri(String raw, Uri baseUri) {
  final cleaned = _cleanCandidate(raw);
  final direct = Uri.tryParse(cleaned);
  if (direct == null) {
    return null;
  }

  if (direct.hasScheme && direct.host.isNotEmpty) {
    return direct;
  }

  if (cleaned.startsWith('//')) {
    return Uri.tryParse('${baseUri.scheme}:$cleaned');
  }

  if (cleaned.startsWith('/')) {
    return baseUri.replace(path: cleaned, query: null, fragment: null);
  }

  return null;
}

String _cleanCandidate(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'''^[\'"]+'''), '')
      .replaceAll(RegExp(r'''[\'"),;\]]+$'''), '');
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
      value.contains('/hls/') ||
      value.contains('/api/video/') ||
      value.contains('master.m3u8');
}

bool _isKnownPlaceholderUri(Uri uri) {
  final host = uri.host.toLowerCase();
  if (host == 'test-videos.co.uk' || host.endsWith('.test-videos.co.uk')) {
    return true;
  }

  final value = uri.toString().toLowerCase();
  if (value.contains('big_buck_bunny')) {
    return true;
  }

  return false;
}

bool _hasStreamHints(String payload) {
  return RegExp(
    r'''(hls|source|sources|master\.m3u8|\.mp4|api\/video)''',
    caseSensitive: false,
    multiLine: true,
  ).hasMatch(payload);
}

bool _isTokenGatedPayload(String payload) {
  return RegExp(
    r'''(api2\/session\/generate-token|session\/sync\?|guestMode|permanentToken)''',
    caseSensitive: false,
    multiLine: true,
  ).hasMatch(payload);
}

bool _isSessionGatedPayload(String payload) {
  final hasEngineUpdate = RegExp(
    r'''(\/engine\/update|loader\.[a-z0-9]+\.js|meta name="csrf-token")''',
    caseSensitive: false,
    multiLine: true,
  ).hasMatch(payload);
  if (!hasEngineUpdate) {
    return false;
  }

  return RegExp(
    r'''(guestMode|permanentToken|test-videos\.co\.uk|Big_Buck_Bunny|api2\/session\/generate-token)''',
    caseSensitive: false,
    multiLine: true,
  ).hasMatch(payload);
}

Uri _normalizeEmbedUrl(Uri url) {
  if (url.path.startsWith('/v/')) {
    return url.replace(path: url.path.replaceFirst('/v/', '/e/'));
  }
  return url;
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
    var decoded = _decodeJsEscapes(rawPacked);

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

String _decodeJsEscapes(String value) {
  final output = StringBuffer();
  var i = 0;
  while (i < value.length) {
    final char = value[i];
    if (char != '\\') {
      output.write(char);
      i++;
      continue;
    }

    if (i + 1 >= value.length) {
      output.write(char);
      break;
    }

    final next = value[i + 1];
    if (next == 'x' && i + 3 < value.length) {
      final hex = value.substring(i + 2, i + 4);
      final code = int.tryParse(hex, radix: 16);
      if (code != null) {
        output.writeCharCode(code);
        i += 4;
        continue;
      }
    }

    if (next == 'u' && i + 5 < value.length) {
      final hex = value.substring(i + 2, i + 6);
      final code = int.tryParse(hex, radix: 16);
      if (code != null) {
        output.writeCharCode(code);
        i += 6;
        continue;
      }
    }

    if (next == '/') {
      output.write('/');
      i += 2;
      continue;
    }

    output.write(next);
    i += 2;
  }
  return output.toString();
}

ResolvedStream _toResolvedStream(Uri url, Uri resolverUrl) {
  final lower = url.toString().toLowerCase();
  final isHls = lower.contains('.m3u8') || lower.contains('/hls/');
  final mimeType = isHls
      ? 'application/vnd.apple.mpegurl'
      : (lower.contains('.mp4') ? 'video/mp4' : null);

  return ResolvedStream(
    url: url,
    qualityLabel: _inferQuality(url),
    mimeType: mimeType,
    isHls: isHls,
    headers: _requestHeaders(resolverUrl, null),
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
