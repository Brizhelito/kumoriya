import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_resolver_common/kumoriya_resolver_common.dart'
    as common;

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
    'sfastwish.com',
    'awish.pro',
    'wishfast.top',
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
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
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
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        // Primary host failed — try mirror hosts before giving up.
        final fallbackStreams = await _tryKnownMirrorFallback(url);
        if (fallbackStreams.isNotEmpty) {
          return Success(ResolveResult(streams: fallbackStreams));
        }
        return Failure(
          StreamwishTransportError(
            message:
                'StreamWish request failed with status ${response.statusCode}.',
          ),
        );
      }

      final extractionPayload = common.buildExtractionPayload(
        common.safeResponseBody(response),
      );
      var streams = _extractStreams(extractionPayload, url);
      if (streams.isEmpty &&
          _isLoadingShell(common.safeResponseBody(response))) {
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

      return Success(ResolveResult(streams: streams));
    } catch (error) {
      // Network/timeout failure — try mirror hosts before giving up.
      final fallbackStreams = await _tryKnownMirrorFallback(url);
      if (fallbackStreams.isNotEmpty) {
        return Success(ResolveResult(streams: fallbackStreams));
      }
      return Failure(
        StreamwishTransportError(
          message: 'StreamWish resolve request failed: $error',
        ),
      );
    }
  }

  /// Try mirrors in parallel for faster fallback (was sequential = 3×15s worst
  /// case, now max 15s total for all mirrors).
  Future<List<ResolvedStream>> _tryKnownMirrorFallback(Uri initialUrl) async {
    if (_mirrorHosts.contains(initialUrl.host.toLowerCase())) {
      return const <ResolvedStream>[];
    }

    final completer = Completer<List<ResolvedStream>>();
    var remaining = _mirrorHosts.length;

    for (final mirrorHost in _mirrorHosts) {
      final mirrorUrl = initialUrl.replace(
        scheme: 'https',
        host: mirrorHost,
        query: null,
        fragment: null,
      );

      () async {
        try {
          final response = await _httpClient
              .get(mirrorUrl, headers: _headers(initialUrl))
              .timeout(const Duration(seconds: 10));
          if (response.statusCode != 200) {
            return const <ResolvedStream>[];
          }

          final payload = common.buildExtractionPayload(
            common.safeResponseBody(response),
          );
          return _extractStreams(payload, mirrorUrl);
        } catch (_) {
          return const <ResolvedStream>[];
        }
      }().then((streams) {
        if (streams.isNotEmpty && !completer.isCompleted) {
          completer.complete(streams);
          return;
        }

        remaining -= 1;
        if (remaining == 0 && !completer.isCompleted) {
          completer.complete(const <ResolvedStream>[]);
        }
      });
    }

    return completer.future;
  }
}

final _swKeyedRe = RegExp(
  r'''(?:file|src|source|hls)\s*[:=]\s*(?:"([^"]+)"|'([^']+)')''',
  caseSensitive: false,
  multiLine: true,
);

final _swDirectRe = RegExp(
  r'''https?:\/\/[\w\-._~:/?#\[\]@!$&'()*+,;=%]+''',
  caseSensitive: false,
  multiLine: true,
);

final _swHintsRe = RegExp(
  r'''(sources|source|hls|master\.m3u8|\.mp4|eval\(function\(p,a,c,k,e,d\))''',
  caseSensitive: false,
  multiLine: true,
);

final _swQualityRe = RegExp(r'(2160|1440|1080|720|480|360)p');

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

  final keyed = _swKeyedRe;
  for (final m in keyed.allMatches(normalized)) {
    final raw = (m.group(1) ?? m.group(2))?.trim();
    if (raw != null && raw.isNotEmpty) {
      candidates.add(raw);
    }
  }

  final direct = _swDirectRe;
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
  return _swHintsRe.hasMatch(payload);
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
  final match = _swQualityRe.firstMatch(uri.toString().toLowerCase());
  if (match != null) {
    return '${match.group(1)}p';
  }
  if (uri.toString().toLowerCase().contains('.m3u8')) {
    return 'auto';
  }
  return 'unknown';
}
