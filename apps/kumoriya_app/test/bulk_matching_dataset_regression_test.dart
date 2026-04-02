import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const bool _skipMatchingTests = true;

void main() {
  test(
    'bulk matching dataset snapshot reflects hardened search and alias behavior',
    () {
      final datasetFile = File(
        'C:\\Users\\Reny\\Documents\\Kumoriya\\docs\\audits\\matching\\bulk_matching_observation_dataset_2026-03-12.json',
      );
      final dataset =
          jsonDecode(datasetFile.readAsStringSync()) as Map<String, Object?>;
      final observations = (dataset['observations']! as List<Object?>)
          .cast<Map<String, Object?>>();
      final summary = dataset['summary']! as Map<String, Object?>;
      final animeNexus = summary['anime_nexus']! as Map<String, Object?>;
      final jkanime = summary['jkanime']! as Map<String, Object?>;

      expect(dataset['target_canonical_count'], 200);
      expect(observations.length, greaterThanOrEqualTo(800));
      expect(animeNexus['failures'] as int, lessThanOrEqualTo(12));
      expect(jkanime['failures'] as int, lessThanOrEqualTo(1));

      Map<String, Object?> findObservation(String source, String title) {
        return observations.firstWhere((item) {
          final canonical = item['canonical']! as Map<String, Object?>;
          return item['source'] == source &&
              canonical['primary_title'] == title &&
              item['search_status'] == 'ok';
        });
      }

      final evangelion = findObservation('jkanime', 'Shin Seiki Evangelion');
      expect(evangelion['decision_verdict'], 'autoMatch');

      final fateStrangeFake = findObservation('jkanime', 'Fate/strange Fake');
      expect(fateStrangeFake['decision_verdict'], 'autoMatch');

      final hero = findObservation(
        'anime_nexus',
        'Yuusha Kei ni Shosu: Choubatsu Yuusha 9004-tai Keimu Kiroku',
      );
      expect(hero['decision_verdict'], 'autoMatch');

      final mojibakeQueries = observations.where((item) {
        final query = item['search_query']?.toString() ?? '';
        return query.contains('Ã') ||
            query.contains('â') ||
            query.contains('å') ||
            query.contains('ð');
      });
      expect(mojibakeQueries, isEmpty);
    },
    skip: _skipMatchingTests,
  );
}
