import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_reader/kumoriya_reader.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:path/path.dart' as p;

import '../../../../shared/storage_providers.dart';
import '../../../manga_downloads/domain/cbz_unpacker.dart';
import '../../../manga_downloads/presentation/providers/manga_download_providers.dart';
import '../../application/services/composite_manga_catalog_repository.dart';
import '../providers/manga_catalog_providers.dart';

/// Loads page list + resume position for a chapter and pushes the
/// `MangaReaderPage`. This widget is the lifecycle-anchor for one
/// reader session: when it leaves the tree, the underlying
/// `MangaReaderPage` and its progress sink go with it.
class MangaReaderRoute extends ConsumerWidget {
  const MangaReaderRoute({
    super.key,
    required this.mangaAnilistId,
    required this.chapter,
    required this.format,
  });

  final int mangaAnilistId;
  final MangaChapter chapter;
  final MangaFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = _ReaderArgs(
      mangaAnilistId: mangaAnilistId,
      chapter: chapter,
      format: format,
    );
    final asyncSession = ref.watch(_chapterSessionProvider(args));
    return asyncSession.when(
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black54,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e.toString(),
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (session) => Consumer(
        builder: (context, innerRef, _) {
          // Resolve sourceChapterId once via openChapter cache (we
          // already populated it during _chapterSessionProvider).
          // The sink looks it up at save() time.
          return MangaReaderPage(
            session: session,
            progressSink: _DriftReaderProgressSink(
              store: innerRef.read(mangaProgressStoreProvider),
              sourceChapterIdResolver: (anilistId, chapter) async {
                final repo = innerRef.read(mangaCatalogRepositoryProvider);
                if (repo is! CompositeMangaCatalogRepository) return null;
                final r = await repo.openChapter(
                  mangaAnilistId: anilistId,
                  chapter: chapter,
                );
                return r.fold<String?>(
                  onSuccess: (v) => v.sourceChapterId,
                  onFailure: (_) => null,
                );
              },
              chapter: chapter,
            ),
          );
        },
      ),
    );
  }
}

@immutable
class _ReaderArgs {
  const _ReaderArgs({
    required this.mangaAnilistId,
    required this.chapter,
    required this.format,
  });

  final int mangaAnilistId;
  final MangaChapter chapter;
  final MangaFormat format;

  @override
  bool operator ==(Object other) =>
      other is _ReaderArgs &&
      other.mangaAnilistId == mangaAnilistId &&
      other.chapter.number == chapter.number &&
      other.chapter.language == chapter.language &&
      other.chapter.scanlator == chapter.scanlator &&
      other.format == format;

  @override
  int get hashCode => Object.hash(
    mangaAnilistId,
    chapter.number,
    chapter.language,
    chapter.scanlator,
    format,
  );
}

final _chapterSessionProvider = FutureProvider.autoDispose
    .family<ChapterSession, _ReaderArgs>((ref, args) async {
      final repo = ref.watch(mangaCatalogRepositoryProvider);
      // We rely on the composite-specific getChapterPages method.
      // Other implementations of MangaCatalogRepository would need
      // their own chapter-session loader; for now only the composite
      // is wired.
      if (repo is! CompositeMangaCatalogRepository) {
        throw Exception(
          'reader.unsupported_repo: Active manga catalog repository '
          'does not support the reader.',
        );
      }

      // Slice 11: prefer the local CBZ when the chapter has a
      // completed download. Falls back to the network path otherwise.
      // We still need `sourceChapterId` for resume persistence; resolve
      // it from the cached SourceChapter (cheap, no I/O) — and only go
      // to the network when the local file is absent.
      // S7.5: tagged lookup carries the originating plugin id so
      // progress / downloads / session state are scoped per-source
      // rather than always landing under the legacy `'mangadex'` key.
      final cachedTagged = repo.lookupTaggedSourceChapter(
        mangaAnilistId: args.mangaAnilistId,
        chapter: args.chapter,
      );
      List<MangaPage>? localPages;
      String? localSourceChapterId;
      String? localSourceId;
      if (cachedTagged != null) {
        final downloadStore = ref.read(mangaDownloadStoreProvider);
        final taskRes = await downloadStore.getTaskByChapter(
          mangaAnilistId: args.mangaAnilistId,
          sourceId: cachedTagged.sourceId,
          sourceChapterId: cachedTagged.chapter.sourceChapterId,
        );
        final task = taskRes.fold(onSuccess: (v) => v, onFailure: (_) => null);
        if (task != null &&
            task.status == MangaDownloadStatus.completed &&
            task.cbzPath != null &&
            await File(task.cbzPath!).exists()) {
          final rootDirFn = ref.read(mangaDownloadsRootDirProvider);
          final root = await rootDirFn();
          final extractDir = Directory(
            p.join(root.path, '_extracted', task.id),
          );
          final unpack = await CbzUnpacker.extract(
            cbzFile: File(task.cbzPath!),
            extractDir: extractDir,
          );
          unpack.fold(
            onSuccess: (pages) {
              localPages = pages;
              localSourceChapterId = cachedTagged.chapter.sourceChapterId;
              localSourceId = cachedTagged.sourceId;
            },
            onFailure: (_) {
              /* fall back to network */
            },
          );
        }
      }

      final ({String sourceId, String sourceChapterId, List<MangaPage> pages})
      opened;
      if (localPages != null &&
          localSourceChapterId != null &&
          localSourceId != null) {
        opened = (
          sourceId: localSourceId!,
          sourceChapterId: localSourceChapterId!,
          pages: localPages!,
        );
      } else {
        final openResult = await repo.openChapter(
          mangaAnilistId: args.mangaAnilistId,
          chapter: args.chapter,
        );
        opened = openResult
            .fold<
              ({
                String sourceId,
                String sourceChapterId,
                List<MangaPage> pages,
              })?
            >(
              onSuccess: (v) => v,
              onFailure: (err) {
                throw Exception('${err.code}: ${err.message}');
              },
            )!;
      }

      // Resume position (best effort; missing → start at page 0).
      int initialPage = 0;
      double? initialOffset;
      try {
        final progressResult = await ref
            .read(mangaProgressStoreProvider)
            .getProgress(
              mangaAnilistId: args.mangaAnilistId,
              sourceId: opened.sourceId,
              sourceChapterId: opened.sourceChapterId,
            );
        progressResult.fold(
          onSuccess: (p) {
            if (p != null) {
              initialPage = p.pageIndex;
              initialOffset = p.scrollOffset;
            }
          },
          onFailure: (_) {},
        );
      } catch (_) {
        // Resume is best-effort; never block the reader on it.
      }

      return ChapterSession(
        mangaAnilistId: args.mangaAnilistId,
        sourceId: opened.sourceId,
        chapter: args.chapter,
        pages: opened.pages,
        mode: defaultReaderModeForFormat(args.format),
        initialPageIndex: initialPage,
        initialScrollOffsetPx: initialOffset,
      );
    });

/// Minimal Drift-backed implementation of `ReaderProgressSink`.
///
/// `MangaProgressStore.upsert` is keyed by `sourceChapterId`, which
/// the reader doesn't carry. We resolve it lazily through the
/// composite repo's per-manga cache (already warm because the reader
/// was opened from the same screen that populated it).
class _DriftReaderProgressSink implements ReaderProgressSink {
  _DriftReaderProgressSink({
    required MangaProgressStore store,
    required Future<String?> Function(int anilistId, MangaChapter chapter)
    sourceChapterIdResolver,
    required this.chapter,
  }) : _store = store,
       _resolve = sourceChapterIdResolver;

  final MangaProgressStore _store;
  final Future<String?> Function(int, MangaChapter) _resolve;
  final MangaChapter chapter;

  @override
  Future<void> save({
    required int mangaAnilistId,
    required String sourceId,
    required double chapterNumber,
    required int pageIndex,
    double? scrollOffsetPx,
    bool completed = false,
  }) async {
    final sourceChapterId = await _resolve(mangaAnilistId, chapter);
    if (sourceChapterId == null) return;
    await _store.upsert(
      MangaChapterProgress(
        mangaAnilistId: mangaAnilistId,
        sourceId: sourceId,
        sourceChapterId: sourceChapterId,
        chapterNumber: chapterNumber,
        pageIndex: pageIndex,
        scrollOffset: scrollOffsetPx,
        readState: completed
            ? MangaReadState.completed
            : MangaReadState.reading,
        updatedAt: DateTime.now(),
      ),
    );
    await _store.upsertReadHistory(
      mangaAnilistId: mangaAnilistId,
      chapterNumber: chapterNumber,
      lastSourceId: sourceId,
      lastSourceChapterId: sourceChapterId,
      lastPageIndex: pageIndex,
    );
  }
}
