import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_resolver_common/kumoriya_resolver_common.dart'
    as common;

import 'errors/vidhide_resolver_error.dart';

/// Resolves VidHide embed links.
///
/// VidHide is a Streamwish-family host. It uses the same DeanEdwards
/// packed JS pattern with sources/file keys pointing to HLS or MP4 streams.
final class VidhideResolverPlugin implements ResolverPlugin {
  VidhideResolverPlugin({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const Set<String> _supportedHosts = <String>{
    'vidhide.com',
    'vidhidepro.com',
    'vidhidevip.com',
    'alions.pro',
    'asnow.pro',
    'alhayah.online',
    'otakuvid.online',
  };

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.vidhide',
    displayName: 'VidHide Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>[
      'vidhide.com',
      'vidhidepro.com',
      'vidhidevip.com',
      'alions.pro',
      'asnow.pro',
      'alhayah.online',
      'otakuvid.online',
    ],
    baseUrls: <String>['https://vidhide.com/e/'],
  );

  @override
  int get priority => 108;

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

    return url.path.startsWith('/e/') ||
        url.path.startsWith('/v/') ||
        url.path.startsWith('/embed/');
  }

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        VidhideUnsupportedHostError(
          message: 'Unsupported VidHide host/path for URL: $url',
        ),
      );
    }

    final segments = url.pathSegments
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (segments.length < 2) {
      return const Failure(
        VidhideMalformedLinkError(
          message: 'VidHide URL does not contain embed id.',
        ),
      );
    }

    try {
      final request = http.Request('GET', url)..headers.addAll(_headers(url));
      final response = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 8));
      final effectiveUrl = switch (response) {
        http.BaseResponseWithUrl responseWithUrl => responseWithUrl.url,
        _ => url,
      };

      if (response.statusCode != 200) {
        return Failure(
          VidhideTransportError(
            message:
                'VidHide request failed with status ${response.statusCode}.',
          ),
        );
      }

      const maxBytes = 5 * 1024 * 1024; // 5 MB
      final contentLength = response.contentLength;
      if (contentLength != null && contentLength > maxBytes) {
        response.stream.listen(null).cancel();
        return const Failure(
          VidhideTransportError(message: 'VidHide response too large.'),
        );
      }

      final payloadBytes = await response.stream.toBytes();
      final payload = utf8.decode(payloadBytes, allowMalformed: true);
      final extractionPayload = common.buildExtractionPayload(payload);
      final streams = _extractStreams(extractionPayload, effectiveUrl);
      if (streams.isEmpty) {
        if (_hasHints(extractionPayload)) {
          return const Failure(
            VidhideInconsistentPayloadError(
              message: 'VidHide payload has stream hints but no valid URLs.',
            ),
          );
        }
        return const Failure(
          VidhideParseError(
            message:
                'No stream candidates were extracted from VidHide payload.',
          ),
        );
      }

      return Success(ResolveResult(streams: streams));
    } catch (error) {
      return Failure(
        VidhideTransportError(
          message: 'VidHide resolve request failed: $error',
        ),
      );
    }
  }
}

final _vhKeyedRe = RegExp(
  r'''(?:file|src|source|hls)\s*[:=]\s*(?:"([^"]+)"|'([^']+)')''',
  caseSensitive: false,
  multiLine: true,
);

final _vhDirectRe = RegExp(
  r'''https?:\/\/[\w\-._~:/?#\[\]@!$&'()*+,;=%]+''',
  caseSensitive: false,
  multiLine: true,
);

final _vhHintsRe = RegExp(
  r'''(sources|source|hls|master\.m3u8|\.mp4|eval\(function\(p,a,c,k,e,d\))''',
  caseSensitive: false,
  multiLine: true,
);

final _vhQualityRe = RegExp(r'(2160|1440|1080|720|480|360)p');

Map<String, String> _headers(Uri url) {
  final origin = '${url.scheme}://${url.host}';
  return <String, String>{'Referer': '$origin/', 'Origin': origin};
}

List<ResolvedStream> _extractStreams(String payload, Uri baseUrl) {
  final normalized = payload
      .replaceAll(r'\/', '/')
      .replaceAll('&amp;', '&')
      .replaceAll(r'\u0026', '&');

  final candidates = <String>{};

  final keyed = _vhKeyedRe;
  for (final m in keyed.allMatches(normalized)) {
    final raw = (m.group(1) ?? m.group(2))?.trim();
    if (raw != null && raw.isNotEmpty) {
      candidates.add(raw);
    }
  }

  final direct = _vhDirectRe;
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
  return _vhHintsRe.hasMatch(payload);
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
  final match = _vhQualityRe.firstMatch(uri.toString().toLowerCase());
  if (match != null) {
    return '${match.group(1)}p';
  }
  if (uri.toString().toLowerCase().contains('.m3u8')) {
    return 'auto';
  }
  return 'unknown';
}
