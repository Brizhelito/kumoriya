import 'package:kumoriya_core/kumoriya_core.dart';

sealed class HqqResolverError implements KumoriyaError {
  const HqqResolverError({
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

final class HqqUnsupportedHostError extends HqqResolverError {
  const HqqUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.hqq.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}

final class HqqMalformedLinkError extends HqqResolverError {
  const HqqMalformedLinkError({required super.message})
    : super(
        code: 'resolver.hqq.malformed_link',
        kind: KumoriyaErrorKind.mapping,
      );
}

final class HqqTransportError extends HqqResolverError {
  const HqqTransportError({required super.message})
    : super(code: 'resolver.hqq.transport', kind: KumoriyaErrorKind.transport);
}

final class HqqParseError extends HqqResolverError {
  const HqqParseError({required super.message})
    : super(code: 'resolver.hqq.parse', kind: KumoriyaErrorKind.mapping);
}

final class HqqInconsistentPayloadError extends HqqResolverError {
  const HqqInconsistentPayloadError({required super.message})
    : super(code: 'resolver.hqq.inconsistent', kind: KumoriyaErrorKind.mapping);
}

final class HqqChallengeRequiredError extends HqqResolverError {
  const HqqChallengeRequiredError({required super.message})
    : super(
        code: 'resolver.hqq.challenge_required',
        kind: KumoriyaErrorKind.mapping,
      );
}
