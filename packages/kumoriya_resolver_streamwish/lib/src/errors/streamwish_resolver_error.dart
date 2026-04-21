import 'package:kumoriya_core/kumoriya_core.dart';

sealed class StreamwishResolverError implements KumoriyaError {
  const StreamwishResolverError({
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

final class StreamwishUnsupportedHostError extends StreamwishResolverError {
  const StreamwishUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.streamwish.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}

final class StreamwishMalformedLinkError extends StreamwishResolverError {
  const StreamwishMalformedLinkError({required super.message})
    : super(
        code: 'resolver.streamwish.malformed_link',
        kind: KumoriyaErrorKind.mapping,
      );
}

/// The StreamWish file was deleted or expired upstream. Returning this
/// instead of a generic parse/transport failure gives the UI and auto-queue
/// an actionable signal (skip this candidate permanently for the episode).
final class StreamwishDeletedError extends StreamwishResolverError {
  const StreamwishDeletedError({required super.message})
    : super(
        code: 'resolver.streamwish.deleted',
        kind: KumoriyaErrorKind.notFound,
      );
}

final class StreamwishTransportError extends StreamwishResolverError {
  const StreamwishTransportError({required super.message})
    : super(
        code: 'resolver.streamwish.transport',
        kind: KumoriyaErrorKind.transport,
      );
}

final class StreamwishParseError extends StreamwishResolverError {
  const StreamwishParseError({required super.message})
    : super(code: 'resolver.streamwish.parse', kind: KumoriyaErrorKind.mapping);
}

final class StreamwishInconsistentPayloadError extends StreamwishResolverError {
  const StreamwishInconsistentPayloadError({required super.message})
    : super(
        code: 'resolver.streamwish.inconsistent',
        kind: KumoriyaErrorKind.mapping,
      );
}
