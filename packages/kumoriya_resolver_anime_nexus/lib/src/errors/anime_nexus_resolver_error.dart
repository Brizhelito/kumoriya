import 'package:kumoriya_core/kumoriya_core.dart';

sealed class AnimeNexusResolverError implements KumoriyaError {
  const AnimeNexusResolverError({
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

final class AnimeNexusUnsupportedHostError extends AnimeNexusResolverError {
  const AnimeNexusUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.anime_nexus.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}

final class AnimeNexusTransportError extends AnimeNexusResolverError {
  const AnimeNexusTransportError({required super.message})
    : super(
        code: 'resolver.anime_nexus.transport',
        kind: KumoriyaErrorKind.transport,
      );
}

final class AnimeNexusParseError extends AnimeNexusResolverError {
  const AnimeNexusParseError({required super.message})
    : super(
        code: 'resolver.anime_nexus.parse',
        kind: KumoriyaErrorKind.mapping,
      );
}

final class AnimeNexusWebSocketError extends AnimeNexusResolverError {
  const AnimeNexusWebSocketError({required super.message})
    : super(
        code: 'resolver.anime_nexus.websocket',
        kind: KumoriyaErrorKind.transport,
      );
}
