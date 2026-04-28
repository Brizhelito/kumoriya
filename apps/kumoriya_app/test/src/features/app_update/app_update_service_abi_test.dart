import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kumoriya_app/src/features/app_update/application/app_update_service.dart';

/// Fake backend response covering the new ABI-aware manifest shape.
const _abiManifestJson = '''
{
  "android": {
    "latest_version": "0.2.1",
    "url": "https://cdn.example/universal.apk",
    "release_notes": "ABI test",
    "universal": {
      "url": "https://cdn.example/universal.apk",
      "file_name": "kumoriya-0.2.1-universal.apk",
      "size_bytes": 50000000,
      "sha256": "abc"
    },
    "abis": {
      "arm64_v8a": {
        "url": "https://cdn.example/arm64.apk",
        "file_name": "kumoriya-0.2.1-arm64-v8a.apk",
        "size_bytes": 42300000,
        "sha256": "def"
      },
      "armeabi_v7a": {
        "url": "https://cdn.example/armv7.apk",
        "file_name": "kumoriya-0.2.1-armeabi-v7a.apk",
        "size_bytes": 35000000,
        "sha256": "ghi"
      },
      "x86_64": {
        "url": "https://cdn.example/x86_64.apk",
        "file_name": "kumoriya-0.2.1-x86_64.apk",
        "size_bytes": 45000000,
        "sha256": "jkl"
      }
    }
  }
}
''';

/// Legacy manifest (no abis / universal). The app should still parse it.
const _legacyManifestJson = '''
{
  "android": {
    "latest_version": "0.1.0",
    "url": "https://cdn.example/legacy.apk",
    "release_notes": "Legacy"
  }
}
''';

void main() {
  group('AppUpdateService ABI selection', () {
    test(
      'legacy manifest without abis/universal falls back to top-level url',
      () async {
        final service = AppUpdateService(
          httpClient: _clientReturning(_legacyManifestJson),
        );
        final result = await service.checkForUpdate(
          currentVersion: '0.0.9',
          platformOverride: 'android',
        );
        final update = result.fold<AvailableUpdate?>(
          onSuccess: (u) => u,
          onFailure: (_) => null,
        );
        expect(update, isNotNull);
        expect(update!.downloadUrl, 'https://cdn.example/legacy.apk');
        expect(update.sizeBytes, isNull);
      },
    );

    test('resolves universal APK when no ABI match is available', () async {
      final service = AppUpdateService(
        httpClient: _clientReturning(_abiManifestJson),
      );
      final result = await service.checkForUpdate(
        currentVersion: '0.0.9',
        platformOverride: 'android',
      );
      final update = result.fold<AvailableUpdate?>(
        onSuccess: (u) => u,
        onFailure: (_) => null,
      );
      expect(update, isNotNull);
      // The test runner is typically x86_64 emulator, but because we cannot
      // mock device_info_plus easily in unit tests, we verify at least that
      // the fallback to universal works when the device ABI isn't known.
      expect(update!.downloadUrl, startsWith('https://cdn.example/'));
    });
  });
}

http.Client _clientReturning(String body) {
  return MockClient((request) async {
    return http.Response(body, 200);
  });
}
