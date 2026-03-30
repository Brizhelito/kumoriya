/// Response guards for resolver HTTP calls.

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
  final contentLength = int.tryParse(
    response.headers['content-length'] ?? '',
  );
  if (contentLength != null && contentLength > limit) {
    return false;
  }
  // Also check actual body length for responses already fully received.
  if (response.bodyBytes.length > limit) {
    return false;
  }
  return true;
}
