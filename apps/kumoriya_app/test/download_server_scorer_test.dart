import 'package:kumoriya_app/src/features/downloads/application/download_server_scorer.dart';
import 'package:test/test.dart';

void main() {
  group('DownloadServerScorer', () {
    late DownloadServerScorer scorer;

    setUp(() => scorer = DownloadServerScorer());

    test('new servers score 0.5 (Laplace prior)', () {
      expect(scorer.score('unknown'), 0.5);
    });

    test('successes raise the score', () {
      scorer.recordSuccess('good');
      expect(scorer.score('good'), greaterThan(0.5));
    });

    test('failures lower the score', () {
      scorer.recordFailure('bad');
      expect(scorer.score('bad'), lessThan(0.5));
    });

    test('rankByScore sorts best first', () {
      scorer
        ..recordSuccess('A')
        ..recordSuccess('A')
        ..recordFailure('B')
        ..recordFailure('B');

      final ranked = scorer.rankByScore(<String>['B', 'A', 'C'], (s) => s);

      expect(ranked, <String>['A', 'C', 'B']);
    });

    test('rankByScore preserves order for equal scores', () {
      final ranked = scorer.rankByScore(<String>['X', 'Y', 'Z'], (s) => s);
      expect(ranked, <String>['X', 'Y', 'Z']);
    });

    test('single-element list returns as-is', () {
      final ranked = scorer.rankByScore(<String>['only'], (s) => s);
      expect(ranked, <String>['only']);
    });
  });
}
