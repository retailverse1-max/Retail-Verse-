import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

/// Responsive helper utilities for adaptive layouts
class ResponsiveUtils {
  ResponsiveUtils._();

  /// Check if screen is tablet size or larger
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= AppConstants.tabletBreakpoint;
  }

  /// Check if screen is phone size
  static bool isPhone(BuildContext context) {
    return MediaQuery.of(context).size.width < AppConstants.tabletBreakpoint;
  }

  /// Get number of columns for product grid based on screen size
  static int getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width >= AppConstants.desktopBreakpoint) {
      return 6;
    } else if (width >= AppConstants.tabletBreakpoint) {
      return 4;
    } else {
      return 2;
    }
  }

  /// Get responsive padding based on screen size
  static EdgeInsets getScreenPadding(BuildContext context) {
    if (isTablet(context)) {
      return const EdgeInsets.all(AppTheme.spacingLG);
    } else {
      return const EdgeInsets.all(AppTheme.spacingMD);
    }
  }

  /// Get responsive card height
  static double getCardHeight(BuildContext context, {double? fixedHeight}) {
    if (fixedHeight != null) return fixedHeight;

    if (isTablet(context)) {
      return 280;
    } else {
      return 240;
    }
  }

  /// Get layout type for POS screen
  static POSScreenLayout getPOSScreenLayout(BuildContext context) {
    if (isTablet(context)) {
      return POSScreenLayout.split;
    } else {
      return POSScreenLayout.stacked;
    }
  }

  /// Get dashboard stats grid configuration
  static DashboardStatsConfig getDashboardStatsConfig(BuildContext context) {
    if (isTablet(context)) {
      return const DashboardStatsConfig(
        crossAxisCount: 4,
        childAspectRatio: 1.5,
        mainAxisSpacing: AppTheme.spacingLG,
        crossAxisSpacing: AppTheme.spacingLG,
      );
    } else {
      return const DashboardStatsConfig(
        crossAxisCount: 2,
        childAspectRatio: 1.3,
        mainAxisSpacing: AppTheme.spacingMD,
        crossAxisSpacing: AppTheme.spacingMD,
      );
    }
  }

  /// Get order list item height
  static double getOrderItemHeight(BuildContext context) {
    if (isTablet(context)) {
      return 120;
    } else {
      return 100;
    }
  }

  /// Get inventory list tile height
  static double getInventoryTileHeight(BuildContext context) {
    if (isTablet(context)) {
      return 100;
    } else {
      return 80;
    }
  }

  /// Calculate font size based on screen width
  static double getResponsiveFontSize(
    BuildContext context, {
    required double baseSize,
    double minFactor = 0.8,
    double maxFactor = 1.2,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseWidth = 375.0; // iPhone SE width as baseline

    double factor = screenWidth / baseWidth;
    factor = factor.clamp(minFactor, maxFactor);

    return baseSize * factor;
  }

  /// Get button size based on platform
  static ButtonSize getButtonSize(BuildContext context) {
    if (isTablet(context)) {
      return const ButtonSize(height: 56, fontSize: 16, iconSize: 24);
    } else {
      return const ButtonSize(height: 48, fontSize: 14, iconSize: 20);
    }
  }

  /// Get dialog width
  static double getDialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth >= AppConstants.desktopBreakpoint) {
      return 600;
    } else if (screenWidth >= AppConstants.tabletBreakpoint) {
      return screenWidth * 0.6;
    } else {
      return screenWidth - AppTheme.spacingXL;
    }
  }

  /// Get split view proportions for POS screen
  static SplitViewProportions getSplitViewProportions(BuildContext context) {
    if (isTablet(context)) {
      return const SplitViewProportions(productsRatio: 0.6, cartRatio: 0.4);
    } else {
      return const SplitViewProportions(productsRatio: 1.0, cartRatio: 0.0);
    }
  }
}

/// Enum for POS screen layouts
enum POSScreenLayout { split, stacked }

/// Configuration for dashboard stats grid
class DashboardStatsConfig {
  final int crossAxisCount;
  final double childAspectRatio;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  const DashboardStatsConfig({
    required this.crossAxisCount,
    required this.childAspectRatio,
    required this.mainAxisSpacing,
    required this.crossAxisSpacing,
  });
}

/// Button size configuration
class ButtonSize {
  final double height;
  final double fontSize;
  final double iconSize;

  const ButtonSize({
    required this.height,
    required this.fontSize,
    required this.iconSize,
  });
}

/// Split view proportions configuration
class SplitViewProportions {
  final double productsRatio;
  final double cartRatio;

  const SplitViewProportions({
    required this.productsRatio,
    required this.cartRatio,
  });
}
