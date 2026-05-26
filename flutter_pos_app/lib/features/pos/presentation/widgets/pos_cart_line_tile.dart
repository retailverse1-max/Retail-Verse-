import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/product_thumbnail.dart';
import '../../../../data/models/cart_model.dart';

/// Single cart line with qty stepper, unit price, line subtotal, remove.
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
            final narrow = c.maxWidth < 360;
            final nameBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(
                  '${AppFormatters.formatCurrency(item.product.price)} each',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );

            final qtyRow = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QtyIconButton(
                  icon: Icons.remove_rounded,
                  onPressed: item.quantity > 1 ? onDecrement : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${item.quantity}',
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _QtyIconButton(
                  icon: Icons.add_rounded,
                  onPressed: canInc ? onIncrement : null,
                ),
                if (!canInc) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Max stock',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ],
            );

            final subtotal = Text(
              AppFormatters.formatCurrency(item.total),
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            );

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProductThumbnail(
                        imageUrl: item.product.imageUrl,
                        size: 48,
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      qtyRow,
                      const Spacer(),
                      subtotal,
                    ],
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ProductThumbnail(
                  imageUrl: item.product.imageUrl,
                  size: 48,
                  borderRadius: BorderRadius.circular(10),
                  placeholderIcon: Icons.inventory_2_outlined,
                ),
                const SizedBox(width: 10),
                Expanded(flex: 5, child: nameBlock),
                Expanded(flex: 3, child: Center(child: qtyRow)),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppColors.error,
                  tooltip: 'Remove',
                ),
                SizedBox(
                  width: 88,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: subtotal,
                  ),
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
