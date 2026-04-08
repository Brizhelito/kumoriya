import 'package:kumoriya_core/kumoriya_core.dart';

sealed class MediafireResolverError implements KumoriyaError {
  const MediafireResolverError({
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

final class MediafireUnsupportedHostError extends MediafireResolverError {
  const MediafireUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.mediafire.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}

final class MediafireTransportError extends MediafireResolverError {
  const MediafireTransportError({required super.message})
    : super(
        code: 'resolver.mediafire.transport',
        kind: KumoriyaErrorKind.transport,
      );
}

final class MediafireParseError extends MediafireResolverError {
  const MediafireParseError({required super.message})
    : super(code: 'resolver.mediafire.parse', kind: KumoriyaErrorKind.mapping);
}

final class MediafireFileUnavailableError extends MediafireResolverError {
  const MediafireFileUnavailableError({required super.message})
    : super(
        code: 'resolver.mediafire.file_unavailable',
        kind: KumoriyaErrorKind.notFound,
      );
}
