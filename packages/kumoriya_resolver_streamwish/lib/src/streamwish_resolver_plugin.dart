import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/streamwish_resolver_error.dart';

final class StreamwishResolverPlugin implements ResolverPlugin {
  StreamwishResolverPlugin({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const Set<String> _supportedHosts = <String>{
    'streamwish.to',
    'sfastwish.com',
    'wishfast.top',
    'awish.pro',
    'strwish.com',
    'playnixes.com',
    'medixiru.com',
    'hgplaycdn.com',
  };

  static const List<String> _mirrorHosts = <String>[
    'playnixes.com',
    'medixiru.com',
    'hgplaycdn.com',
  ];

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.streamwish',
    displayName: 'StreamWish Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>[
      'streamwish.to',
      'sfastwish.com',
      'wishfast.top',
      'awish.pro',
      'strwish.com',
      'playnixes.com',
      'medixiru.com',
      'hgplaycdn.com',
    ],
    baseUrls: <String>['https://streamwish.to/e/'],
  );

  @override
  int get priority => 109;

  @override
  bool supports(Uri url) {
    if (!url.hasScheme || url.host.isEmpty) {
      return false;
    }

    final host = url.host.toLowerCase();
    final supported = _supportedHosts.any(
      (item) => host == item || host.endsWith('.$item'),
    );
    if (!supported) {
      return false;
    }

    return url.path.startsWith('/e/') || url.path.startsWith('/f/');
  }

  @override
  Future<Result<List<ResolvedStream>, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        StreamwishUnsupportedHostError(
          message: 'Unsupported StreamWish host/path for URL: $url',
        ),
      );
    }

    final segments = url.pathSegments
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (segments.length < 2) {
      return const Failure(
        StreamwishMalformedLinkError(
          message: 'StreamWish URL does not contain embed id.',
        ),
      );
    }

    try {
      final response = await _httpClient
          .get(url, headers: _headers(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return Failure(
          StreamwishTransportError(
            message:
                'StreamWish request failed with status ${response.statusCode}.',
          ),
        );
      }

      final extractionPayload = _buildExtractionPayload(response.body);
      var streams = _extractStreams(extractionPayload, url);
      if (streams.isEmpty && _isLoadingShell(response.body)) {
        final fallbackStreams = await _tryKnownMirrorFallback(url);
        if (fallbackStreams.isNotEmpty) {
          streams = fallbackStreams;
        }
      }
      if (streams.isEmpty) {
        if (_hasHints(extractionPayload)) {
          return const Failure(
            StreamwishInconsistentPayloadError(
              message: 'StreamWish payload has stream hints but no valid URLs.',
            ),
          );
        }
        return const Failure(
          StreamwishParseError(
            message:
                'No stream candidates were extracted from StreamWish payload.',
          ),
        );
      }

      return Success(streams);
    } catch (error) {
      return Failure(
        StreamwishTransportError(
          message: 'StreamWish resolve request failed: $error',
        ),
      );
    }
  }

  Future<List<ResolvedStream>> _tryKnownMirrorFallback(Uri initialUrl) async {
    if (_mirrorHosts.contains(initialUrl.host.toLowerCase())) {
      return const <ResolvedStream>[];
    }

    for (final mirrorHost in _mirrorHosts) {
      final mirrorUrl = initialUrl.replace(
        scheme: 'https',
        host: mirrorHost,
        query: null,
        fragment: null,
      );

      try {
        final response = await _httpClient
            .get(mirrorUrl, headers: _headers(initialUrl))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          continue;
        }

        final payload = _buildExtractionPayload(response.body);
        final streams = _extractStreams(payload, mirrorUrl);
        if (streams.isNotEmpty) {
          return streams;
        }
      } catch (_) {
        continue;
      }
    }

    return const <ResolvedStream>[];
  }
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
    if (base == null || count == null) {
      continue;
    }

    final decoded = _decodeDeanEdwards(
      packed: rawPacked,
      base: base,
      count: count,
      dictionary: rawDictionary,
    );
    if (decoded != null && decoded.trim().isNotEmpty) {
      unpacked.add(decoded);
    }
  }
  return unpacked;
}

String? _decodeDeanEdwards({
  required String packed,
  required int base,
  required int count,
  required String dictionary,
}) {
  if (base < 2 || base > 36 || count <= 0) {
    return null;
  }

  final tokens = dictionary.split('|');
  var decoded = _decodeJsEscapes(packed);

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

  return decoded;
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
      i++;
      continue;
    }

    final next = value[i + 1];
    switch (next) {
      case 'n':
        output.write('\n');
        i += 2;
        break;
      case 'r':
        output.write('\r');
        i += 2;
        break;
      case 't':
        output.write('\t');
        i += 2;
        break;
      case '\'':
      case '"':
      case '\\':
      case '/':
        output.write(next);
        i += 2;
        break;
      case 'x':
        final hex = _readHex(value, i + 2, 2);
        if (hex != null) {
          output.write(String.fromCharCode(hex));
          i += 4;
        } else {
          output.write(next);
          i += 2;
        }
        break;
      case 'u':
        final hex = _readHex(value, i + 2, 4);
        if (hex != null) {
          output.write(String.fromCharCode(hex));
          i += 6;
        } else {
          output.write(next);
          i += 2;
        }
        break;
      default:
        output.write(next);
        i += 2;
        break;
    }
  }

  return output.toString();
}

int? _readHex(String value, int start, int length) {
  if (start + length > value.length) {
    return null;
  }
  final raw = value.substring(start, start + length);
  return int.tryParse(raw, radix: 16);
}

Map<String, String> _headers(Uri url) {
  final origin = '${url.scheme}://${url.host}';
  return <String, String>{'Referer': '$origin/', 'Origin': origin};
}

bool _isLoadingShell(String payload) {
  return payload.contains('Page is loading, please wait') &&
      payload.contains('/main.js');
}

List<ResolvedStream> _extractStreams(String payload, Uri baseUrl) {
  final normalized = payload
      .replaceAll(r'\/', '/')
      .replaceAll('&amp;', '&')
      .replaceAll(r'\u0026', '&');

  final candidates = <String>{};

  final keyed = RegExp(
    r'''(?:file|src|source|hls)\s*[:=]\s*(?:"([^"]+)"|'([^']+)')''',
    caseSensitive: false,
    multiLine: true,
  );
  for (final m in keyed.allMatches(normalized)) {
    final raw = (m.group(1) ?? m.group(2))?.trim();
    if (raw != null && raw.isNotEmpty) {
      candidates.add(raw);
    }
  }

  final direct = RegExp(
    r'''https?:\/\/[\w\-._~:/?#\[\]@!$&'()*+,;=%]+''',
    caseSensitive: false,
    multiLine: true,
  );
  for (final m in direct.allMatches(normalized)) {
    final raw = m.group(0)?.trim();
    if (raw != null && raw.isNotEmpty) {
      candidates.add(raw);
    }
  }

  final result = <ResolvedStream>[];
  final seen = <String>{};
  for (final raw in candidates) {
    final uri = _toAbsolute(raw, baseUrl);
    if (uri == null || !_isPlayable(uri)) {
      continue;
    }

    if (seen.add(uri.toString())) {
      result.add(_toResolved(uri, baseUrl));
    }
  }

  return result;
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
  return path.contains('.m3u8') ||
      path.contains('.mp4') ||
      path.contains('/hls/');
}

bool _hasHints(String payload) {
  return RegExp(
    r'''(sources|source|hls|master\.m3u8|\.mp4|eval\(function\(p,a,c,k,e,d\))''',
    caseSensitive: false,
    multiLine: true,
  ).hasMatch(payload);
}

ResolvedStream _toResolved(Uri uri, Uri baseUrl) {
  final value = uri.toString().toLowerCase();
  final isHls = value.contains('.m3u8') || value.contains('/hls/');
  final mime = isHls
      ? 'application/vnd.apple.mpegurl'
      : (value.contains('.mp4') ? 'video/mp4' : null);

  return ResolvedStream(
    url: uri,
    qualityLabel: _inferQuality(uri),
    mimeType: mime,
    isHls: isHls,
    headers: _headers(baseUrl),
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
