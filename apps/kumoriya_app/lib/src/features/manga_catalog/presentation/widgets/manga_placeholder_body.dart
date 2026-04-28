import 'package:flutter/material.dart';

import '../../../../shared/theme/kumoriya_theme.dart';

/// Centered placeholder body shown by manga tabs that don't have real
/// content yet (Slices 8-11). Composed of an icon, a title, and a
/// supporting subtitle. Intentionally minimal — the real implementations
/// arrive in subsequent slices.
class MangaPlaceholderBody extends StatelessWidget {
  const MangaPlaceholderBody({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: KumoriyaColors.surface,
                borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
                border: Border.all(color: KumoriyaColors.borderSubtle),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 40, color: KumoriyaColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: KumoriyaColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: KumoriyaColors.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
