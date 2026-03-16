import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage_flutter.dart';
import 'package:workmanager/workmanager.dart';

/// Workmanager task name for periodic new-episode checks.
const kCheckNewEpisodesTask = 'kumoriya.check_new_episodes';

/// Notification channel configuration.
const _channelId = 'kumoriya_new_episodes';
const _channelName = 'New Episodes';
const _channelDescription =
    'Notifies when a subscribed anime has a new episode';

/// Inline GraphQL query — batch-fetches nextAiringEpisode for a set of IDs.
const _batchAiringStatusQuery = r'''
query BatchAiringStatus($ids: [Int]) {
  Page(perPage: 50) {
    media(id_in: $ids, type: ANIME) {
      id
      title { romaji english }
      nextAiringEpisode { episode airingAt }
    }
  }
}
''';

// ---------------------------------------------------------------------------
// Callback dispatcher — runs in a separate isolate; must be a top-level fn.
// ---------------------------------------------------------------------------

@pragma('vm:entry-point')
void checkNewEpisodesCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kCheckNewEpisodesTask) return true;

    WidgetsFlutterBinding.ensureInitialized();

    try {
      await _runCheckNewEpisodes();
    } catch (e, st) {
      developer.log(
        'CheckNewEpisodesWorker unhandled error: $e',
        name: 'CheckNewEpisodesWorker',
        error: e,
        stackTrace: st,
      );
    }

    return true;
  });
}

// ---------------------------------------------------------------------------
// Core worker logic
// ---------------------------------------------------------------------------

Future<void> _runCheckNewEpisodes() async {
  final db = await openAppDatabase();
  final store = DriftLibraryStore(db);

  final subResult = await store.getSubscribedWithLastEpisode();
  if (subResult is! Success) {
    developer.log(
      'getSubscribedWithLastEpisode failed',
      name: 'CheckNewEpisodesWorker',
    );
    await db.close();
    return;
  }

  final subscribed = (subResult as Success<Map<int, int?>, dynamic>).value;

  if (subscribed.isEmpty) {
    await db.close();
    return;
  }

  final ids = subscribed.keys.toList();
  final airingData = await _fetchAiringStatus(ids);

  if (airingData == null) {
    await db.close();
    return;
  }

  final notifications = FlutterLocalNotificationsPlugin();
  await _initNotifications(notifications);

  final now = DateTime.now();

  for (final entry in airingData.entries) {
    final anilistId = entry.key;
    final title = entry.value['title'] as String;
    final nextEpisode = entry.value['nextEpisode'] as int?;
    final airingAt = entry.value['airingAt'] as DateTime?;

    if (nextEpisode == null) continue;

    // Episode that just aired = nextAiringEpisode.episode - 1
    final latestAired = nextEpisode - 1;
    if (latestAired <= 0) continue;

    final lastNotified = subscribed[anilistId];

    if (lastNotified == null) {
      // First run: initialize silently — don't notify past episodes.
      await store.updateLastNotifiedEpisode(anilistId, latestAired);
      continue;
    }

    // Check if there's a newly aired episode that we haven't notified yet,
    // and it has actually aired (airingAt is in the past for the next one
    // means all episodes up to nextEpisode-1 are available).
    if (latestAired > lastNotified) {
      // Only notify if the aired time is known to be in the past.
      final hasAired = airingAt == null || airingAt.isAfter(now) == false;
      if (!hasAired) continue;

      final newEp = latestAired;
      await _sendNotification(
        notifications,
        id: anilistId,
        title: title,
        episodeNumber: newEp,
      );
      await store.updateLastNotifiedEpisode(anilistId, newEp);

      developer.log(
        'Notified episode $newEp for "$title" (id=$anilistId)',
        name: 'CheckNewEpisodesWorker',
      );
    }
  }

  await db.close();
}

// ---------------------------------------------------------------------------
// AniList batch fetch
// ---------------------------------------------------------------------------

Future<Map<int, Map<String, dynamic>>?> _fetchAiringStatus(
  List<int> ids,
) async {
  try {
    final response = await http
        .post(
          Uri.parse('https://graphql.anilist.co'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'query': _batchAiringStatusQuery,
            'variables': {'ids': ids},
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      developer.log(
        'AniList batch airing status returned ${response.statusCode}',
        name: 'CheckNewEpisodesWorker',
      );
      return null;
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) return null;

    final mediaList =
        (decoded['data']?['Page']?['media'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];

    final result = <int, Map<String, dynamic>>{};
    for (final media in mediaList) {
      final id = media['id'] as int?;
      if (id == null) continue;

      final titleMap = media['title'] as Map<String, dynamic>?;
      final title =
          (titleMap?['english'] as String?) ??
          (titleMap?['romaji'] as String?) ??
          'Unknown Anime';

      final next = media['nextAiringEpisode'] as Map<String, dynamic>?;
      final nextEp = next?['episode'] as int?;
      final airingAtSec = next?['airingAt'] as int?;
      final airingAt = airingAtSec != null
          ? DateTime.fromMillisecondsSinceEpoch(airingAtSec * 1000)
          : null;

      result[id] = {
        'title': title,
        'nextEpisode': nextEp,
        'airingAt': airingAt,
      };
    }

    return result;
  } catch (e) {
    developer.log(
      'fetchAiringStatus error: $e',
      name: 'CheckNewEpisodesWorker',
    );
    return null;
  }
}

// ---------------------------------------------------------------------------
// Notification helpers
// ---------------------------------------------------------------------------

Future<void> _initNotifications(FlutterLocalNotificationsPlugin plugin) async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(const InitializationSettings(android: android));
}

Future<void> _sendNotification(
  FlutterLocalNotificationsPlugin plugin, {
  required int id,
  required String title,
  required int episodeNumber,
}) async {
  const androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    icon: '@mipmap/ic_launcher',
  );

  await plugin.show(
    id,
    title,
    'Episode $episodeNumber is now available!',
    const NotificationDetails(android: androidDetails),
  );
}
