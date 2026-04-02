/// Smoke test that proves HLS downloads survive non-UTF-8 bytes in playlist
/// responses — the exact scenario that was causing FormatException in
/// production when downloading from StreamWish via AnimeFLV.
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
  group('HLS download with non-UTF-8 playlist bytes', () {
    test('completes even when m3u8 contains invalid UTF-8', () async {
      final server = await _NonUtf8HlsServer.start();
      addTearDown(server.close);

      final harness = await _Harness.create();
      addTearDown(harness.dispose);

      await harness.manager.enqueue(
        DownloadTask(
          id: 'hls-bad-encoding',
          anilistId: 12345,
          episodeNumber: 1.0,
          sourceUrl: server.masterUri,
          status: DownloadStatus.pending,
          createdAt: DateTime(2026),
          fileName: 'EP 01 - StreamWish [1080p].ts',
          animeTitle: 'Jujutsu Kaisen Test',
          isHls: true,
        ),
      );

      final task = await harness.waitForTask('hls-bad-encoding');
      expect(task, isNotNull, reason: 'Task should exist in store');
      expect(
        task!.status,
        DownloadStatus.completed,
        reason:
            'HLS download must complete despite non-UTF-8 bytes in playlist. '
            'Got status=${task.status}, error=${task.errorMessage}',
      );
      expect(
        await File(task.filePath!).readAsBytes(),
        _NonUtf8HlsServer.segmentPayload,
      );
    });

    test('completes when m3u8 has BOM prefix', () async {
      final server = await _NonUtf8HlsServer.start(variant: _BomVariant());
      addTearDown(server.close);

      final harness = await _Harness.create();
      addTearDown(harness.dispose);

      await harness.manager.enqueue(
        DownloadTask(
          id: 'hls-bom',
          anilistId: 12345,
          episodeNumber: 2.0,
          sourceUrl: server.masterUri,
          status: DownloadStatus.pending,
          createdAt: DateTime(2026),
          fileName: 'EP 02 - StreamWish [1080p].ts',
          animeTitle: 'Jujutsu Kaisen Test',
          isHls: true,
        ),
      );

      final task = await harness.waitForTask('hls-bom');
      expect(task, isNotNull);
      expect(
        task!.status,
        DownloadStatus.completed,
        reason:
            'HLS download must complete with BOM prefix in playlist. '
            'Got status=${task.status}, error=${task.errorMessage}',
      );
    });

    test('completes when m3u8 is gzip-compressed', () async {
      final server = await _NonUtf8HlsServer.start(variant: _GzipVariant());
      addTearDown(server.close);

      final harness = await _Harness.create();
      addTearDown(harness.dispose);

      await harness.manager.enqueue(
        DownloadTask(
          id: 'hls-gzip',
          anilistId: 12345,
          episodeNumber: 4.0,
          sourceUrl: server.masterUri,
          status: DownloadStatus.pending,
          createdAt: DateTime(2026),
          fileName: 'EP 04 - StreamWish [1080p].ts',
          animeTitle: 'Jujutsu Kaisen Test',
          isHls: true,
        ),
      );

      final task = await harness.waitForTask('hls-gzip');
      expect(task, isNotNull);
      expect(
        task!.status,
        DownloadStatus.completed,
        reason:
            'HLS download must complete with gzip-compressed playlist '
            '(StreamWish CDN scenario). '
            'Got status=${task.status}, error=${task.errorMessage}',
      );
      expect(
        await File(task.filePath!).readAsBytes(),
        _NonUtf8HlsServer.segmentPayload,
      );
    });

    test('completes when m3u8 has Latin-1 chars', () async {
      final server = await _NonUtf8HlsServer.start(variant: _Latin1Variant());
      addTearDown(server.close);

      final harness = await _Harness.create();
      addTearDown(harness.dispose);

      await harness.manager.enqueue(
        DownloadTask(
          id: 'hls-latin1',
          anilistId: 12345,
          episodeNumber: 3.0,
          sourceUrl: server.masterUri,
          status: DownloadStatus.pending,
          createdAt: DateTime(2026),
          fileName: 'EP 03 - StreamWish [1080p].ts',
          animeTitle: 'Jujutsu Kaisen Test',
          isHls: true,
        ),
      );

      final task = await harness.waitForTask('hls-latin1');
      expect(task, isNotNull);
      expect(
        task!.status,
        DownloadStatus.completed,
        reason:
            'HLS download must complete with Latin-1 chars in playlist. '
            'Got status=${task.status}, error=${task.errorMessage}',
      );
    });
  });
}

// ─── Server variants ─────────────────────────────────────────────────────────

abstract class _PlaylistVariant {
  const _PlaylistVariant();
  List<int> masterBytes(String baseUrl);
  List<int> mediaBytes(String baseUrl);
}

/// Default: raw invalid UTF-8 bytes inside comment lines (like a CDN injecting
/// non-ASCII metadata). The parser skips lines starting with '#', so URLs
/// remain valid while the raw bytes break strict UTF-8 decoding.
class _RawInvalidUtf8Variant extends _PlaylistVariant {
  const _RawInvalidUtf8Variant();

  @override
  List<int> masterBytes(String baseUrl) {
    // Comment line with invalid UTF-8 bytes at positions 1 and 2.
    // This reproduces "Unexpected extension byte (at offset 1)".
    return [
      0x23, // '#'
      0x80, // unexpected continuation byte (triggers FormatException)
      0x81, // another invalid byte
      0x0A, // newline
      ...utf8.encode('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1200000\n'),
      ...utf8.encode('$baseUrl/media.m3u8\n'),
    ];
  }

  @override
  List<int> mediaBytes(String baseUrl) {
    // Invalid bytes inside comment lines — URLs are clean.
    return [
      ...utf8.encode('#EXTM3U\n'),
      0x23, 0x80, 0x81, 0x0A, // "# + two invalid bytes + newline"
      ...utf8.encode(
        '#EXTINF:2.0,\n'
        '$baseUrl/seg-1.ts\n'
        '#EXT-X-ENDLIST\n',
      ),
    ];
  }
}

/// BOM (Byte Order Mark) prefix: EF BB BF
class _BomVariant extends _PlaylistVariant {
  @override
  List<int> masterBytes(String baseUrl) {
    return [
      0xEF, 0xBB, 0xBF, // UTF-8 BOM
      ...utf8.encode(
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1200000\n'
        '$baseUrl/media.m3u8\n',
      ),
    ];
  }

  @override
  List<int> mediaBytes(String baseUrl) {
    return [
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(
        '#EXTM3U\n'
        '#EXTINF:2.0,\n'
        '$baseUrl/seg-1.ts\n'
        '#EXT-X-ENDLIST\n',
      ),
    ];
  }
}

/// Gzip-compressed playlist: the entire m3u8 is gzip-encoded, as StreamWish
/// CDN does in production. Bytes start with 0x1f 0x8b (gzip magic).
class _GzipVariant extends _PlaylistVariant {
  @override
  List<int> masterBytes(String baseUrl) {
    final plain = utf8.encode(
      '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1200000\n'
      '$baseUrl/media.m3u8\n',
    );
    return gzip.encode(plain);
  }

  @override
  List<int> mediaBytes(String baseUrl) {
    final plain = utf8.encode(
      '#EXTM3U\n'
      '#EXTINF:2.0,\n'
      '$baseUrl/seg-1.ts\n'
      '#EXT-X-ENDLIST\n',
    );
    return gzip.encode(plain);
  }
}

/// Latin-1 encoded chars (e.g. ñ = 0xF1 in Latin-1, invalid as lone UTF-8)
class _Latin1Variant extends _PlaylistVariant {
  @override
  List<int> masterBytes(String baseUrl) {
    return [
      ...utf8.encode('#EXTM3U\n'),
      0x23, // '#'
      0xF1, // ñ in latin-1, invalid in UTF-8
      0x0A,
      ...utf8.encode(
        '#EXT-X-STREAM-INF:BANDWIDTH=1200000\n'
        '$baseUrl/media.m3u8\n',
      ),
    ];
  }

  @override
  List<int> mediaBytes(String baseUrl) {
    return utf8.encode(
      '#EXTM3U\n'
      '#EXTINF:2.0,\n'
      '$baseUrl/seg-1.ts\n'
      '#EXT-X-ENDLIST\n',
    );
  }
}

// ─── Test server ─────────────────────────────────────────────────────────────

final class _NonUtf8HlsServer {
  _NonUtf8HlsServer._(this._server, this._variant);

  final HttpServer _server;
  final _PlaylistVariant _variant;

  static const segmentPayload = <int>[10, 20, 30, 40, 50];

  String get _baseUrl => 'http://${_server.address.host}:${_server.port}';

  Uri get masterUri => Uri.parse('$_baseUrl/master.m3u8');

  static Future<_NonUtf8HlsServer> start({_PlaylistVariant? variant}) async {
    final v = variant ?? const _RawInvalidUtf8Variant();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final inst = _NonUtf8HlsServer._(server, v);
    server.listen(inst._handle);
    return inst;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest req) async {
    try {
      switch (req.uri.path) {
        case '/master.m3u8':
          final bytes = _variant.masterBytes(_baseUrl);
          req.response.headers.set(
            HttpHeaders.contentTypeHeader,
            'application/vnd.apple.mpegurl',
          );
          req.response.headers.set(
            HttpHeaders.contentLengthHeader,
            bytes.length,
          );
          req.response.add(bytes);
          break;
        case '/media.m3u8':
          final bytes = _variant.mediaBytes(_baseUrl);
          req.response.headers.set(
            HttpHeaders.contentTypeHeader,
            'application/vnd.apple.mpegurl',
          );
          req.response.headers.set(
            HttpHeaders.contentLengthHeader,
            bytes.length,
          );
          req.response.add(bytes);
          break;
        case '/seg-1.ts':
          req.response.headers.set(HttpHeaders.contentTypeHeader, 'video/mp2t');
          req.response.headers.set(
            HttpHeaders.contentLengthHeader,
            segmentPayload.length,
          );
          req.response.add(segmentPayload);
          break;
        default:
          req.response.statusCode = HttpStatus.notFound;
      }
    } finally {
      await req.response.close();
    }
  }
}

// ─── Test harness ────────────────────────────────────────────────────────────

final class _Harness {
  _Harness._({
    required this.tempDir,
    required this.store,
    required this.manager,
  });

  final Directory tempDir;
  final _InMemoryStore store;
  final DownloadManagerService manager;

  static Future<_Harness> create() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'kumoriya-hls-encoding-smoke',
    );
    final store = _InMemoryStore();
    final dirService = DownloadDirectoryService(
      store: _NoopDirStore(),
      defaultDirectoryResolver: () async => tempDir,
    );
    final mgr = DownloadManagerService(
      store: store,
      directoryService: dirService,
      libraryIndexService: DownloadLibraryIndexService(
        store: store,
        directoryService: dirService,
      ),
      maxConcurrent: 1,
      maxRetryAttempts: 1,
    );
    return _Harness._(tempDir: tempDir, store: store, manager: mgr);
  }

  Future<DownloadTask?> waitForTask(String id) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      final task = (await store.getTask(
        id,
      )).fold(onSuccess: (v) => v, onFailure: (_) => null);
      if (task != null &&
          (task.status == DownloadStatus.completed ||
              task.status == DownloadStatus.failed)) {
        return task;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return (await store.getTask(
      id,
    )).fold(onSuccess: (v) => v, onFailure: (_) => null);
  }

  Future<void> dispose() async {
    manager.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

final class _InMemoryStore implements DownloadStore {
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
    final all = _tasks.values.toList();
    return Success(limit != null ? all.take(limit).toList() : all);
  }

  @override
  Future<Result<DownloadTask?, KumoriyaError>> getTask(String id) async =>
      Success(_tasks[id]);

  @override
  Future<Result<DownloadTask?, KumoriyaError>> getTaskByEpisode(
    int anilistId,
    double episodeNumber,
  ) async => Success(
    _tasks.values
        .where(
          (t) => t.anilistId == anilistId && t.episodeNumber == episodeNumber,
        )
        .firstOrNull,
  );

  @override
  Future<Result<List<DownloadTask>, KumoriyaError>> getTasksByAnime(
    int anilistId, {
    int? limit,
  }) async =>
      Success(_tasks.values.where((t) => t.anilistId == anilistId).toList());

  @override
  Future<Result<List<DownloadTask>, KumoriyaError>> getTasksByStatus(
    DownloadStatus status, {
    int? limit,
  }) async {
    final matched = _tasks.values.where((t) => t.status == status).toList();
    return Success(limit != null ? matched.take(limit).toList() : matched);
  }

  @override
  Future<Result<List<DownloadTask>, KumoriyaError>> getTasksByStatuses(
    List<DownloadStatus> statuses, {
    int? limit,
  }) async {
    final statusSet = statuses.toSet();
    final matched = _tasks.values
        .where((t) => statusSet.contains(t.status))
        .toList();
    return Success(limit != null ? matched.take(limit).toList() : matched);
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

final class _NoopDirStore implements DownloadDirectoryStore {
  @override
  Future<String?> readCustomDirectoryPath() async => null;

  @override
  Future<void> writeCustomDirectoryPath(String? path) async {}
}
