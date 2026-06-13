import 'package:kumoriya_core/kumoriya_core.dart';

sealed class MiruroKwikResolverError implements KumoriyaError {
  const MiruroKwikResolverError({
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

final class MiruroKwikUnsupportedHostError extends MiruroKwikResolverError {
  const MiruroKwikUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.miruro_kwik.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}
