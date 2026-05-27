import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/core/utils/formatters.dart';
import 'package:retail_verse_pos/core/widgets/product_media_image.dart';
import 'package:retail_verse_pos/data/models/product_model.dart';
import 'package:retail_verse_pos/features/pos/providers/cart_provider.dart';

/// Route `extra` for `/pos/product` when opened from [PosBillingScreen] (local billing cart).
class PosBillingProductDetailExtra {
  PosBillingProductDetailExtra({
    required this.product,
    required this.onAdded,
  });

  final Product product;
  final void Function(Product product, int quantity) onAdded;
}

/// Product detail from POS catalog — add to cart with quantity (shared [cartProvider]),
/// or [onAddToBilling] when opened from billing.
class PosProductDetailScreen extends ConsumerStatefulWidget {
  const PosProductDetailScreen({
    super.key,
    required this.product,
    this.onAddToBilling,
  });

  final Product product;

  /// When set, "Add to order" calls this instead of [cartProvider] (POS billing local cart).
  final void Function(Product product, int quantity)? onAddToBilling;

  @override
  ConsumerState<PosProductDetailScreen> createState() =>
      _PosProductDetailScreenState();
}

class _PosProductDetailScreenState extends ConsumerState<PosProductDetailScreen> {
  late int _qty;

  @override
  void initState() {
    super.initState();
    _qty = widget.product.isInStock ? 1 : 0;
  }

  void _addToCart() {
    final p = widget.product;
    if (!p.isInStock || _qty < 1) return;
    final billing = widget.onAddToBilling;
    if (billing != null) {
      billing(p, _qty);
    } else {
      ref.read(cartProvider.notifier).addProductWithQuantity(p, _qty);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          billing != null
              ? '${p.name} × $_qty added to order'
              : '${p.name} × $_qty added to cart',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final desc = p.description?.trim();
    final cartState = ref.watch(cartProvider);
    final cartItemCount = cartState.itemCount;

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Product',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.primary),
                onPressed: () => context.push('/pos/cart'),
              ),
              if (cartItemCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Center(
                      child: Text(
                        cartItemCount > 99 ? '99+' : '$cartItemCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 1.8,
              child: ProductMediaImage(
                imageUrl: p.imageUrl,
                fit: BoxFit.cover,
                placeholder: ColoredBox(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: ColoredBox(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    size: 72,
                    color: AppColors.primary.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            p.name,
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppFormatters.formatCurrency(p.price),
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          _chipRow(p),
          const SizedBox(height: 20),
          if (desc != null && desc.isNotEmpty) ...[
            Text(
              'Description',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (p.isInStock) ...[
            Text(
              'Quantity',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _QtyButton(
                  icon: Icons.remove_rounded,
                  onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '$_qty',
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _QtyButton(
                  icon: Icons.add_rounded,
                  onPressed: _qty < p.stock
                      ? () => setState(() => _qty++)
                      : null,
                ),
                const Spacer(),
                Text(
                  'Max ${p.stock}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: p.isInStock ? _addToCart : null,
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: Text(
              !p.isInStock
                  ? 'Out of stock'
                  : (widget.onAddToBilling != null
                      ? 'Add to order'
                      : 'Add to cart'),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
          if (cartItemCount > 0) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/pos/cart'),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Go to Checkout'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chipRow(Product p) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _InfoChip(
          icon: Icons.tag_rounded,
          label: AppFormatters.formatSKU(p.sku),
        ),
        if (p.category.isNotEmpty)
          _InfoChip(icon: Icons.category_outlined, label: p.category),
        _InfoChip(
          icon: Icons.warehouse_outlined,
          label: '${p.stock} ${p.unit} · ${p.stockStatus}',
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: AppColors.primary),
      label: Text(label, style: AppTypography.bodySmall),
      backgroundColor: AppColors.background,
      side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: AppColors.primary),
        ),
      ),
    );
  }
}
