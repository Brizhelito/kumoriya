import 'package:flutter/material.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';

class DownloadPathDialog extends StatelessWidget {
  const DownloadPathDialog({
    super.key,
    required this.suggestedPath,
    required this.onUseDefault,
    required this.onBrowse,
  });

  final String suggestedPath;
  final VoidCallback onUseDefault;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: KumoriyaColors.surface,
      title: Text(context.l10n.downloadFolderTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.downloadFolderDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: KumoriyaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KumoriyaColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              suggestedPath,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: KumoriyaColors.textMuted,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            context.l10n.downloadCancel,
            style: TextStyle(color: KumoriyaColors.textMuted),
          ),
        ),
        TextButton(
          onPressed: onBrowse,
          child: Text(context.l10n.downloadFolderChange),
        ),
        FilledButton(
          onPressed: onUseDefault,
          child: Text(context.l10n.downloadFolderReset),
        ),
      ],
    );
  }
}
