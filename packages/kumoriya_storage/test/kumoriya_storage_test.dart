import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:test/test.dart';

void main() {
  test('episode progress model is constructible', () {
    final progress = EpisodeProgress(
      anilistId: 1,
      episodeNumber: 1,
      position: const Duration(minutes: 3),
      updatedAt: DateTime(2026),
    );

    expect(progress.anilistId, 1);
  });
}
