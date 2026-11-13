import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/product_thumbnail.dart';
import '../../../../data/models/cart_model.dart';

/// Single cart line with qty stepper, unit price, line subtotal, remove.
/// Responsive and overflow-proof on all screen sizes (small phones, foldables, tablets).
class PosCartLineTile extends StatelessWidget {
  const PosCartLineTile({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final maxStock = item.product.stock;
    final canInc = item.quantity < maxStock;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLG),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2C3540)
              : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, c) {
            // Responsive breakpoint: phones and narrow columns use the 2-row layout.
            // Wide screens (tablets/desktops >= 560px) use the single-row layout.
            final isWide = c.maxWidth >= 560;

            final nameBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.product.name,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${AppFormatters.formatCurrency(item.product.price)} each',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (item.product.taxRate > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'GST ${item.product.taxRatePercent.toStringAsFixed(item.product.taxRatePercent.truncateToDouble() == item.product.taxRatePercent ? 0 : 1)}%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );

            final stepperAndBadge = Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _QtyIconButton(
                      icon: Icons.remove_rounded,
                      onPressed: item.quantity > 1 ? onDecrement : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${item.quantity}',
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _QtyIconButton(
                      icon: Icons.add_rounded,
                      onPressed: canInc ? onIncrement : null,
                    ),
                  ],
                ),
                if (!canInc)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Text(
                      'Max stock',
                      style: TextStyle(
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            );

            final subtotal = Text(
              AppFormatters.formatCurrency(item.total),
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            );

            if (!isWide) {
              // Mobile / narrow layout: 2 rows to give ample room for title, stepper, and subtotal
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProductThumbnail(
                        imageUrl: item.product.imageUrl,
                        size: 46,
                        borderRadius: BorderRadius.circular(10),
                        placeholderIcon: Icons.inventory_2_outlined,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: nameBlock),
                      IconButton(
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: AppColors.error,
                        tooltip: 'Remove',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: stepperAndBadge),
                      const SizedBox(width: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: subtotal,
                      ),
                    ],
                  ),
                ],
              );
            }

            // Wide / tablet / desktop layout
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ProductThumbnail(
                  imageUrl: item.product.imageUrl,
                  size: 48,
                  borderRadius: BorderRadius.circular(10),
                  placeholderIcon: Icons.inventory_2_outlined,
                ),
                const SizedBox(width: 12),
                Expanded(child: nameBlock),
                const SizedBox(width: 12),
                stepperAndBadge,
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 70, maxWidth: 120),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: subtotal,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppColors.error,
                  tooltip: 'Remove',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QtyIconButton extends StatelessWidget {
  const _QtyIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 20,
            color: onPressed != null ? AppColors.primary : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
