import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Elite Typography for Retail Verse
/// Using 'Outfit' for a high-end, premium brand aesthetic.
class AppTypography {
  AppTypography._();

  // Font Sizes - Refined for premium hierarchy
  static const double fontSizeXS = 12.0;
  static const double fontSizeSM = 14.0;
  static const double fontSizeMD = 16.0;
  static const double fontSizeLG = 18.0;
  static const double fontSizeXL = 22.0;
  static const double fontSize2XL = 26.0;
  static const double fontSize3XL = 32.0;
  static const double fontSize4XL = 40.0;
  static const double fontSize5XL = 48.0;

  static TextStyle _style({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double height = 1.1,
    double? letterSpacing,
  }) {
    return GoogleFonts.outfit(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // --- ELITE DISPLAY (Large Numbers/Brand) ---
  static TextStyle get displayLarge => _style(
        fontSize: fontSize5XL,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
        letterSpacing: -1.5,
      );

  static TextStyle get displayMedium => _style(
        fontSize: fontSize4XL,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
        letterSpacing: -1.0,
      );

  static TextStyle get displaySmall => _style(
        fontSize: fontSize3XL,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  // --- BOLD HEADLINES (Section Headers) ---
  static TextStyle get headlineLarge => _style(
        fontSize: fontSize2XL,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineMedium => _style(
        fontSize: fontSizeXL,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineSmall => _style(
        fontSize: fontSizeLG,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  // --- PREMIUM TITLES (Cards, Buttons) ---
  static TextStyle get titleLarge => _style(
        fontSize: fontSizeLG,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get titleMedium => _style(
        fontSize: fontSizeMD,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get titleSmall => _style(
        fontSize: fontSizeSM,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  // --- READABLE BODY (SaaS Style) ---
  static TextStyle get bodyLarge => _style(
        fontSize: fontSizeLG,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => _style(
        fontSize: fontSizeMD,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodySmall => _style(
        fontSize: fontSizeSM,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.textSecondary,
      );

  // --- COMPACT LABELS (Captions, Details) ---
  static TextStyle get labelLarge => _style(
        fontSize: fontSizeMD,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get labelMedium => _style(
        fontSize: fontSizeSM,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      );

  static TextStyle get labelSmall => _style(
        fontSize: fontSizeXS,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
      );

  static TextStyle get caption => _style(
        fontSize: fontSizeXS,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get priceMedium => _style(
        fontSize: fontSizeXL,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
      );
}
