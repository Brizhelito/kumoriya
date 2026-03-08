import 'package:kumoriya_core/kumoriya_core.dart';

sealed class AnilistError implements KumoriyaError {
  const AnilistError({
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

final class AnilistTransportError extends AnilistError {
  const AnilistTransportError({required super.message, this.statusCode})
    : super(
        code: 'anilist.transport',
        kind: KumoriyaErrorKind.transport,
      );

  final int? statusCode;
}

final class AnilistMappingError extends AnilistError {
  const AnilistMappingError({required super.message})
    : super(
        code: 'anilist.mapping',
        kind: KumoriyaErrorKind.mapping,
      );
}

final class AnilistNotFoundError extends AnilistError {
  const AnilistNotFoundError({required super.message})
    : super(
        code: 'anilist.not_found',
        kind: KumoriyaErrorKind.notFound,
      );
}

final class AnilistUnexpectedError extends AnilistError {
  const AnilistUnexpectedError({required super.message})
    : super(
        code: 'anilist.unexpected',
        kind: KumoriyaErrorKind.unexpected,
      );
}
