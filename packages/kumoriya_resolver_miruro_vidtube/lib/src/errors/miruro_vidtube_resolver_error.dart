import 'package:kumoriya_core/kumoriya_core.dart';

sealed class MiruroVidtubeResolverError implements KumoriyaError {
  const MiruroVidtubeResolverError({
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

final class MiruroVidtubeUnsupportedHostError
    extends MiruroVidtubeResolverError {
  const MiruroVidtubeUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.miruro_vidtube.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}
