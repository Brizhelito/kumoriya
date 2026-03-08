import 'package:kumoriya_core/kumoriya_core.dart';

sealed class FilemoonResolverError implements KumoriyaError {
  const FilemoonResolverError({
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

final class FilemoonUnsupportedHostError extends FilemoonResolverError {
  const FilemoonUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.filemoon.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}

final class FilemoonMalformedLinkError extends FilemoonResolverError {
  const FilemoonMalformedLinkError({required super.message})
    : super(
        code: 'resolver.filemoon.malformed_link',
        kind: KumoriyaErrorKind.mapping,
      );
}

final class FilemoonTransportError extends FilemoonResolverError {
  const FilemoonTransportError({required super.message})
    : super(
        code: 'resolver.filemoon.transport',
        kind: KumoriyaErrorKind.transport,
      );
}

final class FilemoonParseError extends FilemoonResolverError {
  const FilemoonParseError({required super.message})
    : super(code: 'resolver.filemoon.parse', kind: KumoriyaErrorKind.mapping);
}

final class FilemoonInconsistentPayloadError extends FilemoonResolverError {
  const FilemoonInconsistentPayloadError({required super.message})
    : super(
        code: 'resolver.filemoon.inconsistent',
        kind: KumoriyaErrorKind.mapping,
      );
}
