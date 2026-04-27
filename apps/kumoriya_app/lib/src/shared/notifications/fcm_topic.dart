/// Conventions for FCM topic names shared between server and client.
///
/// Kept in a tiny pure-Dart file so it can be unit-tested without
/// pulling the Firebase SDK into the test target.
library;

/// Prefix used by the API when dispatching airing-episode pushes.
/// Server code publishes to `media_{anilistId}`.
const String kMediaTopicPrefix = 'media_';

/// Broadcast topic for new-app-version pushes. Every Android client
/// subscribes on launch so a single API publish reaches all installs.
///
/// Mirrors `notifications.AppUpdatesTopic` on the Go side
/// (`kumoriya-api/internal/notifications/topics.go`).
const String kAppUpdatesTopic = 'app_updates';

/// Builds the FCM topic name for per-media airing notifications.
///
/// Accepts a positive AniList media id; returns `null` for invalid ids
/// so callers can skip subscription without throwing.
String? mediaTopicForAnilistId(int anilistId) {
  if (anilistId <= 0) return null;
  return '$kMediaTopicPrefix$anilistId';
}

/// Parses the AniList id back out of a `media_{id}` topic name.
/// Returns `null` when the topic doesn't match the media convention.
int? anilistIdFromMediaTopic(String topic) {
  if (!topic.startsWith(kMediaTopicPrefix)) return null;
  final tail = topic.substring(kMediaTopicPrefix.length);
  return int.tryParse(tail);
}
