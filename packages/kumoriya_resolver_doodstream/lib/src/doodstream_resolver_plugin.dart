import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_resolver_common/kumoriya_resolver_common.dart';

import 'errors/doodstream_resolver_error.dart';

/// Resolves Doodstream/DoodLa embed links.
///
/// Doodstream uses a token-based pass_md5 endpoint that returns a partial URL,
/// then the client appends a random string and a timestamp to build the final
/// playable URL. The Referer must be the embed page.
final class DoodstreamResolverPlugin implements ResolverPlugin {
  DoodstreamResolverPlugin({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const Set<String> _supportedHosts = <String>{
    'doodstream.com',
    'dood.la',
    'dood.to',
    'dood.so',
    'dood.pm',
    'dood.wf',
    'dood.re',
    'dood.watch',
    'dood.cx',
    'dood.ws',
    'dood.sh',
    'dood.yt',
    'ds2play.com',
    'd0000d.com',
    'do0od.com',
    'd000d.com',
    'doods.pro',
    'd-s.io',
    'dsvplay.com',
    'myvidplay.com',
  };

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.doodstream',
    displayName: 'Doodstream Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>[
      'doodstream.com',
      'dood.la',
      'dood.to',
      'dood.so',
      'dood.pm',
      'dood.wf',
      'dood.re',
      'dood.watch',
      'dood.cx',
      'dood.ws',
      'dood.sh',
      'dood.yt',
      'ds2play.com',
      'd0000d.com',
      'do0od.com',
      'd000d.com',
      'doods.pro',
      'd-s.io',
      'dsvplay.com',
      'myvidplay.com',
    ],
    baseUrls: <String>['https://doodstream.com/e/'],
  );

  @override
  int get priority => 101;

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
        DoodstreamUnsupportedHostError(
          message: 'Unsupported Doodstream host/path for URL: $url',
        ),
      );
    }

    final segments = url.pathSegments
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (segments.length < 2) {
      return const Failure(
        DoodstreamMalformedLinkError(
          message: 'Doodstream URL does not contain embed id.',
        ),
      );
    }

    try {
      final embedResponse = await _httpClient
          .get(url, headers: _headers(url))
          .timeout(const Duration(seconds: 8));

      if (embedResponse.statusCode != 200) {
        return Failure(
          DoodstreamTransportError(
            message:
                'Doodstream embed request failed with status ${embedResponse.statusCode}.',
          ),
        );
      }

      if (!isResponseSizeAcceptable(embedResponse)) {
        return const Failure(
          DoodstreamTransportError(
            message: 'Doodstream embed response too large.',
          ),
        );
      }

      final passMd5Path = _extractPassMd5Path(safeResponseBody(embedResponse));
      if (passMd5Path == null) {
        if (_hasHints(safeResponseBody(embedResponse))) {
          return const Failure(
            DoodstreamInconsistentPayloadError(
              message:
                  'Doodstream payload has stream hints but no pass_md5 path was found.',
            ),
          );
        }
        return const Failure(
          DoodstreamParseError(
            message: 'No pass_md5 token path was found in Doodstream payload.',
          ),
        );
      }

      final tokenUrl = url.replace(
        path: passMd5Path,
        query: null,
        fragment: null,
      );

      // Token endpoint is lightweight — short timeout reduces total resolve time.
      final tokenResponse = await _httpClient
          .get(tokenUrl, headers: _tokenHeaders(url))
          .timeout(const Duration(seconds: 8));

      if (tokenResponse.statusCode != 200) {
        return Failure(
          DoodstreamTransportError(
            message:
                'Doodstream token request failed with status ${tokenResponse.statusCode}.',
          ),
        );
      }

      final partialUrl = safeResponseBody(tokenResponse).trim();
      if (partialUrl.isEmpty || !partialUrl.startsWith('http')) {
        return const Failure(
          DoodstreamParseError(
            message: 'Doodstream token endpoint returned invalid partial URL.',
          ),
        );
      }

      final randomStr = _generateRandomString(10);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final streamUrl = Uri.tryParse(
        '$partialUrl$randomStr?token=$randomStr&expiry=$timestamp',
      );

      if (streamUrl == null) {
        return const Failure(
          DoodstreamParseError(
            message: 'Failed to build Doodstream stream URL from token.',
          ),
        );
      }

      return Success(
        ResolveResult(
          streams: <ResolvedStream>[
            ResolvedStream(
              url: streamUrl,
              qualityLabel: 'unknown',
              mimeType: 'video/mp4',
              isHls: false,
              headers: _playbackHeaders(url),
            ),
          ],
        ),
      );
    } catch (error) {
      return Failure(
        DoodstreamTransportError(
          message: 'Doodstream resolve request failed: $error',
        ),
      );
    }
  }
}

Map<String, String> _headers(Uri url) {
  final origin = '${url.scheme}://${url.host}';
  return <String, String>{'Referer': '$origin/', 'Origin': origin};
}

Map<String, String> _tokenHeaders(Uri embedUrl) {
  return <String, String>{'Referer': embedUrl.toString()};
}

Map<String, String> _playbackHeaders(Uri embedUrl) {
  return <String, String>{'Referer': '${embedUrl.scheme}://${embedUrl.host}/'};
}

final _passMd5PathRe = RegExp(
  r'''['"](/pass_md5/[^"']+)['"]''',
  caseSensitive: false,
  multiLine: true,
);

final _doodHintsRe = RegExp(
  r'''(pass_md5|dsplayer|dood|\.mp4|source)''',
  caseSensitive: false,
  multiLine: true,
);

String? _extractPassMd5Path(String payload) {
  final match = _passMd5PathRe.firstMatch(payload);
  return match?.group(1)?.trim();
}

bool _hasHints(String payload) {
  return _doodHintsRe.hasMatch(payload);
}

String _generateRandomString(int length) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random();
  return String.fromCharCodes(
    Iterable.generate(
      length,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ),
  );
}
