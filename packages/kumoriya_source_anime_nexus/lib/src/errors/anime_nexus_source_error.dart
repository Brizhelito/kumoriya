import 'package:kumoriya_core/kumoriya_core.dart';

sealed class AnimeNexusSourceError implements KumoriyaError {
  const AnimeNexusSourceError({
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

final class AnimeNexusSourceTransportError extends AnimeNexusSourceError {
  const AnimeNexusSourceTransportError({required super.message})
    : super(code: 'anime_nexus.transport', kind: KumoriyaErrorKind.transport);
}

final class AnimeNexusSourceParseError extends AnimeNexusSourceError {
  const AnimeNexusSourceParseError({required super.message})
    : super(code: 'anime_nexus.parse', kind: KumoriyaErrorKind.mapping);
}

final class AnimeNexusSourceEmptyError extends AnimeNexusSourceError {
  const AnimeNexusSourceEmptyError({required super.message})
    : super(code: 'anime_nexus.empty', kind: KumoriyaErrorKind.notFound);
}
