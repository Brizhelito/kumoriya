import 'package:kumoriya_core/kumoriya_core.dart';

sealed class JkPlayerResolverError implements KumoriyaError {
  const JkPlayerResolverError({
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

final class JkPlayerUnsupportedHostError extends JkPlayerResolverError {
  const JkPlayerUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.jkplayer.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}

final class JkPlayerMalformedLinkError extends JkPlayerResolverError {
  const JkPlayerMalformedLinkError({required super.message})
    : super(
        code: 'resolver.jkplayer.malformed_link',
        kind: KumoriyaErrorKind.mapping,
      );
}

final class JkPlayerTransportError extends JkPlayerResolverError {
  const JkPlayerTransportError({required super.message})
    : super(
        code: 'resolver.jkplayer.transport',
        kind: KumoriyaErrorKind.transport,
      );
}

final class JkPlayerParseError extends JkPlayerResolverError {
  const JkPlayerParseError({required super.message})
    : super(code: 'resolver.jkplayer.parse', kind: KumoriyaErrorKind.mapping);
}

final class JkPlayerInconsistentPayloadError extends JkPlayerResolverError {
  const JkPlayerInconsistentPayloadError({required super.message})
    : super(
        code: 'resolver.jkplayer.inconsistent',
        kind: KumoriyaErrorKind.mapping,
      );
}
