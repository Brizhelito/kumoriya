import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_common/kumoriya_resolver_common.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/mediafire_resolver_error.dart';

/// MediaFire resolver — download-only, no streaming.
///
/// MediaFire file pages expose a `#downloadButton` link pointing at the
/// direct CDN URL (`download*.mediafire.com/…`).  This resolver fetches
/// the page and extracts that link.
final class MediafireResolverPlugin implements ResolverPlugin {
  MediafireResolverPlugin({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const Set<String> _supportedHosts = <String>{
    'mediafire.com',
    'www.mediafire.com',
  };

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.mediafire',
    displayName: 'MediaFire Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
    supportedHosts: <String>['mediafire.com', 'www.mediafire.com'],
    baseUrls: <String>['https://www.mediafire.com/file/'],
  );

  /// Lower priority than most streaming resolvers since MediaFire is
  /// download-only and not suitable for playback.
  @override
  int get priority => 150;

  @override
  bool supports(Uri url) {
    if (!url.hasScheme || url.host.isEmpty) return false;
    final host = url.host.toLowerCase();
    if (!_supportedHosts.contains(host)) return false;
    // Accept /file/{key}/..., /download/{key}/..., and synthetic /probe path
    // used by ResolverRegistry.selectWithFallback().
    return url.path.startsWith('/file/') ||
        url.path.startsWith('/download/') ||
        url.path == '/probe';
  }

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    try {
      // If the URL is a proxy/wrapper (not a mediafire.com host), manually
      // follow the redirect chain to discover the real MediaFire URL.
      // package:http follows redirects automatically but doesn't expose the
      // final URL, and the proxy might redirect directly to the CDN.
      final isProxy = !_supportedHosts.contains(url.host.toLowerCase());
      final targetUrl = isProxy ? await _resolveProxy(url) : url;
      _log('resolve url=$url isProxy=$isProxy targetUrl=$targetUrl');

      // If the proxy resolved directly to a download CDN URL
      // (download*.mediafire.com/…), skip page parsing entirely.
      if (_isDirectCdnUrl(targetUrl)) {
        final filename = targetUrl.pathSegments.isNotEmpty
            ? targetUrl.pathSegments.last
            : null;
        return Success(
          ResolveResult(
            streams: <ResolvedStream>[
              ResolvedStream(
                url: targetUrl,
                qualityLabel: 'download',
                mimeType: _guessMimeType(filename),
                isHls: false,
                headers: const <String, String>{},
              ),
            ],
          ),
        );
      }

      final response = await _httpClient
          .get(
            targetUrl,
            headers: <String, String>{
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        return Failure(
          MediafireTransportError(
            message:
                'MediaFire request failed with status ${response.statusCode}.',
          ),
        );
      }

      final body = safeResponseBody(response);

      if (_fileRemovedRe.hasMatch(body)) {
        return const Failure(
          MediafireFileUnavailableError(
            message: 'MediaFire file has been removed or is unavailable.',
          ),
        );
      }

      final directUrl = _extractDownloadUrl(body);
      if (directUrl == null) {
        return const Failure(
          MediafireParseError(
            message: 'Could not extract download URL from MediaFire page.',
          ),
        );
      }

      final filename = _extractFilename(body);
      final mimeType = _guessMimeType(filename);

      return Success(
        ResolveResult(
          streams: <ResolvedStream>[
            ResolvedStream(
              url: directUrl,
              qualityLabel: 'download',
              mimeType: mimeType,
              isHls: false,
              headers: const <String, String>{},
            ),
          ],
        ),
      );
    } catch (error) {
      return Failure(
        MediafireTransportError(
          message: 'MediaFire resolve request failed: $error',
        ),
      );
    }
  }

  /// Manually follow redirects from a proxy URL to discover the real
  /// MediaFire URL.  We do this manually because `package:http`'s
  /// auto-redirect doesn't expose the final URL.
  Future<Uri> _resolveProxy(Uri proxyUrl) async {
    var current = proxyUrl;
    for (var i = 0; i < 5; i++) {
      final request = http.Request('GET', current)
        ..followRedirects = false
        ..headers['User-Agent'] =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
        ..headers['Referer'] = 'https://jkanime.net/'
        ..headers['Accept'] =
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
      final streamed = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 8));
      // Drain the body so the connection is released.
      await streamed.stream.drain<void>();
      if (streamed.statusCode >= 300 && streamed.statusCode < 400) {
        final location = streamed.headers['location'];
        if (location != null && location.isNotEmpty) {
          current = current.resolve(location);
          continue;
        }
      }
      break;
    }
    return current;
  }

  /// `true` when the URL points at MediaFire's direct CDN
  /// (`download*.mediafire.com/…`) rather than the file page.
  static bool _isDirectCdnUrl(Uri url) {
    final host = url.host.toLowerCase();
    return host.startsWith('download') && host.endsWith('.mediafire.com');
  }

  static void _log(String message) {
    developer.log(message, name: 'kumoriya.resolver.mediafire');
  }
}

// --- Extraction helpers -----------------------------------------------------

/// Matches the download button href in the MediaFire file page.
/// MediaFire renders:
///   <a id="downloadButton" ... href="https://download123.mediafire.com/...">
final _downloadButtonRe = RegExp(
  r'''id\s*=\s*["']downloadButton["'][^>]*href\s*=\s*["'](https?://download[^"']+)["']''',
  caseSensitive: false,
);

/// Fallback: match any href pointing at download*.mediafire.com.
final _downloadCdnRe = RegExp(
  r'''href\s*=\s*["'](https?://download\d*\.mediafire\.com/[^"']+)["']''',
  caseSensitive: false,
);

/// Detects pages where the file has been removed / DMCA'd.
final _fileRemovedRe = RegExp(
  r'(file has been removed|This file is no longer available|Invalid or Deleted File)',
  caseSensitive: false,
);

/// Tries to extract filename from the page title or breadcrumb.
final _filenameRe = RegExp(
  r'<div\s+class="filename"[^>]*>([^<]+)<',
  caseSensitive: false,
);

Uri? _extractDownloadUrl(String body) {
  // Primary: the #downloadButton element.
  final btnMatch = _downloadButtonRe.firstMatch(body);
  if (btnMatch != null) {
    return Uri.tryParse(btnMatch.group(1)!);
  }

  // Fallback: any CDN href.
  final cdnMatch = _downloadCdnRe.firstMatch(body);
  if (cdnMatch != null) {
    return Uri.tryParse(cdnMatch.group(1)!);
  }

  return null;
}

String? _extractFilename(String body) {
  final match = _filenameRe.firstMatch(body);
  return match?.group(1)?.trim();
}

String _guessMimeType(String? filename) {
  if (filename == null) return 'video/mp4';
  final lower = filename.toLowerCase();
  if (lower.endsWith('.mkv')) return 'video/x-matroska';
  if (lower.endsWith('.avi')) return 'video/x-msvideo';
  if (lower.endsWith('.webm')) return 'video/webm';
  return 'video/mp4';
}
