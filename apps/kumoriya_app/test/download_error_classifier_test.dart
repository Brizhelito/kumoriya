import 'dart:async';
import 'dart:io';

import 'package:kumoriya_app/src/features/downloads/application/download_error_classifier.dart';
import 'package:test/test.dart';

void main() {
  group('classifyDownloadError', () {
    test('HttpException with 403 → linkExpired', () {
      final kind = classifyDownloadError(
        const HttpException('HTTP 403 Forbidden'),
      );
      expect(kind, DownloadErrorKind.linkExpired);
    });

    test('HttpException with 404 → notFound', () {
      final kind = classifyDownloadError(
        const HttpException('HTTP 404 Not Found'),
      );
      expect(kind, DownloadErrorKind.notFound);
    });

    test('HttpException with 429 → rateLimited', () {
      final kind = classifyDownloadError(
        const HttpException('HTTP 429 Too Many Requests'),
      );
      expect(kind, DownloadErrorKind.rateLimited);
    });

    test('HttpException with 502 → serverError', () {
      final kind = classifyDownloadError(
        const HttpException('HTTP 502 Bad Gateway'),
      );
      expect(kind, DownloadErrorKind.serverError);
    });

    test('HttpException with 503 → serverError', () {
      final kind = classifyDownloadError(
        const HttpException('HTTP 503 Service Unavailable'),
      );
      expect(kind, DownloadErrorKind.serverError);
    });

    test('SocketException → networkError', () {
      final kind = classifyDownloadError(
        const SocketException('Connection refused'),
      );
      expect(kind, DownloadErrorKind.networkError);
    });

    test('TimeoutException → networkError', () {
      final kind = classifyDownloadError(TimeoutException('timed out'));
      expect(kind, DownloadErrorKind.networkError);
    });

    test(
      'HandshakeException with CERTIFICATE_VERIFY_FAILED → certificateError',
      () {
        final kind = classifyDownloadError(
          HandshakeException(
            'Handshake error (OS Error: CERTIFICATE_VERIFY_FAILED)',
          ),
        );
        expect(kind, DownloadErrorKind.certificateError);
      },
    );

    test('FileSystemException with no space → diskError', () {
      final kind = classifyDownloadError(
        const FileSystemException('No space left on device'),
      );
      expect(kind, DownloadErrorKind.diskError);
    });

    test('FileSystemException with permission → diskError', () {
      final kind = classifyDownloadError(
        const FileSystemException('Permission denied'),
      );
      expect(kind, DownloadErrorKind.diskError);
    });

    test('FileSystemException generic → unrecoverable', () {
      final kind = classifyDownloadError(
        const FileSystemException('Something else'),
      );
      expect(kind, DownloadErrorKind.unrecoverable);
    });

    test('unknown error → unrecoverable', () {
      final kind = classifyDownloadError(Exception('mysterious error'));
      expect(kind, DownloadErrorKind.unrecoverable);
    });
  });

  group('isReResolvable', () {
    test('linkExpired is re-resolvable', () {
      expect(isReResolvable(DownloadErrorKind.linkExpired), isTrue);
    });

    test('notFound is re-resolvable', () {
      expect(isReResolvable(DownloadErrorKind.notFound), isTrue);
    });

    test('serverError is re-resolvable', () {
      expect(isReResolvable(DownloadErrorKind.serverError), isTrue);
    });

    test('networkError is re-resolvable', () {
      expect(isReResolvable(DownloadErrorKind.networkError), isTrue);
    });

    test('diskError is not re-resolvable', () {
      expect(isReResolvable(DownloadErrorKind.diskError), isFalse);
    });

    test('rateLimited is not re-resolvable', () {
      expect(isReResolvable(DownloadErrorKind.rateLimited), isFalse);
    });
  });

  group('humanReadableDownloadError', () {
    test('linkExpired produces descriptive message', () {
      final msg = humanReadableDownloadError(
        DownloadErrorKind.linkExpired,
        const HttpException('HTTP 403'),
      );
      expect(msg, contains('enlace'));
    });

    test('diskError produces descriptive message', () {
      final msg = humanReadableDownloadError(
        DownloadErrorKind.diskError,
        const FileSystemException('No space'),
      );
      expect(msg, contains('almacenamiento'));
    });

    test('unrecoverable passes through raw error', () {
      final msg = humanReadableDownloadError(
        DownloadErrorKind.unrecoverable,
        Exception('custom error'),
      );
      expect(msg, contains('custom error'));
    });
  });
}
