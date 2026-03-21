import 'dart:async';
import 'dart:io';

import 'package:kumoriya_core/kumoriya_core.dart';

/// Download failure categories that drive recovery strategy.
enum DownloadErrorKind {
  /// CDN token expired (403 after HTTP retries).
  /// Recovery: re-resolve the same server for a fresh URL.
  linkExpired,

  /// Rate limited (429).
  /// Recovery: long backoff, then retry same URL.
  rateLimited,

  /// Server error (5xx) — upstream instability.
  /// Recovery: retry with backoff, then re-resolve if persistent.
  serverError,

  /// Network error (timeout, DNS, socket reset).
  /// Recovery: backoff and retry.
  networkError,

  /// TLS certificate validation failed.
  /// Recovery: retry with download-scoped insecure TLS fallback.
  certificateError,

  /// Resource not found (404) — file removed from host.
  /// Recovery: try a different server.
  notFound,

  /// Local disk full or permission denied.
  /// Recovery: pause and inform user (not auto-recoverable).
  diskError,

  /// Unclassified or truly unrecoverable.
  /// Recovery: mark failed, surface to user.
  unrecoverable,
}

/// Classifies a download error [Object] into a [DownloadErrorKind].
///
/// Uses type checks first, then falls back to message inspection for
/// HTTP errors that surface as [HttpException] with status codes embedded.
DownloadErrorKind classifyDownloadError(Object error) {
  // Disk / file-system errors.
  if (error is FileSystemException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('no space') || msg.contains('enospc')) {
      return DownloadErrorKind.diskError;
    }
    if (msg.contains('permission') || msg.contains('access denied')) {
      return DownloadErrorKind.diskError;
    }
    return DownloadErrorKind.unrecoverable;
  }

  // Network-level errors.
  if (error is HandshakeException) {
    // .message only has the short label; the CERTIFICATE_VERIFY_FAILED
    // detail is in .osError — use toString() which includes both.
    return _looksLikeCertificateVerifyFailure(error.toString())
        ? DownloadErrorKind.certificateError
        : DownloadErrorKind.networkError;
  }

  if (error is SocketException || error is TimeoutException) {
    return DownloadErrorKind.networkError;
  }

  // HTTP errors — inspect the message for status codes.
  if (error is HttpException) {
    return _classifyHttpMessage(error.message);
  }

  // Fallback: inspect toString() for common patterns.
  return _classifyHttpMessage(error.toString());
}

DownloadErrorKind _classifyHttpMessage(String message) {
  if (_looksLikeCertificateVerifyFailure(message)) {
    return DownloadErrorKind.certificateError;
  }
  if (message.contains('403')) return DownloadErrorKind.linkExpired;
  if (message.contains('404')) return DownloadErrorKind.notFound;
  if (message.contains('429')) return DownloadErrorKind.rateLimited;
  if (_serverErrorPattern.hasMatch(message)) {
    return DownloadErrorKind.serverError;
  }
  if (message.toLowerCase().contains('timeout') ||
      message.toLowerCase().contains('connection')) {
    return DownloadErrorKind.networkError;
  }
  return DownloadErrorKind.unrecoverable;
}

final _serverErrorPattern = RegExp(r'50[0-4]');

bool _looksLikeCertificateVerifyFailure(String message) {
  final normalized = message.toLowerCase();
  return normalized.contains('certificate_verify_failed') ||
      normalized.contains('certificate verify failed') ||
      normalized.contains('certificateverifyfailed');
}

/// Whether [kind] is potentially recoverable by re-resolving the download URL
/// (e.g. getting a fresh CDN token or trying an alternative server).
bool isReResolvable(DownloadErrorKind kind) {
  return kind == DownloadErrorKind.linkExpired ||
      kind == DownloadErrorKind.notFound ||
      kind == DownloadErrorKind.serverError ||
      kind == DownloadErrorKind.networkError;
}

/// Produces a human-readable error message for display in the downloads UI.
String humanReadableDownloadError(DownloadErrorKind kind, Object rawError) {
  return switch (kind) {
    DownloadErrorKind.linkExpired =>
      'El enlace expiró. Se intentará obtener uno nuevo automáticamente.',
    DownloadErrorKind.notFound =>
      'El archivo ya no existe en el servidor. Se buscará una alternativa.',
    DownloadErrorKind.rateLimited =>
      'Demasiadas solicitudes al servidor. Se reintentará con más espera.',
    DownloadErrorKind.serverError =>
      'Error temporal del servidor. Se reintentará automáticamente.',
    DownloadErrorKind.networkError =>
      'Error de conexión: ${_friendlyNetworkDetail(rawError)}. '
          'Se intentará con otro servidor automáticamente.',
    DownloadErrorKind.certificateError =>
      'El servidor presentó un certificado TLS inválido o vencido.',
    DownloadErrorKind.diskError =>
      'Error de almacenamiento. Verifica espacio disponible y permisos.',
    DownloadErrorKind.unrecoverable => _describeRawError(rawError),
  };
}

String _describeRawError(Object rawError) {
  if (rawError is KumoriyaError) {
    return '${rawError.code}: ${rawError.message}';
  }
  return '$rawError';
}

/// Returns a short, user-friendly label for the network-level failure.
String _friendlyNetworkDetail(Object rawError) {
  if (rawError is TimeoutException) return 'tiempo de espera agotado';
  if (rawError is SocketException) {
    final msg = rawError.message.toLowerCase();
    if (msg.contains('connection refused')) return 'conexión rechazada';
    if (msg.contains('no route') || msg.contains('network is unreachable')) {
      return 'sin conexión a internet';
    }
    return 'error de socket';
  }
  if (rawError is HandshakeException) return 'error de handshake TLS';
  if (rawError is HttpException) {
    final msg = rawError.message;
    if (msg.toLowerCase().contains('timeout')) {
      return 'tiempo de espera agotado';
    }
    return msg;
  }
  return 'problema de red';
}
