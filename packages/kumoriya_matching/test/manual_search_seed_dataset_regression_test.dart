import 'package:test/test.dart';

import '../tool/src/manual_seed_support.dart';

const bool _skipMatchingTests = true;

void main() {
  test('manual search seed dataset preserves conservative query safety', () {
    final report = evaluateManualSeedDataset();

    expect(report.totalRows, greaterThanOrEqualTo(15));
    expect(report.totalQueries, greaterThanOrEqualTo(8));
    expect(report.queryUnsafeAutoMatches, 0);
    expect(report.querySafeAccuracy, greaterThanOrEqualTo(0.95));
    expect(report.queryMatchRecall, greaterThanOrEqualTo(0.85));
    expect(report.queryBestCandidateAccuracy, greaterThanOrEqualTo(0.80));
  }, skip: _skipMatchingTests);
}
