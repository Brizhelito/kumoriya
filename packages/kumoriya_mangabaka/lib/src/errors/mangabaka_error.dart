import 'package:kumoriya_core/kumoriya_core.dart';

/// Sealed root of MangaBaka adapter errors. Mirrors the AniList error
/// hierarchy so the application layer can pattern-match consistently
/// across metadata gateways.
sealed class MangaBakaError implements KumoriyaError {
  const MangaBakaError({
    required this.code,
    required this.message,
    required this.kind,
  });

  @override
  final String code;

  @override
  final String message;

  @override
  final KumoriyaErrorKind kind;
}

/// Raised when the HTTP layer fails (DNS, connection, non-success status
/// codes that are not specifically modeled below).
final class MangaBakaTransportError extends MangaBakaError {
  const MangaBakaTransportError({required super.message, this.statusCode})
    : super(code: 'mangabaka.transport', kind: KumoriyaErrorKind.transport);

  final int? statusCode;
}

/// Raised when MangaBaka returns 5xx or is otherwise temporarily
/// unavailable. Distinct from generic transport errors so the caller
/// can apply different retry/back-off strategies.
final class MangaBakaServiceUnavailableError extends MangaBakaError {
  const MangaBakaServiceUnavailableError({
    required super.message,
    this.statusCode,
  }) : super(
         code: 'mangabaka.service_unavailable',
         kind: KumoriyaErrorKind.transport,
       );

  final int? statusCode;
}

/// Raised when the API answers 429. `retryAfter` is parsed from the
/// `Retry-After` header when present; otherwise null.
final class MangaBakaRateLimitError extends MangaBakaError {
  const MangaBakaRateLimitError({required super.message, this.retryAfter})
    : super(code: 'mangabaka.rate_limit', kind: KumoriyaErrorKind.transport);

  final Duration? retryAfter;
}

/// Raised when the response body cannot be decoded into the expected
/// shape (invalid JSON, missing required fields, wrong types).
final class MangaBakaMappingError extends MangaBakaError {
  const MangaBakaMappingError({required super.message})
    : super(code: 'mangabaka.mapping', kind: KumoriyaErrorKind.mapping);
}

/// Raised when the requested series id does not exist (HTTP 404).
final class MangaBakaNotFoundError extends MangaBakaError {
  const MangaBakaNotFoundError({required super.message})
    : super(code: 'mangabaka.not_found', kind: KumoriyaErrorKind.notFound);
}

/// Raised when MangaBaka returns a payload that conforms to the schema
/// but indicates a logical failure not covered above.
final class MangaBakaUnexpectedError extends MangaBakaError {
  const MangaBakaUnexpectedError({required super.message})
    : super(code: 'mangabaka.unexpected', kind: KumoriyaErrorKind.unexpected);
}
