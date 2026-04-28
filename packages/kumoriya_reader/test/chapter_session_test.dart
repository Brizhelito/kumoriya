import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_reader/kumoriya_reader.dart';

void main() {
  group('ChapterSession', () {
    test('rejects negative initialPageIndex', () {
      expect(
        () => ChapterSession(
          mangaAnilistId: 1,
          sourceId: 'mangadex',
          chapter: const MangaChapter(number: 1, title: 't', language: 'en'),
          pages: const <MangaPage>[],
          mode: ReaderMode.paginated,
          initialPageIndex: -1,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('initialScrollOffsetPx is optional and defaults to null', () {
      final session = ChapterSession(
        mangaAnilistId: 1,
        sourceId: 'mangadex',
        chapter: const MangaChapter(number: 1, title: 't', language: 'en'),
        pages: <MangaPage>[
          MangaPage(index: 0, imageUrl: Uri.parse('https://x/a.jpg')),
        ],
        mode: ReaderMode.vertical,
      );
      expect(session.initialScrollOffsetPx, isNull);
      expect(session.initialPageIndex, 0);
    });
  });
}
