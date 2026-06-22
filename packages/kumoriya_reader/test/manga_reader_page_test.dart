import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_reader/kumoriya_reader.dart';

class _RecordingSink implements ReaderProgressSink {
  final List<({int pageIndex, double? offset, bool completed})> calls = [];

  @override
  Future<void> save({
    required int mangaAnilistId,
    required String sourceId,
    required double chapterNumber,
    required int pageIndex,
    double? scrollOffsetPx,
    bool completed = false,
  }) async {
    calls.add((
      pageIndex: pageIndex,
      offset: scrollOffsetPx,
      completed: completed,
    ));
  }
}

void main() {
  ChapterSession buildSession({
    required ReaderMode mode,
    int pageCount = 3,
    int initialPageIndex = 0,
  }) {
    return ChapterSession(
      mangaAnilistId: 1,
      sourceId: 'mangadex',
      chapter: const MangaChapter(number: 1, title: 't', language: 'en'),
      pages: List.generate(
        pageCount,
        (i) => MangaPage(
          index: i,
          imageUrl: Uri.parse('https://example.test/p$i.jpg'),
        ),
      ),
      mode: mode,
      initialPageIndex: initialPageIndex,
    );
  }

  testWidgets('renders empty state when chapter has no pages', (tester) async {
    final session = ChapterSession(
      mangaAnilistId: 1,
      sourceId: 'mangadex',
      chapter: const MangaChapter(number: 1, title: 't', language: 'en'),
      pages: const <MangaPage>[],
      mode: ReaderMode.paginated,
    );
    await tester.pumpWidget(
      MaterialApp(home: MangaReaderPage(session: session)),
    );
    await tester.pump();
    expect(find.text('This chapter has no pages.'), findsOneWidget);
  });

  testWidgets('renders title from session.title', (tester) async {
    final session = ChapterSession(
      mangaAnilistId: 1,
      sourceId: 'mangadex',
      chapter: const MangaChapter(number: 1, title: 't', language: 'en'),
      pages: <MangaPage>[
        MangaPage(index: 0, imageUrl: Uri.parse('https://x/a.jpg')),
      ],
      mode: ReaderMode.paginated,
      title: 'Custom Title',
    );
    await tester.pumpWidget(
      MaterialApp(home: MangaReaderPage(session: session)),
    );
    await tester.pump();
    expect(find.text('Custom Title'), findsOneWidget);
  });

  testWidgets('falls back to "Chapter N" when no title is provided', (
    tester,
  ) async {
    final session = buildSession(mode: ReaderMode.paginated, pageCount: 1);
    await tester.pumpWidget(
      MaterialApp(home: MangaReaderPage(session: session)),
    );
    await tester.pump();
    expect(find.text('Chapter 1'), findsOneWidget);
  });

  testWidgets('flushes progress on dispose when a sink is provided', (
    tester,
  ) async {
    final sink = _RecordingSink();
    final session = buildSession(
      mode: ReaderMode.paginated,
      pageCount: 3,
      initialPageIndex: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MangaReaderPage(session: session, progressSink: sink),
      ),
    );
    await tester.pump();
    // Replace with another widget so the reader disposes.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(sink.calls, isNotEmpty);
    expect(sink.calls.last.pageIndex, 1);
  });
}
