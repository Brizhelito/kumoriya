import 'dart:convert';
import 'dart:io';

import 'package:kumoriya_mangabaka/kumoriya_mangabaka.dart';
import 'package:test/test.dart';

void main() {
  group('MangaBakaSeriesMapper.map (Solo Leveling fixture)', () {
    late Map<String, dynamic> data;

    setUpAll(() {
      data =
          jsonDecode(
                File(
                  'test/fixtures/series_3397_solo_leveling.json',
                ).readAsStringSync(),
              )['data']
              as Map<String, dynamic>;
    });

    test('extracts core identity fields', () {
      final series = MangaBakaSeriesMapper.map(data);
      expect(series.id, 3397);
      expect(series.title, 'Solo Leveling');
      expect(series.state, MangaBakaSeriesState.active);
      expect(series.mergedWith, isNull);
      expect(series.type, MangaBakaSeriesType.manhwa);
      expect(series.status, MangaBakaSeriesStatus.completed);
      expect(series.year, 2018);
    });

    test('flattens secondary titles, deduped case-insensitively', () {
      final series = MangaBakaSeriesMapper.map(data);
      expect(series.secondaryTitles, isNotEmpty);
      // Spot-check a known variant we observed during reconnaissance.
      expect(
        series.secondaryTitles.any((t) => t.toLowerCase() == 'solo leveling'),
        isTrue,
        reason: 'expected a romanized "Solo Leveling" variant',
      );
      // No duplicates ignoring case.
      final lowered = series.secondaryTitles
          .map((t) => t.toLowerCase())
          .toList();
      expect(lowered.length, lowered.toSet().length);
    });

    test('exposes cross-tracker IDs from the source map', () {
      final series = MangaBakaSeriesMapper.map(data);
      expect(series.crossIds.anilistId, 105398);
      expect(series.crossIds.myAnimeListId, 121496);
      expect(series.crossIds.kitsuId, 54114);
      expect(series.crossIds.mangaUpdatesId, '6z1uqw7');
      expect(series.crossIds.animePlanetId, 'solo-leveling');
      expect(series.crossIds.animeNewsNetworkId, 32926);
      expect(series.crossIds.shikimoriId, 121496);
      expect(series.crossIds.hasAny, isTrue);
    });

    test('picks a non-empty cover url (prefers `raw`)', () {
      final series = MangaBakaSeriesMapper.map(data);
      expect(series.coverUrl, isNotNull);
      expect(series.coverUrl!.startsWith('http'), isTrue);
    });

    test('extracts authors and artists as strings', () {
      final series = MangaBakaSeriesMapper.map(data);
      expect(series.authors, contains('Chu-Gong'));
      expect(series.artists, contains('Seong-Rak Jang'));
    });

    test('titleCorpus emits priority-ordered, dedup unique titles', () {
      final series = MangaBakaSeriesMapper.map(data);
      final corpus = series.titleCorpus.toList();
      expect(corpus, isNotEmpty);
      expect(corpus.first, 'Solo Leveling');
      // No case-insensitive dups.
      final loweredSet = corpus.map((t) => t.toLowerCase()).toSet();
      expect(corpus.length, loweredSet.length);
    });
  });

  group('MangaBakaSeriesMapper.map (merged fixture)', () {
    test('detects merged state and surfaces canonical id', () {
      final raw = jsonDecode(
        File('test/fixtures/series_10023_merged.json').readAsStringSync(),
      );
      final data =
          (raw as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      final series = MangaBakaSeriesMapper.map(data);
      expect(series.state, MangaBakaSeriesState.merged);
      expect(series.mergedWith, isNotNull);
      expect(series.mergedWith, isNot(equals(series.id)));
    });
  });

  group('MangaBakaSeriesMapper.map (defensive)', () {
    test('throws FormatException when id is missing', () {
      expect(
        () => MangaBakaSeriesMapper.map(<String, dynamic>{
          'title': 'X',
          'type': 'manga',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when title is missing or empty', () {
      expect(
        () => MangaBakaSeriesMapper.map(<String, dynamic>{
          'id': 1,
          'title': '   ',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('produces empty cross-ids when source map is missing', () {
      final series = MangaBakaSeriesMapper.map(<String, dynamic>{
        'id': 1,
        'title': 'Test',
      });
      expect(series.crossIds.hasAny, isFalse);
    });

    test('coerces stringly-typed numeric ids in the source map', () {
      final series = MangaBakaSeriesMapper.map(<String, dynamic>{
        'id': 1,
        'title': 'Test',
        'source': <String, dynamic>{
          'anilist': <String, dynamic>{'id': '999'},
          'manga_updates': <String, dynamic>{'id': 42},
        },
      });
      expect(series.crossIds.anilistId, 999);
      expect(series.crossIds.mangaUpdatesId, '42');
    });

    test('tolerates null id values in cross-tracker entries', () {
      final series = MangaBakaSeriesMapper.map(<String, dynamic>{
        'id': 1,
        'title': 'Test',
        'source': <String, dynamic>{
          'anilist': <String, dynamic>{'id': null, 'rating': null},
        },
      });
      expect(series.crossIds.anilistId, isNull);
    });

    test('falls back to unknown for unrecognized enum values', () {
      final series = MangaBakaSeriesMapper.map(<String, dynamic>{
        'id': 1,
        'title': 'Test',
        'state': 'wat',
        'type': 'wat',
        'status': 'wat',
      });
      expect(series.state, MangaBakaSeriesState.unknown);
      expect(series.type, MangaBakaSeriesType.unknown);
      expect(series.status, MangaBakaSeriesStatus.unknown);
    });
  });
}
