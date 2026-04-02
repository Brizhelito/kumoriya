import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_common/kumoriya_resolver_common.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/mp4upload_resolver_error.dart';

final class Mp4uploadResolverPlugin implements ResolverPlugin {
  Mp4uploadResolverPlugin({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const Set<String> _supportedHosts = <String>{
    'mp4upload.com',
    'www.mp4upload.com',
  };

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.mp4upload',
    displayName: 'Mp4Upload Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>['mp4upload.com', 'www.mp4upload.com'],
    baseUrls: <String>['https://www.mp4upload.com/embed-'],
  );

  @override
  int get priority => 103;

  @override
  bool supports(Uri url) {
    if (!url.hasScheme || url.host.isEmpty) {
      return false;
    }

    final host = url.host.toLowerCase();
    if (!_supportedHosts.contains(host)) {
      return false;
    }

    return url.path.contains('/embed-') || url.path.endsWith('.html');
  }

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        Mp4uploadUnsupportedHostError(
          message: 'Unsupported Mp4Upload host/path for URL: $url',
        ),
      );
    }

    if (url.path.trim().isEmpty) {
      return const Failure(
        Mp4uploadMalformedLinkError(message: 'Mp4Upload URL path is empty.'),
      );
    }

    try {
      final response = await _httpClient
          .get(url, headers: _headers(url))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return Failure(
          Mp4uploadTransportError(
            message:
                'Mp4Upload request failed with status ${response.statusCode}.',
          ),
        );
      }

      final streams = _extractStreams(safeResponseBody(response), baseUrl: url);
      if (streams.isEmpty) {
        if (_hasHints(safeResponseBody(response))) {
          return const Failure(
            Mp4uploadInconsistentPayloadError(
              message: 'Mp4Upload payload has hints but no valid stream URLs.',
            ),
          );
        }

        return const Failure(
          Mp4uploadParseError(
            message: 'No stream candidates extracted from Mp4Upload payload.',
          ),
        );
      }

      return Success(ResolveResult(streams: streams));
    } catch (error) {
      return Failure(
        Mp4uploadTransportError(
          message: 'Mp4Upload resolve request failed: $error',
        ),
      );
    }
  }
}

Map<String, String> _headers(Uri url) {
  final origin = '${url.scheme}://${url.host}';
  return <String, String>{'Referer': '$origin/', 'Origin': origin};
}

final _mp4KeyedRe = RegExp(
  r'''(?:file|src|source)\s*[:=]\s*(?:"([^"]+)"|'([^']+)')''',
  caseSensitive: false,
  multiLine: true,
);

final _mp4DirectRe = RegExp(
  r'''https?:\/\/[\w\-._~:/?#\[\]@!$&'()*+,;=%]+''',
  caseSensitive: false,
  multiLine: true,
);

List<ResolvedStream> _extractStreams(String payload, {required Uri baseUrl}) {
  final normalized = payload
      .replaceAll(r'\/', '/')
      .replaceAll('&amp;', '&')
      .replaceAll(r'\u0026', '&');

  final candidates = <String>{};

  for (final m in _mp4KeyedRe.allMatches(normalized)) {
    final raw = (m.group(1) ?? m.group(2))?.trim();
    if (raw != null && raw.isNotEmpty) {
      candidates.add(raw);
    }
  }

  for (final m in _mp4DirectRe.allMatches(normalized)) {
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
  return path.contains('.mp4') || path.contains('.m3u8');
}

final _mp4HintsRe = RegExp(
  r'''(source|sources|file\s*:|\.mp4|\.m3u8)''',
  caseSensitive: false,
  multiLine: true,
);

final _qualityRe = RegExp(r'(2160|1440|1080|720|480|360)p');

bool _hasHints(String payload) {
  return _mp4HintsRe.hasMatch(payload);
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
  final match = _qualityRe.firstMatch(uri.toString().toLowerCase());
  if (match != null) {
    return '${match.group(1)}p';
  }
  if (uri.toString().toLowerCase().contains('.m3u8')) {
    return 'auto';
  }
  return 'unknown';
}
