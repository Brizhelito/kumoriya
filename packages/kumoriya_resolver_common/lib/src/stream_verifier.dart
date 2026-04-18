/// Lightweight pre-verification for resolved stream URLs.
library;

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Content-Type prefixes accepted as valid video or manifest responses.
const _acceptedContentTypes = <String>[
  'video/',
  'application/octet-stream',
  'binary/octet-stream',
  'application/vnd.apple.mpegurl',
  'application/x-mpegurl',
];

/// Content-Type prefixes that definitively indicate a non-video response
/// (error page, captcha redirect, JSON error, etc.).
const _rejectedContentTypes = <String>[
  'text/html',
  'text/xml',
  'text/plain',
  'application/json',
  'application/xml',
  'image/',
];

/// Outcome of a stream URL pre-verification probe.
enum StreamVerifyOutcome {
  /// Response confirmed a valid video or HLS manifest content-type.
  verified,

  /// Response definitively returned a non-video content-type (e.g. HTML)
  /// or HTTP 404. The stream should be excluded from the candidate list.
  rejected,

  /// Could not determine — timeout, transport error, unsupported HEAD/Range,
  /// or ambiguous status code. Callers should keep the stream (conservative
  /// pass-through to avoid dropping valid streams on transient errors).
  uncertain,
}

/// Verify a resolved stream [url] with a lightweight `GET Range: bytes=0-0`
/// request.
///
/// Only returns [StreamVerifyOutcome.rejected] when there is strong evidence
/// the URL is broken:
/// - HTTP 404
/// - HTTP 200/206 with a definitively non-video Content-Type
///
/// Returns [StreamVerifyOutcome.uncertain] for timeouts, transport failures,
/// and ambiguous status codes — callers must not drop streams on uncertainty.
///
/// [headers] should include any Referer / cookie headers the resolver
/// discovered during resolution.
///
/// If [client] is not provided, a temporary [http.Client] is created and
/// closed after the request. Pass a shared client when verifying multiple
/// streams concurrently for better connection reuse.
Future<StreamVerifyOutcome> verifyStreamUrl(
  Uri url,
  Map<String, String> headers, {
  Duration timeout = const Duration(seconds: 3),
  http.Client? client,
}) async {
  final owned = client == null;
  final httpClient = client ?? http.Client();
  try {
    final req = http.Request('GET', url);
    req.headers.addAll(headers);
    req.headers['Range'] = 'bytes=0-0';
    req.headers['Connection'] = 'close';

    final streamed = await httpClient.send(req).timeout(timeout);
    // Drain the body (≤1 byte from Range request) without allocating.
    await streamed.stream.drain<void>();

    final status = streamed.statusCode;
    // Normalize: strip charset / parameters from content-type.
    final contentType = (streamed.headers['content-type'] ?? '')
        .toLowerCase()
        .split(';')
        .first
        .trim();

    // HTTP 404 → definitively gone.
    if (status == 404) return StreamVerifyOutcome.rejected;

    // For 2xx responses, check content-type signal.
    if (status >= 200 && status < 300) {
      for (final bad in _rejectedContentTypes) {
        if (contentType.startsWith(bad)) return StreamVerifyOutcome.rejected;
      }
      for (final good in _acceptedContentTypes) {
        if (contentType.startsWith(good)) return StreamVerifyOutcome.verified;
      }
      // Unknown content-type but 2xx → uncertain, pass through.
      return StreamVerifyOutcome.uncertain;
    }

    // Any other status (4xx except 404, 5xx) → uncertain.
    return StreamVerifyOutcome.uncertain;
  } on TimeoutException {
    return StreamVerifyOutcome.uncertain;
  } on SocketException {
    return StreamVerifyOutcome.uncertain;
  } on http.ClientException {
    return StreamVerifyOutcome.uncertain;
  } catch (_) {
    return StreamVerifyOutcome.uncertain;
  } finally {
    if (owned) httpClient.close();
  }
}
