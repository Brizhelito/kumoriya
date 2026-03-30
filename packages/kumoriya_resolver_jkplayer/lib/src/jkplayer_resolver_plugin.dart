import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/jkplayer_resolver_error.dart';

/// Resolves `/jkplayer/um` and `/jkplayer/umv` links from JKAnime pages.
final class JkPlayerResolverPlugin implements ResolverPlugin {
  JkPlayerResolverPlugin({http.Client? httpClient, Uri? baseUri})
    : _httpClient = httpClient ?? http.Client(),
      _baseUri = baseUri ?? Uri.parse('https://jkanime.net/');

  final http.Client _httpClient;
  final Uri _baseUri;

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.jkplayer.um',
    displayName: 'JKPlayer UM Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>['jkanime.net'],
    baseUrls: <String>[
      'https://jkanime.net/jkplayer/um',
      'https://jkanime.net/jkplayer/umv',
    ],
  );

  @override
  int get priority => 100;

  @override
  bool supports(Uri url) {
    if (!_isJkAnimeHost(url)) {
      return false;
    }
    return url.path == '/jkplayer/um' || url.path == '/jkplayer/umv';
  }

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        JkPlayerUnsupportedHostError(
          message: 'Unsupported JKPlayer UM resolver path for URL: $url',
        ),
      );
    }
    if (!url.queryParameters.containsKey('e')) {
      return const Failure(
        JkPlayerMalformedLinkError(
          message:
              'JKPlayer UM source link is missing required token parameter.',
        ),
      );
    }

    return _resolveHtmlPayload(url);
  }

  Future<Result<ResolveResult, KumoriyaError>> _resolveHtmlPayload(
    Uri url,
  ) async {
    try {
      final response = await _httpClient
          .get(url, headers: _requestHeaders(_baseUri))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return Failure(
          JkPlayerTransportError(
            message:
                'JKPlayer UM request failed with status ${response.statusCode}.',
          ),
        );
      }

      final streamUrls = _extractStreamUrls(
        response.body,
        allowUnknownExtension: false,
      );
      if (streamUrls.isEmpty) {
        final hasUrlHints = _jkUrlHintsRe.hasMatch(response.body);

        if (hasUrlHints) {
          return const Failure(
            JkPlayerInconsistentPayloadError(
              message:
                  'JKPlayer UM payload has stream hints but no valid stream URLs were extracted.',
            ),
          );
        }

        return const Failure(
          JkPlayerParseError(
            message:
                'No stream URL candidates were found in JKPlayer UM payload.',
          ),
        );
      }

      final streams = streamUrls
          .map((streamUrl) => _toResolvedStream(streamUrl, _baseUri))
          .toList(growable: false);

      return Success(ResolveResult(streams: streams));
    } catch (error) {
      return Failure(
        JkPlayerTransportError(
          message: 'JKPlayer UM resolve request failed: $error',
        ),
      );
    }
  }
}

/// Resolves `/jkplayer/jk?u=...` links that usually map to jkplayers stream URLs.
final class JkPlayerJkResolverPlugin implements ResolverPlugin {
  JkPlayerJkResolverPlugin({http.Client? httpClient, Uri? baseUri})
    : _httpClient = httpClient ?? http.Client(),
      _baseUri = baseUri ?? Uri.parse('https://jkanime.net/');

  final http.Client _httpClient;
  final Uri _baseUri;

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.jkplayer.jk',
    displayName: 'JKPlayer JK Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>['jkanime.net'],
    baseUrls: <String>['https://jkanime.net/jkplayer/jk'],
  );

  @override
  int get priority => 120;

  @override
  bool supports(Uri url) {
    if (!_isJkAnimeHost(url)) {
      return false;
    }
    return url.path == '/jkplayer/jk';
  }

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        JkPlayerUnsupportedHostError(
          message: 'Unsupported JKPlayer JK resolver path for URL: $url',
        ),
      );
    }
    if (!url.queryParameters.containsKey('u')) {
      return const Failure(
        JkPlayerMalformedLinkError(
          message:
              'JKPlayer JK source link is missing required stream path parameter.',
        ),
      );
    }

    try {
      final response = await _httpClient
          .get(url, headers: _requestHeaders(_baseUri))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return Failure(
          JkPlayerTransportError(
            message:
                'JKPlayer JK request failed with status ${response.statusCode}.',
          ),
        );
      }

      final streamUrls = _extractStreamUrls(
        response.body,
        allowUnknownExtension: true,
      );

      if (streamUrls.isEmpty) {
        return const Failure(
          JkPlayerParseError(
            message: 'No stream URL was found in JKPlayer JK payload.',
          ),
        );
      }

      final streams = streamUrls
          .map((streamUrl) => _toResolvedStream(streamUrl, _baseUri))
          .toList(growable: false);
      return Success(ResolveResult(streams: streams));
    } catch (error) {
      return Failure(
        JkPlayerTransportError(
          message: 'JKPlayer JK resolve request failed: $error',
        ),
      );
    }
  }
}

final _jkUrlHintsRe = RegExp(
  r'''(m3u8|mp4|source|file|url\s*:)''',
  caseSensitive: false,
  multiLine: true,
);

final _jkDirectRe = RegExp(
  r'''https?:\/\/[^\s"'<>]+''',
  caseSensitive: false,
  multiLine: true,
);

final _jkKeyedRe = RegExp(
  r'''(?:url|file|source)\s*:\s*(?:"([^"]+)"|'([^']+)')''',
  caseSensitive: false,
  multiLine: true,
);

final _jkQualityRe = RegExp(r'(2160|1440|1080|720|480|360)p');

bool _isJkAnimeHost(Uri url) {
  final host = url.host.toLowerCase();
  return host.endsWith('jkanime.net');
}

Map<String, String> _requestHeaders(Uri baseUri) {
  return <String, String>{
    'Referer': baseUri.toString(),
    'Origin': baseUri.origin,
  };
}

ResolvedStream _toResolvedStream(Uri streamUrl, Uri baseUri) {
  final lowerPath = streamUrl.path.toLowerCase();
  final isHls = lowerPath.contains('.m3u8');
  final mimeType = isHls
      ? 'application/vnd.apple.mpegurl'
      : lowerPath.contains('.mp4')
      ? 'video/mp4'
      : null;

  return ResolvedStream(
    url: streamUrl,
    qualityLabel: _inferQualityLabel(streamUrl),
    mimeType: mimeType,
    isHls: isHls,
    headers: _requestHeaders(baseUri),
  );
}

List<Uri> _extractStreamUrls(
  String html, {
  required bool allowUnknownExtension,
}) {
  final normalized = html
      .replaceAll(r'\/', '/')
      .replaceAll('&amp;', '&')
      .replaceAll(r'\u0026', '&');

  final candidates = <String>{};

  for (final match in _jkDirectRe.allMatches(normalized)) {
    final value = match.group(0);
    if (value != null && value.isNotEmpty) {
      candidates.add(value.trim());
    }
  }

  for (final match in _jkKeyedRe.allMatches(normalized)) {
    final raw = match.group(1) ?? match.group(2);
    if (raw != null && raw.isNotEmpty) {
      candidates.add(raw.trim());
    }
  }

  final streams = <Uri>[];
  final seen = <String>{};
  for (final raw in candidates) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty || !uri.hasScheme) {
      continue;
    }

    final lowerPath = uri.path.toLowerCase();
    final isKnownMedia =
        lowerPath.contains('.m3u8') || lowerPath.contains('.mp4');
    if (!allowUnknownExtension && !isKnownMedia) {
      continue;
    }

    final key = uri.toString();
    if (seen.add(key)) {
      streams.add(uri);
    }
  }

  return streams;
}

String _inferQualityLabel(Uri url) {
  final value = url.toString().toLowerCase();
  final match = _jkQualityRe.firstMatch(value);
  if (match != null) {
    return '${match.group(1)}p';
  }
  if (value.contains('.m3u8')) {
    return 'auto';
  }
  return 'unknown';
}
