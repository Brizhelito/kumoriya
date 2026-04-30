import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Decides whether a thrown exception represents a *transport* failure that
/// is safe to retry against a different mirror, versus an application-level
/// failure (parse error, 4xx auth/not-found, 5xx with a structured body)
/// that the caller must see verbatim.
///
/// Transport failures are characterized by the request never producing a
/// usable response body from the target host: DNS failure, TCP refused,
/// connection reset, idle timeout, TLS handshake failure, request abort.
///
/// HTTP status codes are *not* inspected here; that decision belongs to the
/// caller (e.g. a 404 on a UUID lookup is not a mirror problem). If a plugin
/// wants to treat a specific 5xx as transport-equivalent it can wrap the
/// response and rethrow a transport-classified exception itself.
final class TransportFailure {
  TransportFailure._();

  /// Returns `true` if [error] looks like a network-layer fault that may
  /// resolve by switching mirrors.
  static bool classify(Object error) {
    if (error is SocketException) return true;
    if (error is HttpException) return true;
    if (error is TimeoutException) return true;
    if (error is http.ClientException) return true;
    return false;
  }
}
