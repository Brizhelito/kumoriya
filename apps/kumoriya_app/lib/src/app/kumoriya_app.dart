import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kumoriya_app/l10n/generated/app_localizations.dart';

import '../features/anime_catalog/presentation/pages/calendar_page.dart';
import '../features/anime_catalog/presentation/pages/downloads_page.dart';
import '../features/anime_catalog/presentation/pages/home_page.dart';
import '../features/anime_catalog/presentation/pages/library_page.dart';
import '../features/anime_catalog/presentation/pages/search_page.dart';
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
      home: AppNavigationShell(
        tabBuilders: <KumoriyaTab, WidgetBuilder>{
          KumoriyaTab.home: (_) => const HomePage(),
          KumoriyaTab.search: (_) => const SearchPage(),
          KumoriyaTab.calendar: (_) => const CalendarPage(),
          KumoriyaTab.library: (_) => const LibraryPage(),
          KumoriyaTab.downloads: (_) => const DownloadsPage(),
        },
      ),
    );
  }
}
