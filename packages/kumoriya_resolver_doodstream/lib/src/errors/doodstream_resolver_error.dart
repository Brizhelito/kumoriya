import 'package:kumoriya_core/kumoriya_core.dart';

sealed class DoodstreamResolverError implements KumoriyaError {
  const DoodstreamResolverError({
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

final class DoodstreamUnsupportedHostError extends DoodstreamResolverError {
  const DoodstreamUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.doodstream.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}

final class DoodstreamMalformedLinkError extends DoodstreamResolverError {
  const DoodstreamMalformedLinkError({required super.message})
    : super(
        code: 'resolver.doodstream.malformed_link',
        kind: KumoriyaErrorKind.mapping,
      );
}

final class DoodstreamTransportError extends DoodstreamResolverError {
  const DoodstreamTransportError({required super.message})
    : super(
        code: 'resolver.doodstream.transport',
        kind: KumoriyaErrorKind.transport,
      );
}

final class DoodstreamParseError extends DoodstreamResolverError {
  const DoodstreamParseError({required super.message})
    : super(code: 'resolver.doodstream.parse', kind: KumoriyaErrorKind.mapping);
}

final class DoodstreamInconsistentPayloadError extends DoodstreamResolverError {
  const DoodstreamInconsistentPayloadError({required super.message})
    : super(
        code: 'resolver.doodstream.inconsistent',
        kind: KumoriyaErrorKind.mapping,
      );
}
