import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_app/l10n/generated/app_localizations.dart';

import '../features/anime_catalog/presentation/pages/calendar_page.dart';
import '../features/anime_catalog/presentation/pages/downloads_page.dart';
import '../features/anime_catalog/presentation/pages/home_page.dart';
import '../features/anime_catalog/presentation/pages/library_page.dart';
import '../features/anime_catalog/presentation/pages/search_page.dart';
import '../features/anime_catalog/presentation/providers/anime_catalog_providers.dart';
import '../features/downloads/application/download_directory_service.dart';
import '../features/downloads/presentation/download_providers.dart';
import '../features/downloads/presentation/widgets/download_path_dialog.dart';
import '../shared/navigation/app_navigation_shell.dart';
import '../shared/theme/kumoriya_theme.dart';
import 'l10n.dart';

class KumoriyaApp extends StatelessWidget {
  const KumoriyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDownloadPath());
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
