import 'dart:io';

import 'package:kumoriya_source_runtime/kumoriya_source_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('MirrorRotator.run', () {
    test('returns first mirror result when primary succeeds', () async {
      final rotator = MirrorRotator(
        MirrorList(<Uri>[
          Uri.parse('https://a.example/'),
          Uri.parse('https://b.example/'),
        ]),
      );
      final attempts = <String>[];
      final result = await rotator.run<String>((base) async {
        attempts.add(base.host);
        return 'ok:${base.host}';
      });
      expect(result, 'ok:a.example');
      expect(attempts, <String>['a.example']);
    });

    test('rotates to next mirror on transport failure', () async {
      final rotator = MirrorRotator(
        MirrorList(<Uri>[
          Uri.parse('https://a.example/'),
          Uri.parse('https://b.example/'),
          Uri.parse('https://c.example/'),
        ]),
      );
      final attempts = <String>[];
      final result = await rotator.run<String>((base) async {
        attempts.add(base.host);
        if (base.host == 'a.example') {
          throw const SocketException('refused');
        }
        return 'ok:${base.host}';
      });
      expect(result, 'ok:b.example');
      expect(attempts, <String>['a.example', 'b.example']);
    });

    test(
      'rethrows non-transport failure without trying further mirrors',
      () async {
        final rotator = MirrorRotator(
          MirrorList(<Uri>[
            Uri.parse('https://a.example/'),
            Uri.parse('https://b.example/'),
          ]),
        );
        final attempts = <String>[];
        await expectLater(
          rotator.run<String>((base) async {
            attempts.add(base.host);
            throw const FormatException('bad json');
          }),
          throwsA(isA<FormatException>()),
        );
        expect(attempts, <String>['a.example']);
      },
    );

    test('rethrows last transport error when all mirrors fail', () async {
      final rotator = MirrorRotator(
        MirrorList(<Uri>[
          Uri.parse('https://a.example/'),
          Uri.parse('https://b.example/'),
        ]),
      );
      final attempts = <String>[];
      await expectLater(
        rotator.run<String>((base) async {
          attempts.add(base.host);
          throw SocketException('down on ${base.host}');
        }),
        throwsA(
          isA<SocketException>().having(
            (e) => e.message,
            'message',
            'down on b.example',
          ),
        ),
      );
      expect(attempts, <String>['a.example', 'b.example']);
    });

    test('walks single-entry list once', () async {
      final rotator = MirrorRotator(
        MirrorList.single(Uri.parse('https://only.example/')),
      );
      final attempts = <String>[];
      final result = await rotator.run<String>((base) async {
        attempts.add(base.host);
        return 'ok';
      });
      expect(result, 'ok');
      expect(attempts, <String>['only.example']);
    });

    test('honors preferred override on construction', () async {
      final rotator = MirrorRotator(
        MirrorList(<Uri>[
          Uri.parse('https://a.example/'),
          Uri.parse('https://b.example/'),
        ]).withPreferred(Uri.parse('https://b.example/')),
      );
      final attempts = <String>[];
      await rotator.run<String>((base) async {
        attempts.add(base.host);
        return 'ok';
      });
      expect(attempts, <String>['b.example']);
    });
  });
}
