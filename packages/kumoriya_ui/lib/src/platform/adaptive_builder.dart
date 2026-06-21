import 'package:flutter/widgets.dart';

import 'form_factor.dart';
import 'form_factor_provider.dart';

/// A widget that renders different builders based on the active [FormFactor].
///
/// If [tablet] builder is null, falls back to [mobile].
/// This keeps tablet adaptation opt-in per component.
///
/// Usage:
/// ```dart
/// AdaptiveBuilder(
///   mobile: (context) => MobileGrid(),
///   tablet: (context) => TabletGrid(),
///   desktop: (context) => DesktopGrid(),
/// )
/// ```
class AdaptiveBuilder extends StatelessWidget {
  const AdaptiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  /// Builder for mobile form factor (width < 600px on mobile OS).
  final WidgetBuilder mobile;

  /// Builder for tablet form factor (600–960px on mobile OS).
  /// If null, falls back to [mobile].
  final WidgetBuilder? tablet;

  /// Builder for desktop form factor (≥ 960px or desktop OS).
  final WidgetBuilder desktop;

  @override
  Widget build(BuildContext context) {
    final factor = FormFactorProvider.formFactorOf(context);
    return switch (factor) {
      FormFactor.mobile => mobile(context),
      FormFactor.tablet => (tablet ?? mobile)(context),
      FormFactor.desktop => desktop(context),
    };
  }
}

/// A sliver variant of [AdaptiveBuilder] for use in [CustomScrollView].
class SliverAdaptiveBuilder extends StatelessWidget {
  const SliverAdaptiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder desktop;

  @override
  Widget build(BuildContext context) {
    final factor = FormFactorProvider.formFactorOf(context);
    return switch (factor) {
      FormFactor.mobile => mobile(context),
      FormFactor.tablet => (tablet ?? mobile)(context),
      FormFactor.desktop => desktop(context),
    };
  }
}
