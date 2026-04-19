import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_common/kumoriya_resolver_common.dart';
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
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
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

    // Transport phase.
    final http.Response response;
    try {
      response = await _httpClient
          .get(url, headers: _headers(url))
          .timeout(const Duration(seconds: 8));
    } catch (error) {
      return Failure(
        YouruploadTransportError(
          message: 'YourUpload resolve request failed: $error',
        ),
      );
    }

    if (response.statusCode != 200) {
      return Failure(
        YouruploadTransportError(
          message:
              'YourUpload request failed with status ${response.statusCode}.',
        ),
      );
    }

    // Parse phase.
    try {
      final body = safeResponseBody(response);
      final streams = _extractStreams(body, baseUrl: url);
      if (streams.isEmpty) {
        if (_hasHints(body)) {
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

      return Success(ResolveResult(streams: streams));
    } catch (error) {
      return Failure(
        YouruploadParseError(
          message: 'Failed to parse YourUpload payload: $error',
        ),
      );
    }
  }
}

/// Known YourUpload CDN hosts. Streams are served from `vidcache.net` with
/// a numeric port, not from `yourupload.com` itself.
const Set<String> _youruploadCdnHosts = <String>{
  'yourupload.com',
  'vidcache.net',
};

/// Whether [uri] points to a YourUpload-owned CDN host.
///
/// Previously any URL with `.mp4`/`.m3u8` in the payload qualified as a
/// candidate, which meant analytics/ad trackers hosted elsewhere leaked
/// through. Gate by host suffix so only YourUpload-owned endpoints are
/// considered playable.
bool _isYouruploadHost(Uri uri) {
  final host = uri.host.toLowerCase();
  if (host.isEmpty) return false;
  return _youruploadCdnHosts.any(
    (allowed) => host == allowed || host.endsWith('.$allowed'),
  );
}

Map<String, String> _headers(Uri url) {
  final origin = '${url.scheme}://${url.host}';
  return <String, String>{'Referer': '$origin/', 'Origin': origin};
}

final _yuKeyedRe = RegExp(
  r'''(?:og:video|twitter:player:stream|file)\D+https?:\/\/[^\s"'<>]+''',
  caseSensitive: false,
  multiLine: true,
);

final _yuUrlRe = RegExp(r'''https?:\/\/[^\s"'<>]+''', caseSensitive: false);

final _yuDirectRe = RegExp(
  r'''https?:\/\/[^\s"'<>]+''',
  caseSensitive: false,
  multiLine: true,
);

final _yuHintsRe = RegExp(
  r'''(og:video|twitter:player:stream|jwplayerOptions|video\.mp4|file:)''',
  caseSensitive: false,
  multiLine: true,
);

List<ResolvedStream> _extractStreams(String payload, {required Uri baseUrl}) {
  final normalized = payload
      .replaceAll(r'\/', '/')
      .replaceAll('&amp;', '&')
      .replaceAll(r'\u0026', '&');
  final candidates = <String>{};

  for (final match in _yuKeyedRe.allMatches(normalized)) {
    final raw = _yuUrlRe.firstMatch(match.group(0) ?? '');
    final value = raw?.group(0)?.trim();
    if (value != null && value.isNotEmpty) {
      candidates.add(value);
    }
  }

  for (final match in _yuDirectRe.allMatches(normalized)) {
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
    // Only keep URLs served by the YourUpload CDN. Extension-based
    // filtering alone leaked ad/tracker URLs that happened to contain
    // ".mp4" query fragments.
    if (!_isYouruploadHost(uri)) {
      continue;
    }
    if (seen.add(uri.toString())) {
      streams.add(_toResolved(uri, baseUrl));
    }
  }
  return streams;
}

bool _hasHints(String payload) {
  return _yuHintsRe.hasMatch(payload);
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
