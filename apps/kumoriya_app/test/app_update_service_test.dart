import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_app/src/features/app_update/application/app_update_service.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const packageInfoChannel = MethodChannel(
    'dev.fluttercommunity.plus/package_info',
  );

  group('AppUpdateService.checkForUpdate', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(packageInfoChannel, (call) async {
            if (call.method != 'getAll') {
              return null;
            }
            return <String, dynamic>{
              'appName': 'Kumoriya',
              'packageName': 'dev.kumoriya.app',
              'version': '0.1.0',
              'buildNumber': '1',
              'buildSignature': '',
              'installerStore': '',
            };
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(packageInfoChannel, null);
    });

    test('returns update when remote version is newer', () async {
      final client = MockClient((_) async {
        return http.Response(_manifest(latestVersion: '0.1.1'), 200);
      });
      final service = AppUpdateService(httpClient: client);

      final result = await service.checkForUpdate();

      result.fold(
        onSuccess: (update) {
          expect(update, isNotNull);
          expect(update!.currentVersion, '0.1.0');
          expect(update.newVersion, '0.1.1');
          expect(
            update.downloadUrl,
            contains(
              '/artifacts/windows/v0.1.1/Kumoriya-0.1.1-windows-x64-setup.exe',
            ),
          );
        },
        onFailure: (error) => fail('Expected success, got ${error.code}'),
      );
    });

    test('returns null when remote version is the same', () async {
      final client = MockClient((_) async {
        return http.Response(_manifest(latestVersion: '0.1.0'), 200);
      });
      final service = AppUpdateService(httpClient: client);

      final result = await service.checkForUpdate();

      result.fold(
        onSuccess: (update) => expect(update, isNull),
        onFailure: (error) => fail('Expected success, got ${error.code}'),
      );
    });

    test('returns transport failure on non-200 manifest response', () async {
      final client = MockClient((_) async {
        return http.Response('server error', 500);
      });
      final service = AppUpdateService(httpClient: client);

      final result = await service.checkForUpdate();

      result.fold(
        onSuccess: (_) => fail('Expected failure on HTTP 500'),
        onFailure: (error) {
          expect(error.code, 'update_manifest_fetch');
          expect(error.kind, KumoriyaErrorKind.transport);
        },
      );
    });

    test('returns network failure on socket exception', () async {
      final client = MockClient((_) async {
        throw const SocketException('offline');
      });
      final service = AppUpdateService(httpClient: client);

      final result = await service.checkForUpdate();

      result.fold(
        onSuccess: (_) => fail('Expected failure on network error'),
        onFailure: (error) {
          expect(error.code, 'update_network');
          expect(error.kind, KumoriyaErrorKind.transport);
        },
      );
    });

    test('returns generic failure for invalid JSON manifest', () async {
      final client = MockClient((_) async {
        return http.Response('not-json', 200);
      });
      final service = AppUpdateService(httpClient: client);

      final result = await service.checkForUpdate();

      result.fold(
        onSuccess: (_) => fail('Expected failure on invalid manifest JSON'),
        onFailure: (error) => expect(error.code, 'update_check_failed'),
      );
    });
  });
}

String _manifest({required String latestVersion}) {
  final payload = <String, Object?>{
    'android': <String, Object?>{
      'latest_version': latestVersion,
      'url':
          'https://pub-8159019abe1741a097538b976c19722c.r2.dev/artifacts/android/v$latestVersion/kumoriya-$latestVersion.apk',
      'release_notes': 'Debug release',
    },
    'windows': <String, Object?>{
      'latest_version': latestVersion,
      'url':
          'https://pub-8159019abe1741a097538b976c19722c.r2.dev/artifacts/windows/v$latestVersion/Kumoriya-$latestVersion-windows-x64-setup.exe',
      'release_notes': 'Debug release',
    },
  };
  return jsonEncode(payload);
}
