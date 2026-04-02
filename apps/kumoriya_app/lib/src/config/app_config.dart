/// Central app configuration constants.
///
/// The Sentry DSN is a public client key — Sentry explicitly states it is safe
/// to embed in client-side apps. The only risk is someone flooding your project
/// with fake events, which Sentry rate-limits automatically.
///
/// To override at build time:
///   flutter build apk --dart-define=SENTRY_DSN=other_dsn
abstract final class AppConfig {
  static const sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue:
        'https://00e44198b19fef95c36667703ae74898@o4511142303236096.ingest.us.sentry.io/4511142304481280',
  );

  static const sentryEnvironment = String.fromEnvironment(
    'SENTRY_ENV',
    defaultValue: 'alpha',
  );

  /// Must match `version` in pubspec.yaml: name@version+build.
  static const sentryRelease = String.fromEnvironment(
    'SENTRY_RELEASE',
    defaultValue: 'kumoriya@0.1.3+4',
  );

  /// Enables verbose download diagnostics when explicitly requested.
  ///
  /// Example:
  ///   flutter run --dart-define=KUMORIYA_DOWNLOAD_DEBUG_LOGS=true
  static const downloadDebugLogsEnabled = bool.fromEnvironment(
    'KUMORIYA_DOWNLOAD_DEBUG_LOGS',
    defaultValue: false,
  );
}
