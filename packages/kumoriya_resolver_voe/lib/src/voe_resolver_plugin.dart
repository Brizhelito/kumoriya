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
      final response = await _httpClient
          .get(url, headers: _requestHeaders(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return Failure(
          VoeTransportError(
            message: 'VOE request failed with status ${response.statusCode}.',
          ),
        );
      }

      final streams = _extractStreams(
        response.body,
        url,
      ).map((stream) => _toResolvedStream(stream, url)).toList(growable: false);

      if (streams.isEmpty) {
        final hasStreamHints = _hasStreamHints(response.body);
        if (hasStreamHints) {
          return const Failure(
            VoeInconsistentPayloadError(
              message: 'VOE payload has stream hints but no valid stream URLs.',
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

Map<String, String> _requestHeaders(Uri url) {
  final origin = '${url.scheme}://${url.host}';
  return <String, String>{'Referer': '$origin/', 'Origin': origin};
}

List<Uri> _extractStreams(String payload, Uri resolverUrl) {
  final normalized = payload
      .replaceAll(r'\/', '/')
      .replaceAll('&amp;', '&')
      .replaceAll(r'\u0026', '&')
      .replaceAll(r'\x2F', '/');

  final rawCandidates = <String>{};

  final keyedPattern = RegExp(
    r'''(?:hls|file|src|source)\s*[:=]\s*(?:"([^"]+)"|'([^']+)')''',
    caseSensitive: false,
    multiLine: true,
  );
  for (final match in keyedPattern.allMatches(normalized)) {
    final value = match.group(1) ?? match.group(2);
    if (value != null && value.trim().isNotEmpty) {
      rawCandidates.add(value.trim());
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
      rawCandidates.add(value.trim());
    }
  }

  final streams = <Uri>[];
  final seen = <String>{};

  for (final raw in rawCandidates) {
    final uri = _toAbsoluteUri(raw, resolverUrl);
    if (uri == null || !_isPlayableUri(uri)) {
      continue;
    }

    final key = uri.toString();
    if (seen.add(key)) {
      streams.add(uri);
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
      value.contains('/hls/') ||
      value.contains('master.m3u8');
}

bool _hasStreamHints(String payload) {
  return RegExp(
    r'''(hls|source|sources|master\.m3u8|\.mp4)''',
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
