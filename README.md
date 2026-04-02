# Kumoriya

Kumoriya is now bootstrapped as a real Flutter monorepo with plugin-first architecture foundations.

## Workspace

- `apps/kumoriya_app`: main Flutter app (Android + Windows)
- `packages/kumoriya_core`: Result/error boundary primitives
- `packages/kumoriya_domain`: canonical anime domain models
- `packages/kumoriya_plugins`: source/resolver plugin contracts + manifest model
- `packages/kumoriya_anilist`: AniList gateway contract package
- `packages/kumoriya_storage`: storage boundary contracts
- `packages/kumoriya_testing`: shared testing utilities

## Quick start

1. `flutter pub get`
2. `dart format .`
3. `dart analyze`

## Manual Debug Flags

- `KUMORIYA_DOWNLOAD_DEBUG_LOGS`
	Enables verbose download diagnostics on demand. Default: `false`.
	Example run: `flutter run --dart-define=KUMORIYA_DOWNLOAD_DEBUG_LOGS=true`
	Example build: `flutter build apk --dart-define=KUMORIYA_DOWNLOAD_DEBUG_LOGS=true`
	When enabled on Android, download logs are written to app storage and can be
	collected with the existing capture script.

## Scope of this bootstrap

- Includes architecture contracts and package boundaries.
- Excludes feature logic (AniList implementation, source plugins, resolvers, playback, downloads).
