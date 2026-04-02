import 'package:flutter/material.dart';

import '../../../../shared/theme/kumoriya_theme.dart';
import '../../application/release_notes_catalog.dart';

class PostUpdateReleaseNotesDialog extends StatelessWidget {
  const PostUpdateReleaseNotesDialog({
    super.key,
    required this.previousVersion,
    required this.notes,
  });

  final String previousVersion;
  final LocalReleaseNotes notes;

  static Future<void> show(
    BuildContext context, {
    required String previousVersion,
    required LocalReleaseNotes notes,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => PostUpdateReleaseNotesDialog(
        previousVersion: previousVersion,
        notes: notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spanish = Localizations.localeOf(context).languageCode == 'es';
    final textTheme = Theme.of(context).textTheme;

    Widget section(String label, List<String> items) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: KumoriyaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: KumoriyaColors.textPrimary,
              ),
            ),
            const SizedBox(height: KumoriyaSpacing.xs),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: KumoriyaSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: KumoriyaColors.primary,
                      ),
                    ),
                    const SizedBox(width: KumoriyaSpacing.sm),
                    Expanded(
                      child: Text(
                        item,
                        style: textTheme.bodyMedium?.copyWith(
                          color: KumoriyaColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return AlertDialog(
      backgroundColor: KumoriyaColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
      ),
      title: Row(
        children: <Widget>[
          const Icon(Icons.auto_awesome, color: KumoriyaColors.primary),
          const SizedBox(width: KumoriyaSpacing.sm),
          Expanded(child: Text(notes.title)),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KumoriyaSpacing.sm,
                  vertical: KumoriyaSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: KumoriyaColors.primaryContainer,
                  borderRadius: BorderRadius.circular(KumoriyaRadius.sm),
                ),
                child: Text(
                  'v$previousVersion → v${notes.version}',
                  style: textTheme.labelMedium?.copyWith(
                    color: KumoriyaColors.primaryLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: KumoriyaSpacing.md),
              Text(
                notes.summary,
                style: textTheme.bodyMedium?.copyWith(
                  color: KumoriyaColors.textSecondary,
                ),
              ),
              section(spanish ? 'Agregado' : 'Added', notes.added),
              section(spanish ? 'Cambios' : 'Changed', notes.changed),
              section(spanish ? 'Corregido' : 'Fixed', notes.fixed),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(spanish ? 'Entendido' : 'Got it'),
        ),
      ],
    );
  }
}
