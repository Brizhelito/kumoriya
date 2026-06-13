import 'package:kumoriya_core/kumoriya_core.dart';

sealed class MiruroAnidbResolverError implements KumoriyaError {
  const MiruroAnidbResolverError({
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

final class MiruroAnidbUnsupportedHostError extends MiruroAnidbResolverError {
  const MiruroAnidbUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.miruro_anidb.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}
