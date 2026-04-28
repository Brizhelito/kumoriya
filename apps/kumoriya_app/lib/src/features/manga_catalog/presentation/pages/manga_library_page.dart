import 'package:flutter/material.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../widgets/manga_placeholder_body.dart';

class MangaLibraryPage extends StatelessWidget {
  const MangaLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      body: SafeArea(
        child: MangaPlaceholderBody(
          icon: Icons.library_books_rounded,
          title: context.l10n.mangaLibraryTitle,
          subtitle: context.l10n.mangaComingSoonSlice10,
        ),
      ),
    );
  }
}
