import 'package:flutter/material.dart';

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
      title: const Text('Choose Download Folder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select a folder for offline downloads.',
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
            'Not Now',
            style: TextStyle(color: KumoriyaColors.textMuted),
          ),
        ),
        TextButton(onPressed: onBrowse, child: const Text('Browse')),
        FilledButton(
          onPressed: onUseDefault,
          child: const Text('Use Recommended'),
        ),
      ],
    );
  }
}
