import 'package:kumoriya_core/kumoriya_core.dart';

sealed class StreamtapeResolverError implements KumoriyaError {
  const StreamtapeResolverError({
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

final class StreamtapeUnsupportedHostError extends StreamtapeResolverError {
  const StreamtapeUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.streamtape.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}

final class StreamtapeMalformedLinkError extends StreamtapeResolverError {
  const StreamtapeMalformedLinkError({required super.message})
    : super(
        code: 'resolver.streamtape.malformed_link',
        kind: KumoriyaErrorKind.mapping,
      );
}

final class StreamtapeTransportError extends StreamtapeResolverError {
  const StreamtapeTransportError({required super.message})
    : super(
        code: 'resolver.streamtape.transport',
        kind: KumoriyaErrorKind.transport,
      );
}

/// The Streamtape video was removed by the uploader or expired. Returning
/// this instead of the generic transport error makes the failure actionable
/// upstream (e.g. the UI can show "this mirror is dead" and the auto-queue
/// can skip the candidate permanently for this episode).
final class StreamtapeDeletedError extends StreamtapeResolverError {
  const StreamtapeDeletedError({required super.message})
    : super(
        code: 'resolver.streamtape.deleted',
        kind: KumoriyaErrorKind.notFound,
      );
}

final class StreamtapeParseError extends StreamtapeResolverError {
  const StreamtapeParseError({required super.message})
    : super(code: 'resolver.streamtape.parse', kind: KumoriyaErrorKind.mapping);
}

final class StreamtapeInconsistentPayloadError extends StreamtapeResolverError {
  const StreamtapeInconsistentPayloadError({required super.message})
    : super(
        code: 'resolver.streamtape.inconsistent',
        kind: KumoriyaErrorKind.mapping,
      );
}
