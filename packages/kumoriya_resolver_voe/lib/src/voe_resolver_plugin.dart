import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/voe_resolver_error.dart';

final class VoeResolverPlugin implements ResolverPlugin {
  VoeResolverPlugin({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

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
  Future<Result<List<ResolvedStream>, KumoriyaError>> resolve(Uri url) async {
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
      var currentUrl = url;
      Uri? referer;

      for (var hop = 0; hop < 3; hop++) {
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

        payloads.add(_FetchedPayload(url: currentUrl, body: response.body));

        final redirectUrl = _extractJavascriptRedirect(
          response.body,
          baseUrl: currentUrl,
        );
        if (redirectUrl == null ||
            payloads.any(
              (item) => item.url.toString() == redirectUrl.toString(),
            )) {
          break;
        }

        referer = currentUrl;
        currentUrl = redirectUrl;
      }

      final extractionPayload = payloads.map((item) => item.body).join('\n');
      final streams = _extractStreams(extractionPayload, payloads.last.url)
          .map((stream) => _toResolvedStream(stream, payloads.last.url))
          .toList(growable: false);

      if (streams.isEmpty) {
        final tokenGated = _isTokenGatedPayload(extractionPayload);
        final hasStreamHints = _hasStreamHints(extractionPayload);
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

      return Success(streams);
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
      .replaceAll(r'\u0026', '&');

  final patterns = <RegExp>[
    RegExp(
      r'''(?:window\.)?location(?:\.href)?\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ),
    RegExp(
      r'''location\.replace\(\s*["']([^"']+)["']\s*\)''',
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
    final decoded = Uri.decodeFull(encoded);
    final bytes = UriData.parse('data:;base64,$decoded').contentAsBytes();
    if (bytes.isEmpty) {
      return null;
    }
    return String.fromCharCodes(bytes);
  } catch (_) {
    return null;
  }
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
