import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/shared/notifications/fcm_topic.dart';

void main() {
  group('kAppUpdatesTopic', () {
    test('matches the server-side constant', () {
      // Mirrors `notifications.AppUpdatesTopic` in
      // kumoriya-api/internal/notifications/topics.go. If the server
      // ever changes the topic name, this test forces the client side
      // to follow.
      expect(kAppUpdatesTopic, 'app_updates');
    });
  });

  group('mediaTopicForAnilistId', () {
    test('returns media_{id} for a positive id', () {
      expect(mediaTopicForAnilistId(147105), 'media_147105');
      expect(mediaTopicForAnilistId(1), 'media_1');
    });

    test('returns null for zero or negative ids', () {
      expect(mediaTopicForAnilistId(0), isNull);
      expect(mediaTopicForAnilistId(-1), isNull);
    });
  });

  group('anilistIdFromMediaTopic', () {
    test('parses a valid media_{id} topic', () {
      expect(anilistIdFromMediaTopic('media_147105'), 147105);
    });

    test('returns null for non-media topics', () {
      expect(anilistIdFromMediaTopic('foo_123'), isNull);
      expect(anilistIdFromMediaTopic(''), isNull);
    });

    test('returns null when the tail is not numeric', () {
      expect(anilistIdFromMediaTopic('media_abc'), isNull);
      expect(anilistIdFromMediaTopic('media_'), isNull);
    });

    test('round-trips with mediaTopicForAnilistId', () {
      const ids = [1, 42, 147105, 999999];
      for (final id in ids) {
        final topic = mediaTopicForAnilistId(id);
        expect(topic, isNotNull);
        expect(anilistIdFromMediaTopic(topic!), id);
      }
    });
  });
}
