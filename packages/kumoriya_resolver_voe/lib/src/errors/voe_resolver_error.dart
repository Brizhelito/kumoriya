import 'package:kumoriya_core/kumoriya_core.dart';

sealed class VoeResolverError implements KumoriyaError {
  const VoeResolverError({
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

final class VoeUnsupportedHostError extends VoeResolverError {
  const VoeUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.voe.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}

final class VoeMalformedLinkError extends VoeResolverError {
  const VoeMalformedLinkError({required super.message})
    : super(
        code: 'resolver.voe.malformed_link',
        kind: KumoriyaErrorKind.mapping,
      );
}

final class VoeTransportError extends VoeResolverError {
  const VoeTransportError({required super.message})
    : super(code: 'resolver.voe.transport', kind: KumoriyaErrorKind.transport);
}

final class VoeParseError extends VoeResolverError {
  const VoeParseError({required super.message})
    : super(code: 'resolver.voe.parse', kind: KumoriyaErrorKind.mapping);
}

final class VoeInconsistentPayloadError extends VoeResolverError {
  const VoeInconsistentPayloadError({required super.message})
    : super(code: 'resolver.voe.inconsistent', kind: KumoriyaErrorKind.mapping);
}
