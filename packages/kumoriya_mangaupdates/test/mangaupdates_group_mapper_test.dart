import 'dart:convert';
import 'dart:io';

import 'package:kumoriya_mangaupdates/kumoriya_mangaupdates.dart';
import 'package:test/test.dart';

void main() {
  group('MangaUpdatesGroupMapper.map', () {
    test('parses the LeviatanScans fixture (active=false case)', () {
      final data =
          jsonDecode(File('test/fixtures/group_detail.json').readAsStringSync())
              as Map<String, dynamic>;
      final group = MangaUpdatesGroupMapper.map(data);

      expect(group.id, 60273359075);
      expect(group.name, 'LeviatanScans');
      expect(group.active, isFalse);
      expect(group.url, isNotNull);
      expect(group.notes, contains('LSComic'));
      expect(group.siteUrl, isNotNull);
      expect(group.discordUrl, isNotNull);
    });

    test('defaults active to false when the field is missing', () {
      final group = MangaUpdatesGroupMapper.map(<String, dynamic>{
        'group_id': 1,
        'name': 'Stub',
      });
      expect(group.active, isFalse);
    });

    test('throws FormatException when group_id is missing', () {
      expect(
        () => MangaUpdatesGroupMapper.map(<String, dynamic>{'name': 'X'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when name is missing', () {
      expect(
        () => MangaUpdatesGroupMapper.map(<String, dynamic>{'group_id': 1}),
        throwsA(isA<FormatException>()),
      );
    });

    test('drops empty social fields rather than echoing empty strings', () {
      final group = MangaUpdatesGroupMapper.map(<String, dynamic>{
        'group_id': 1,
        'name': 'Stub',
        'social': <String, dynamic>{
          'site': '   ',
          'facebook': '',
          'discord': 'https://discord.gg/x',
        },
      });
      expect(group.siteUrl, isNull);
      expect(group.facebookUrl, isNull);
      expect(group.discordUrl, 'https://discord.gg/x');
    });
  });
}
