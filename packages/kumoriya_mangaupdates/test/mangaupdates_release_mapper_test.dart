import 'dart:convert';
import 'dart:io';

import 'package:kumoriya_mangaupdates/kumoriya_mangaupdates.dart';
import 'package:test/test.dart';

void main() {
  group('MangaUpdatesReleaseMapper.map', () {
    late List<dynamic> results;

    setUpAll(() {
      final envelope =
          jsonDecode(
                File('test/fixtures/releases_search.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      results = envelope['results'] as List<dynamic>;
    });

    test('parses a release record from the live fixture', () {
      final record =
          (results.first as Map<String, dynamic>)['record']
              as Map<String, dynamic>;
      final release = MangaUpdatesReleaseMapper.map(record);

      expect(release.id, isPositive);
      expect(release.chapter, isNotNull);
      expect(release.timeAdded, isA<DateTime>());
      expect(release.timeAdded.year, greaterThan(2010));
      expect(release.groups, isNotEmpty);

      final group = release.groups.first;
      expect(group.id, isPositive);
      expect(group.name.isNotEmpty, isTrue);
    });

    test('parses time_added from rfc3339 preferentially', () {
      final record = <String, dynamic>{
        'id': 1,
        'series_id': 99,
        'title': 'X',
        'time_added': <String, dynamic>{
          'as_rfc3339': '2024-01-15T10:30:00-08:00',
          'timestamp': 0,
        },
      };
      final release = MangaUpdatesReleaseMapper.map(record);
      expect(release.timeAdded.toUtc().year, 2024);
      expect(release.timeAdded.toUtc().month, 1);
    });

    test('falls back to unix timestamp when rfc3339 is missing', () {
      final record = <String, dynamic>{
        'id': 1,
        'time_added': <String, dynamic>{'timestamp': 1700000000},
      };
      final release = MangaUpdatesReleaseMapper.map(record);
      expect(release.timeAdded.isUtc, isTrue);
      expect(release.timeAdded.year, 2023);
    });

    test('throws FormatException when id is missing', () {
      expect(
        () => MangaUpdatesReleaseMapper.map(<String, dynamic>{
          'time_added': <String, dynamic>{'timestamp': 1700000000},
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when time_added is unparseable', () {
      expect(
        () => MangaUpdatesReleaseMapper.map(<String, dynamic>{'id': 1}),
        throwsA(isA<FormatException>()),
      );
    });

    test('skips malformed group entries instead of failing', () {
      final record = <String, dynamic>{
        'id': 1,
        'time_added': <String, dynamic>{'timestamp': 1700000000},
        'groups': <dynamic>[
          <String, dynamic>{'group_id': 10, 'name': 'OK'},
          <String, dynamic>{'name': 'no id'},
          'just a string',
          <String, dynamic>{'group_id': 11, 'name': '   '},
        ],
      };
      final release = MangaUpdatesReleaseMapper.map(record);
      expect(release.groups, hasLength(1));
      expect(release.groups.single.name, 'OK');
    });
  });
}
