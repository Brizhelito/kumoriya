import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kumoriya_app/src/features/downloads/application/download_directory_service.dart';
import 'package:kumoriya_app/src/features/downloads/application/download_library_index_service.dart';
import 'package:kumoriya_app/src/features/downloads/application/download_manager_service.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:test/test.dart';

void main() {
  group('DownloadManagerService smoke', () {
    test(
      'completes direct, HLS, and queued downloads over a local HTTP server',
      () async {
        final server = await _SmokeServer.start();
        addTearDown(server.close);

        final harness = await _SmokeHarness.create(maxConcurrent: 1);
        addTearDown(harness.dispose);

        await harness.manager.enqueue(
          _task(
            id: 'direct-1',
            anilistId: 101,
            episodeNumber: 1,
            sourceUrl: server.directUri,
            fileName: 'EP 01 - Direct.mp4',
            animeTitle: 'Smoke Direct',
          ),
        );
        await harness.manager.enqueue(
          _task(
            id: 'hls-1',
            anilistId: 102,
            episodeNumber: 1,
            sourceUrl: server.masterPlaylistUri,
            isHls: true,
            fileName: 'EP 01 - Hls.ts',
            animeTitle: 'Smoke HLS',
          ),
        );
        await harness.manager.enqueue(
          _task(
            id: 'direct-2',
            anilistId: 103,
            episodeNumber: 1,
            sourceUrl: server.directUri,
            fileName: 'EP 01 - Direct 2.mp4',
            animeTitle: 'Smoke Direct 2',
          ),
        );

        final directOne = await harness.waitForTask('direct-1');
        final hls = await harness.waitForTask('hls-1');
        final directTwo = await harness.waitForTask('direct-2');

        expect(directOne?.status, DownloadStatus.completed);
        expect(hls?.status, DownloadStatus.completed);
        expect(directTwo?.status, DownloadStatus.completed);

        expect(
          await File(directOne!.filePath!).readAsBytes(),
          _SmokeServer.directBytes,
        );
        expect(await File(hls!.filePath!).readAsBytes(), _SmokeServer.hlsBytes);
        expect(
          await File(directTwo!.filePath!).readAsBytes(),
          _SmokeServer.directBytes,
        );

        expect(server.maxActiveRequests, lessThanOrEqualTo(2));
        expect(server.requestedPaths, contains('/video.mp4'));
        expect(server.requestedPaths, contains('/master.m3u8'));
        expect(server.requestedPaths, contains('/media.m3u8'));
        expect(server.requestedPaths, contains('/seg-1.ts'));
        expect(server.requestedPaths, contains('/seg-2.ts'));
      },
    );
  });
}

DownloadTask _task({
  required String id,
  required int anilistId,
  required double episodeNumber,
  required Uri sourceUrl,
  required String fileName,
  required String animeTitle,
  bool isHls = false,
}) {
  return DownloadTask(
    id: id,
    anilistId: anilistId,
    episodeNumber: episodeNumber,
    sourceUrl: sourceUrl,
    status: DownloadStatus.pending,
    createdAt: DateTime(2026),
    fileName: fileName,
    animeTitle: animeTitle,
    isHls: isHls,
  );
}

final class _SmokeHarness {
  _SmokeHarness._({
    required this.tempDir,
    required this.store,
    required this.manager,
  });

  final Directory tempDir;
  final _InMemoryDownloadStore store;
  final DownloadManagerService manager;

  static Future<_SmokeHarness> create({required int maxConcurrent}) async {
    final tempDir = await Directory.systemTemp.createTemp(
      'kumoriya-download-smoke',
    );
    final store = _InMemoryDownloadStore();
    final directoryService = DownloadDirectoryService(
      store: _NoopDirectoryStore(),
      defaultDirectoryResolver: () async => tempDir,
    );
    final manager = DownloadManagerService(
      store: store,
      directoryService: directoryService,
      libraryIndexService: DownloadLibraryIndexService(
        store: store,
        directoryService: directoryService,
      ),
      maxConcurrent: maxConcurrent,
      maxRetryAttempts: 2,
    );
    return _SmokeHarness._(tempDir: tempDir, store: store, manager: manager);
  }

  Future<DownloadTask?> waitForTask(String taskId) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline)) {
      final task = (await store.getTask(
        taskId,
      )).fold(onSuccess: (value) => value, onFailure: (_) => null);
      if (task != null &&
          (task.status == DownloadStatus.completed ||
              task.status == DownloadStatus.failed)) {
        return task;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return (await store.getTask(
      taskId,
    )).fold(onSuccess: (value) => value, onFailure: (_) => null);
  }

  Future<void> dispose() async {
    manager.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

final class _SmokeServer {
  _SmokeServer._(this._server);

  final HttpServer _server;
  final requestedPaths = <String>[];
  var activeRequests = 0;
  var maxActiveRequests = 0;

  static const directBytes = <int>[1, 2, 3, 4, 5, 6];
  static const hlsBytes = <int>[7, 8, 9, 10, 11, 12];

  Uri get directUri =>
      Uri.parse('http://${_server.address.host}:${_server.port}/video.mp4');
  Uri get masterPlaylistUri =>
      Uri.parse('http://${_server.address.host}:${_server.port}/master.m3u8');

  static Future<_SmokeServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final smoke = _SmokeServer._(server);
    server.listen(smoke._handleRequest);
    return smoke;
  }

  Future<void> close() async {
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    activeRequests++;
    if (activeRequests > maxActiveRequests) {
      maxActiveRequests = activeRequests;
    }
    requestedPaths.add(request.uri.path);

    try {
      switch (request.uri.path) {
        case '/video.mp4':
          await _serveDirect(request);
          break;
        case '/master.m3u8':
          await _writeString(request.response, '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1200000
media.m3u8
''', contentType: 'application/vnd.apple.mpegurl');
          break;
        case '/media.m3u8':
          await _writeString(request.response, '''
#EXTM3U
#EXTINF:4.0,
seg-1.ts
#EXTINF:4.0,
seg-2.ts
''', contentType: 'application/vnd.apple.mpegurl');
          break;
        case '/seg-1.ts':
          await _serveBytes(
            request.response,
            hlsBytes.sublist(0, 3),
            contentType: 'video/mp2t',
          );
          break;
        case '/seg-2.ts':
          await Future<void>.delayed(const Duration(milliseconds: 150));
          await _serveBytes(
            request.response,
            hlsBytes.sublist(3),
            contentType: 'video/mp2t',
          );
          break;
        default:
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
      }
    } finally {
      activeRequests--;
    }
  }

  Future<void> _serveDirect(HttpRequest request) async {
    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range == null) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await _serveBytes(
        request.response,
        directBytes,
        contentType: 'video/mp4',
      );
      return;
    }

    final offset = _parseRangeOffset(range);
    if (offset == null || offset >= directBytes.length) {
      request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes */${directBytes.length}',
      );
      await request.response.close();
      return;
    }

    final partial = directBytes.sublist(offset);
    request.response.statusCode = HttpStatus.partialContent;
    request.response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes $offset-${directBytes.length - 1}/${directBytes.length}',
    );
    await _serveBytes(
      request.response,
      partial,
      contentType: 'video/mp4',
      contentLength: partial.length,
    );
  }

  int? _parseRangeOffset(String range) {
    final match = RegExp(r'bytes=(\d+)-').firstMatch(range);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  Future<void> _writeString(
    HttpResponse response,
    String body, {
    required String contentType,
  }) async {
    final bytes = utf8.encode(body.trim());
    await _serveBytes(
      response,
      bytes,
      contentType: contentType,
      contentLength: bytes.length,
    );
  }

  Future<void> _serveBytes(
    HttpResponse response,
    List<int> bytes, {
    required String contentType,
    int? contentLength,
  }) async {
    response.headers.set(HttpHeaders.contentTypeHeader, contentType);
    response.headers.set(
      HttpHeaders.contentLengthHeader,
      contentLength ?? bytes.length,
    );
    response.add(bytes);
    await response.close();
  }
}

final class _InMemoryDownloadStore implements DownloadStore {
  final _tasks = <String, DownloadTask>{};

  @override
  Future<Result<void, KumoriyaError>> deleteTask(String id) async {
    _tasks.remove(id);
    return const Success(null);
  }

  @override
  Future<Result<List<DownloadTask>, KumoriyaError>> getAllTasks() async {
    return Success(_tasks.values.toList(growable: false));
  }

  @override
  Future<Result<DownloadTask?, KumoriyaError>> getTask(String id) async {
    return Success(_tasks[id]);
  }

  @override
  Future<Result<DownloadTask?, KumoriyaError>> getTaskByEpisode(
    int anilistId,
    double episodeNumber,
  ) async {
    return Success(
      _tasks.values.where((task) {
        return task.anilistId == anilistId &&
            task.episodeNumber == episodeNumber;
      }).firstOrNull,
    );
  }

  @override
  Future<Result<List<DownloadTask>, KumoriyaError>> getTasksByAnime(
    int anilistId,
  ) async {
    return Success(
      _tasks.values
          .where((task) => task.anilistId == anilistId)
          .toList(growable: false),
    );
  }

  @override
  Future<Result<List<DownloadTask>, KumoriyaError>> getTasksByStatus(
    DownloadStatus status,
  ) async {
    return Success(
      _tasks.values
          .where((task) => task.status == status)
          .toList(growable: false),
    );
  }

  @override
  Future<Result<void, KumoriyaError>> insertTask(DownloadTask task) async {
    _tasks[task.id] = task;
    return const Success(null);
  }

  @override
  Future<Result<void, KumoriyaError>> updateTask(DownloadTask task) async {
    _tasks[task.id] = task;
    return const Success(null);
  }
}

final class _NoopDirectoryStore implements DownloadDirectoryStore {
  @override
  Future<String?> readCustomDirectoryPath() async => null;

  @override
  Future<void> writeCustomDirectoryPath(String? path) async {}
}
