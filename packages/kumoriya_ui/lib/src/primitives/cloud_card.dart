import 'package:flutter/material.dart';

import '../platform/form_factor_provider.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_gradients.dart';
import '../tokens/cloud_motion.dart';
import '../tokens/cloud_radius.dart';

/// A cloud-styled card with gradient background, cloud shadow,
/// and a lift-on-hover effect for desktop.
class CloudCard extends StatefulWidget {
  const CloudCard({
    super.key,
    required this.child,
    this.onTap,
    this.gradient = true,
    this.padding = const EdgeInsets.all(16),
    this.radius = CloudRadius.lg,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool gradient;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  State<CloudCard> createState() => _CloudCardState();
}

class _CloudCardState extends State<CloudCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final factor = FormFactorProvider.formFactorOf(context);
    final isInteractive = widget.onTap != null;

    Widget card = AnimatedContainer(
      duration: CloudMotion.fast,
      curve: CloudMotion.easeCloud,
      transform: _hovered && factor.isDesktop && isInteractive
          ? (Matrix4.identity()..translate(0.0, -6.0))
          : Matrix4.identity(),
      decoration: BoxDecoration(
        color: widget.gradient ? null : colors.surface,
        gradient: widget.gradient ? CloudGradients.cloud(colors) : null,
        borderRadius: BorderRadius.circular(widget.radius),
        boxShadow: _hovered && factor.isDesktop
            ? colors.shadowHover
            : colors.shadow,
      ),
      child: Padding(padding: widget.padding, child: widget.child),
    );

    if (isInteractive) {
      card = MouseRegion(
        cursor: factor.isDesktop
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: card,
        ),
      );
    }

    return card;
  }
}
