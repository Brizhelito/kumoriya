import 'package:flutter/material.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/universe/widgets/universe_switch.dart';
import '../widgets/manga_placeholder_body.dart';

/// Home page for the manga universe. Renders the [UniverseSwitch] in its
/// header so the user can hop back to the anime universe at any time.
/// Body is a placeholder until Slice 8 replaces it with real content.
class MangaHomePage extends StatelessWidget {
  const MangaHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: UniverseSwitch(),
              ),
            ),
            Expanded(
              child: MangaPlaceholderBody(
                icon: Icons.menu_book_rounded,
                title: context.l10n.mangaHomeTitle,
                subtitle: context.l10n.mangaComingSoonSlice8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
