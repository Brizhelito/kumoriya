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
    'mixdrop.ag',
    'mixdrop.top',
    'mixdrop.my',
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
      'mixdrop.ag',
      'mixdrop.top',
      'mixdrop.my',
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
    final hostSupported = _supportedHosts.any(
      (supported) => host == supported || host.endsWith('.$supported'),
    );
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
      final response = await _httpClient
          .get(url, headers: _headers(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return Failure(
          MixdropTransportError(
            message:
                'MixDrop request failed with status ${response.statusCode}.',
          ),
        );
      }

      final streams = _extractStreams(response.body, baseUrl: url);
      if (streams.isEmpty) {
        if (_hasHints(response.body)) {
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

Map<String, String> _headers(Uri url) {
  final origin = '${url.scheme}://${url.host}';
  return <String, String>{'Referer': '$origin/', 'Origin': origin};
}

List<ResolvedStream> _extractStreams(String payload, {required Uri baseUrl}) {
  final normalized = payload
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
      path.contains('/video/');
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
