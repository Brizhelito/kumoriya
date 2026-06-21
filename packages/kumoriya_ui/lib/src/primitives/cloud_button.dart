import 'package:flutter/material.dart';

import '../platform/form_factor_provider.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_motion.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';

/// Cloud-styled button with three variants: primary, secondary, ghost.
///
/// Pill shape, cloud shadow, translateY(-1px) on hover.
class CloudButton extends StatefulWidget {
  const CloudButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = CloudButtonVariant.primary,
    this.icon,
    this.enabled = true,
  });

  /// Factory for a text-label primary button.
  factory CloudButton.primary({
    Key? key,
    required VoidCallback? onPressed,
    required String label,
    IconData? icon,
  }) {
    return CloudButton(
      key: key,
      onPressed: onPressed,
      icon: icon,
      child: Text(label),
    );
  }

  /// Factory for a secondary (accent) button.
  factory CloudButton.secondary({
    Key? key,
    required VoidCallback? onPressed,
    required String label,
    IconData? icon,
  }) {
    return CloudButton(
      key: key,
      onPressed: onPressed,
      variant: CloudButtonVariant.secondary,
      icon: icon,
      child: Text(label),
    );
  }

  /// Factory for a ghost (outlined/transparent) button.
  factory CloudButton.ghost({
    Key? key,
    required VoidCallback? onPressed,
    required String label,
    IconData? icon,
  }) {
    return CloudButton(
      key: key,
      onPressed: onPressed,
      variant: CloudButtonVariant.ghost,
      icon: icon,
      child: Text(label),
    );
  }

  final VoidCallback? onPressed;
  final Widget child;
  final CloudButtonVariant variant;
  final IconData? icon;
  final bool enabled;

  @override
  State<CloudButton> createState() => _CloudButtonState();
}

enum CloudButtonVariant { primary, secondary, ghost }

class _CloudButtonState extends State<CloudButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final factor = FormFactorProvider.formFactorOf(context);
    final isEnabled = widget.enabled && widget.onPressed != null;

    final bgColor = _resolveBg(colors, isEnabled);
    final fgColor = _resolveFg(colors, isEnabled);
    final border = _resolveBorder(colors, isEnabled);
    final shadows = _resolveShadows(colors, isEnabled);

    Widget button = AnimatedContainer(
      duration: CloudMotion.fast,
      curve: CloudMotion.easeCloud,
      transform: _hovered && factor.isDesktop && isEnabled
          ? (Matrix4.identity()..translate(0.0, -1.0))
          : Matrix4.identity(),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(CloudRadius.pill),
        border: border,
        boxShadow: shadows,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: CloudSpacing.s5,
        vertical: CloudSpacing.s3,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 18, color: fgColor),
            SizedBox(width: CloudSpacing.s2),
          ],
          DefaultTextStyle(
            style: TextStyle(
              color: fgColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            child: widget.child,
          ),
        ],
      ),
    );

    if (isEnabled) {
      button = MouseRegion(
        cursor: factor.isDesktop
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: button,
        ),
      );
    }

    return button;
  }

  Color? _resolveBg(CloudColors colors, bool isEnabled) {
    if (!isEnabled) return colors.surface2;
    if (_pressed) {
      return switch (widget.variant) {
        CloudButtonVariant.primary => colors.primary,
        CloudButtonVariant.secondary => colors.accentSoft,
        CloudButtonVariant.ghost => colors.surface2,
      };
    }
    return switch (widget.variant) {
      CloudButtonVariant.primary => colors.text,
      CloudButtonVariant.secondary => colors.accent,
      CloudButtonVariant.ghost => null,
    };
  }

  Color _resolveFg(CloudColors colors, bool isEnabled) {
    if (!isEnabled) return colors.textSoft;
    return switch (widget.variant) {
      CloudButtonVariant.primary =>
        colors.isDark ? colors.bg : const Color(0xFFFFFFFF),
      CloudButtonVariant.secondary => colors.text,
      CloudButtonVariant.ghost => colors.textMuted,
    };
  }

  Border? _resolveBorder(CloudColors colors, bool isEnabled) {
    if (widget.variant != CloudButtonVariant.ghost) return null;
    return Border.all(
      color: isEnabled
          ? colors.surface2
          : colors.surface2.withValues(alpha: 0.5),
      width: 1.5,
    );
  }

  List<BoxShadow>? _resolveShadows(CloudColors colors, bool isEnabled) {
    if (!isEnabled) return null;
    if (widget.variant == CloudButtonVariant.ghost) return null;
    return colors.shadowSm;
  }
}
