import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:pointycastle/export.dart';

import 'errors/upnshare_resolver_error.dart';

final class UpnshareResolverPlugin implements ResolverPlugin {
  UpnshareResolverPlugin({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const String _host = 'animeav1.uns.bio';
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.upnshare',
    displayName: 'UPNShare Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>[_host],
    baseUrls: <String>['https://animeav1.uns.bio/#'],
  );

  @override
  int get priority => 111;

  @override
  bool supports(Uri url) {
    if (!url.hasScheme || url.host.toLowerCase() != _host) {
      return false;
    }

    return _extractToken(url) != null;
  }

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        UpnshareUnsupportedHostError(
          message: 'Unsupported UPNShare host/path for URL: $url',
        ),
      );
    }

    final token = _extractToken(url);
    if (token == null) {
      return const Failure(
        UpnshareMalformedLinkError(
          message: 'UPNShare URL does not contain a playable token.',
        ),
      );
    }

    final apiUrl = _videoApiUrl(url, token);
    try {
      final response = await _httpClient
          .get(apiUrl, headers: _headers(url))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return Failure(
          UpnshareTransportError(
            message:
                'UPNShare request failed with status ${response.statusCode}.',
          ),
        );
      }

      final payload = _decryptPayload(response.body);
      if (payload == null) {
        return const Failure(
          UpnshareParseError(
            message: 'UPNShare payload could not be decrypted or parsed.',
          ),
        );
      }

      final streams = _extractStreams(payload, baseUrl: url);
      if (streams.isEmpty) {
        return const Failure(
          UpnshareInconsistentPayloadError(
            message: 'UPNShare payload did not expose a playable stream URL.',
          ),
        );
      }

      return Success(ResolveResult(streams: streams));
    } catch (error) {
      return Failure(
        UpnshareTransportError(
          message: 'UPNShare resolve request failed: $error',
        ),
      );
    }
  }
}

Uri _videoApiUrl(Uri inputUrl, String token) {
  return Uri(
    scheme: inputUrl.scheme,
    host: inputUrl.host,
    path: '/api/v1/video',
    queryParameters: <String, String>{
      'id': token,
      'w': '$_defaultScreenWidth',
      'h': '$_defaultScreenHeight',
      'r': '',
    },
  );
}

Map<String, String> _headers(Uri pageUrl) {
  final origin = '${pageUrl.scheme}://${pageUrl.host}';
  return <String, String>{
    'Referer': pageUrl.toString(),
    'Origin': origin,
    'User-Agent': 'Mozilla/5.0',
  };
}

String? _extractToken(Uri url) {
  final fragment = url.fragment.trim();
  if (fragment.isEmpty) {
    return null;
  }

  final token = fragment.split('&').first.trim();
  return token.isEmpty ? null : token;
}

Map<String, dynamic>? _decryptPayload(String hexPayload) {
  final normalizedHex = hexPayload.trim();
  if (normalizedHex.isEmpty || !_isHexString(normalizedHex)) {
    return null;
  }

  try {
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    );
    final parameters =
        PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
          ParametersWithIV<KeyParameter>(
            KeyParameter(Uint8List.fromList(utf8.encode(_upnshareKeyText))),
            Uint8List.fromList(utf8.encode(_upnshareIvText)),
          ),
          null,
        );

    cipher.init(false, parameters);
    final decryptedBytes = cipher.process(_hexToBytes(normalizedHex));
    final decoded = utf8.decode(decryptedBytes);
    final json = jsonDecode(decoded);
    return json is Map<String, dynamic> ? json : null;
  } catch (_) {
    return null;
  }
}

List<ResolvedStream> _extractStreams(
  Map<String, dynamic> payload, {
  required Uri baseUrl,
}) {
  final entries = <({String raw, String key})>[
    if (payload['cf'] is String)
      (raw: payload['cf'] as String, key: 'cf'),
    if (payload['source'] is String)
      (raw: payload['source'] as String, key: 'source'),
  ];

  final streams = <ResolvedStream>[];
  final seen = <String>{};

  for (final entry in entries) {
    final normalized = entry.raw.replaceAll(r'\/', '/').trim();
    if (normalized.isEmpty || !seen.add(normalized)) {
      continue;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      continue;
    }

    final isHls = _isHlsCandidate(uri, normalized);
    final quality = _inferQuality(uri);

    streams.add(
      ResolvedStream(
        url: uri,
        qualityLabel: quality,
        mimeType: isHls ? 'application/vnd.apple.mpegurl' : 'video/mp4',
        isHls: isHls,
        headers: _streamHeaders(baseUrl),
        supportsEmbeddedTrackSelection: false,
      ),
    );
  }

  return streams;
}

Map<String, String> _streamHeaders(Uri pageUrl) {
  final origin = '${pageUrl.scheme}://${pageUrl.host}';
  return <String, String>{'Referer': '$origin/', 'Origin': origin};
}

bool _isHlsCandidate(Uri uri, String raw) {
  final path = uri.path.toLowerCase();
  return path.endsWith('.m3u8') ||
      path.endsWith('.txt') ||
      raw.contains('/cf-master.');
}

Uint8List _hexToBytes(String value) {
  final output = Uint8List(value.length ~/ 2);
  for (var index = 0; index < value.length; index += 2) {
    output[index ~/ 2] = int.parse(
      value.substring(index, index + 2),
      radix: 16,
    );
  }
  return output;
}

final _qualityRe = RegExp(r'(2160|1440|1080|720|480|360)p?');

String _inferQuality(Uri uri) {
  final match = _qualityRe.firstMatch(uri.toString());
  if (match != null) {
    return '${match.group(1)}p';
  }
  return 'auto';
}

bool _isHexString(String value) {
  if (value.length.isOdd) {
    return false;
  }

  for (final codeUnit in value.codeUnits) {
    final isDigit = codeUnit >= 48 && codeUnit <= 57;
    final isUpperHex = codeUnit >= 65 && codeUnit <= 70;
    final isLowerHex = codeUnit >= 97 && codeUnit <= 102;
    if (!isDigit && !isUpperHex && !isLowerHex) {
      return false;
    }
  }

  return true;
}

const String _upnshareKeyText = 'kiemtienmua911ca';
const String _upnshareIvText = '1234567890oiuytr';
const int _defaultScreenWidth = 1440;
const int _defaultScreenHeight = 900;
