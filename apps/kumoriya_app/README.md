# kumoriya_app

Main Flutter app for Kumoriya.

## Manual Debug Flags

- `KUMORIYA_DOWNLOAD_DEBUG_LOGS`
	Default: `false`.
	Enables verbose download diagnostics only when explicitly requested.

Run with logs enabled:

```powershell
flutter run --dart-define=KUMORIYA_DOWNLOAD_DEBUG_LOGS=true
```

Build with logs enabled:

```powershell
flutter build apk --dart-define=KUMORIYA_DOWNLOAD_DEBUG_LOGS=true
```

When enabled on Android, the app writes download logs to app storage and the
Windows capture script can sync them back to the PC.
