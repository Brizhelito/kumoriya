import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/library/domain/unified_library_entry.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

void main() {
  group('UnifiedLibraryEntry', () {
    test('equality is keyed by (mediaKind, anilistId)', () {
      const a1 = UnifiedLibraryEntry(
        mediaKind: MediaKind.anime,
        anilistId: 1,
        title: 'Naruto',
      );
      const a1Other = UnifiedLibraryEntry(
        mediaKind: MediaKind.anime,
        anilistId: 1,
        title: 'A different title — still the same entry',
        coverImageUrl: 'https://x/cover.jpg',
      );
      const m1 = UnifiedLibraryEntry(
        mediaKind: MediaKind.manga,
        anilistId: 1,
        title: 'Naruto (manga)',
      );

      // Same kind + id → equal even with different display fields.
      expect(a1, equals(a1Other));
      expect(a1.hashCode, equals(a1Other.hashCode));
      // Same id but different kind → distinct entries.
      expect(a1, isNot(equals(m1)));
    });

    test('coverImageUrl is optional', () {
      const e = UnifiedLibraryEntry(
        mediaKind: MediaKind.manga,
        anilistId: 7,
        title: 'No cover yet',
      );
      expect(e.coverImageUrl, isNull);
    });
  });
}
