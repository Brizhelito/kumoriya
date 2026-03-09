import 'package:kumoriya_core/kumoriya_core.dart';

sealed class YouruploadResolverError implements KumoriyaError {
  const YouruploadResolverError({
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

final class YouruploadUnsupportedHostError extends YouruploadResolverError {
  const YouruploadUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.yourupload.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}

final class YouruploadMalformedLinkError extends YouruploadResolverError {
  const YouruploadMalformedLinkError({required super.message})
    : super(
        code: 'resolver.yourupload.malformed_link',
        kind: KumoriyaErrorKind.mapping,
      );
}

final class YouruploadTransportError extends YouruploadResolverError {
  const YouruploadTransportError({required super.message})
    : super(
        code: 'resolver.yourupload.transport',
        kind: KumoriyaErrorKind.transport,
      );
}

final class YouruploadParseError extends YouruploadResolverError {
  const YouruploadParseError({required super.message})
    : super(code: 'resolver.yourupload.parse', kind: KumoriyaErrorKind.mapping);
}

final class YouruploadInconsistentPayloadError extends YouruploadResolverError {
  const YouruploadInconsistentPayloadError({required super.message})
    : super(
        code: 'resolver.yourupload.inconsistent',
        kind: KumoriyaErrorKind.mapping,
      );
}
