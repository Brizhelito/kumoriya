import 'package:kumoriya_core/kumoriya_core.dart';

sealed class JkAnimeError implements KumoriyaError {
  const JkAnimeError({
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

final class JkAnimeTransportError extends JkAnimeError {
  const JkAnimeTransportError({required super.message})
    : super(code: 'jkanime.transport', kind: KumoriyaErrorKind.transport);
}

final class JkAnimeParseError extends JkAnimeError {
  const JkAnimeParseError({required super.message})
    : super(code: 'jkanime.parse', kind: KumoriyaErrorKind.mapping);
}

final class JkAnimeSourceEmptyError extends JkAnimeError {
  const JkAnimeSourceEmptyError({required super.message})
    : super(code: 'jkanime.empty', kind: KumoriyaErrorKind.notFound);
}
