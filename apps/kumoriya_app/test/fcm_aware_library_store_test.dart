import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/shared/notifications/fcm_aware_library_store.dart';
import 'package:kumoriya_app/src/shared/notifications/fcm_service.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

void main() {
  group('FcmAwareLibraryStore.setSubscription', () {
    test('subscribes to media_{id} topic when notify=true', () async {
      final inner = _FakeLibraryStore();
      final fcm = _RecordingFcm();
      final store = FcmAwareLibraryStore(inner: inner, fcm: fcm);

      final result = await store.setSubscription(147105, notify: true);

      expect(result.isSuccess, isTrue);
      expect(inner.lastSetSubscription, (147105, true));
      expect(fcm.subscribed, [147105]);
      expect(fcm.unsubscribed, isEmpty);
    });

    test('unsubscribes from media_{id} topic when notify=false', () async {
      final inner = _FakeLibraryStore();
      final fcm = _RecordingFcm();
      final store = FcmAwareLibraryStore(inner: inner, fcm: fcm);

      await store.setSubscription(147105, notify: false);

      expect(fcm.unsubscribed, [147105]);
      expect(fcm.subscribed, isEmpty);
    });

    test('does not call FCM when the inner write fails', () async {
      final inner = _FakeLibraryStore(setSubscriptionFails: true);
      final fcm = _RecordingFcm();
      final store = FcmAwareLibraryStore(inner: inner, fcm: fcm);

      final result = await store.setSubscription(1, notify: true);

      expect(result.isSuccess, isFalse);
      expect(fcm.subscribed, isEmpty);
      expect(fcm.unsubscribed, isEmpty);
    });

    test('swallows FCM errors and still reports success', () async {
      final inner = _FakeLibraryStore();
      final fcm = _RecordingFcm(throwOnSubscribe: true);
      final store = FcmAwareLibraryStore(inner: inner, fcm: fcm);

      final result = await store.setSubscription(1, notify: true);

      // Inner write must have completed and the decorator reports success.
      expect(result.isSuccess, isTrue);
      expect(inner.lastSetSubscription, (1, true));
    });
  });

  group('FcmAwareLibraryStore pass-through', () {
    test('setFavorite is forwarded and does not touch FCM', () async {
      final inner = _FakeLibraryStore();
      final fcm = _RecordingFcm();
      final store = FcmAwareLibraryStore(inner: inner, fcm: fcm);

      await store.setFavorite(42, isFavorite: true);

      expect(inner.favoriteCalls, 1);
      expect(fcm.subscribed, isEmpty);
      expect(fcm.unsubscribed, isEmpty);
    });

    test('getSubscribedAnimeIds is forwarded to inner', () async {
      final inner = _FakeLibraryStore(subscribedIds: {10, 20, 30});
      final store = FcmAwareLibraryStore(inner: inner, fcm: _RecordingFcm());

      final result = await store.getSubscribedAnimeIds();

      expect(result.fold(onSuccess: (s) => s, onFailure: (_) => <int>{}), {
        10,
        20,
        30,
      });
    });
  });
}

// ─── Fakes ─────────────────────────────────────────────────────────

class _RecordingFcm implements FcmTopicSubscriber {
  _RecordingFcm({this.throwOnSubscribe = false});

  final bool throwOnSubscribe;
  final List<int> subscribed = [];
  final List<int> unsubscribed = [];

  @override
  Future<void> subscribeToMedia(int anilistId) async {
    if (throwOnSubscribe) throw StateError('fcm unavailable');
    subscribed.add(anilistId);
  }

  @override
  Future<void> unsubscribeFromMedia(int anilistId) async {
    unsubscribed.add(anilistId);
  }
}

class _FakeLibraryStore implements LibraryStore {
  _FakeLibraryStore({
    this.setSubscriptionFails = false,
    this.subscribedIds = const <int>{},
  });

  final bool setSubscriptionFails;
  final Set<int> subscribedIds;

  (int, bool)? lastSetSubscription;
  int favoriteCalls = 0;

  @override
  Future<Result<void, KumoriyaError>> setSubscription(
    int anilistId, {
    required bool notify,
  }) async {
    if (setSubscriptionFails) {
      return const Failure(
        SimpleError(code: 'fake', message: 'fake failure'),
      );
    }
    lastSetSubscription = (anilistId, notify);
    return const Success(null);
  }

  @override
  Future<Result<Set<int>, KumoriyaError>> getSubscribedAnimeIds() async {
    return Success(subscribedIds);
  }

  @override
  Future<Result<void, KumoriyaError>> setFavorite(
    int anilistId, {
    required bool isFavorite,
    DateTime? addedAt,
  }) async {
    favoriteCalls++;
    return const Success(null);
  }

  // ─── Unused in these tests ──

  @override
  Future<Result<Set<int>, KumoriyaError>> getFavoriteAnimeIds() async =>
      const Success(<int>{});

  @override
  Future<Result<Map<int, int?>, KumoriyaError>>
  getSubscribedWithLastEpisode() async => const Success(<int, int?>{});

  @override
  Future<Result<Map<int, int?>, KumoriyaError>>
  getTrackedAnimeWithLastEpisode() async => const Success(<int, int?>{});

  @override
  Future<Result<void, KumoriyaError>> updateLastNotifiedEpisode(
    int anilistId,
    int episodeNumber,
  ) async => const Success(null);

  @override
  Future<Result<void, KumoriyaError>> setAutoDownload(
    int anilistId, {
    required bool autoDownload,
  }) async => const Success(null);

  @override
  Future<String?> getAutoDownloadAudioPreference(int anilistId) async => null;

  @override
  Future<void> setAutoDownloadAudioPreference(
    int anilistId,
    String preference,
  ) async {}

  @override
  Future<Result<Set<int>, KumoriyaError>> getAutoDownloadAnimeIds() async =>
      const Success(<int>{});

  @override
  Future<Result<void, KumoriyaError>> clearAll() async => const Success(null);
}
