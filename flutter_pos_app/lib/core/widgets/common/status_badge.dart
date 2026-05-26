import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Premium status badge widget for displaying order/product statuses
class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType type;
  final bool isSmall;

  const StatusBadge({
    super.key,
    required this.label,
    required this.type,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 12,
        vertical: isSmall ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: colors.backgroundColor,
        borderRadius: BorderRadius.circular(isSmall ? 4 : 8),
        border: Border.all(color: colors.borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isSmall) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colors.dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style:
                (isSmall ? AppTypography.labelSmall : AppTypography.labelMedium)
                    .copyWith(
                      color: colors.textColor,
                      fontWeight: FontWeight.w500,
                    ),
          ),
        ],
      ),
    );
  }

  _StatusColors _getColors() {
    switch (type) {
      case StatusType.success:
        return _StatusColors(
          backgroundColor: AppColors.successLight,
          borderColor: AppColors.success,
          dotColor: AppColors.success,
          textColor: AppColors.success,
        );

      case StatusType.warning:
        return _StatusColors(
          backgroundColor: AppColors.warningLight,
          borderColor: AppColors.warning,
          dotColor: AppColors.warning,
          textColor: AppColors.warning,
        );

      case StatusType.error:
        return _StatusColors(
          backgroundColor: AppColors.errorLight,
          borderColor: AppColors.error,
          dotColor: AppColors.error,
          textColor: AppColors.error,
        );

      case StatusType.info:
        return _StatusColors(
          backgroundColor: AppColors.infoLight,
          borderColor: AppColors.info,
          dotColor: AppColors.info,
          textColor: AppColors.info,
        );

      case StatusType.neutral:
        return _StatusColors(
          backgroundColor: AppColors.backgroundSecondary,
          borderColor: AppColors.border,
          dotColor: AppColors.textTertiary,
          textColor: AppColors.textSecondary,
        );
    }
  }
}

enum StatusType { success, warning, error, info, neutral }

class _StatusColors {
  final Color backgroundColor;
  final Color borderColor;
  final Color dotColor;
  final Color textColor;

  _StatusColors({
    required this.backgroundColor,
    required this.borderColor,
    required this.dotColor,
    required this.textColor,
  });
}
