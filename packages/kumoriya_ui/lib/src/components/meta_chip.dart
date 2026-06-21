import 'package:flutter/widgets.dart';

import '../platform/form_factor_provider.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';

/// Meta chip for format, year, episode count.
class MetaChip extends StatelessWidget {
  const MetaChip({super.key, required this.label, this.isActive = false});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: CloudSpacing.s2,
        vertical: CloudSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: isActive ? colors.primarySoft : colors.surface2,
        borderRadius: BorderRadius.circular(CloudRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? colors.text : colors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
