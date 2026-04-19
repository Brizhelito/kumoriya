import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_common/kumoriya_resolver_common.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/pixeldrain_resolver_error.dart';

final class PixeldrainResolverPlugin implements ResolverPlugin {
  PixeldrainResolverPlugin({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const Set<String> _supportedHosts = <String>{
    'pixeldrain.com',
    'www.pixeldrain.com',
  };

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.pixeldrain',
    displayName: 'Pixeldrain Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>['pixeldrain.com', 'www.pixeldrain.com'],
    baseUrls: <String>['https://pixeldrain.com/u/'],
  );

  @override
  int get priority => 107;

  @override
  bool supports(Uri url) {
    if (!url.hasScheme || url.host.isEmpty) {
      return false;
    }
    if (!_supportedHosts.contains(url.host.toLowerCase())) {
      return false;
    }
    return url.path.startsWith('/u/') || url.path.startsWith('/api/file/');
  }

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        PixeldrainUnsupportedHostError(
          message: 'Unsupported Pixeldrain host/path for URL: $url',
        ),
      );
    }

    final directApi = _extractApiUrlFromInput(url);
    if (directApi != null) {
      return Success(
        ResolveResult(streams: <ResolvedStream>[_toResolved(directApi, null)]),
      );
    }

    // Transport phase: isolate network errors from payload parsing so the
    // auto-queue can classify them distinctly.
    final http.Response response;
    try {
      response = await _httpClient
          .get(url, headers: _browserHeaders(url))
          .timeout(const Duration(seconds: 8));
    } catch (error) {
      return Failure(
        PixeldrainTransportError(
          message: 'Pixeldrain resolve request failed: $error',
        ),
      );
    }

    if (response.statusCode != 200) {
      return Failure(
        PixeldrainTransportError(
          message:
              'Pixeldrain request failed with status ${response.statusCode}.',
        ),
      );
    }

    // Parse phase.
    try {
      final body = safeResponseBody(response);
      final directUrl = _extractApiUrlFromPayload(body);
      if (directUrl == null) {
        if (_hasHints(body)) {
          return const Failure(
            PixeldrainInconsistentPayloadError(
              message:
                  'Pixeldrain payload has video hints but no API file URL.',
            ),
          );
        }

        return const Failure(
          PixeldrainParseError(
            message: 'No playable Pixeldrain URL found in payload.',
          ),
        );
      }

      return Success(
        ResolveResult(
          streams: <ResolvedStream>[
            _toResolved(directUrl, _extractMimeType(body)),
          ],
        ),
      );
    } catch (error) {
      return Failure(
        PixeldrainParseError(
          message: 'Failed to parse Pixeldrain payload: $error',
        ),
      );
    }
  }
}

Map<String, String> _browserHeaders(Uri url) {
  return <String, String>{
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Referer': '${url.scheme}://${url.host}/',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  };
}

Uri? _extractApiUrlFromInput(Uri url) {
  final segments = url.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.length >= 2 && segments[0] == 'api' && segments[1] == 'file') {
    return url;
  }
  return null;
}

final _pdApiRe = RegExp(
  r'''https?:\/\/(?:www\.)?pixeldrain\.com\/api\/file\/[A-Za-z0-9]+''',
  caseSensitive: false,
);

final _pdIdRe = RegExp(r'''"id":"([A-Za-z0-9]+)"''', caseSensitive: false);

final _pdHintsRe = RegExp(
  r'''(og:video|twitter:player:stream|viewer_data|mime_type|allow_video_player)''',
  caseSensitive: false,
  multiLine: true,
);

final _pdMimeRe = RegExp(
  r'''"mime_type"\s*:\s*"([^"]+)"''',
  caseSensitive: false,
);

Uri? _extractApiUrlFromPayload(String payload) {
  final normalized = payload.replaceAll(r'\/', '/');
  final directMatch = _pdApiRe.firstMatch(normalized);
  final direct = directMatch?.group(0);
  if (direct != null) {
    return Uri.tryParse(direct);
  }

  final idMatch = _pdIdRe.firstMatch(normalized);
  final id = idMatch?.group(1);
  return id == null ? null : Uri.parse('https://pixeldrain.com/api/file/$id');
}

bool _hasHints(String payload) {
  return _pdHintsRe.hasMatch(payload);
}

String? _extractMimeType(String payload) {
  final match = _pdMimeRe.firstMatch(payload);
  final mime = match?.group(1)?.trim();
  if (mime == null || mime.isEmpty) {
    return null;
  }
  // Only trust video/* MIME types — anything else and we fall back to the
  // default so we do not mislabel audio or unknown binaries as playable.
  if (!mime.toLowerCase().startsWith('video/')) {
    return null;
  }
  return mime;
}

ResolvedStream _toResolved(Uri uri, String? mimeType) {
  final effectiveMime = mimeType ?? 'video/mp4';
  final isHls = effectiveMime.contains('mpegurl');
  return ResolvedStream(
    url: uri,
    qualityLabel: 'unknown',
    mimeType: effectiveMime,
    isHls: isHls,
    headers: <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Referer': 'https://pixeldrain.com/',
    },
  );
}
