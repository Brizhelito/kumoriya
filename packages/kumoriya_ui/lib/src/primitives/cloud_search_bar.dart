import 'package:flutter/material.dart';

import '../platform/form_factor.dart';
import '../platform/form_factor_provider.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_motion.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';

/// Cloud-styled search bar — pill shape, surface-2 bg, focus glow.
class CloudSearchBar extends StatefulWidget {
  const CloudSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search…',
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<CloudSearchBar> createState() => _CloudSearchBarState();
}

class _CloudSearchBarState extends State<CloudSearchBar> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final factor = FormFactorProvider.formFactorOf(context);

    return AnimatedContainer(
      duration: CloudMotion.fast,
      curve: CloudMotion.easeCloud,
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(CloudRadius.pill),
        boxShadow: _focused ? colors.shadowSm : null,
        border: _focused
            ? Border.all(color: colors.primarySoft, width: 2)
            : null,
      ),
      padding: EdgeInsets.symmetric(horizontal: CloudSpacing.s4),
      child: Row(
        children: <Widget>[
          Icon(Icons.search_rounded, color: colors.textSoft, size: 18),
          SizedBox(width: CloudSpacing.s2),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: TextStyle(color: colors.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(color: colors.textSoft, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: CloudSpacing.s3),
              ),
            ),
          ),
          if (factor.isDesktop)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: CloudSpacing.s2,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(4),
                boxShadow: colors.shadowSm,
              ),
              child: Text(
                '⌘K',
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
