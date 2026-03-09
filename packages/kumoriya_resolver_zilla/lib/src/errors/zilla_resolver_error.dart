import 'package:kumoriya_core/kumoriya_core.dart';

sealed class ZillaResolverError implements KumoriyaError {
  const ZillaResolverError({
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

final class ZillaUnsupportedHostError extends ZillaResolverError {
  const ZillaUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.zilla.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}

final class ZillaMalformedLinkError extends ZillaResolverError {
  const ZillaMalformedLinkError({required super.message})
    : super(
        code: 'resolver.zilla.malformed_link',
        kind: KumoriyaErrorKind.mapping,
      );
}

final class ZillaTransportError extends ZillaResolverError {
  const ZillaTransportError({required super.message})
    : super(
        code: 'resolver.zilla.transport',
        kind: KumoriyaErrorKind.transport,
      );
}

final class ZillaParseError extends ZillaResolverError {
  const ZillaParseError({required super.message})
    : super(code: 'resolver.zilla.parse', kind: KumoriyaErrorKind.mapping);
}
