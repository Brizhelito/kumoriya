import 'package:flutter/widgets.dart';

import '../platform/form_factor_provider.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_gradients.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';

/// Base surface container with cloud shadow and optional gradient.
///
/// This is the foundational building block — most visible surfaces
/// in the design system are wrapped in a [CloudSurface].
class CloudSurface extends StatelessWidget {
  const CloudSurface({
    super.key,
    this.padding,
    this.margin,
    this.radius = CloudRadius.lg,
    this.gradient = false,
    this.shadowLevel = _ShadowLevel.base,
    this.clipBehavior = Clip.none,
    required this.child,
  });

  /// No shadow variant.
  const CloudSurface.flat({
    super.key,
    this.padding,
    this.margin,
    this.radius = CloudRadius.lg,
    this.gradient = false,
    this.clipBehavior = Clip.none,
    required this.child,
  }) : shadowLevel = _ShadowLevel.none;

  /// Small shadow variant.
  const CloudSurface.sm({
    super.key,
    this.padding,
    this.margin,
    this.radius = CloudRadius.lg,
    this.gradient = false,
    this.clipBehavior = Clip.none,
    required this.child,
  }) : shadowLevel = _ShadowLevel.sm;

  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final bool gradient;
  final _ShadowLevel shadowLevel;
  final Clip clipBehavior;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return Container(
      margin: margin,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: gradient ? null : colors.surface,
        gradient: gradient ? CloudGradients.cloud(colors) : null,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: _resolveShadow(colors),
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
  }

  List<BoxShadow>? _resolveShadow(CloudColors colors) {
    return switch (shadowLevel) {
      _ShadowLevel.none => null,
      _ShadowLevel.sm => colors.shadowSm,
      _ShadowLevel.base => colors.shadow,
      _ShadowLevel.lg => colors.shadowLg,
    };
  }
}

enum _ShadowLevel { none, sm, base, lg }
