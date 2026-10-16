import 'package:flutter/material.dart';

/// Production-ready modern floating Navy Blue SnackBar for the entire app.
/// - Flexible positioning: docks cleanly at the bottom, just above keyboard,
///   bottom navigation bar, or system navigation bar.
/// - Aesthetics: Sleek Navy Blue (#0F172A), subtle border, soft shadow,
///   subtle icon accent, no red, no green.
class AppSnackBar {
  AppSnackBar._();

  static const Color navyBackground = Color(0xFF0F172A);
  static const Color navyBorder = Color(0xFF1E293B);

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: duration,
        backgroundColor: navyBackground,
        elevation: 8,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: navyBorder, width: 1),
        ),
        action: action,
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isError ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded,
                size: 16,
                color: const Color(0xFF93C5FD), // Subtle soft blue accent (no red, no green)
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
