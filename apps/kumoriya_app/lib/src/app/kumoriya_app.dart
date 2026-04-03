import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_app/l10n/generated/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../features/anime_catalog/presentation/pages/calendar_page.dart';
import '../features/anime_catalog/presentation/pages/downloads_page.dart';
import '../features/anime_catalog/presentation/pages/home_page.dart';
import '../features/anime_catalog/presentation/pages/library_page.dart';
import '../features/anime_catalog/presentation/pages/search_page.dart';
import '../features/anime_catalog/presentation/providers/anime_catalog_providers.dart';
import '../features/app_update/application/release_notes_catalog.dart';
import '../features/app_update/application/seen_app_version_store.dart';
import '../features/app_update/presentation/widgets/update_available_dialog.dart';
import '../features/app_update/presentation/widgets/post_update_release_notes_dialog.dart';
import '../features/app_update/presentation/app_update_providers.dart';
import '../features/downloads/application/download_directory_service.dart';
import '../features/downloads/presentation/download_providers.dart';
import '../features/downloads/presentation/widgets/download_path_dialog.dart';
import '../shared/auth/deep_link_handler.dart';
import '../shared/navigation/app_navigation_shell.dart';
import '../shared/theme/kumoriya_theme.dart';
import 'l10n.dart';

class KumoriyaApp extends StatefulWidget {
  const KumoriyaApp({super.key});

  @override
  State<KumoriyaApp> createState() => _KumoriyaAppState();
}

class _KumoriyaAppState extends State<KumoriyaApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final DeepLinkHandler _deepLinkHandler;

  @override
  void initState() {
    super.initState();
    _deepLinkHandler = DeepLinkHandler(navigatorKey: _navigatorKey);
    _deepLinkHandler.init();
  }

  @override
  void dispose() {
    _deepLinkHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      supportedLocales: AppLocalizations.supportedLocales,
      theme: KumoriyaTheme.dark,
      darkTheme: KumoriyaTheme.dark,
      themeMode: ThemeMode.dark,
      home: const _FirstLaunchGate(),
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
      await _checkDownloadPath();
      await _showReleaseNotesIfNeeded();
      await _checkForStartupUpdate();
    });
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
    return AppNavigationShell(
      fallbackReasonNotifier: ref.watch(anilistCacheFallbackReasonProvider),
      tabBuilders: <KumoriyaTab, WidgetBuilder>{
        KumoriyaTab.home: (_) => const HomePage(),
        KumoriyaTab.search: (_) => const SearchPage(),
        KumoriyaTab.calendar: (_) => const CalendarPage(),
        KumoriyaTab.library: (_) => const LibraryPage(),
        KumoriyaTab.downloads: (_) => const DownloadsPage(),
      },
    );
  }
}
