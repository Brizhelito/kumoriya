package notifications

// Shared FCM topic conventions between server and Flutter client.
//
// Keep names here in sync with
// `apps/kumoriya_app/lib/src/shared/notifications/fcm_topic.dart`.
const (
	// AppUpdatesTopic is the broadcast topic for new-app-version pushes.
	// Every Android client subscribes on launch via FcmService.initialize
	// so a single publish reaches all installs.
	AppUpdatesTopic = "app_updates"
)
