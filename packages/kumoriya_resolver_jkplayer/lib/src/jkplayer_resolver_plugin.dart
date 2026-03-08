import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/jkplayer_resolver_error.dart';

final class JkPlayerResolverPlugin implements ResolverPlugin {
  JkPlayerResolverPlugin({http.Client? httpClient, Uri? baseUri})
    : _httpClient = httpClient ?? http.Client(),
      _baseUri = baseUri ?? Uri.parse('https://jkanime.net/');

  final http.Client _httpClient;
  final Uri _baseUri;

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.jkplayer',
    displayName: 'JKPlayer Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>['jkanime.net'],
    baseUrls: <String>['https://jkanime.net/jkplayer'],
  );

  @override
  bool supports(Uri url) {
    final host = url.host.toLowerCase();
    return host.endsWith('jkanime.net') && url.path.contains('/jkplayer/');
  }

  @override
  Future<Result<List<ResolvedStream>, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        JkPlayerUnsupportedHostError(
          message: 'Unsupported resolver host/path for URL: $url',
        ),
      );
    }
    if (!url.queryParameters.containsKey('e')) {
      return const Failure(
        JkPlayerMalformedLinkError(
          message: 'JKPlayer source link is missing required token parameter.',
        ),
      );
    }

    try {
      final response = await _httpClient
          .get(
            url,
            headers: <String, String>{
              'Referer': _baseUri.toString(),
              'Origin': _baseUri.origin,
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return Failure(
          JkPlayerTransportError(
            message:
                'JKPlayer request failed with status ${response.statusCode}.',
          ),
        );
      }

      final streamUrls = _extractStreamUrls(response.body);
      if (streamUrls.isEmpty) {
        final hasUrlHints = RegExp(
          r'''(m3u8|mp4|source|file|url\s*:)''',
          caseSensitive: false,
          multiLine: true,
        ).hasMatch(response.body);

        if (hasUrlHints) {
          return const Failure(
            JkPlayerInconsistentPayloadError(
              message:
                  'JKPlayer payload has stream hints but no valid stream URLs were extracted.',
            ),
          );
        }

        return const Failure(
          JkPlayerParseError(
            message: 'No stream URL candidates were found in JKPlayer payload.',
          ),
        );
      }

      final headers = <String, String>{
        'Referer': _baseUri.toString(),
        'Origin': _baseUri.origin,
      };

      final streams = streamUrls
          .map((streamUrl) {
            final isHls = streamUrl.path.toLowerCase().contains('.m3u8');
            return ResolvedStream(
              url: streamUrl,
              qualityLabel: _inferQualityLabel(streamUrl),
              mimeType: isHls ? 'application/vnd.apple.mpegurl' : 'video/mp4',
              isHls: isHls,
              headers: headers,
            );
          })
          .toList(growable: false);

      return Success(streams);
    } catch (error) {
      return Failure(
        JkPlayerTransportError(
          message: 'JKPlayer resolve request failed: $error',
        ),
      );
    }
  }

  List<Uri> _extractStreamUrls(String html) {
    final normalized = html
        .replaceAll(r'\/', '/')
        .replaceAll('&amp;', '&')
        .replaceAll(r'\u0026', '&');

    final candidates = <String>{};

    final directPattern = RegExp(
      r'''https?:\/\/[^\s"'<>]+(?:\.m3u8|\.mp4)[^\s"'<>]*''',
      caseSensitive: false,
      multiLine: true,
    );
    for (final match in directPattern.allMatches(normalized)) {
      final value = match.group(0);
      if (value != null && value.isNotEmpty) {
        candidates.add(value.trim());
      }
    }

    final keyedPattern = RegExp(
      r'''(?:url|file|source)\s*:\s*(?:"([^"]+)"|'([^']+)')''',
      caseSensitive: false,
      multiLine: true,
    );
    for (final match in keyedPattern.allMatches(normalized)) {
      final raw = match.group(1) ?? match.group(2);
      if (raw == null || raw.isEmpty) {
        continue;
      }
      if (raw.contains('.m3u8') || raw.contains('.mp4')) {
        candidates.add(raw.trim());
      }
    }

    final streams = <Uri>[];
    for (final raw in candidates) {
      final uri = Uri.tryParse(raw);
      if (uri == null || uri.host.isEmpty || !uri.hasScheme) {
        continue;
      }
      final lowerPath = uri.path.toLowerCase();
      if (!lowerPath.contains('.m3u8') && !lowerPath.contains('.mp4')) {
        continue;
      }
      streams.add(uri);
    }

    return streams;
  }

  String _inferQualityLabel(Uri url) {
    final value = url.toString().toLowerCase();
    final match = RegExp(r'(2160|1440|1080|720|480|360)p').firstMatch(value);
    if (match != null) {
      return '${match.group(1)}p';
    }
    if (value.contains('.m3u8')) {
      return 'auto';
    }
    return 'unknown';
  }
}
