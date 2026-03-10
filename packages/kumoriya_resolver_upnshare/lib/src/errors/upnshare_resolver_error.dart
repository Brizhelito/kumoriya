import 'package:kumoriya_core/kumoriya_core.dart';

sealed class UpnshareResolverError implements KumoriyaError {
  const UpnshareResolverError({
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

final class UpnshareUnsupportedHostError extends UpnshareResolverError {
  const UpnshareUnsupportedHostError({required super.message})
    : super(
        code: 'resolver.upnshare.unsupported_host',
        kind: KumoriyaErrorKind.notFound,
      );
}

final class UpnshareMalformedLinkError extends UpnshareResolverError {
  const UpnshareMalformedLinkError({required super.message})
    : super(
        code: 'resolver.upnshare.malformed_link',
        kind: KumoriyaErrorKind.mapping,
      );
}

final class UpnshareTransportError extends UpnshareResolverError {
  const UpnshareTransportError({required super.message})
    : super(
        code: 'resolver.upnshare.transport',
        kind: KumoriyaErrorKind.transport,
      );
}

final class UpnshareParseError extends UpnshareResolverError {
  const UpnshareParseError({required super.message})
    : super(code: 'resolver.upnshare.parse', kind: KumoriyaErrorKind.mapping);
}

final class UpnshareInconsistentPayloadError extends UpnshareResolverError {
  const UpnshareInconsistentPayloadError({required super.message})
    : super(
        code: 'resolver.upnshare.inconsistent',
        kind: KumoriyaErrorKind.mapping,
      );
}
