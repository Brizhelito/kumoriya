import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_reader/kumoriya_reader.dart';

void main() {
  group('defaultReaderModeForFormat', () {
    test('manhwa and manhua default to vertical', () {
      expect(
        defaultReaderModeForFormat(MangaFormat.manhwa),
        ReaderMode.vertical,
      );
      expect(
        defaultReaderModeForFormat(MangaFormat.manhua),
        ReaderMode.vertical,
      );
    });

    test('manga / one-shot / doujinshi default to paginated', () {
      expect(
        defaultReaderModeForFormat(MangaFormat.manga),
        ReaderMode.paginated,
      );
      expect(
        defaultReaderModeForFormat(MangaFormat.oneShot),
        ReaderMode.paginated,
      );
      expect(
        defaultReaderModeForFormat(MangaFormat.doujinshi),
        ReaderMode.paginated,
      );
    });

    test('unknown defaults to paginated (safer for traditional layout)', () {
      expect(
        defaultReaderModeForFormat(MangaFormat.unknown),
        ReaderMode.paginated,
      );
    });
  });
}
