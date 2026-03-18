import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_app/src/features/downloads/application/download_directory_service.dart';

void main() {
  group('DownloadDirectoryService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'kumoriya-download-directory-',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns configured custom directory when available', () async {
      final customDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}custom-downloads',
      );
      final store = _InMemoryDownloadDirectoryStore(customDir.path);
      final service = DownloadDirectoryService(
        store: store,
        defaultDirectoryResolver: () async => Directory(
          '${tempDir.path}${Platform.pathSeparator}default-downloads',
        ),
        directoryPicker: () async => null,
        androidPermissionRequester: () async => true,
      );

      final info = await service.getDirectoryInfo();

      expect(info.isCustom, isTrue);
      expect(info.path, customDir.path);
      expect(await customDir.exists(), isTrue);
    });

    test('falls back to default and clears invalid configured path', () async {
      final invalidTarget = File(
        '${tempDir.path}${Platform.pathSeparator}not-a-directory.txt',
      );
      await invalidTarget.writeAsString('x');

      final store = _InMemoryDownloadDirectoryStore(invalidTarget.path);
      final defaultDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}default-downloads',
      );
      final service = DownloadDirectoryService(
        store: store,
        defaultDirectoryResolver: () async => defaultDir,
        directoryPicker: () async => null,
        androidPermissionRequester: () async => true,
      );

      final info = await service.getDirectoryInfo();

      expect(info.isCustom, isFalse);
      expect(info.path, defaultDir.path);
      expect(await defaultDir.exists(), isTrue);
      expect(await store.readCustomDirectoryPath(), isNull);
    });

    test('selectDirectory persists the picked directory', () async {
      final pickedDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}picked-downloads',
      );
      final store = _InMemoryDownloadDirectoryStore();
      final service = DownloadDirectoryService(
        store: store,
        defaultDirectoryResolver: () async => Directory(
          '${tempDir.path}${Platform.pathSeparator}default-downloads',
        ),
        directoryPicker: () async => pickedDir.path,
        androidPermissionRequester: () async => true,
      );

      final result = await service.selectDirectory();

      expect(
        result,
        isA<Success<DownloadDirectorySelectionOutcome, KumoriyaError>>(),
      );
      final outcome =
          (result as Success<DownloadDirectorySelectionOutcome, KumoriyaError>)
              .value;
      expect(outcome.changed, isTrue);
      expect(outcome.info.isCustom, isTrue);
      expect(outcome.info.path, pickedDir.path);
      expect(await store.readCustomDirectoryPath(), pickedDir.path);
    });

    test('returns cancelled outcome when picker is dismissed', () async {
      final store = _InMemoryDownloadDirectoryStore();
      final service = DownloadDirectoryService(
        store: store,
        defaultDirectoryResolver: () async => Directory(
          '${tempDir.path}${Platform.pathSeparator}default-downloads',
        ),
        directoryPicker: () async => null,
        androidPermissionRequester: () async => true,
      );

      final result = await service.selectDirectory();

      expect(
        result,
        isA<Success<DownloadDirectorySelectionOutcome, KumoriyaError>>(),
      );
      final outcome =
          (result as Success<DownloadDirectorySelectionOutcome, KumoriyaError>)
              .value;
      expect(outcome.changed, isFalse);
      expect(await store.readCustomDirectoryPath(), isNull);
    });
  });
}

final class _InMemoryDownloadDirectoryStore implements DownloadDirectoryStore {
  _InMemoryDownloadDirectoryStore([this._value]);

  String? _value;

  @override
  Future<String?> readCustomDirectoryPath() async => _value;

  @override
  Future<void> writeCustomDirectoryPath(String? path) async {
    _value = path;
  }
}
