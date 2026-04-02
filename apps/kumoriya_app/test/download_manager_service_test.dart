import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kumoriya_app/src/features/downloads/application/download_directory_service.dart';
import 'package:kumoriya_app/src/features/downloads/application/download_library_index_service.dart';
import 'package:kumoriya_app/src/features/downloads/application/download_manager_service.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:test/test.dart';

void main() {
  group('DownloadManagerService', () {
    test('completes a direct download', () async {
      final harness = await _DownloadHarness.create(
        client: _SequenceClient(
          responses: <http.StreamedResponse>[
            _streamedResponse(
              bytes: <int>[1, 2, 3, 4],
              statusCode: 200,
              headers: <String, String>{'content-length': '4'},
            ),
          ],
        ),
      );
      addTearDown(harness.dispose);

      final task = _task();
      await harness.manager.enqueue(task);
      final completed = await harness.waitForTask(task.id);

      expect(completed?.status, DownloadStatus.completed);
      expect(completed?.downloadedBytes, 4);
      expect(completed?.filePath, isNotNull);
      expect(await File(completed!.filePath!).readAsBytes(), <int>[1, 2, 3, 4]);
    });

    test('recovers a direct download after an interrupted stream', () async {
      final harness = await _DownloadHarness.create(
        client: _SequenceClient(
          responses: <http.StreamedResponse>[
            _streamedResponse(
              bytes: <int>[1, 2, 3],
              statusCode: 200,
              headers: <String, String>{'content-length': '6'},
            ),
            _streamedResponse(
              bytes: <int>[4, 5, 6],
              statusCode: 206,
              headers: <String, String>{
                'content-length': '3',
                'content-range': 'bytes 3-5/6',
              },
            ),
          ],
        ),
      );
      addTearDown(harness.dispose);

      final task = _task();
      await harness.manager.enqueue(task);
      final completed = await harness.waitForTask(task.id);

      expect(completed?.status, DownloadStatus.completed);
      expect(completed?.downloadedBytes, 6);
      expect(await File(completed!.filePath!).readAsBytes(), <int>[
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
      expect(harness.sequenceClient.requestedRanges, <String?>[
        null,
        'bytes=3-',
      ]);
    });

    test('persists a useful failure message for the UI', () async {
      final harness = await _DownloadHarness.createWithClient(
        client: _ThrowingClient(
          error: const SimpleError(
            code: 'resolver_not_found',
            message: 'No resolver plugin matched host "voe.sx".',
          ),
        ),
      );
      addTearDown(harness.dispose);

      final task = _task();
      await harness.manager.enqueue(task);
      final failed = await harness.waitForTask(task.id);

      expect(failed?.status, DownloadStatus.failed);
      expect(
        failed?.errorMessage,
        'resolver_not_found: No resolver plugin matched host "voe.sx".',
      );
    });

    test(
      'retries direct downloads with insecure TLS on expired certificates',
      () async {
        final fallbackClient = _SequenceClient(
          responses: <http.StreamedResponse>[
            _streamedResponse(
              bytes: <int>[7, 8, 9, 10],
              statusCode: 200,
              headers: <String, String>{'content-length': '4'},
            ),
          ],
        );
        final harness = await _DownloadHarness.createWithClient(
          client: _ThrowingClient(
            error: HandshakeException(
              'Handshake error in client '
              '(OS Error: CERTIFICATE_VERIFY_FAILED: certificate has expired)',
            ),
          ),
          insecureHttpClientFactory: () => fallbackClient,
        );
        addTearDown(harness.dispose);

        final task = _task(
          id: 'download-task-tls-direct',
          sourceUrl: Uri.parse('https://cdn.example/video.mp4'),
        );
        await harness.manager.enqueue(task);
        final completed = await harness.waitForTask(task.id);

        expect(completed?.status, DownloadStatus.completed);
        expect(await File(completed!.filePath!).readAsBytes(), <int>[
          7,
          8,
          9,
          10,
        ]);
        expect(fallbackClient.requestedRanges, <String?>[null]);
      },
    );

    test(
      'retries HLS downloads with insecure TLS on expired certificates',
      () async {
        final fallbackClient = _SequenceClient(
          responses: <http.StreamedResponse>[
            _streamedResponse(
              bytes:
                  '''
#EXTM3U
#EXTINF:4.0,
seg-1.ts
#EXTINF:4.0,
seg-2.ts
'''
                      .codeUnits,
              statusCode: 200,
              headers: <String, String>{'content-length': '38'},
            ),
            _streamedResponse(
              bytes: <int>[1, 2, 3],
              statusCode: 200,
              headers: <String, String>{'content-length': '3'},
            ),
            _streamedResponse(
              bytes: <int>[4, 5, 6],
              statusCode: 200,
              headers: <String, String>{'content-length': '3'},
            ),
          ],
        );
        final harness = await _DownloadHarness.createWithClient(
          client: _ThrowingClient(
            error: HandshakeException(
              'Handshake error in client '
              '(OS Error: CERTIFICATE_VERIFY_FAILED: certificate has expired)',
            ),
          ),
          insecureHttpClientFactory: () => fallbackClient,
        );
        addTearDown(harness.dispose);

        final task = _task(
          id: 'download-task-tls-hls',
          isHls: true,
          fileName: 'EP 01 - TLS.ts',
          sourceUrl: Uri.parse('https://cdn.example/master.m3u8'),
        );
        await harness.manager.enqueue(task);
        final completed = await harness.waitForTask(task.id);

        expect(completed?.status, DownloadStatus.completed);
        expect(await File(completed!.filePath!).readAsBytes(), <int>[
          1,
          2,
          3,
          4,
          5,
          6,
        ]);
      },
    );

    test(
      'allows StreamWish HLS downloads to start concurrently on Android',
      () async {
        final client = _GateableHlsClient();
        final harness = await _DownloadHarness.createWithClient(
          client: client,
          maxConcurrent: 2,
        );
        addTearDown(harness.dispose);

        final firstTask = _task(
          id: 'download-task-sw-1',
          episodeNumber: 1,
          sourceUrl: Uri.parse('https://cdn.example/sw-1/master.m3u8'),
          fileName: 'EP 01 - SW.ts',
          isHls: true,
          serverName: 'SW',
          detectedHost: 'premilkyway.com',
          headers: const <String, String>{
            'Referer': 'https://sfastwish.com/',
            'Origin': 'https://sfastwish.com',
          },
        );
        final secondTask = _task(
          id: 'download-task-sw-2',
          episodeNumber: 2,
          sourceUrl: Uri.parse('https://cdn.example/sw-2/master.m3u8'),
          fileName: 'EP 02 - SW.ts',
          isHls: true,
          serverName: 'SW',
          detectedHost: 'premilkyway.com',
          headers: const <String, String>{
            'Referer': 'https://sfastwish.com/',
            'Origin': 'https://sfastwish.com',
          },
        );

        await harness.manager.enqueue(firstTask);
        await harness.manager.enqueue(secondTask);

        await Future<void>.delayed(const Duration(milliseconds: 150));

        final firstStatus = await harness.storeTask(firstTask.id);
        final secondStatus = await harness.storeTask(secondTask.id);

        expect(firstStatus?.status, DownloadStatus.downloading);
        expect(secondStatus?.status, DownloadStatus.downloading);

        client.release();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
    );

    test('keeps non-StreamWish HLS downloads concurrent on Android', () async {
      final client = _GateableHlsClient();
      final harness = await _DownloadHarness.createWithClient(
        client: client,
        maxConcurrent: 2,
      );
      addTearDown(harness.dispose);

      final firstTask = _task(
        id: 'download-task-filemoon-1',
        episodeNumber: 1,
        sourceUrl: Uri.parse('https://cdn.example/filemoon-1/master.m3u8'),
        fileName: 'EP 01 - Filemoon.ts',
        isHls: true,
        serverName: 'Filemoon',
        detectedHost: 'filemoon.sx',
      );
      final secondTask = _task(
        id: 'download-task-filemoon-2',
        episodeNumber: 2,
        sourceUrl: Uri.parse('https://cdn.example/filemoon-2/master.m3u8'),
        fileName: 'EP 02 - Filemoon.ts',
        isHls: true,
        serverName: 'Filemoon',
        detectedHost: 'filemoon.sx',
      );

      await harness.manager.enqueue(firstTask);
      await harness.manager.enqueue(secondTask);

      await Future<void>.delayed(const Duration(milliseconds: 150));

      final firstStatus = await harness.storeTask(firstTask.id);
      final secondStatus = await harness.storeTask(secondTask.id);

      expect(firstStatus?.status, DownloadStatus.downloading);
      expect(secondStatus?.status, DownloadStatus.downloading);

      client.release();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });
}

DownloadTask _task({
  String id = 'download-task-1',
  double episodeNumber = 1,
  Uri? sourceUrl,
  String fileName = 'EP 01 - Test.mp4',
  bool isHls = false,
  String? serverName,
  String? detectedHost,
  Map<String, String> headers = const <String, String>{},
}) {
  return DownloadTask(
    id: id,
    anilistId: 1,
    episodeNumber: episodeNumber,
    sourceUrl: sourceUrl ?? Uri.parse('https://cdn.example/video.mp4'),
    status: DownloadStatus.pending,
    createdAt: DateTime(2026),
    animeTitle: 'Test Anime',
    fileName: fileName,
    isHls: isHls,
    serverName: serverName,
    detectedHost: detectedHost,
    headers: headers,
  );
}

http.StreamedResponse _streamedResponse({
  required List<int> bytes,
  required int statusCode,
  Map<String, String> headers = const <String, String>{},
}) {
  return http.StreamedResponse(
    Stream<List<int>>.fromIterable(<List<int>>[bytes]),
    statusCode,
    headers: headers,
    contentLength: bytes.length,
  );
}

final class _DownloadHarness {
  _DownloadHarness._({
    required this.tempDir,
    required this.client,
    required this.store,
    required this.manager,
  });

  final Directory tempDir;
  final _InMemoryDownloadStore store;
  final http.Client client;
  final DownloadManagerService manager;

  static Future<_DownloadHarness> create({
    required _SequenceClient client,
  }) async {
    return createWithClient(client: client);
  }

  static Future<_DownloadHarness> createWithClient({
    required http.Client client,
    http.Client Function()? insecureHttpClientFactory,
    int maxConcurrent = 1,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp(
      'kumoriya-download-manager',
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
      httpClient: client,
      insecureHttpClientFactory: insecureHttpClientFactory,
      maxRetryAttempts: 2,
    );
    return _DownloadHarness._(
      tempDir: tempDir,
      client: client,
      store: store,
      manager: manager,
    );
  }

  _SequenceClient get sequenceClient => client as _SequenceClient;

  Future<DownloadTask?> storeTask(String taskId) async {
    return (await store.getTask(
      taskId,
    )).fold(onSuccess: (value) => value, onFailure: (_) => null);
  }

  Future<DownloadTask?> waitForTask(String taskId) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      final task = (await store.getTask(
        taskId,
      )).fold(onSuccess: (value) => value, onFailure: (_) => null);
      if (task != null &&
          (task.status == DownloadStatus.completed ||
              task.status == DownloadStatus.failed)) {
        return task;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return (await store.getTask(
      taskId,
    )).fold(onSuccess: (value) => value, onFailure: (_) => null);
  }

  Future<void> dispose() async {
    manager.dispose();
    // Small delay lets async file handles close on Windows before cleanup.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } on FileSystemException {
      // Ignore — Windows may still hold a file lock from the HTTP client.
    }
  }
}

final class _SequenceClient extends http.BaseClient {
  _SequenceClient({required List<http.StreamedResponse> responses})
    : _responses = Queue<http.StreamedResponse>.from(responses);

  final Queue<http.StreamedResponse> _responses;
  final requestedRanges = <String?>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedRanges.add(request.headers['Range']);
    if (_responses.isEmpty) {
      throw StateError('No more HTTP responses configured');
    }
    return _responses.removeFirst();
  }
}

final class _GateableHlsClient extends http.BaseClient {
  final Completer<void> _gate = Completer<void>();

  void release() {
    if (!_gate.isCompleted) {
      _gate.complete();
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await _gate.future;

    if (request.method == 'HEAD') {
      return _streamedResponse(
        bytes: const <int>[],
        statusCode: 200,
        headers: const <String, String>{'content-length': '3'},
      );
    }

    if (request.url.path.toLowerCase().endsWith('.m3u8')) {
      return _streamedResponse(
        bytes:
            '''
#EXTM3U
#EXTINF:4.0,
seg.ts
#EXT-X-ENDLIST
'''
                .codeUnits,
        statusCode: 200,
        headers: const <String, String>{'content-length': '38'},
      );
    }

    return _streamedResponse(
      bytes: const <int>[1, 2, 3],
      statusCode: 200,
      headers: const <String, String>{'content-length': '3'},
    );
  }
}

final class _ThrowingClient extends http.BaseClient {
  _ThrowingClient({required this.error});

  final Object error;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw error;
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
  Future<Result<List<DownloadTask>, KumoriyaError>> getAllTasks({
    int? limit,
  }) async {
    final all = _tasks.values.toList(growable: false);
    if (limit != null && all.length > limit) {
      return Success(all.sublist(0, limit));
    }
    return Success(all);
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
    int anilistId, {
    int? limit,
  }) async {
    return Success(
      _tasks.values
          .where((task) => task.anilistId == anilistId)
          .toList(growable: false),
    );
  }

  @override
  Future<Result<List<DownloadTask>, KumoriyaError>> getTasksByStatus(
    DownloadStatus status, {
    int? limit,
  }) async {
    final all = _tasks.values
        .where((task) => task.status == status)
        .toList(growable: false);
    return Success(limit != null ? all.take(limit).toList() : all);
  }

  @override
  Future<Result<List<DownloadTask>, KumoriyaError>> getTasksByStatuses(
    List<DownloadStatus> statuses, {
    int? limit,
  }) async {
    final statusSet = statuses.toSet();
    final all = _tasks.values
        .where((task) => statusSet.contains(task.status))
        .toList(growable: false);
    return Success(limit != null ? all.take(limit).toList() : all);
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
