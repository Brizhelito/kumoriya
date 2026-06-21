import 'package:flutter/widgets.dart';

import '../tokens/cloud_colors.dart';
import 'form_factor.dart';

/// Provides the active [FormFactor] and [CloudColors] to all descendants.
///
/// Wrap the app root in [FormFactorProvider] to enable adaptive layouts
/// and cloud theming throughout the widget tree.
class FormFactorProvider extends StatefulWidget {
  const FormFactorProvider({
    super.key,
    required this.colors,
    required this.child,
  });

  /// The active cloud color palette.
  final CloudColors colors;

  /// The child widget tree.
  final Widget child;

  /// Retrieves the nearest [FormFactorData] from the widget tree.
  static FormFactorData of(BuildContext context) {
    final data = context
        .dependOnInheritedWidgetOfExactType<_FormFactorInherited>();
    assert(data != null, 'FormFactorProvider not found in widget tree.');
    return data!.data;
  }

  /// Retrieves the nearest [FormFactor] from the widget tree.
  static FormFactor formFactorOf(BuildContext context) => of(context).factor;

  /// Retrieves the nearest [CloudColors] from the widget tree.
  static CloudColors colorsOf(BuildContext context) => of(context).colors;

  @override
  State<FormFactorProvider> createState() => _FormFactorProviderState();
}

class _FormFactorProviderState extends State<FormFactorProvider> {
  FormFactor _factor = FormFactor.mobile;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateFactor();
  }

  void _updateFactor() {
    final width = MediaQuery.sizeOf(context).width;
    final factor = FormFactor.fromPlatform(width: width);
    if (factor != _factor) {
      setState(() => _factor = factor);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-check on each build to catch resize events (desktop window resize).
    final width = MediaQuery.sizeOf(context).width;
    _factor = FormFactor.fromPlatform(width: width);

    return _FormFactorInherited(
      data: FormFactorData(factor: _factor, colors: widget.colors),
      child: widget.child,
    );
  }
}

/// Immutable snapshot of the active form factor and colors.
class FormFactorData {
  const FormFactorData({required this.factor, required this.colors});

  final FormFactor factor;
  final CloudColors colors;
}

class _FormFactorInherited extends InheritedWidget {
  const _FormFactorInherited({required this.data, required super.child});

  final FormFactorData data;

  @override
  bool updateShouldNotify(_FormFactorInherited oldWidget) {
    return data.factor != oldWidget.data.factor ||
        data.colors != oldWidget.data.colors;
  }
}
