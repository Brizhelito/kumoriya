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
