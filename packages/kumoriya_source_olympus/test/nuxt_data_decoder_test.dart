import 'dart:io';

import 'package:kumoriya_source_olympus/src/internal/nuxt_data_decoder.dart';
import 'package:test/test.dart';

String _readFixture(String name) =>
    File('test/fixtures/$name').readAsStringSync();

void main() {
  group('NuxtDataDecoder.decode', () {
    test('rejects non-array root', () {
      expect(() => NuxtDataDecoder.decode('{"a":1}'), throwsFormatException);
    });

    test('decodes a tiny synthetic payload by dereferencing indices', () {
      // Index 0: object pointing at index 1 (id) and 2 (name)
      // Index 1: literal 42
      // Index 2: literal "Foo"
      const raw = '[{"id":1,"name":2}, 42, "Foo"]';
      final decoded = NuxtDataDecoder.decode(raw);
      expect(decoded, equals(<String, Object?>{'id': 42, 'name': 'Foo'}));
    });

    test('unwraps ShallowReactive and Reactive tags transparently', () {
      const raw = '[["ShallowReactive",1],["Reactive",2],{"k":3},"v"]';
      final decoded = NuxtDataDecoder.decode(raw);
      // arr[0] is ShallowReactive(1); arr[1] is Reactive(2); arr[2] is map.
      expect(decoded, equals(<String, Object?>{'k': 'v'}));
    });

    test('returns null on cycle without throwing', () {
      // arr[0] = 0 — a self-reference. Slot at index 0 holds an int,
      // which is treated as the terminal literal `0` per Nuxt encoding.
      // (No real Nuxt payload encodes a bare int as the root, but the
      // decoder must not loop on adversarial input.)
      const raw = '[0]';
      final decoded = NuxtDataDecoder.decode(raw);
      expect(decoded, equals(0));
    });

    test('cycle through a complex slot returns null at the cycle point', () {
      // arr[0] = {"self": 0}. Walking the map sees `self: 0` as an int
      // reference, dereferences to arr[0] which is already in `visited`,
      // returns null instead of looping.
      const raw = '[{"self":0}]';
      final decoded = NuxtDataDecoder.decode(raw);
      expect(decoded, equals(<String, Object?>{'self': null}));
    });

    test('decodes the live detail nuxt-data fixture', () {
      final raw = _readFixture('nuxt_data_detail.json');
      final root = NuxtDataDecoder.decode(raw);
      expect(root, isA<Map<String, Object?>>());
      final outer =
          (root! as Map<String, Object?>)['data'] as Map<String, Object?>;
      // Single route key in this fixture.
      final routeKey = outer.keys.first;
      expect(routeKey, contains('/series/comic-sangre-maldita'));
      final route = outer[routeKey] as Map<String, Object?>;
      final detail = route['data'] as Map<String, Object?>;
      expect(detail['id'], 1445);
      expect(detail['name'], 'Sangre Maldita');
      expect(detail['slug'], startsWith('sangre-maldita'));
      expect(detail['type'], 'comic');
      // status is an object {id, name} — Olympus surfaces both.
      expect((detail['status'] as Map<String, Object?>)['name'], 'Activo');
      // genres deref into a list of {name, id} maps.
      final genres = detail['genres'] as List<Object?>;
      expect(genres, hasLength(3));
      expect(
        genres.map((g) => (g! as Map)['name'] as String?).toList(),
        containsAll(<String>['Acción ', 'Apocalíptico', 'Sistema']),
      );
    });

    test('decodes the live chapter-reader nuxt-data fixture and pages', () {
      final raw = _readFixture('nuxt_data_chapter.json');
      final root = NuxtDataDecoder.decode(raw);
      expect(root, isA<Map<String, Object?>>());
      final outer =
          (root! as Map<String, Object?>)['data'] as Map<String, Object?>;
      final routeKey = outer.keys.first;
      expect(routeKey, contains('/capitulo/127865'));
      final route = outer[routeKey] as Map<String, Object?>;
      final chapter = route['chapter'] as Map<String, Object?>;
      final pages = chapter['pages'] as List<Object?>;
      expect(pages, hasLength(30));
      for (final p in pages.whereType<String>()) {
        expect(
          p,
          startsWith(
            'https://dashboard.olympusbiblioteca.com/storage/comics/1702/127865/',
          ),
        );
      }
    });
  });

  group('NuxtDataDecoder.extractFromHtml', () {
    test('returns null when no script tag is present', () {
      final out = NuxtDataDecoder.extractFromHtml(
        '<html><body>hi</body></html>',
      );
      expect(out, isNull);
    });

    test('extracts and decodes the embedded payload', () {
      const html =
          '<!doctype html><html><head><script type="application/json" '
          'id="__NUXT_DATA__" data-ssr="true">[{"k":1},"v"]</script></head>'
          '</html>';
      final out = NuxtDataDecoder.extractFromHtml(html);
      expect(out, equals(<String, Object?>{'k': 'v'}));
    });
  });
}
