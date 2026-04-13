import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_resolver_common/kumoriya_resolver_common.dart';
import 'package:pointycastle/export.dart';

import 'errors/filemoon_resolver_error.dart';

final class FilemoonResolverPlugin implements ResolverPlugin {
  FilemoonResolverPlugin({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const Set<String> _supportedHosts = <String>{
    'filemoon.sx',
    'filemoon.to',
    'filemoon.nl',
    'filemoon.in',
    'filemoon.link',
    'kerapoxy.cc',
    'bysekoze.com',
    'f75s.com',
  };

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.filemoon',
    displayName: 'Filemoon Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>[
      'filemoon.sx',
      'filemoon.to',
      'filemoon.nl',
      'filemoon.in',
      'filemoon.link',
      'kerapoxy.cc',
      'bysekoze.com',
      'f75s.com',
    ],
    baseUrls: <String>['https://filemoon.sx/e/'],
  );

  @override
  int get priority => 105;

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

    return url.path.startsWith('/e/') || url.path.startsWith('/d/');
  }

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        FilemoonUnsupportedHostError(
          message: 'Unsupported Filemoon host/path for URL: $url',
        ),
      );
    }

    final pathSegments = url.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    if (pathSegments.length < 2) {
      return const Failure(
        FilemoonMalformedLinkError(
          message: 'Filemoon URL does not contain required embed identifier.',
        ),
      );
    }

    try {
      final response = await _httpClient
          .get(url, headers: _requestHeaders(url))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return Failure(
          FilemoonTransportError(
            message:
                'Filemoon request failed with status ${response.statusCode}.',
          ),
        );
      }

      if (!isResponseSizeAcceptable(response)) {
        return const Failure(
          FilemoonTransportError(message: 'Filemoon response too large.'),
        );
      }

      final streams = _extractStreams(
        safeResponseBody(response),
        resolverUrl: url,
      );
      if (streams.isEmpty) {
        // Only attempt the expensive dynamic API flow if the page is from a
        // known dynamic host AND the payload actually contains stream hints
        // (player init, HLS references, etc). This avoids a wasted 8s round-
        // trip when the page is genuinely empty or unavailable.
        if (_isDynamicHost(url.host) &&
            _hasStreamHints(safeResponseBody(response))) {
          final dynamicResult = await _resolveDynamicByseFlow(
            url,
            httpClient: _httpClient,
          );
          if (dynamicResult != null) {
            return dynamicResult.fold(
              onSuccess: (s) => Success(ResolveResult(streams: s)),
              onFailure: Failure.new,
            );
          }
        }

        if (_isUnavailablePayload(safeResponseBody(response))) {
          return Failure(
            FilemoonTransportError(
              message:
                  'Filemoon host responded but reported source unavailable for this video.',
            ),
          );
        }

        if (_hasStreamHints(safeResponseBody(response))) {
          return const Failure(
            FilemoonInconsistentPayloadError(
              message:
                  'Filemoon payload includes stream hints but no valid candidates were extracted.',
            ),
          );
        }
        return const Failure(
          FilemoonParseError(
            message:
                'No stream candidates were extracted from Filemoon payload.',
          ),
        );
      }

      return Success(ResolveResult(streams: streams));
    } catch (error) {
      return Failure(
        FilemoonTransportError(
          message: 'Filemoon resolve request failed: $error',
        ),
      );
    }
  }
}

Future<Result<List<ResolvedStream>, KumoriyaError>?> _resolveDynamicByseFlow(
  Uri sourceUrl, {
  http.Client? httpClient,
}) async {
  final client = httpClient;
  if (client == null) {
    return null;
  }

  final code = _extractVideoCode(sourceUrl);
  if (code == null) {
    return null;
  }

  // Use the /embed/playback endpoint which returns AES-256-GCM encrypted
  // source data, instead of /embed/details which only returns an embed frame
  // URL pointing to another SPA shell.
  final playbackUri = sourceUrl.replace(
    path: '/api/videos/$code/embed/playback',
    query: null,
    fragment: null,
  );

  try {
    final response = await client
        .get(playbackUri, headers: _requestHeaders(sourceUrl))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      return null;
    }

    final decoded = _decodeDetails(safeResponseBody(response));
    if (decoded == null) {
      return null;
    }

    final errorMessage = decoded['error'];
    if (errorMessage is String && errorMessage.trim().isNotEmpty) {
      return Failure(
        FilemoonTransportError(
          message: 'Filemoon playback endpoint rejected request: $errorMessage',
        ),
      );
    }

    final playback = decoded['playback'];
    if (playback is! Map<String, dynamic>) {
      return null;
    }

    final sources = _decryptPlaybackSources(playback);
    if (sources == null || sources.isEmpty) {
      return null;
    }

    final streams = <ResolvedStream>[];
    for (final source in sources) {
      if (source is! Map<String, dynamic>) continue;
      final urlRaw = source['url'];
      if (urlRaw is! String || urlRaw.trim().isEmpty) continue;

      final uri = Uri.tryParse(urlRaw.trim());
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) continue;

      final label = source['label'];
      final mimeType = source['mime_type'];
      final lower = uri.toString().toLowerCase();
      final isHls = lower.contains('.m3u8') ||
          lower.contains('/hls/') ||
          lower.contains('/hls2/') ||
          (mimeType is String &&
              mimeType.toLowerCase().contains('mpegurl'));

      streams.add(
        ResolvedStream(
          url: uri,
          qualityLabel: label is String && label.isNotEmpty
              ? label
              : _inferQuality(uri),
          mimeType: mimeType is String ? mimeType : null,
          isHls: isHls,
          headers: _requestHeaders(sourceUrl),
        ),
      );
    }

    if (streams.isEmpty) {
      return null;
    }

    return Success(streams);
  } catch (_) {
    return null;
  }
}

/// Decrypts AES-256-GCM encrypted playback data from the bysekoze/f75s
/// `/api/videos/{code}/embed/playback` endpoint.
///
/// The [playback] map contains:
/// - `key_parts`: list of base64url-encoded key fragments (concatenated = 32-byte key)
/// - `iv`: base64url-encoded 12-byte nonce
/// - `payload`: base64url-encoded ciphertext + GCM auth tag
///
/// Returns the list of source objects on success, or `null` on any failure.
List<dynamic>? _decryptPlaybackSources(Map<String, dynamic> playback) {
  try {
    final keyParts = playback['key_parts'];
    if (keyParts is! List || keyParts.isEmpty) return null;

    final ivRaw = playback['iv'];
    final payloadRaw = playback['payload'];
    if (ivRaw is! String || payloadRaw is! String) return null;

    // Concatenate key parts (each is base64url).
    final keyBytes = <int>[];
    for (final part in keyParts) {
      if (part is! String) return null;
      keyBytes.addAll(_base64UrlDecodeUnpadded(part));
    }
    if (keyBytes.length != 32) return null; // AES-256

    final iv = _base64UrlDecodeUnpadded(ivRaw);
    if (iv.length != 12) return null; // GCM standard nonce

    final ciphertext = _base64UrlDecodeUnpadded(payloadRaw);
    if (ciphertext.length < 16) return null; // at least the auth tag

    final cipher = GCMBlockCipher(AESEngine())..init(
      false, // decrypt
      AEADParameters(
        KeyParameter(Uint8List.fromList(keyBytes)),
        128, // tag length in bits
        Uint8List.fromList(iv),
        Uint8List(0), // no additional authenticated data
      ),
    );

    final plaintext = cipher.process(Uint8List.fromList(ciphertext));

    final decoded = jsonDecode(utf8.decode(plaintext));
    if (decoded is! Map<String, dynamic>) return null;

    final sources = decoded['sources'];
    return sources is List ? sources : null;
  } catch (_) {
    return null;
  }
}

Uint8List _base64UrlDecodeUnpadded(String input) {
  var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
  final remainder = normalized.length % 4;
  if (remainder != 0) {
    normalized = normalized.padRight(normalized.length + (4 - remainder), '=');
  }
  return base64Decode(normalized);
}

Map<String, dynamic>? _decodeDetails(String payload) {
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {
    return null;
  }
  return null;
}

String? _extractVideoCode(Uri url) {
  final segments = url.pathSegments
      .where((segment) => segment.trim().isNotEmpty)
      .toList(growable: false);
  if (segments.length < 2) {
    return null;
  }
  return segments.last.trim();
}

Map<String, String> _requestHeaders(Uri url, {Uri? referer}) {
  final origin = '${url.scheme}://${url.host}';
  return <String, String>{
    'Referer': referer?.toString() ?? '$origin/',
    'Origin': origin,
  };
}

final _fmSourceWithLabelRe = RegExp(
  r'''{[^{}]{0,200}?file\s*:\s*(?:"([^"]+)"|'([^']+)')[^{}]{0,200}?(?:label\s*:\s*(?:"([^"]+)"|'([^']+)'))?[^{}]{0,200}?}''',
  caseSensitive: false,
  multiLine: true,
);

final _fmKeyedRe = RegExp(
  r'''(?:file|src|source|hls)\s*[:=]\s*(?:"([^"]+)"|'([^']+)')''',
  caseSensitive: false,
  multiLine: true,
);

final _fmDirectRe = RegExp(
  r'''https?:\/\/[\w\-._~:/?#\[\]@!$&'()*+,;=%]+''',
  caseSensitive: false,
  multiLine: true,
);

final _fmStreamHintsRe = RegExp(
  r'''(sources|file\s*:\s*['"h]|hls|master\.m3u8|\.mp4)''',
  caseSensitive: false,
  multiLine: true,
);

final _fmUnavailableRe = RegExp(
  r'''(video source is unavailable|embedding from this domain is not allowed|we can\'t find the video)''',
  caseSensitive: false,
  multiLine: true,
);

final _fmQualityRe = RegExp(r'(2160|1440|1080|720|480|360)p');

List<ResolvedStream> _extractStreams(
  String payload, {
  required Uri resolverUrl,
}) {
  final normalized = payload
      .replaceAll(r'\/', '/')
      .replaceAll('&amp;', '&')
      .replaceAll(r'\u0026', '&')
      .replaceAll(r'\x2F', '/');

  final streams = <ResolvedStream>[];
  final seen = <String>{};

  for (final match in _fmSourceWithLabelRe.allMatches(normalized)) {
    final file = (match.group(1) ?? match.group(2))?.trim();
    final label = (match.group(3) ?? match.group(4))?.trim();
    if (file == null || file.isEmpty) {
      continue;
    }

    final uri = _toAbsoluteUri(file, resolverUrl);
    if (uri == null || !_isPlayableUri(uri)) {
      continue;
    }

    final key = uri.toString();
    if (seen.add(key)) {
      streams.add(_toResolvedStream(uri, resolverUrl, explicitLabel: label));
    }
  }

  for (final match in _fmKeyedRe.allMatches(normalized)) {
    final raw = (match.group(1) ?? match.group(2))?.trim();
    if (raw == null || raw.isEmpty) {
      continue;
    }

    final uri = _toAbsoluteUri(raw, resolverUrl);
    if (uri == null || !_isPlayableUri(uri)) {
      continue;
    }

    final key = uri.toString();
    if (seen.add(key)) {
      streams.add(_toResolvedStream(uri, resolverUrl));
    }
  }

  for (final match in _fmDirectRe.allMatches(normalized)) {
    final raw = match.group(0)?.trim();
    if (raw == null || raw.isEmpty) {
      continue;
    }

    final uri = Uri.tryParse(raw);
    if (uri == null || !_isPlayableUri(uri)) {
      continue;
    }

    final key = uri.toString();
    if (seen.add(key)) {
      streams.add(_toResolvedStream(uri, resolverUrl));
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
      value.contains('/hls/');
}

bool _hasStreamHints(String payload) {
  return _fmStreamHintsRe.hasMatch(payload);
}

bool _isDynamicHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'bysekoze.com' ||
      normalized.endsWith('.bysekoze.com') ||
      normalized == 'f75s.com' ||
      normalized.endsWith('.f75s.com');
}

bool _isUnavailablePayload(String payload) {
  return _fmUnavailableRe.hasMatch(payload);
}

ResolvedStream _toResolvedStream(
  Uri url,
  Uri resolverUrl, {
  String? explicitLabel,
}) {
  final lower = url.toString().toLowerCase();
  final isHls = lower.contains('.m3u8') || lower.contains('/hls/');
  final mimeType = isHls
      ? 'application/vnd.apple.mpegurl'
      : (lower.contains('.mp4') ? 'video/mp4' : null);

  return ResolvedStream(
    url: url,
    qualityLabel: explicitLabel?.isNotEmpty == true
        ? explicitLabel
        : _inferQuality(url),
    mimeType: mimeType,
    isHls: isHls,
    headers: _requestHeaders(resolverUrl),
  );
}

String _inferQuality(Uri url) {
  final match = _fmQualityRe.firstMatch(url.toString().toLowerCase());
  if (match != null) {
    return '${match.group(1)}p';
  }
  if (url.toString().toLowerCase().contains('.m3u8')) {
    return 'auto';
  }
  return 'unknown';
}
