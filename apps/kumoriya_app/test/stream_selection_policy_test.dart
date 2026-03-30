import 'package:flutter/foundation.dart';
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

  test('rankCandidates deduplicates by URL and preserves best-first order', () {
    final ranked = policy.rankCandidates(<ResolvedStream>[
      ResolvedStream(
        url: Uri.parse('https://cdn.example/master-720p.m3u8'),
        qualityLabel: '720p',
        isHls: true,
      ),
      ResolvedStream(
        url: Uri.parse('https://cdn.example/master-720p.m3u8'),
        qualityLabel: '720p',
        isHls: true,
      ),
      ResolvedStream(
        url: Uri.parse('https://cdn.example/video-1080p.mp4'),
        qualityLabel: '1080p',
        isHls: false,
      ),
    ]);

    expect(ranked.length, 2);
    expect(ranked.first.url.path, contains('720p.m3u8'));
  });

  test('R2: no longer penalises high Anime Nexus quality on Android', () {
    const androidPolicy = StreamSelectionPolicy(
      platform: TargetPlatform.android,
    );

    final selected = androidPolicy.selectBest(<ResolvedStream>[
      ResolvedStream(
        url: Uri.parse(
          'http://127.0.0.1:41421/anime-nexus/session/master/5300/1.m3u8',
        ),
        qualityLabel: '1080p',
        mimeType: 'application/vnd.apple.mpegurl',
        isHls: true,
      ),
      ResolvedStream(
        url: Uri.parse(
          'http://127.0.0.1:41421/anime-nexus/session/master/4400/1.m3u8',
        ),
        qualityLabel: '720p',
        mimeType: 'application/vnd.apple.mpegurl',
        isHls: true,
      ),
    ]);

    expect(selected, isNotNull);
    // With hwdec=auto-safe the penalty is gone — 1080p ranks highest.
    expect(selected!.qualityLabel, '1080p');
    expect(selected.url.path, contains('/5300/'));
  });
}
