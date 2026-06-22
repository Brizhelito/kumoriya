import 'package:flutter/material.dart';

import '../../../../app/l10n.dart';
import 'package:kumoriya_ui/kumoriya_ui.dart';

class MyListPage extends StatelessWidget {
  const MyListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: Text(context.l10n.libraryTitle)),
      body: SafeArea(
        child: EmptyStateView(
          title: context.l10n.libraryTitle,
          icon: Icons.video_library_rounded,
          message: context.l10n.myListHistoryEmpty,
        ),
      ),
    );
  }
}
