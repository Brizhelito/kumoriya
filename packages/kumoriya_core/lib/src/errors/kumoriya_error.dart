abstract interface class KumoriyaError {
  String get code;
  String get message;
}

final class SimpleError implements KumoriyaError {
  const SimpleError({required this.code, required this.message});

  @override
  final String code;

  @override
  final String message;
}
