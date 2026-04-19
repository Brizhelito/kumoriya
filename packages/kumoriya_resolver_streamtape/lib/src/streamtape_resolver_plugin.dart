import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_resolver_common/kumoriya_resolver_common.dart';

import 'errors/streamtape_resolver_error.dart';

/// Resolves Streamtape embed links into playable stream URLs.
///
/// Streamtape uses a two-part JS token concatenation pattern where the
/// real video URL is split across a `document.getElementById` call and
/// a substring token appended from a second variable.
final class StreamtapeResolverPlugin implements ResolverPlugin {
  StreamtapeResolverPlugin({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const Set<String> _supportedHosts = <String>{
    'streamtape.com',
    'streamtape.to',
    'streamtape.net',
    'streamtape.xyz',
    'streamtape.site',
    'strtape.cloud',
    'stape.fun',
    'strcloud.in',
    'tapecontent.net',
  };

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.streamtape',
    displayName: 'Streamtape Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>[
      'streamtape.com',
      'streamtape.to',
      'streamtape.net',
      'streamtape.xyz',
      'streamtape.site',
      'strtape.cloud',
      'stape.fun',
      'strcloud.in',
      'tapecontent.net',
    ],
    baseUrls: <String>['https://streamtape.com/e/'],
  );

  @override
  int get priority => 102;

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
        StreamtapeUnsupportedHostError(
          message: 'Unsupported Streamtape host/path for URL: $url',
        ),
      );
    }

    final segments = url.pathSegments
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (segments.length < 2) {
      return const Failure(
        StreamtapeMalformedLinkError(
          message: 'Streamtape URL does not contain embed id.',
        ),
      );
    }

    // Transport phase: isolate network errors from parse failures so the
    // auto-queue can classify them distinctly and skip the resolver faster
    // on repeatable transport issues.
    final http.Response response;
    try {
      response = await _httpClient
          .get(url, headers: _headers(url))
          .timeout(const Duration(seconds: 8));
    } catch (error) {
      return Failure(
        StreamtapeTransportError(
          message: 'Streamtape resolve request failed: $error',
        ),
      );
    }

    if (response.statusCode != 200) {
      return Failure(
        StreamtapeTransportError(
          message:
              'Streamtape request failed with status ${response.statusCode}.',
        ),
      );
    }

    if (!isResponseSizeAcceptable(response)) {
      return const Failure(
        StreamtapeTransportError(message: 'Streamtape response too large.'),
      );
    }

    try {
      final body = safeResponseBody(response);
      final streams = _extractStreams(body, baseUrl: url);
      if (streams.isEmpty) {
        if (_hasHints(body)) {
          return const Failure(
            StreamtapeInconsistentPayloadError(
              message:
                  'Streamtape payload has stream hints but no valid URLs were extracted.',
            ),
          );
        }
        return const Failure(
          StreamtapeParseError(
            message:
                'No stream candidates were extracted from Streamtape payload.',
          ),
        );
      }

      return Success(ResolveResult(streams: streams));
    } catch (error) {
      return Failure(
        StreamtapeParseError(
          message: 'Failed to parse Streamtape payload: $error',
        ),
      );
    }
  }
}

Map<String, String> _headers(Uri url) {
  final origin = '${url.scheme}://${url.host}';
  return <String, String>{
    'Referer': '$origin/',
    'Origin': origin,
    // Some Streamtape mirrors reject requests without a browser-like UA,
    // even for the embed page. Keep it in sync with the stream header set
    // so CDN playback receives consistent fingerprints.
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  };
}

final _stTokenRe = RegExp(
  r'''document\.getElementById\([^)]+\)\.innerHTML\s*=\s*["`']\s*(\/\/[^"'`\s]+)["`']\s*\+\s*\(\s*["`']\s*([^"'`]+)["`']\s*\)\s*\.substring\(\s*(\d+)\s*\)''',
  caseSensitive: false,
  multiLine: true,
);

final _stDirectRe = RegExp(
  r'''https?:\/\/[^\s"'<>]*?(?:tapecontent\.net|streamtape\.com)[^\s"'<>]*?\.(?:mp4|m3u8)[^\s"'<>]*''',
  caseSensitive: false,
  multiLine: true,
);

final _stHintsRe = RegExp(
  r'''(getElementById|robotlink|tapecontent|\.mp4|innerHTML)''',
  caseSensitive: false,
  multiLine: true,
);

final _stQualityRe = RegExp(r'(2160|1440|1080|720|480|360)p');

List<ResolvedStream> _extractStreams(String payload, {required Uri baseUrl}) {
  final normalized = payload
      .replaceAll(r'\/', '/')
      .replaceAll('&amp;', '&')
      .replaceAll(r'\u0026', '&');

  final streams = <ResolvedStream>[];
  final seen = <String>{};

  for (final match in _stTokenRe.allMatches(normalized)) {
    final urlBase = match.group(1)?.trim();
    final tokenFull = match.group(2)?.trim();
    final offsetStr = match.group(3)?.trim();
    if (urlBase == null || tokenFull == null || offsetStr == null) {
      continue;
    }

    final offset = int.tryParse(offsetStr);
    if (offset == null || offset >= tokenFull.length) {
      continue;
    }

    final fullUrl = 'https:$urlBase${tokenFull.substring(offset)}';
    final uri = Uri.tryParse(fullUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      continue;
    }

    if (seen.add(uri.toString())) {
      streams.add(_toResolved(uri, baseUrl));
    }
  }

  // Fallback: look for direct tapecontent.net or streamtape CDN URLs
  for (final match in _stDirectRe.allMatches(normalized)) {
    final raw = match.group(0)?.trim();
    if (raw == null || raw.isEmpty) {
      continue;
    }

    final uri = Uri.tryParse(raw);
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
  return _stHintsRe.hasMatch(payload);
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
  final match = _stQualityRe.firstMatch(uri.toString().toLowerCase());
  if (match != null) {
    return '${match.group(1)}p';
  }
  if (uri.toString().toLowerCase().contains('.m3u8')) {
    return 'auto';
  }
  return 'unknown';
}
