import 'package:flutter/material.dart';

import '../platform/form_factor_provider.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_spacing.dart';

/// L1 screen section header with optional "see all" action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
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
    final colors = FormFactorProvider.colorsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: CloudSpacing.s3),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                seeAllLabel ?? 'See all',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// L2 card section header (smaller, inline).
class CardHeader extends StatelessWidget {
  const CardHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: CloudSpacing.s2),
      child: Text(
        title,
        style: TextStyle(
          color: colors.text,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
