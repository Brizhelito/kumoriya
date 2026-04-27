import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:test/test.dart';

void main() {
  group('MediaKind', () {
    test('wireValue is stable for known kinds', () {
      expect(MediaKind.anime.wireValue, 'anime');
      expect(MediaKind.manga.wireValue, 'manga');
    });

    test('tryParse round-trips wireValue for every kind', () {
      for (final kind in MediaKind.values) {
        expect(MediaKind.tryParse(kind.wireValue), kind);
      }
    });

    test('tryParse returns null for unknown or null input', () {
      expect(MediaKind.tryParse(null), isNull);
      expect(MediaKind.tryParse(''), isNull);
      expect(MediaKind.tryParse('ANIME'), isNull); // case sensitive
      expect(MediaKind.tryParse('lightnovel'), isNull);
    });

    test('parse throws ArgumentError on unknown input', () {
      expect(() => MediaKind.parse('lightnovel'), throwsArgumentError);
    });

    test('parse round-trips wireValue for every kind', () {
      for (final kind in MediaKind.values) {
        expect(MediaKind.parse(kind.wireValue), kind);
      }
    });
  });
}
