import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Responsive layout widget that adapts to screen size
class ResponsiveLayout extends StatelessWidget {
  final Widget phoneLayout;
  final Widget tabletLayout;

  const ResponsiveLayout({
    super.key,
    required this.phoneLayout,
    required this.tabletLayout,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return tabletLayout;
        } else {
          return phoneLayout;
        }
      },
    );
  }
}
