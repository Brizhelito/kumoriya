import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_resolver_common/kumoriya_resolver_common.dart';

import 'errors/okru_resolver_error.dart';

final class OkruResolverPlugin implements ResolverPlugin {
  OkruResolverPlugin({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const Set<String> _supportedHosts = <String>{'ok.ru', 'www.ok.ru'};

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.okru',
    displayName: 'Okru Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>['ok.ru', 'www.ok.ru'],
    baseUrls: <String>['https://ok.ru/videoembed/'],
  );

  @override
  int get priority => 109;

  @override
  bool supports(Uri url) {
    if (!url.hasScheme || url.host.isEmpty) {
      return false;
    }
    if (!_supportedHosts.contains(url.host.toLowerCase())) {
      return false;
    }
    return url.path.startsWith('/videoembed/');
  }

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    if (!supports(url)) {
      return Failure(
        OkruUnsupportedHostError(
          message: 'Unsupported Okru host/path for URL: $url',
        ),
      );
    }

    if (url.pathSegments.length < 2) {
      return const Failure(
        OkruMalformedLinkError(
          message: 'Okru URL does not contain a video identifier.',
        ),
      );
    }

    // Transport phase — only network-level errors (timeout, socket, DNS)
    // propagate from here. We deliberately keep the parsing phase below
    // outside this block so a malformed JSON payload does not get
    // reclassified as a transport failure (which would poison telemetry
    // and mislead the retry policy).
    final http.Response response;
    try {
      response = await _httpClient
          .get(url, headers: _headers(url))
          .timeout(const Duration(seconds: 8));
    } catch (error) {
      return Failure(
        OkruTransportError(message: 'Okru resolve request failed: $error'),
      );
    }

    if (response.statusCode != 200) {
      return Failure(
        OkruTransportError(
          message: 'Okru request failed with status ${response.statusCode}.',
        ),
      );
    }

    if (!isResponseSizeAcceptable(response)) {
      return const Failure(
        OkruTransportError(message: 'Okru response too large.'),
      );
    }

    // Parsing phase — any exception here is a structural issue with the
    // payload (schema change, truncated HTML, mangled JSON) and must be
    // reported as a parse error.
    final payloadBody = safeResponseBody(response);
    final List<ResolvedStream> streams;
    try {
      streams = _extractStreams(payloadBody, baseUrl: url);
    } on FormatException catch (error) {
      return Failure(
        OkruParseError(
          message: 'Okru payload JSON could not be decoded: ${error.message}',
        ),
      );
    } catch (error) {
      return Failure(
        OkruParseError(message: 'Okru payload parse failed: $error'),
      );
    }

    if (streams.isEmpty) {
      if (_hasHints(payloadBody)) {
        return const Failure(
          OkruInconsistentPayloadError(
            message: 'Okru payload had player hints but no playable streams.',
          ),
        );
      }

      return const Failure(
        OkruParseError(message: 'No playable Okru stream found in payload.'),
      );
    }

    return Success(ResolveResult(streams: streams));
  }
}

Map<String, String> _headers(Uri url) {
  final origin = '${url.scheme}://${url.host}';
  return <String, String>{'Referer': '$origin/', 'Origin': origin};
}

final _dataOptionsRe = RegExp(
  r'data-options="([^"]+)"',
  caseSensitive: false,
  multiLine: true,
);

List<ResolvedStream> _extractStreams(String payload, {required Uri baseUrl}) {
  final dataOptionsMatch = _dataOptionsRe.firstMatch(payload);
  final dataOptionsRaw = dataOptionsMatch?.group(1);
  if (dataOptionsRaw == null || dataOptionsRaw.isEmpty) {
    return const <ResolvedStream>[];
  }

  final unescaped = _htmlUnescape(dataOptionsRaw);
  final dataOptions = jsonDecode(unescaped);
  if (dataOptions is! Map<String, dynamic>) {
    return const <ResolvedStream>[];
  }

  final flashvars = dataOptions['flashvars'];
  if (flashvars is! Map<String, dynamic>) {
    return const <ResolvedStream>[];
  }

  final metadataRaw = flashvars['metadata'];
  if (metadataRaw is! String || metadataRaw.isEmpty) {
    return const <ResolvedStream>[];
  }

  final metadata = jsonDecode(metadataRaw);
  if (metadata is! Map<String, dynamic>) {
    return const <ResolvedStream>[];
  }

  final streams = <ResolvedStream>[];
  final seen = <String>{};

  final manifestUrl = metadata['hlsManifestUrl'];
  if (manifestUrl is String && manifestUrl.isNotEmpty) {
    final manifest = Uri.tryParse(manifestUrl);
    if (manifest != null && seen.add(manifest.toString())) {
      streams.add(
        ResolvedStream(
          url: manifest,
          qualityLabel: 'auto',
          mimeType: 'application/vnd.apple.mpegurl',
          isHls: true,
          headers: _headers(baseUrl),
        ),
      );
    }
  }

  final videos = metadata['videos'];
  if (videos is List) {
    for (final entry in videos) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }
      final rawUrl = entry['url'];
      if (rawUrl is! String || rawUrl.isEmpty) {
        continue;
      }
      final uri = Uri.tryParse(rawUrl);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        continue;
      }
      if (!seen.add(uri.toString())) {
        continue;
      }
      streams.add(
        ResolvedStream(
          url: uri,
          qualityLabel: _qualityLabel(entry['name']),
          mimeType: 'video/mp4',
          isHls: false,
          headers: _headers(baseUrl),
        ),
      );
    }
  }

  return streams;
}

String _htmlUnescape(String value) {
  return value
      .replaceAll('&quot;', '"')
      .replaceAll('&#34;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');
}

String _qualityLabel(Object? raw) {
  final value = raw?.toString().trim().toLowerCase();
  if (value == null || value.isEmpty) {
    return 'unknown';
  }

  // OK.ru returns descriptive names; map them to standard resolution labels
  // so the player's quality scoring can rank and differentiate streams.
  const nameToResolution = <String, String>{
    'mobile': '144p',
    'lowest': '240p',
    'low': '360p',
    'sd': '480p',
    'hd': '720p',
    'full': '1080p',
    'quad': '1440p',
    'ultra': '2160p',
  };

  return nameToResolution[value] ?? value;
}

final _okruHintsRe = RegExp(
  r'(data-options=|flashvars|metadata&quot;|hlsManifestUrl|okVideoPlayerEnabled)',
  caseSensitive: false,
  multiLine: true,
);

bool _hasHints(String payload) {
  return _okruHintsRe.hasMatch(payload);
}
