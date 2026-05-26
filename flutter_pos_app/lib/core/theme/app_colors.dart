import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core Brand Colors - Premium Sapphire & Indigo
  static const Color primary = Color(0xFF6366F1);    // Indigo 500
  static const Color accent = Color(0xFF1E1B4B);     // Deep Indigo 950
  static const Color secondary = Color(0xFF4F46E5);  // Indigo 600
  
  // Neutral Palette
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color backgroundSecondary = Color(0xFFF1F5F9); // Slate 100
  static const Color backgroundTertiary = Color(0xFFE2E8F0); // Slate 200
  static const Color border = Color(0xFFE2E8F0);
  
  // Semantic Colors - Modern & Balanced
  static const Color success = Color(0xFF10B981);    // Emerald 500
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color error = Color(0xFFEF4444);      // Red 500
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF59E0B);    // Amber 500
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF3B82F6);       // Blue 500
  static const Color infoLight = Color(0xFFDBEAFE);

  // Additional Legacy/Specific Colors
  static const Color primaryDark = Color(0xFF4338CA);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color amazonYellow = Color(0xFFFF9900);
  static const Color amazonOrange = Color(0xFFFF9900);
  static const Color black = Color(0xFF000000);
  static const Color shadowLight = Color(0xFFE2E8F0);

  // Surface Colors
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFF1F5F9);
  static const Color divider = Color(0xFFF1F5F9);

  // Text Colors - High Contrast Slate
  static const Color textPrimary = Color(0xFF0F172A);   // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textTertiary = Color(0xFF94A3B8);  // Slate 400
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Gradients for Premium Look
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> shadowSubtle = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.04),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.08),
      blurRadius: 30,
      offset: const Offset(0, 12),
    ),
  ];

  // Helper for components expecting Color for shadowColor
  static const Color shadowColor = Color(0x0F0F172A);
}
