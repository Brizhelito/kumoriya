import 'package:kumoriya_source_runtime/kumoriya_source_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('MirrorList', () {
    test('rejects empty input', () {
      expect(() => MirrorList(<Uri>[]), throwsArgumentError);
    });

    test('preserves order of provided entries', () {
      final list = MirrorList(<Uri>[
        Uri.parse('https://a.example/'),
        Uri.parse('https://b.example/'),
      ]);
      expect(list.entries.map((u) => u.host).toList(), <String>[
        'a.example',
        'b.example',
      ]);
      expect(list.primary.host, 'a.example');
      expect(list.length, 2);
    });

    test('normalizes entries to end with trailing slash', () {
      final list = MirrorList(<Uri>[
        Uri.parse('https://a.example'),
        Uri.parse('https://b.example/api'),
      ]);
      expect(list.entries[0].path, '/');
      expect(list.entries[1].path, '/api/');
    });

    test('withPreferred promotes override and dedupes', () {
      final list = MirrorList(<Uri>[
        Uri.parse('https://a.example/'),
        Uri.parse('https://b.example/'),
        Uri.parse('https://c.example/'),
      ]);
      final preferred = list.withPreferred(Uri.parse('https://b.example/'));
      expect(preferred.entries.map((u) => u.host).toList(), <String>[
        'b.example',
        'a.example',
        'c.example',
      ]);
      expect(preferred.length, 3);
    });

    test('withPreferred adds new override when not in original list', () {
      final list = MirrorList(<Uri>[Uri.parse('https://a.example/')]);
      final preferred = list.withPreferred(
        Uri.parse('https://override.example/'),
      );
      expect(preferred.entries.map((u) => u.host).toList(), <String>[
        'override.example',
        'a.example',
      ]);
    });

    test('single() builds a one-entry list', () {
      final list = MirrorList.single(Uri.parse('https://a.example/'));
      expect(list.length, 1);
      expect(list.primary.host, 'a.example');
    });
  });
}
