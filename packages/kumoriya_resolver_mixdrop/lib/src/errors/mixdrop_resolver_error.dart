import 'package:kumoriya_core/kumoriya_core.dart';

sealed class MixdropResolverError implements KumoriyaError {
  const MixdropResolverError({
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

final class MixdropUnsupportedHostError extends MixdropResolverError {
  const MixdropUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.mixdrop.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}

final class MixdropMalformedLinkError extends MixdropResolverError {
  const MixdropMalformedLinkError({required super.message})
    : super(
        code: 'resolver.mixdrop.malformed_link',
        kind: KumoriyaErrorKind.mapping,
      );
}

final class MixdropTransportError extends MixdropResolverError {
  const MixdropTransportError({required super.message})
    : super(
        code: 'resolver.mixdrop.transport',
        kind: KumoriyaErrorKind.transport,
      );
}

final class MixdropParseError extends MixdropResolverError {
  const MixdropParseError({required super.message})
    : super(code: 'resolver.mixdrop.parse', kind: KumoriyaErrorKind.mapping);
}

final class MixdropInconsistentPayloadError extends MixdropResolverError {
  const MixdropInconsistentPayloadError({required super.message})
    : super(
        code: 'resolver.mixdrop.inconsistent',
        kind: KumoriyaErrorKind.mapping,
      );
}
