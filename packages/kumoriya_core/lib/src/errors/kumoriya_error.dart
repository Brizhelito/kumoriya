abstract interface class KumoriyaError {
  String get code;
  String get message;
  KumoriyaErrorKind get kind;
}

enum KumoriyaErrorKind { transport, mapping, notFound, unexpected, cancelled }

final class SimpleError implements KumoriyaError {
  const SimpleError({
    required this.code,
    required this.message,
    this.kind = KumoriyaErrorKind.unexpected,
  });

  @override
  final String code;

  @override
  final String message;

  @override
  final KumoriyaErrorKind kind;
}
