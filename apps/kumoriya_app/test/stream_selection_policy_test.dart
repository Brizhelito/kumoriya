import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/player/application/services/stream_selection_policy.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

void main() {
  const policy = StreamSelectionPolicy();

  test('returns null when candidates are empty', () {
    final selected = policy.selectBest(const <ResolvedStream>[]);
    expect(selected, isNull);
  });

  test('prefers HLS with higher quality when available', () {
    final selected = policy.selectBest(<ResolvedStream>[
      ResolvedStream(
        url: Uri.parse('https://cdn.example/video-720p.mp4'),
        qualityLabel: '720p',
        isHls: false,
      ),
      ResolvedStream(
        url: Uri.parse('https://cdn.example/master-480p.m3u8'),
        qualityLabel: '480p',
        isHls: true,
      ),
      ResolvedStream(
        url: Uri.parse('https://cdn.example/master-1080p.m3u8'),
        qualityLabel: '1080p',
        isHls: true,
      ),
    ]);

    expect(selected, isNotNull);
    expect(selected!.url.path, contains('1080p.m3u8'));
  });
}
