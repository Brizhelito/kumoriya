import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_app/src/features/manga_downloads/application/manga_download_manager.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

void main() {
  late AppDatabase db;
  late DriftMangaDownloadStore store;
  late Directory tmpRoot;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftMangaDownloadStore(db);
    tmpRoot = await Directory.systemTemp.createTemp('manga_dlm_test_');
  });

  tearDown(() async {
    await db.close();
    if (await tmpRoot.exists()) {
      await tmpRoot.delete(recursive: true);
    }
  });

  test('enqueue downloads pages, packs CBZ, marks task completed', () async {
    final plugin = _FakeMangaPlugin(
      pages: [
        SourcePage(index: 0, imageUrl: Uri.parse('https://cdn.test/p0.jpg')),
        SourcePage(index: 1, imageUrl: Uri.parse('https://cdn.test/p1.png')),
      ],
    );

    final fakeBytes = <Uri, List<int>>{
      Uri.parse('https://cdn.test/p0.jpg'): const [10, 20, 30],
      Uri.parse('https://cdn.test/p1.png'): const [40, 50],
    };
    final client = MockClient((req) async {
      final body = fakeBytes[req.url];
      if (body == null) return http.Response('not found', 404);
      return http.Response.bytes(body, 200);
    });

    final manager = MangaDownloadManager(
      store: store,
      downloadsRootDir: () async => tmpRoot,
      pluginResolver: (_) => plugin,
      httpClient: client,
    );

    final task = MangaDownloadTask(
      id: 'task-1',
      mangaAnilistId: 42,
      sourceId: 'mangadex',
      sourceMangaId: 'm-1',
      sourceChapterId: 'c-1',
      chapterNumber: 1.0,
      status: MangaDownloadStatus.pending,
      mangaTitle: 'Sample Manga',
      chapterTitle: 'Pilot',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );

    final completed = manager.statusStream
        .where(
          (e) =>
              e.taskId == 'task-1' &&
              (e.newStatus == MangaDownloadStatus.completed ||
                  e.newStatus == MangaDownloadStatus.failed),
        )
        .first;

    final r = await manager.enqueue(task);
    expect(r.isSuccess, isTrue);

    final finalEvent = await completed.timeout(const Duration(seconds: 5));
    expect(finalEvent.newStatus, MangaDownloadStatus.completed);

    // Task row reflects final state.
    final stored = await store.getTask('task-1');
    final t = stored.fold(onSuccess: (v) => v, onFailure: (_) => null);
    expect(t, isNotNull);
    expect(t!.status, MangaDownloadStatus.completed);
    expect(t.pageCount, 2);
    expect(t.pagesDownloaded, 2);
    expect(t.cbzPath, isNotNull);

    // CBZ exists and has the right entries.
    final cbz = File(t.cbzPath!);
    expect(await cbz.exists(), isTrue);
    final archive = ZipDecoder().decodeBytes(await cbz.readAsBytes());
    final names = archive.files.map((f) => f.name).toList()..sort();
    expect(names, ['000.jpg', '001.png', 'metadata.json']);

    final sidecar = File('${cbz.path}$mangaDownloadSidecarSuffix');
    expect(await sidecar.exists(), isTrue);
    final sidecarJson =
        jsonDecode(await sidecar.readAsString()) as Map<String, dynamic>;
    expect(sidecarJson['mediaKind'], 'manga');
    expect(sidecarJson['taskId'], 'task-1');
    expect(sidecarJson['mangaAnilistId'], 42);
    expect(sidecarJson['sourceId'], 'mangadex');
    expect(sidecarJson['sourceChapterId'], 'c-1');
    expect(sidecarJson['cbzPath'], cbz.path);
    expect(sidecarJson['fileName'], cbz.uri.pathSegments.last);
    expect(sidecarJson['totalBytes'], await cbz.length());

    manager.dispose();
  });

  test('marks task failed when the source plugin yields no pages', () async {
    final plugin = _FakeMangaPlugin(pages: <SourcePage>[]);
    final manager = MangaDownloadManager(
      store: store,
      downloadsRootDir: () async => tmpRoot,
      pluginResolver: (_) => plugin,
      httpClient: MockClient((_) async => http.Response('', 200)),
    );

    final task = MangaDownloadTask(
      id: 't-empty',
      mangaAnilistId: 1,
      sourceId: 'mangadex',
      sourceMangaId: 'm',
      sourceChapterId: 'c',
      chapterNumber: 1.0,
      status: MangaDownloadStatus.pending,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );

    final terminal = manager.statusStream
        .where((e) => e.newStatus == MangaDownloadStatus.failed)
        .first;
    await manager.enqueue(task);
    final ev = await terminal.timeout(const Duration(seconds: 5));
    expect(ev.errorMessage, 'manga_downloads.empty_chapter');

    manager.dispose();
  });

  test('marks task failed and reports plugin code when fetch fails', () async {
    final plugin = _FakeMangaPlugin(
      pageError: const SimpleError(
        code: 'plugin.bad_things',
        message: 'oh no',
        kind: KumoriyaErrorKind.transport,
      ),
    );
    final manager = MangaDownloadManager(
      store: store,
      downloadsRootDir: () async => tmpRoot,
      pluginResolver: (_) => plugin,
      httpClient: MockClient((_) async => http.Response('', 200)),
    );

    final task = MangaDownloadTask(
      id: 't-fail',
      mangaAnilistId: 2,
      sourceId: 'mangadex',
      sourceMangaId: 'm',
      sourceChapterId: 'c',
      chapterNumber: 1.0,
      status: MangaDownloadStatus.pending,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
    final terminal = manager.statusStream
        .where((e) => e.newStatus == MangaDownloadStatus.failed)
        .first;
    await manager.enqueue(task);
    final ev = await terminal.timeout(const Duration(seconds: 5));
    expect(ev.errorMessage, 'plugin.bad_things');
    manager.dispose();
  });

  test('delete removes the task row and the CBZ file', () async {
    // Seed a "completed" task with a real file on disk.
    final cbz = File('${tmpRoot.path}/42/x.cbz');
    await cbz.parent.create(recursive: true);
    await cbz.writeAsBytes(const [1, 2, 3]);
    final sidecar = File('${cbz.path}$mangaDownloadSidecarSuffix');
    await sidecar.writeAsString('{"mediaKind":"manga"}');

    final task = MangaDownloadTask(
      id: 't-del',
      mangaAnilistId: 42,
      sourceId: 'mangadex',
      sourceMangaId: 'm',
      sourceChapterId: 'c',
      chapterNumber: 1.0,
      status: MangaDownloadStatus.completed,
      cbzPath: cbz.path,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
    await store.insertTask(task);

    final manager = MangaDownloadManager(
      store: store,
      downloadsRootDir: () async => tmpRoot,
      pluginResolver: (_) => null,
      httpClient: MockClient((_) async => http.Response('', 200)),
    );

    await manager.delete('t-del');
    expect(await cbz.exists(), isFalse);
    expect(await sidecar.exists(), isFalse);
    final r = await store.getTask('t-del');
    expect(r.fold(onSuccess: (v) => v, onFailure: (_) => null), isNull);
    manager.dispose();
  });
}

class _FakeMangaPlugin implements MangaSourcePlugin {
  _FakeMangaPlugin({this.pages = const <SourcePage>[], this.pageError});

  final List<SourcePage> pages;
  final KumoriyaError? pageError;

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'mangadex',
    displayName: 'MangaDex',
    type: PluginType.source,
    capabilities: <PluginCapability>{},
  );

  @override
  MangaSourceCapabilities get mangaCapabilities =>
      const MangaSourceCapabilities();

  @override
  Future<Result<List<SourcePage>, KumoriyaError>> getChapterPages(
    SourceChapter chapter,
  ) async {
    if (pageError != null) return Failure(pageError!);
    return Success(pages);
  }

  @override
  Future<Result<List<SourceChapter>, KumoriyaError>> getChapters(
    MangaChapterQuery query,
  ) async => const Success(<SourceChapter>[]);

  @override
  Future<Result<SourceMangaDetail, KumoriyaError>> getMangaDetail(
    String sourceMangaId,
  ) async => Failure(
    const SimpleError(
      code: 'unimpl',
      message: 'unused',
      kind: KumoriyaErrorKind.unexpected,
    ),
  );

  @override
  Future<Result<List<SourceMangaMatch>, KumoriyaError>> getLatestUpdates({
    int page = 1,
    int limit = 20,
  }) async => const Success(<SourceMangaMatch>[]);

  @override
  Future<Result<List<SourceMangaMatch>, KumoriyaError>> search(
    MangaSearchQuery query,
  ) async => const Success(<SourceMangaMatch>[]);
}
