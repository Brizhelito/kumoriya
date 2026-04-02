import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_common/kumoriya_resolver_common.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/hqq_resolver_error.dart';

final class HqqResolverPlugin implements ResolverPlugin {
  HqqResolverPlugin({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const Set<String> _supportedHosts = <String>{'hqq.tv', 'www.hqq.tv'};

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.hqq',
    displayName: 'Netu / HQQ Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>['hqq.tv', 'www.hqq.tv'],
    baseUrls: <String>['https://hqq.tv/player/embed_player.php'],
  );

  @override
  int get priority => 110;

  @override
  bool supports(Uri url) {
    if (!url.hasScheme || url.host.isEmpty) {
      return false;
    }
    if (!_supportedHosts.contains(url.host.toLowerCase())) {
      return false;
    }
    return url.path == '/player/embed_player.php' || url.path.startsWith('/e/');
  }

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        HqqUnsupportedHostError(
          message: 'Unsupported HQQ host/path for URL: $url',
        ),
      );
    }

    final embedUrl = _toEmbedUrl(url);
    if (embedUrl == null) {
      return const Failure(
        HqqMalformedLinkError(
          message: 'HQQ URL does not contain a playable identifier.',
        ),
      );
    }

    try {
      final pageResponse = await _httpClient
          .get(embedUrl, headers: _pageHeaders())
          .timeout(const Duration(seconds: 8));

      if (pageResponse.statusCode != 200) {
        return Failure(
          HqqTransportError(
            message:
                'HQQ request failed with status ${pageResponse.statusCode}.',
          ),
        );
      }

      final pageConfig = _extractPageConfig(safeResponseBody(pageResponse));
      final md5Result = await _resolveViaMd5Handshake(
        embedUrl,
        pageConfig: pageConfig,
      );

      if (md5Result != null) {
        return md5Result.fold(
          onSuccess: (s) => Success(ResolveResult(streams: s)),
          onFailure: Failure.new,
        );
      }

      final streams = _extractTrustedStreams(
        safeResponseBody(pageResponse),
        baseUrl: embedUrl,
      );
      if (streams.isEmpty) {
        if (_requiresChallenge(safeResponseBody(pageResponse))) {
          return const Failure(
            HqqChallengeRequiredError(
              message:
                  'HQQ requires a runtime click/captcha challenge before exposing the stream.',
            ),
          );
        }

        if (_hasHints(safeResponseBody(pageResponse))) {
          return const Failure(
            HqqInconsistentPayloadError(
              message: 'HQQ payload had player hints but no playable streams.',
            ),
          );
        }

        return const Failure(
          HqqParseError(message: 'No playable HQQ stream found in payload.'),
        );
      }

      return Success(ResolveResult(streams: streams));
    } catch (error) {
      return Failure(
        HqqTransportError(message: 'HQQ resolve request failed: $error'),
      );
    }
  }

  Future<Result<List<ResolvedStream>, KumoriyaError>?> _resolveViaMd5Handshake(
    Uri embedUrl, {
    required _HqqPageConfig pageConfig,
  }) async {
    if (!pageConfig.isComplete) {
      return null;
    }

    final md5Url = embedUrl.replace(path: '/player/get_md5.php', query: '');
    final payload = <String, Object?>{
      'htoken': '',
      'sh': pageConfig.sh,
      'ver': '4',
      'secure': pageConfig.secure,
      'adb': pageConfig.adb,
      'v': pageConfig.videoKey,
      'token': '',
      'gt': pageConfig.gt,
      'embed_from': pageConfig.embedFrom,
      'wasmcheck': 0,
      'adscore': '',
      'click_hash': '',
      'clickx': 0,
      'clicky': 0,
    };

    final response = await _httpClient
        .post(md5Url, headers: _md5Headers(embedUrl), body: jsonEncode(payload))
        .timeout(const Duration(seconds: 8));

    final body = safeResponseBody(response).trim();
    if (body.isEmpty) {
      return null;
    }

    final decoded = _tryDecodeJsonObject(body);
    if (decoded == null) {
      if (response.statusCode >= 400) {
        return Failure(
          HqqTransportError(
            message:
                'HQQ md5 handshake failed with status ${response.statusCode}.',
          ),
        );
      }
      return null;
    }

    final failure = _mapHandshakeFailure(decoded);
    if (failure != null) {
      return Failure(failure);
    }

    final streams = _extractStreamsFromMd5Payload(decoded, baseUrl: embedUrl);
    if (streams.isEmpty) {
      return const Failure(
        HqqInconsistentPayloadError(
          message: 'HQQ md5 handshake returned JSON without a playable stream.',
        ),
      );
    }

    return Success(streams);
  }
}

Uri? _toEmbedUrl(Uri url) {
  if (url.path == '/player/embed_player.php') {
    final videoId = url.queryParameters['vid'];
    if (videoId == null || videoId.isEmpty) {
      return null;
    }
    return url.replace(fragment: '');
  }

  final segments = url.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.length != 2 || segments.first != 'e') {
    return null;
  }

  return Uri(
    scheme: url.scheme,
    host: url.host,
    path: '/player/embed_player.php',
    queryParameters: <String, String>{'vid': segments[1]},
  );
}

Map<String, String> _pageHeaders() {
  return const <String, String>{'User-Agent': 'Mozilla/5.0'};
}

Map<String, String> _md5Headers(Uri url) {
  final origin = '${url.scheme}://${url.host}';
  return <String, String>{
    'User-Agent': 'Mozilla/5.0',
    'Referer': url.toString(),
    'Origin': origin,
    'Content-Type': 'application/json',
  };
}

Map<String, String> _streamHeaders(Uri url) {
  final origin = '${url.scheme}://${url.host}';
  return <String, String>{'Referer': '$origin/', 'Origin': origin};
}

List<ResolvedStream> _extractStreamsFromMd5Payload(
  Map<String, dynamic> payload, {
  required Uri baseUrl,
}) {
  final obfLink = payload['obf_link'];
  if (obfLink is! String || obfLink.isEmpty) {
    return const <ResolvedStream>[];
  }

  final decodedLink = _decodeObfLink(obfLink);
  if (decodedLink == null || decodedLink.isEmpty) {
    return const <ResolvedStream>[];
  }

  final normalized = decodedLink.startsWith('//')
      ? 'https:$decodedLink'
      : decodedLink;
  final finalUrl = _appendHlsSuffixIfNeeded(normalized);
  final uri = Uri.tryParse(finalUrl);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return const <ResolvedStream>[];
  }

  return <ResolvedStream>[_toResolvedStream(uri, baseUrl)];
}

final _hqqSourceRe = RegExp(
  r'''(?:olplayer\.src\(\s*\{[\s\S]*?src:\s*["']?|<source[^>]+src=["'])(https?:\/\/|\/\/)[^"'<>]+(?:\.m3u8|\.mp4)[^"'<>]*''',
  caseSensitive: false,
  multiLine: true,
);

final _hqqUrlRe = RegExp(
  r'''(https?:\/\/|\/\/)[^"'<>]+(?:\.m3u8|\.mp4)[^"'<>]*''',
  caseSensitive: false,
);

final _hqqHintsRe = RegExp(
  r'(og:video|olplayer|embed_player|get_md5\.php|get_player_image\.php|videojs)',
  caseSensitive: false,
  multiLine: true,
);

final _hqqChallengeRe = RegExp(
  r'(get_player_image\.php|click_hash|checkbotclick|need_captcha|h-captcha)',
  caseSensitive: false,
  multiLine: true,
);

List<ResolvedStream> _extractTrustedStreams(
  String payload, {
  required Uri baseUrl,
}) {
  final normalized = payload
      .replaceAll(r'\/', '/')
      .replaceAll('&amp;', '&')
      .replaceAll(r'\u0026', '&');

  final candidates = <String>{};

  for (final match in _hqqSourceRe.allMatches(normalized)) {
    final snippet = match.group(0);
    if (snippet == null ||
        snippet.contains('/*') ||
        snippet.contains('//olplayer')) {
      continue;
    }
    final urlMatch = _hqqUrlRe.firstMatch(snippet);
    final candidate = urlMatch?.group(0);
    if (candidate != null && candidate.isNotEmpty) {
      candidates.add(
        candidate.startsWith('//') ? 'https:$candidate' : candidate,
      );
    }
  }

  return candidates
      .map(Uri.tryParse)
      .whereType<Uri>()
      .where((uri) => uri.hasScheme && uri.host.isNotEmpty)
      .map((uri) => _toResolvedStream(uri, baseUrl))
      .toList(growable: false);
}

bool _hasHints(String payload) {
  return _hqqHintsRe.hasMatch(payload);
}

bool _requiresChallenge(String payload) {
  return _hqqChallengeRe.hasMatch(payload);
}

Map<String, dynamic>? _tryDecodeJsonObject(String payload) {
  try {
    final decoded = jsonDecode(payload);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

HqqResolverError? _mapHandshakeFailure(Map<String, dynamic> payload) {
  if (payload['407']?.toString() == '1') {
    return const HqqChallengeRequiredError(
      message: 'HQQ md5 handshake rejected the request with a challenge gate.',
    );
  }
  if (payload['need_captcha']?.toString() == '1' ||
      payload['wrong_recaptcha']?.toString() == '1') {
    return const HqqChallengeRequiredError(
      message: 'HQQ requires captcha validation before exposing the stream.',
    );
  }
  if (payload['blocked']?.toString() == '1') {
    return const HqqChallengeRequiredError(
      message: 'HQQ blocked this request before stream extraction.',
    );
  }
  if (payload['pending'] != null || payload['try_again']?.toString() == '1') {
    return const HqqChallengeRequiredError(
      message: 'HQQ reported a pending runtime challenge instead of a stream.',
    );
  }
  return null;
}

String? _decodeObfLink(String value) {
  if (value.contains('.')) {
    return value;
  }
  if (value.length < 4) {
    return null;
  }

  final buffer = StringBuffer();
  final encoded = value.substring(1);
  for (var index = 0; index < encoded.length; index += 3) {
    final end = index + 3;
    if (end > encoded.length) {
      return null;
    }
    final chunk = encoded.substring(index, end);
    final codePoint = int.tryParse(chunk, radix: 16);
    if (codePoint == null) {
      return null;
    }
    buffer.writeCharCode(codePoint);
  }

  return buffer.toString();
}

String _appendHlsSuffixIfNeeded(String value) {
  final lower = value.toLowerCase();
  if (lower.contains('.m3u8') || lower.contains('.mp4')) {
    return value;
  }
  return '$value.mp4.m3u8';
}

ResolvedStream _toResolvedStream(Uri uri, Uri baseUrl) {
  final lower = uri.toString().toLowerCase();
  final isHls = lower.contains('.m3u8');
  return ResolvedStream(
    url: uri,
    qualityLabel: isHls ? 'auto' : 'unknown',
    mimeType: isHls ? 'application/vnd.apple.mpegurl' : 'video/mp4',
    isHls: isHls,
    headers: _streamHeaders(baseUrl),
  );
}

_HqqPageConfig _extractPageConfig(String payload) {
  return _HqqPageConfig(
    secure: _extractQuotedValue(payload, 'secure') ?? '0',
    videoKey: _extractQuotedValue(payload, 'videokeyorig'),
    adb: _extractQuotedValue(payload, 'adbn'),
    embedFrom: _extractQuotedValue(payload, 'embedfrm') ?? '0',
    gt: _extractQuotedValue(payload, 'gtr') ?? '',
    sh: _extractQuotedValue(payload, 'shh') ?? '',
  );
}

final _hqqQuotedValueCache = <String, RegExp>{};

String? _extractQuotedValue(String payload, String variableName) {
  final re = _hqqQuotedValueCache.putIfAbsent(
    variableName,
    () => RegExp(
      '$variableName\\s*=\\s*[\'"]([^\'"]*)[\'"]',
      caseSensitive: false,
      multiLine: true,
    ),
  );
  final match = re.firstMatch(payload);
  return match?.group(1)?.trim();
}

final class _HqqPageConfig {
  const _HqqPageConfig({
    required this.secure,
    required this.videoKey,
    required this.adb,
    required this.embedFrom,
    required this.gt,
    required this.sh,
  });

  final String secure;
  final String? videoKey;
  final String? adb;
  final String embedFrom;
  final String gt;
  final String sh;

  bool get isComplete =>
      videoKey != null &&
      videoKey!.isNotEmpty &&
      adb != null &&
      adb!.isNotEmpty;
}
