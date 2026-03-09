import 'package:kumoriya_core/kumoriya_core.dart';

sealed class AnimeAv1Error implements KumoriyaError {
  const AnimeAv1Error({
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

final class AnimeAv1TransportError extends AnimeAv1Error {
  const AnimeAv1TransportError({required super.message})
    : super(code: 'animeav1.transport', kind: KumoriyaErrorKind.transport);
}

final class AnimeAv1ParseError extends AnimeAv1Error {
  const AnimeAv1ParseError({required super.message})
    : super(code: 'animeav1.parse', kind: KumoriyaErrorKind.mapping);
}

final class AnimeAv1SourceEmptyError extends AnimeAv1Error {
  const AnimeAv1SourceEmptyError({required super.message})
    : super(code: 'animeav1.empty', kind: KumoriyaErrorKind.notFound);
}
