import 'package:flutter/material.dart';
import '../theme/kumoriya_theme.dart';

class MetaChip extends StatelessWidget {
  const MetaChip({super.key, required this.label, this.isActive = false});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? KumoriyaColors.primaryContainer
            : KumoriyaColors.surfaceElevated,
        borderRadius: BorderRadius.circular(KumoriyaRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isActive
              ? KumoriyaColors.primaryLight
              : KumoriyaColors.textTertiary,
        ),
      ),
    );
  }
}
