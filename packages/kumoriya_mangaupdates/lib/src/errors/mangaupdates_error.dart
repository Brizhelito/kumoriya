import 'package:kumoriya_core/kumoriya_core.dart';

/// Sealed root of MangaUpdates adapter errors. Mirrors the MangaBaka
/// and AniList error hierarchies so the application layer can
/// pattern-match consistently across metadata gateways.
sealed class MangaUpdatesError implements KumoriyaError {
  const MangaUpdatesError({
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

/// Raised when the HTTP layer fails (DNS, connection, non-success
/// status codes that are not specifically modeled below).
final class MangaUpdatesTransportError extends MangaUpdatesError {
  const MangaUpdatesTransportError({required super.message, this.statusCode})
    : super(code: 'mangaupdates.transport', kind: KumoriyaErrorKind.transport);

  final int? statusCode;
}

/// Raised when MangaUpdates returns 5xx or is otherwise temporarily
/// unavailable.
final class MangaUpdatesServiceUnavailableError extends MangaUpdatesError {
  const MangaUpdatesServiceUnavailableError({
    required super.message,
    this.statusCode,
  }) : super(
         code: 'mangaupdates.service_unavailable',
         kind: KumoriyaErrorKind.transport,
       );

  final int? statusCode;
}

/// Raised when the API answers 429. `retryAfter` is parsed from the
/// `Retry-After` header when present; otherwise null.
final class MangaUpdatesRateLimitError extends MangaUpdatesError {
  const MangaUpdatesRateLimitError({required super.message, this.retryAfter})
    : super(code: 'mangaupdates.rate_limit', kind: KumoriyaErrorKind.transport);

  final Duration? retryAfter;
}

/// Raised when the response body cannot be decoded into the expected
/// shape (invalid JSON, missing required fields, wrong types).
final class MangaUpdatesMappingError extends MangaUpdatesError {
  const MangaUpdatesMappingError({required super.message})
    : super(code: 'mangaupdates.mapping', kind: KumoriyaErrorKind.mapping);
}

/// Raised when the requested resource does not exist (HTTP 404). The
/// MangaUpdates API returns 404 with an **empty body**, so callers
/// must rely on the status code rather than a JSON envelope.
final class MangaUpdatesNotFoundError extends MangaUpdatesError {
  const MangaUpdatesNotFoundError({required super.message})
    : super(code: 'mangaupdates.not_found', kind: KumoriyaErrorKind.notFound);
}

/// Raised for logical failures that conform to the schema but are not
/// otherwise modeled.
final class MangaUpdatesUnexpectedError extends MangaUpdatesError {
  const MangaUpdatesUnexpectedError({required super.message})
    : super(
        code: 'mangaupdates.unexpected',
        kind: KumoriyaErrorKind.unexpected,
      );
}
