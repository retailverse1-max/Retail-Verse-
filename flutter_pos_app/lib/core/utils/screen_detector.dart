import 'package:flutter/material.dart';

/// Screen detection and logging utility for responsive design testing
class ScreenDetector {
  ScreenDetector._();

  /// Detect and log complete screen information
  static void logScreenInfo(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final width = size.width;
    final height = size.height;
    final pixelRatio = mediaQuery.devicePixelRatio;
    final orientation = mediaQuery.orientation;
    final padding = mediaQuery.padding;
    final viewInsets = mediaQuery.viewInsets;

    // Determine device type
    String deviceType;
    if (width < 600) {
      deviceType = '📱 MOBILE';
    } else if (width < 900) {
      deviceType = '📱 TABLET (Small)';
    } else if (width < 1200) {
      deviceType = '📱 TABLET (Large)';
    } else {
      deviceType = '💻 DESKTOP';
    }

    // Determine layout breakpoints
    String breakpoint;
    if (width < 375) {
      breakpoint = 'Extra Small (Compact)';
    } else if (width < 600) {
      breakpoint = 'Small (Standard Phone)';
    } else if (width < 900) {
      breakpoint = 'Medium (Phablet/Small Tablet)';
    } else if (width < 1200) {
      breakpoint = 'Large (Tablet)';
    } else {
      breakpoint = 'Extra Large (Desktop)';
    }

    print('''
╔═══════════════════════════════════════════════════════════╗
║                    📊 SCREEN DETECTION                     ║
╠═══════════════════════════════════════════════════════════╣
║  Device Type: $deviceType
║  Breakpoint: $breakpoint
╠───────────────────────────────────────────────────────────╢
║  Dimensions:
║  • Width:  ${width.toStringAsFixed(2)} px
║  • Height: ${height.toStringAsFixed(2)} px
║  • Aspect Ratio: ${(width / height).toStringAsFixed(2)}
╠───────────────────────────────────────────────────────────╢
║  Display Properties:
║  • Pixel Ratio: ${pixelRatio.toStringAsFixed(2)}x
║  • Orientation: ${orientation == Orientation.portrait ? 'Portrait ↕️' : 'Landscape ↔️'}
║  • Safe Area Top: ${padding.top.toStringAsFixed(0)} px
║  • Safe Area Bottom: ${padding.bottom.toStringAsFixed(0)} px
╠───────────────────────────────────────────────────────────╢
║  Responsive Layout Recommendations:
║  • Grid Columns: ${getRecommendedColumns(width)}
║  • Card Width: ${getRecommendedCardWidth(width)} px
║  • Use ${width < 600
        ? '2 columns'
        : width < 900
        ? '3 columns'
        : '4 columns'} for inventory grid
╠───────────────────────────────────────────────────────────╢
║  Keyboard State: ${viewInsets.bottom > 0 ? '🔑 OPEN (${viewInsets.bottom.toStringAsFixed(0)} px)' : '⌨️ CLOSED'}
╚═══════════════════════════════════════════════════════════╝
''');
  }

  /// Get recommended column count for GridView
  static int getRecommendedColumns(double width) {
    if (width < 600) return 2;
    if (width < 900) return 3;
    return 4;
  }

  /// Get recommended card width
  static double getRecommendedCardWidth(double width) {
    if (width < 600) return (width - 48) / 2;
    if (width < 900) return (width - 64) / 3;
    return (width - 80) / 4;
  }

  /// Check if current device is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  /// Check if current device is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1200;
  }

  /// Check if current device is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  /// Auto-detect and return layout configuration
  static Map<String, dynamic> getLayoutConfig(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return {
      'isMobile': width < 600,
      'isTablet': width >= 600 && width < 900,
      'isDesktop': width >= 900,
      'crossAxisCount': getRecommendedColumns(width),
      'cardWidth': getRecommendedCardWidth(width),
      'useCompactLayout': width < 600,
    };
  }
}
