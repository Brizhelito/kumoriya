import 'package:kumoriya_core/kumoriya_core.dart';

sealed class Mp4uploadResolverError implements KumoriyaError {
  const Mp4uploadResolverError({
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

final class Mp4uploadUnsupportedHostError extends Mp4uploadResolverError {
  const Mp4uploadUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.mp4upload.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}

final class Mp4uploadMalformedLinkError extends Mp4uploadResolverError {
  const Mp4uploadMalformedLinkError({required super.message})
    : super(
        code: 'resolver.mp4upload.malformed_link',
        kind: KumoriyaErrorKind.mapping,
      );
}

final class Mp4uploadTransportError extends Mp4uploadResolverError {
  const Mp4uploadTransportError({required super.message})
    : super(
        code: 'resolver.mp4upload.transport',
        kind: KumoriyaErrorKind.transport,
      );
}

final class Mp4uploadParseError extends Mp4uploadResolverError {
  const Mp4uploadParseError({required super.message})
    : super(code: 'resolver.mp4upload.parse', kind: KumoriyaErrorKind.mapping);
}

final class Mp4uploadInconsistentPayloadError extends Mp4uploadResolverError {
  const Mp4uploadInconsistentPayloadError({required super.message})
    : super(
        code: 'resolver.mp4upload.inconsistent',
        kind: KumoriyaErrorKind.mapping,
      );
}
