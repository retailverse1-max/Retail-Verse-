import 'package:flutter/material.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

class TrialBanner extends StatelessWidget {
  final Map<String, dynamic> user;

  const TrialBanner({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    if (user['subscriptionPlan'] != 'trial') {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final expiryString = user['subscriptionExpiry'];
    if (expiryString == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final expiryDate = DateTime.tryParse(expiryString);
    if (expiryDate == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final now = DateTime.now();
    final difference = expiryDate.difference(now);
    final daysLeft = difference.inDays;

    if (daysLeft < 0) {
      // Handled by router redirect to expired screen anyway, but just in case
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final isUrgent = daysLeft <= 3;
    final bgColor = isUrgent ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4);
    final borderColor = isUrgent ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0);
    final iconColor = isUrgent ? const Color(0xFFDC2626) : const Color(0xFF16A34A);

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            FaIcon(
              isUrgent ? FontAwesomeIcons.circleExclamation : FontAwesomeIcons.clockRotateLeft,
              color: iconColor,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUrgent 
                        ? 'Trial Expiring Soon!' 
                        : 'Free Trial Active',
                    style: AppTypography.titleMedium.copyWith(
                      color: iconColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You have $daysLeft days left in your free trial. Subscribe to keep using the app.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () {
                context.push('/upgrade');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: const Text('Upgrade Now', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
