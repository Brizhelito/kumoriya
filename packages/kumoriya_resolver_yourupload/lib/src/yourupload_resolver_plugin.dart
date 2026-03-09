import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/yourupload_resolver_error.dart';

final class YouruploadResolverPlugin implements ResolverPlugin {
  YouruploadResolverPlugin({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const Set<String> _supportedHosts = <String>{
    'yourupload.com',
    'www.yourupload.com',
  };

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.yourupload',
    displayName: 'YourUpload Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>['yourupload.com', 'www.yourupload.com'],
    baseUrls: <String>['https://www.yourupload.com/embed/'],
  );

  @override
  int get priority => 106;

  @override
  bool supports(Uri url) {
    if (!url.hasScheme || url.host.isEmpty) {
      return false;
    }

    if (!_supportedHosts.contains(url.host.toLowerCase())) {
      return false;
    }

    return url.path.startsWith('/embed/') || url.path.startsWith('/watch/');
  }

  @override
  Future<Result<List<ResolvedStream>, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        YouruploadUnsupportedHostError(
          message: 'Unsupported YourUpload host/path for URL: $url',
        ),
      );
    }

    if (url.pathSegments.length < 2) {
      return const Failure(
        YouruploadMalformedLinkError(
          message: 'YourUpload URL does not contain a video identifier.',
        ),
      );
    }

    try {
      final response = await _httpClient
          .get(url, headers: _headers(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return Failure(
          YouruploadTransportError(
            message:
                'YourUpload request failed with status ${response.statusCode}.',
          ),
        );
      }

      final streams = _extractStreams(response.body, baseUrl: url);
      if (streams.isEmpty) {
        if (_hasHints(response.body)) {
          return const Failure(
            YouruploadInconsistentPayloadError(
              message:
                  'YourUpload payload has stream hints but no playable URLs.',
            ),
          );
        }

        return const Failure(
          YouruploadParseError(
            message: 'No stream candidates extracted from YourUpload payload.',
          ),
        );
      }

      return Success(streams);
    } catch (error) {
      return Failure(
        YouruploadTransportError(
          message: 'YourUpload resolve request failed: $error',
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

  final keyedPattern = RegExp(
    r'''(?:og:video|twitter:player:stream|file)\D+https?:\/\/[^\s"'<>]+''',
    caseSensitive: false,
    multiLine: true,
  );
  for (final match in keyedPattern.allMatches(normalized)) {
    final raw = RegExp(
      r'''https?:\/\/[^\s"'<>]+''',
      caseSensitive: false,
    ).firstMatch(match.group(0) ?? '');
    final value = raw?.group(0)?.trim();
    if (value != null && value.isNotEmpty) {
      candidates.add(value);
    }
  }

  final directPattern = RegExp(
    r'''https?:\/\/[^\s"'<>]+''',
    caseSensitive: false,
    multiLine: true,
  );
  for (final match in directPattern.allMatches(normalized)) {
    final value = match.group(0)?.trim();
    if (value != null &&
        value.isNotEmpty &&
        (value.contains('.mp4') || value.contains('.m3u8'))) {
      candidates.add(value);
    }
  }

  final streams = <ResolvedStream>[];
  final seen = <String>{};
  for (final candidate in candidates) {
    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      continue;
    }
    if (seen.add(uri.toString())) {
      streams.add(_toResolved(uri, baseUrl));
    }
  }
  return streams;
}

bool _hasHints(String payload) {
  return RegExp(
    r'''(og:video|twitter:player:stream|jwplayerOptions|video\.mp4|file:)''',
    caseSensitive: false,
    multiLine: true,
  ).hasMatch(payload);
}

ResolvedStream _toResolved(Uri uri, Uri baseUrl) {
  final lower = uri.toString().toLowerCase();
  final isHls = lower.contains('.m3u8');
  return ResolvedStream(
    url: uri,
    qualityLabel: isHls ? 'auto' : 'unknown',
    mimeType: isHls ? 'application/vnd.apple.mpegurl' : 'video/mp4',
    isHls: isHls,
    headers: _headers(baseUrl),
  );
}
