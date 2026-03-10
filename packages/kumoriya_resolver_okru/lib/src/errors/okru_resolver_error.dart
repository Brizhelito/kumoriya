import 'package:kumoriya_core/kumoriya_core.dart';

sealed class OkruResolverError implements KumoriyaError {
  const OkruResolverError({
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

final class OkruUnsupportedHostError extends OkruResolverError {
  const OkruUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.okru.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}

final class OkruMalformedLinkError extends OkruResolverError {
  const OkruMalformedLinkError({required super.message})
    : super(
        code: 'resolver.okru.malformed_link',
        kind: KumoriyaErrorKind.mapping,
      );
}

final class OkruTransportError extends OkruResolverError {
  const OkruTransportError({required super.message})
    : super(code: 'resolver.okru.transport', kind: KumoriyaErrorKind.transport);
}

final class OkruParseError extends OkruResolverError {
  const OkruParseError({required super.message})
    : super(code: 'resolver.okru.parse', kind: KumoriyaErrorKind.mapping);
}

final class OkruInconsistentPayloadError extends OkruResolverError {
  const OkruInconsistentPayloadError({required super.message})
    : super(
        code: 'resolver.okru.inconsistent',
        kind: KumoriyaErrorKind.mapping,
      );
}
