import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../theme/kumoriya_theme.dart';

/// Screen-level section header (L1).
/// Uses titleLarge (18/w700) for the title.
class KumoriyaSectionHeader extends StatelessWidget {
  const KumoriyaSectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.seeAllLabel,
  });

  final String title;
  final VoidCallback? onSeeAll;
  final String? seeAllLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              foregroundColor: KumoriyaColors.textTertiary,
              textStyle: Theme.of(context).textTheme.labelMedium,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(seeAllLabel ?? context.l10n.sectionSeeAll),
          ),
      ],
    );
  }
}
