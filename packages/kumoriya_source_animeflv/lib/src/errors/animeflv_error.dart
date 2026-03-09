import 'package:kumoriya_core/kumoriya_core.dart';

sealed class AnimeFlvError implements KumoriyaError {
  const AnimeFlvError({
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

final class AnimeFlvTransportError extends AnimeFlvError {
  const AnimeFlvTransportError({required super.message})
    : super(code: 'animeflv.transport', kind: KumoriyaErrorKind.transport);
}

final class AnimeFlvParseError extends AnimeFlvError {
  const AnimeFlvParseError({required super.message})
    : super(code: 'animeflv.parse', kind: KumoriyaErrorKind.mapping);
}

final class AnimeFlvSourceEmptyError extends AnimeFlvError {
  const AnimeFlvSourceEmptyError({required super.message})
    : super(code: 'animeflv.empty', kind: KumoriyaErrorKind.notFound);
}
