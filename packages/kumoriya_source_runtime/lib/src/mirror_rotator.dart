import 'dart:async';

import 'mirror_list.dart';
import 'transport_failure.dart';

/// Wraps a request closure so a transport-classified failure on the current
/// mirror transparently retries the next mirror in [mirrors], in order.
///
/// Iteration is deterministic and each `run` call walks the full list once.
/// The rotator does not maintain a "current preferred" cursor — that is the
/// caller's concern (typically a settings layer that rebuilds the list with
/// `MirrorList.withPreferred`). Stateless rotation keeps the helper safe to
/// share across concurrent requests.
///
/// On non-transport failures the original error is rethrown verbatim and no
/// further mirror is attempted, so parse/auth/4xx mistakes never silently
/// degrade by hammering every fallback.
final class MirrorRotator {
  const MirrorRotator(this.mirrors);

  final MirrorList mirrors;

  /// Runs [request] for each mirror in order. Returns the first successful
  /// result. If every mirror fails with a transport-classified error,
  /// rethrows the *last* error (preserving original stack trace).
  ///
  /// [request] receives the current mirror's base URI and must return a
  /// future of the desired result. The closure is responsible for resolving
  /// any path/query against [base].
  Future<T> run<T>(Future<T> Function(Uri base) request) async {
    Object? lastError;
    StackTrace? lastStack;
    for (final base in mirrors.entries) {
      try {
        return await request(base);
      } catch (error, stack) {
        if (!TransportFailure.classify(error)) {
          rethrow;
        }
        lastError = error;
        lastStack = stack;
      }
    }
    Error.throwWithStackTrace(
      lastError ?? StateError('MirrorRotator exhausted with no error'),
      lastStack ?? StackTrace.current,
    );
  }
}
