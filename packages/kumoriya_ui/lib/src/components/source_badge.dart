import 'package:flutter/widgets.dart';

import '../platform/form_factor_provider.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';

/// Source badge pill — shows plugin source name with optional audio kind.
class SourceBadge extends StatelessWidget {
  const SourceBadge({
    super.key,
    required this.sourceName,
    this.isHighlighted = false,
    this.compact = false,
  });

  final String sourceName;
  final bool isHighlighted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return Container(
      height: compact ? 26 : 30,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
      decoration: BoxDecoration(
        color: isHighlighted ? colors.primarySoft : colors.surface,
        borderRadius: BorderRadius.circular(CloudRadius.pill),
        border: Border.all(
          color: isHighlighted
              ? colors.primary.withValues(alpha: 0.6)
              : colors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Center(
        child: Text(
          sourceName,
          style: TextStyle(
            color: isHighlighted ? colors.primary : colors.primary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
