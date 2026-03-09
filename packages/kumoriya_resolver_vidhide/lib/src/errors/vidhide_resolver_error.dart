import 'package:kumoriya_core/kumoriya_core.dart';

sealed class VidhideResolverError implements KumoriyaError {
  const VidhideResolverError({
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

final class VidhideUnsupportedHostError extends VidhideResolverError {
  const VidhideUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.vidhide.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}

final class VidhideMalformedLinkError extends VidhideResolverError {
  const VidhideMalformedLinkError({required super.message})
    : super(
        code: 'resolver.vidhide.malformed_link',
        kind: KumoriyaErrorKind.mapping,
      );
}

final class VidhideTransportError extends VidhideResolverError {
  const VidhideTransportError({required super.message})
    : super(
        code: 'resolver.vidhide.transport',
        kind: KumoriyaErrorKind.transport,
      );
}

final class VidhideParseError extends VidhideResolverError {
  const VidhideParseError({required super.message})
    : super(code: 'resolver.vidhide.parse', kind: KumoriyaErrorKind.mapping);
}

final class VidhideInconsistentPayloadError extends VidhideResolverError {
  const VidhideInconsistentPayloadError({required super.message})
    : super(
        code: 'resolver.vidhide.inconsistent',
        kind: KumoriyaErrorKind.mapping,
      );
}
