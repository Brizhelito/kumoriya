import 'package:flutter/foundation.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import 'fcm_service.dart';

/// Reconciles FCM topic subscriptions against the locally-known
/// "notify new episodes" set.
///
/// Called after:
///   - login completes and a sync pull has finished (new subscriptions
///     may have arrived from the server)
///   - app boot on an already-authenticated account (topics may have
///     been lost if Firebase was reinstalled, app data cleared, etc.)
///
/// Intentionally one-way (local → FCM): the FCM server does not
/// expose "list my current subscriptions", so we treat the library
/// store as the source of truth and subscribe everything that should
/// be subscribed. Stale topic subscriptions on FCM's side are harmless
/// — they just mean a message goes nowhere.
final class FcmTopicSyncService {
  FcmTopicSyncService({
    required LibraryStore libraryStore,
    required FcmTopicSubscriber fcm,
  }) : _libraryStore = libraryStore,
       _fcm = fcm;

  final LibraryStore _libraryStore;
  final FcmTopicSubscriber _fcm;

  /// Subscribes to every `media_{id}` topic whose anime is currently
  /// marked `notify_new_episodes=true` in the local library. Idempotent.
  ///
  /// Best-effort: a failure partway through is logged in debug mode
  /// and swallowed — the next call will retry the same set.
  Future<void> syncTopicsWithLibrary() async {
    if (!FcmService.isSupported) return;
    final result = await _libraryStore.getSubscribedAnimeIds();
    final ids = result.fold<Set<int>>(
      onSuccess: (s) => s,
      onFailure: (_) => const <int>{},
    );
    if (ids.isEmpty) {
      if (kDebugMode) {
        debugPrint('[FCM/topic-sync] no subscribed anime — nothing to do');
      }
      return;
    }
    if (kDebugMode) {
      debugPrint('[FCM/topic-sync] re-subscribing ${ids.length} topic(s)');
    }
    for (final id in ids) {
      try {
        await _fcm.subscribeToMedia(id);
      } catch (err) {
        if (kDebugMode) {
          debugPrint('[FCM/topic-sync] subscribe $id failed: $err');
        }
      }
    }
  }
}
