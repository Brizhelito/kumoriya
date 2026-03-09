import 'package:kumoriya_core/kumoriya_core.dart';

sealed class PixeldrainResolverError implements KumoriyaError {
  const PixeldrainResolverError({
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

final class PixeldrainUnsupportedHostError extends PixeldrainResolverError {
  const PixeldrainUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.pixeldrain.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}

final class PixeldrainMalformedLinkError extends PixeldrainResolverError {
  const PixeldrainMalformedLinkError({required super.message})
    : super(
        code: 'resolver.pixeldrain.malformed_link',
        kind: KumoriyaErrorKind.mapping,
      );
}

final class PixeldrainTransportError extends PixeldrainResolverError {
  const PixeldrainTransportError({required super.message})
    : super(
        code: 'resolver.pixeldrain.transport',
        kind: KumoriyaErrorKind.transport,
      );
}

final class PixeldrainParseError extends PixeldrainResolverError {
  const PixeldrainParseError({required super.message})
    : super(code: 'resolver.pixeldrain.parse', kind: KumoriyaErrorKind.mapping);
}

final class PixeldrainInconsistentPayloadError extends PixeldrainResolverError {
  const PixeldrainInconsistentPayloadError({required super.message})
    : super(
        code: 'resolver.pixeldrain.inconsistent',
        kind: KumoriyaErrorKind.mapping,
      );
}
