import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_app/l10n/generated/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../features/anime_catalog/presentation/pages/calendar_page.dart';
import '../features/anime_catalog/presentation/pages/downloads_page.dart';
import '../features/anime_catalog/presentation/pages/home_page.dart';
import '../features/anime_catalog/presentation/pages/library_page.dart';
import '../features/anime_catalog/presentation/pages/search_page.dart';
import '../features/library/presentation/pages/unified_library_page.dart';
import '../features/manga_catalog/presentation/pages/manga_downloads_page.dart';
import '../features/manga_catalog/presentation/pages/manga_home_page.dart';
import '../features/manga_catalog/presentation/pages/manga_search_page.dart';
import '../features/app_update/application/release_notes_catalog.dart';
import '../features/app_update/application/seen_app_version_store.dart';
import '../features/app_update/presentation/widgets/update_available_dialog.dart';
import '../features/app_update/presentation/widgets/post_update_release_notes_dialog.dart';
import '../features/app_update/presentation/app_update_providers.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/downloads/application/download_directory_service.dart';
import '../features/downloads/presentation/download_providers.dart';
import '../features/downloads/presentation/widgets/download_path_dialog.dart';
import '../features/player/presentation/pages/player_performance_benchmark_page.dart';
import '../features/settings/application/app_language_preference.dart';
import '../shared/auth/auth_providers.dart';
import '../shared/auth/deep_link_handler.dart';
import '../shared/cache/anilist_recovery_watcher.dart';
import '../shared/cache/combined_fallback_reason_provider.dart';
import '../shared/dev/dev_cache_seeder.dart';
import '../shared/navigation/app_navigation_shell.dart';
import '../shared/storage_providers.dart';
import '../shared/sync/sync_providers.dart';
import '../shared/theme/kumoriya_theme.dart';
import '../shared/universe/active_universe_providers.dart';
import 'l10n.dart';

class KumoriyaApp extends ConsumerStatefulWidget {
  const KumoriyaApp({super.key});

  @override
  ConsumerState<KumoriyaApp> createState() => _KumoriyaAppState();
}

class _KumoriyaAppState extends ConsumerState<KumoriyaApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final DeepLinkHandler _deepLinkHandler;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _deepLinkHandler = DeepLinkHandler(navigatorKey: _navigatorKey);
    _deepLinkHandler.init();

    // Sync coordinator lifecycle hooks: push on resume; schedule
    // expedited background push on pause. See [SyncCoordinator].
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        final coordinator = ref.read(syncCoordinatorProvider);
        // fire-and-forget; coordinator handles errors internally.
        coordinator.notifyAppResumed();
      },
      onPause: () {
        final coordinator = ref.read(syncCoordinatorProvider);
        coordinator.notifyAppPaused();
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _deepLinkHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Active universe drives the accent that flows through MaterialApp's
    // ThemeData. Watching the provider here means the whole app rebuilds
    // its theme with the new primary on every universe switch — and
    // MaterialApp's implicit AnimatedTheme cross-fades the change.
    final accent = ref.watch(universeAccentProvider);
    final themeData = KumoriyaTheme.forUniverse(accent);
    // Language override (null → device locale resolved against
    // supportedLocales). Async until the JSON file is loaded; default
    // is `system` so the first frame already respects the device.
    final languagePref = ref
        .watch(appLanguageProvider)
        .maybeWhen(
          data: (pref) => pref,
          orElse: () => AppLanguagePreference.system,
        );
    return MaterialApp(
      navigatorKey: _navigatorKey,
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: languagePref.toLocale(),
      supportedLocales: AppLocalizations.supportedLocales,
      theme: themeData,
      darkTheme: themeData,
      themeMode: ThemeMode.dark,
      home: kPlayerPerfBenchmarkMode
          ? const PlayerPerformanceBenchmarkPage()
          : const _FirstLaunchGate(),
    );
  }
}

class _FirstLaunchGate extends ConsumerStatefulWidget {
  const _FirstLaunchGate();

  @override
  ConsumerState<_FirstLaunchGate> createState() => _FirstLaunchGateState();
}

class _FirstLaunchGateState extends ConsumerState<_FirstLaunchGate> {
  final SeenAppVersionStore _seenAppVersionStore = const SeenAppVersionStore();
  bool _runningStartupUpdateCheck = false;
  bool _checkedReleaseNotes = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _seedDevFixturesIfDebug();
      await _checkDownloadPath();
      await _requestNotificationPermission();
      await _showReleaseNotesIfNeeded();
      await _checkForStartupUpdate();
      await _showLoginPromptIfNeeded();
    });
  }

  /// In debug builds, populate the local anime/manga caches with a
  /// small set of well-known titles so the home / search screens have
  /// content to render even when AniList is unreachable. No-op in
  /// release.
  Future<void> _seedDevFixturesIfDebug() async {
    if (!kDebugMode || !mounted) return;
    final seeder = DevCacheSeeder(
      animeStore: ref.read(anilistCacheStoreProvider),
      mangaStore: ref.read(mangaCacheStoreProvider),
    );
    await seeder.seedIfEmpty();
  }

  /// On Android 13+ request POST_NOTIFICATIONS permission once. The flag
  /// file prevents re-showing the rationale dialog on every launch.
  Future<void> _requestNotificationPermission() async {
    if (!Platform.isAndroid || !mounted) return;

    final flagFile = await _onboardingFlagFile('notification_permission_asked');
    if (await flagFile.exists()) return;

    // Show a rationale dialog before the system prompt.
    if (!mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: KumoriyaColors.surface,
        title: Text(
          context.l10n.onboardingNotificationTitle,
          style: const TextStyle(color: KumoriyaColors.textPrimary),
        ),
        content: Text(
          context.l10n.onboardingNotificationBody,
          style: const TextStyle(color: KumoriyaColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.onboardingNotificationSkip),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: KumoriyaColors.primary,
              foregroundColor: KumoriyaColors.textPrimary,
            ),
            child: Text(context.l10n.onboardingNotificationAllow),
          ),
        ],
      ),
    );

    if (proceed == true) {
      await Permission.notification.request();
    }
    // Mark asked regardless of outcome.
    await flagFile.parent.create(recursive: true);
    await flagFile.writeAsString('1', flush: true);
  }

  /// If user is not authenticated and hasn't dismissed the prompt yet, show it.
  Future<void> _showLoginPromptIfNeeded() async {
    if (!mounted) return;
    final isAuth = ref.read(isAuthenticatedProvider);
    if (isAuth) return;

    final flagFile = await _onboardingFlagFile('login_prompt_dismissed');
    if (await flagFile.exists()) return;
    if (!mounted) return;

    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const LoginPage()));

    // Mark shown after the user returns (either logged in or pressed skip).
    await flagFile.parent.create(recursive: true);
    await flagFile.writeAsString('1', flush: true);
  }

  static Future<File> _onboardingFlagFile(String key) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}onboarding_$key');
  }

  Future<void> _showReleaseNotesIfNeeded() async {
    if (!mounted || _checkedReleaseNotes) {
      return;
    }
    _checkedReleaseNotes = true;

    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;
      final previousVersion = await _seenAppVersionStore.read();

      if (previousVersion == null || previousVersion == currentVersion) {
        await _seenAppVersionStore.write(currentVersion);
        return;
      }

      if (!mounted) {
        return;
      }

      final notes = releaseNotesForVersion(
        currentVersion,
        Localizations.localeOf(context),
      );
      await _seenAppVersionStore.write(currentVersion);

      if (notes == null || !mounted) {
        return;
      }

      await PostUpdateReleaseNotesDialog.show(
        context,
        previousVersion: previousVersion,
        notes: notes,
      );
    } catch (_) {
      // Best-effort UX enhancement; startup should continue even if it fails.
    }
  }

  Future<void> _checkDownloadPath() async {
    final service = ref.read(downloadDirectoryServiceProvider);
    final configured = await service.hasConfiguredDownloadDirectory();
    if (!configured && mounted) {
      if (Platform.isAndroid) {
        await DownloadDirectoryService.requestAndroidStorageAccess();
      }
      final suggestion = await service.getDefaultSuggestionPath();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => DownloadPathDialog(
          suggestedPath: suggestion,
          onUseDefault: () async {
            await service.selectDirectoryPath(suggestion);
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          onBrowse: () async {
            final outcome = await service.selectDirectory();
            outcome.fold(
              onSuccess: (result) {
                if (result.status == DownloadDirectorySelectionStatus.updated) {
                  if (ctx.mounted) Navigator.of(ctx).pop();
                }
              },
              onFailure: (_) {},
            );
          },
        ),
      );
    }
  }

  Future<void> _checkForStartupUpdate() async {
    if (!mounted || _runningStartupUpdateCheck) {
      return;
    }

    if (!Platform.isAndroid && !Platform.isWindows) {
      return;
    }

    _runningStartupUpdateCheck = true;
    try {
      final result = await ref.read(appUpdateServiceProvider).checkForUpdate();
      if (!mounted) return;

      final maybeUpdate = result.fold(
        onSuccess: (update) => update,
        onFailure: (_) => null,
      );

      if (maybeUpdate == null || !mounted) {
        return;
      }

      await UpdateAvailableDialog.show(context, maybeUpdate);
    } finally {
      _runningStartupUpdateCheck = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnilistRecoveryWatcher(
      child: AppNavigationShell(
        fallbackReasonNotifier: ref.watch(combinedFallbackReasonProvider),
        onTapRetry: () => invalidateCatalogProviders(ref),
        animeTabBuilders: <KumoriyaAnimeTab, WidgetBuilder>{
          KumoriyaAnimeTab.home: (_) => const HomePage(),
          KumoriyaAnimeTab.search: (_) => const SearchPage(),
          KumoriyaAnimeTab.calendar: (_) => const CalendarPage(),
          KumoriyaAnimeTab.library: (_) => const LibraryPage(),
          KumoriyaAnimeTab.downloads: (_) => const DownloadsPage(),
        },
        mangaTabBuilders: <KumoriyaMangaTab, WidgetBuilder>{
          KumoriyaMangaTab.home: (_) => const MangaHomePage(),
          KumoriyaMangaTab.search: (_) => const MangaSearchPage(),
          KumoriyaMangaTab.library: (_) => const UnifiedLibraryPage(),
          KumoriyaMangaTab.downloads: (_) => const MangaDownloadsPage(),
        },
      ),
    );
  }
}
