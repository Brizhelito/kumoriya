import 'dart:convert';
import 'dart:io';

import 'package:kumoriya_mangaupdates/kumoriya_mangaupdates.dart';
import 'package:test/test.dart';

void main() {
  group('MangaUpdatesSeriesMapper.map (search hit)', () {
    late Map<String, dynamic> firstHit;

    setUpAll(() {
      final raw = jsonDecode(
        File('test/fixtures/series_search.json').readAsStringSync(),
      );
      final results = (raw as Map<String, dynamic>)['results'] as List;
      firstHit =
          (results.first as Map<String, dynamic>)['record']
              as Map<String, dynamic>;
    });

    test('extracts core identity fields from a search hit', () {
      final series = MangaUpdatesSeriesMapper.map(firstHit);
      expect(series.id, 15180124327);
      expect(series.title, 'Solo Leveling');
      expect(series.url, startsWith('https://www.mangaupdates.com/'));
      expect(series.type, MangaUpdatesSeriesType.manhwa);
      expect(series.year, '2018');
      expect(series.bayesianRating, closeTo(8.47, 0.01));
      expect(series.ratingVotes, isPositive);
    });

    test('parses the genres list (object-shaped entries)', () {
      final series = MangaUpdatesSeriesMapper.map(firstHit);
      expect(series.genres, isNotEmpty);
      // The fixture contains entries shaped as {genre: "Action"} —
      // verify we collapsed them to flat strings.
      expect(series.genres.first, isA<String>());
      expect(series.genres.first.isNotEmpty, isTrue);
    });

    test('parses last_updated as a DateTime', () {
      final series = MangaUpdatesSeriesMapper.map(firstHit);
      expect(series.lastUpdated, isNotNull);
      expect(series.lastUpdated!.year, greaterThan(2020));
    });

    test('search hit titleCorpus is just the canonical title', () {
      final series = MangaUpdatesSeriesMapper.map(firstHit);
      // Search hits don't carry `associated`, so the corpus is
      // a single-element iterable.
      expect(series.titleCorpus.toList(), <String>['Solo Leveling']);
    });
  });

  group('MangaUpdatesSeriesMapper.map (detail)', () {
    late Map<String, dynamic> detail;

    setUpAll(() {
      detail =
          jsonDecode(
                File('test/fixtures/series_detail.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
    });

    test('promotes detail-only fields', () {
      final series = MangaUpdatesSeriesMapper.map(detail);
      expect(series.latestChapter, 201);
      expect(series.completed, isTrue);
      expect(series.licensed, isTrue);
      expect(series.statusNote, isNotNull);
    });

    test('flattens associated titles into the series corpus', () {
      final series = MangaUpdatesSeriesMapper.map(detail);
      expect(series.associatedTitles, isNotEmpty);
      // The fixture contains "Jogador solo" as an associated title.
      expect(
        series.associatedTitles.any((t) => t.toLowerCase() == 'jogador solo'),
        isTrue,
      );
      // titleCorpus should expand beyond just the canonical title.
      expect(series.titleCorpus.length, greaterThan(1));
      expect(series.titleCorpus.first, 'Solo Leveling');
    });

    test('titleCorpus dedup is case-insensitive and order-preserving', () {
      final series = MangaUpdatesSeriesMapper.map(detail);
      final corpus = series.titleCorpus.toList();
      final lowered = corpus.map((t) => t.toLowerCase()).toList();
      expect(lowered.length, lowered.toSet().length);
      expect(corpus.first, 'Solo Leveling');
    });
  });

  group('MangaUpdatesSeriesMapper.map (defensive)', () {
    test('throws FormatException when series_id is missing', () {
      expect(
        () => MangaUpdatesSeriesMapper.map(<String, dynamic>{'title': 'X'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when title is missing or empty', () {
      expect(
        () => MangaUpdatesSeriesMapper.map(<String, dynamic>{
          'series_id': 1,
          'title': '   ',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('falls back to unknown for unrecognized type', () {
      final series = MangaUpdatesSeriesMapper.map(<String, dynamic>{
        'series_id': 1,
        'title': 'Test',
        'type': 'mystery-format',
      });
      expect(series.type, MangaUpdatesSeriesType.other);
    });

    test('tolerates flat string lists in associated', () {
      final series = MangaUpdatesSeriesMapper.map(<String, dynamic>{
        'series_id': 1,
        'title': 'Test',
        'associated': <String>['Alt 1', 'Alt 2'],
      });
      expect(series.associatedTitles, <String>['Alt 1', 'Alt 2']);
    });
  });
}
