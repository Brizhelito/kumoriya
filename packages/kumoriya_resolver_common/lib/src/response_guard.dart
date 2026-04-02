/// Response guards for resolver HTTP calls.

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Maximum response body size (5 MB) for embed page HTML payloads.
///
/// Protects against unexpectedly large responses that waste bandwidth
/// and time. Embed pages are typically 50–500 KB.
const int maxEmbedResponseBytes = 5 * 1024 * 1024;

/// Check the Content-Length header of a standard [http.Response].
///
/// Returns `true` if the response is within the allowed size limit.
/// Returns `false` if Content-Length exceeds [maxEmbedResponseBytes].
///
/// If Content-Length is not set (common), returns `true` and relies
/// on the already-received body length check.
bool isResponseSizeAcceptable(http.Response response, {int? maxBytes}) {
  final limit = maxBytes ?? maxEmbedResponseBytes;
  final contentLength = int.tryParse(response.headers['content-length'] ?? '');
  if (contentLength != null && contentLength > limit) {
    return false;
  }
  // Also check actual body length for responses already fully received.
  if (response.bodyBytes.length > limit) {
    return false;
  }
  return true;
}

/// Safely decode an HTTP response body as a string.
///
/// Video embed pages often contain non-UTF-8 bytes that cause
/// `FormatException: Unexpected extension byte` when using the default
/// `response.body` (which decodes as UTF-8). This function tries UTF-8
/// first with `allowMalformed: true`, which replaces invalid sequences
/// with the Unicode replacement character instead of throwing.
String safeResponseBody(http.Response response) {
  return utf8.decode(response.bodyBytes, allowMalformed: true);
}
