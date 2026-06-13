import 'package:kumoriya_core/kumoriya_core.dart';

sealed class MiruroVibeplayerResolverError implements KumoriyaError {
  const MiruroVibeplayerResolverError({
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

final class MiruroVibeplayerUnsupportedHostError
    extends MiruroVibeplayerResolverError {
  const MiruroVibeplayerUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.miruro_vibeplayer.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}
