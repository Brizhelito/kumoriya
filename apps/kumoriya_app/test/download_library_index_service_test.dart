import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/downloads/application/download_directory_service.dart';
import 'package:kumoriya_app/src/features/downloads/application/download_identity.dart';
import 'package:kumoriya_app/src/features/downloads/application/download_library_index_service.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late DriftDownloadStore store;
  late DownloadDirectoryService directoryService;
  late DownloadLibraryIndexService indexService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kumoriya-library-index-');
    db = AppDatabase(NativeDatabase.memory());
    store = DriftDownloadStore(db);
    directoryService = DownloadDirectoryService(
      store: _InMemoryDownloadDirectoryStore(tempDir.path),
      defaultDirectoryResolver: () async => tempDir,
      directoryPicker: () async => tempDir.path,
      androidPermissionRequester: () async => true,
    );
    indexService = DownloadLibraryIndexService(
      store: store,
      directoryService: directoryService,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('imports completed downloads from manifest sidecars', () async {
    final mediaFile = File(
      '${tempDir.path}${Platform.pathSeparator}EP 01 - Filemoon [1080p].mp4',
    );
    await mediaFile.writeAsBytes(List<int>.filled(128, 7), flush: true);

    final task = DownloadTask(
      id: buildDownloadTaskId(anilistId: 777, episodeNumber: 1),
      anilistId: 777,
      episodeNumber: 1,
      sourceUrl: Uri.parse('https://example.com/video.mp4'),
      status: DownloadStatus.completed,
      createdAt: DateTime(2026, 3, 19),
      fileName: mediaFile.uri.pathSegments.last,
      filePath: mediaFile.path,
      totalBytes: 128,
      downloadedBytes: 128,
      sourcePluginId: 'kumoriya.source.animeflv',
      serverName: 'Filemoon',
      detectedHost: 'filemoon.sx',
      animeTitle: 'Test Anime',
      qualityLabel: '1080p',
    );
    await indexService.writeManifest(
      task: task,
      mediaPath: mediaFile.path,
      totalBytes: 128,
    );

    final report = await indexService.syncDirectory(tempDir);

    expect(report.importedCount, 1);
    final loaded = await store.getTaskByEpisode(777, 1);
    final saved = (loaded as Success<DownloadTask?, KumoriyaError>).value;
    expect(saved, isNotNull);
    expect(saved!.status, DownloadStatus.completed);
    expect(saved.filePath, mediaFile.path);
    expect(saved.totalBytes, 128);
  });

  test('removes completed tasks whose files were deleted', () async {
    final missingPath = '${tempDir.path}${Platform.pathSeparator}missing.mp4';
    await store.insertTask(
      DownloadTask(
        id: buildDownloadTaskId(anilistId: 10, episodeNumber: 2),
        anilistId: 10,
        episodeNumber: 2,
        sourceUrl: Uri.parse('https://example.com/missing.mp4'),
        status: DownloadStatus.completed,
        createdAt: DateTime(2026, 3, 19),
        fileName: 'missing.mp4',
        filePath: missingPath,
        totalBytes: 42,
        downloadedBytes: 42,
      ),
    );

    final report = await indexService.syncDirectory(tempDir);

    expect(report.removedMissingCount, 1);
    final loaded = await store.getTaskByEpisode(10, 2);
    final saved = (loaded as Success<DownloadTask?, KumoriyaError>).value;
    expect(saved, isNull);
  });
}

final class _InMemoryDownloadDirectoryStore implements DownloadDirectoryStore {
  _InMemoryDownloadDirectoryStore(this._value);

  String? _value;

  @override
  Future<String?> readCustomDirectoryPath() async => _value;

  @override
  Future<void> writeCustomDirectoryPath(String? path) async {
    _value = path;
  }
}
