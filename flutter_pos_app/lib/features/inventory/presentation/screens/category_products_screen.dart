import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/navigation/role_nav.dart';
import '../../../../core/navigation/role_route_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/product_thumbnail.dart';
import '../../../../data/models/product_model.dart' as api;
import '../../../auth/providers/auth_provider.dart';
import '../../../dashboard/providers/dashboard_providers.dart';
import '../../../pos/providers/product_providers.dart';
import '../../data/models/category.dart';

/// Category products loaded from GET /products (filtered by category name).
class CategoryProductsScreen extends ConsumerStatefulWidget {
  final Category category;

  const CategoryProductsScreen({super.key, required this.category});

  @override
  ConsumerState<CategoryProductsScreen> createState() =>
      _CategoryProductsScreenState();
}

class _CategoryProductsScreenState
    extends ConsumerState<CategoryProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<api.Product> _filter(List<api.Product> all) {
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.sku.toLowerCase().contains(q);
    }).toList();
  }

  int _inStockCount(List<api.Product> list) =>
      list.where((p) => p.stock > 10).length;

  int _lowStockCount(List<api.Product> list) =>
      list.where((p) => p.stock > 0 && p.stock <= 10).length;

  Future<void> _navigateToAddProduct() async {
    final role = effectiveUserRole(ref.read(authProvider).user);
    if (role != 'admin' && role != 'super_admin' && role != 'inventory_manager') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 120, left: 16, right: 16),
          content: Text('Only admin can add products.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    await context.push(
      '/inventory/${widget.category.id}/add-product',
      extra: widget.category,
    );
    if (mounted) {
      ref.invalidate(categoryProductsProvider(widget.category.name));
    }
  }

  Future<void> _deleteProduct(api.Product product) async {
    final role = effectiveUserRole(ref.read(authProvider).user);
    if (role == 'seo_manager') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 120, left: 16, right: 16),
          content: Text('SEO Manager cannot delete products.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    try {
      await ref.read(productRepositoryProvider).deleteProduct(product.id);
      if (mounted) {
        ref.invalidate(categoryProductsProvider(widget.category.name));
        ref.invalidate(productsProvider);
        invalidateAllDashboardProviders(ref);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
            content: Text('${product.name} removed'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException
            ? (e.statusCode == 403
                ? 'No permission to delete products (inventory role required).'
                : e.message)
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
            content: Text(msg),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _editProduct(api.Product product) async {
    final role = effectiveUserRole(ref.read(authProvider).user);
    final isSeoManager = role == 'seo_manager';

    final nameCtrl = TextEditingController(text: product.name);
    final descCtrl = TextEditingController(text: product.description ?? '');
    final priceCtrl = TextEditingController(text: product.price.toString());
    final stockCtrl = TextEditingController(text: product.stock.toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Update Product',
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'SKU: ${product.sku}',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Product Title',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: AppColors.backgroundSecondary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descCtrl,
                  maxLines: 4,
                  minLines: 3,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: AppColors.backgroundSecondary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                if (!isSeoManager) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Price',
                            prefixText: '\$ ',
                            labelStyle: const TextStyle(color: AppColors.textSecondary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: AppColors.cardBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.primary, width: 2),
                            ),
                            filled: true,
                            fillColor: AppColors.backgroundSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: stockCtrl,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Stock',
                            labelStyle: const TextStyle(color: AppColors.textSecondary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: AppColors.cardBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.primary, width: 2),
                            ),
                            filled: true,
                            fillColor: AppColors.backgroundSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTypography.titleSmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (ok != true || !mounted) return;

    try {
      if (isSeoManager) {
        await ref.read(productRepositoryProvider).updateProduct(
              id: product.id,
              name: nameCtrl.text.trim(),
              description: descCtrl.text.trim(),
            );
      } else {
        final price = double.tryParse(priceCtrl.text.trim());
        final stock = int.tryParse(stockCtrl.text.trim());
        await ref.read(productRepositoryProvider).updateProduct(
              id: product.id,
              name: nameCtrl.text.trim(),
              description: descCtrl.text.trim(),
              price: price,
              stock: stock,
            );
      }
      ref.invalidate(categoryProductsProvider(widget.category.name));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: 120, left: 16, right: 16),
            content: Text('Product updated'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
            content: Text('Update failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      nameCtrl.dispose();
      descCtrl.dispose();
      priceCtrl.dispose();
      stockCtrl.dispose();
    }
  }

  Future<void> _toggleActive(api.Product product) async {
    try {
      final newStatus = !product.isActive;
      await ref.read(productRepositoryProvider).updateProduct(
            id: product.id,
            isActive: newStatus,
          );
      if (mounted) {
        ref.invalidate(categoryProductsProvider(widget.category.name));
        ref.invalidate(productsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
            content: Text(newStatus
                ? '${product.name} activated'
                : '${product.name} deactivated'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
            content: Text('Failed to update status: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showProductMenu(BuildContext context, api.Product product) {
    final role = effectiveUserRole(ref.read(authProvider).user);
    final canDelete = role == 'admin' || role == 'super_admin' || role == 'inventory_manager';
    final isSeoManager = role == 'seo_manager';
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (canDelete) ...[
              ListTile(
                leading: Icon(
                  product.isActive
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_rounded,
                  color:
                      product.isActive ? AppColors.success : AppColors.textSecondary,
                  size: 28,
                ),
                title: Text(product.isActive
                    ? 'Active (Tap to Deactivate)'
                    : 'Inactive (Tap to Activate)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleActive(product);
                },
              ),
            ],
            if (canDelete || isSeoManager) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(ctx);
                  _editProduct(product);
                },
              ),
            ],
            if (canDelete) ...[
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Delete',
                    style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog<void>(
                    context: context,
                    builder: (dctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      title: const Text('Delete product?'),
                      content:
                          Text('Remove "${product.name}" from the store?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dctx),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(dctx);
                            _deleteProduct(product);
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            if (!canDelete && !isSeoManager) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('You do not have permission to modify this product.', style: AppTypography.bodyMedium),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = effectiveUserRole(ref.watch(authProvider).user);
    final canAccessInventory = canAccessInventoryManagement(role);
    final canAddProduct = role == 'admin' || role == 'super_admin' || role == 'inventory_manager';
    final canManageProduct = canAddProduct || role == 'seo_manager';
    final async = ref.watch(categoryProductsProvider(widget.category.name));

    if (!canAccessInventory) {
      return RoleAccessDeniedView(onGoHome: () => context.go('/dashboard'));
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    final isDesktop = screenWidth >= 900;

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        centerTitle: false,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/inventory');
            }
          },
        ),
        title: Text(
          widget.category.name,
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        actions: [
          if (canAddProduct)
            Padding(
              padding: EdgeInsets.only(right: isPhone ? 8 : 16),
              child: isPhone
                  // On small phones: icon-only circular button
                  ? IconButton(
                      onPressed: _navigateToAddProduct,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 20),
                      ),
                    )
                  // On tablets/desktops: full button with label
                  : ElevatedButton.icon(
                      onPressed: _navigateToAddProduct,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: Text(isTablet ? 'Add' : 'Add Product'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 14 : 18,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 64, color: AppColors.error.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  'Failed to load products',
                  style: AppTypography.titleMedium
                      .copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        data: (all) {
          final filtered = _filter(all);
          // Grid columns based on screen size
          final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 1);
          final useGrid = !isPhone; // phones use list, tablets/desktops use grid

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(categoryProductsProvider(widget.category.name));
              await ref.read(
                categoryProductsProvider(widget.category.name).future,
              );
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                // ── SEARCH BAR ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isPhone ? 16 : 24,
                      16,
                      isPhone ? 16 : 24,
                      8,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: AppColors.cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) =>
                            setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          hintStyle: AppTypography.bodyMedium
                              .copyWith(color: AppColors.textTertiary),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.textSecondary,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── SUMMARY CARDS ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isPhone ? 16 : 24,
                      vertical: 8,
                    ),
                    child: _buildSummaryRow(all, isPhone),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // ── PRODUCTS: LIST (phone) or GRID (tablet/desktop) ──
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    child: _buildEmptyState(),
                  )
                else if (useGrid)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isPhone ? 16 : 24,
                      vertical: 8,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: isDesktop ? 0.75 : 0.78,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _ProductGridCard(
                          product: filtered[index],
                          showMenu: canManageProduct, // same logic as canManage
                          onTap: () => _showProductMenu(
                              context, filtered[index]),
                          onMenuTap: () =>
                              _showProductMenu(context, filtered[index]),
                        ),
                        childCount: filtered.length,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _ProductCard(
                          product: filtered[index],
                          showMenu: canManageProduct,
                          onTap: () => ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.only(
                                  bottom: 120, left: 16, right: 16),
                              content: Text(
                                '${filtered[index].name} · SKU ${filtered[index].sku}',
                              ),
                            ),
                          ),
                          onMenuTap: () =>
                              _showProductMenu(context, filtered[index]),
                        ),
                        childCount: filtered.length,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(List<api.Product> all, bool isPhone) {
    final cards = [
      _SummaryCard(
        title: 'Total',
        value: all.length.toString(),
        icon: Icons.inventory_2_outlined,
        color: AppColors.primary,
      ),
      _SummaryCard(
        title: 'In Stock',
        subtitle: '>10 units',
        value: _inStockCount(all).toString(),
        icon: Icons.check_circle_outline,
        color: AppColors.success,
      ),
      _SummaryCard(
        title: 'Low Stock',
        value: _lowStockCount(all).toString(),
        icon: Icons.warning_outlined,
        color: AppColors.warning,
      ),
    ];

    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i < cards.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 72,
              color: AppColors.primary.withOpacity(0.2)),
          const SizedBox(height: 20),
          Text(
            'No products found',
            style: AppTypography.titleMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ── Summary Card ─────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontSize: 18,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
                fontSize: 9,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Product List Card (Phone) ─────────────────────────────────
class _ProductCard extends StatelessWidget {
  final api.Product product;
  final bool showMenu;
  final VoidCallback onTap;
  final VoidCallback onMenuTap;

  const _ProductCard({
    required this.product,
    this.showMenu = true,
    required this.onTap,
    required this.onMenuTap,
  });

  Color _statusColor() {
    if (product.stock > 10) return AppColors.success;
    if (product.stock > 0) return AppColors.warning;
    return AppColors.error;
  }

  String _statusText() {
    if (product.stock > 10) return 'In Stock';
    if (product.stock > 0) return 'Low Stock';
    return 'Out of Stock';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final statusText = _statusText();
    final thumbSize = MediaQuery.of(context).size.width < 380 ? 64.0 : 80.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: thumbSize,
                    height: thumbSize,
                    child: ProductThumbnail(
                      imageUrl: product.imageUrl,
                      size: thumbSize,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        product.sku,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '₹${product.price.toStringAsFixed(2)}',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const Spacer(),
                          // Stock badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusText,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${product.stock} units',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Menu button
                if (showMenu)
                  GestureDetector(
                    onTap: onMenuTap,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 34), // Maintain spacing if hidden
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Product Grid Card (Tablet / Desktop) ─────────────────────
class _ProductGridCard extends StatelessWidget {
  final api.Product product;
  final bool showMenu;
  final VoidCallback onTap;
  final VoidCallback onMenuTap;

  const _ProductGridCard({
    required this.product,
    this.showMenu = true,
    required this.onTap,
    required this.onMenuTap,
  });

  Color _statusColor() {
    if (product.stock > 10) return AppColors.success;
    if (product.stock > 0) return AppColors.warning;
    return AppColors.error;
  }

  String _statusText() {
    if (product.stock > 10) return 'In Stock';
    if (product.stock > 0) return 'Low Stock';
    return 'Out of Stock';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final statusText = _statusText();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            Expanded(
              flex: 10,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: AppColors.backgroundSecondary,
                      child: ProductThumbnail(
                        imageUrl: product.imageUrl,
                        size: double.infinity,
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    // Price badge
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          '₹${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    // Menu button
                    if (showMenu)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: onMenuTap,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.more_vert_rounded,
                                size: 16, color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Info area
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '$statusText · ${product.stock}u',
                            style: AppTypography.bodySmall.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
