import 'package:flutter/material.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../widgets/manga_placeholder_body.dart';

class MangaDownloadsPage extends StatelessWidget {
  const MangaDownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      body: SafeArea(
        child: MangaPlaceholderBody(
          icon: Icons.download_rounded,
          title: context.l10n.mangaDownloadsTitle,
          subtitle: context.l10n.mangaComingSoonSlice11,
        ),
      ),
    );
  }
}
