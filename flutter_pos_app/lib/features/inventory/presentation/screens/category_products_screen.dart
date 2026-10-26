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
import '../../providers/category_providers.dart';
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
  bool _isSnackBarActive = false;

  void _showLocalSnackBar(SnackBar snackBar) {
    if (!mounted) return;
    setState(() => _isSnackBarActive = true);
    ScaffoldMessenger.of(context).showSnackBar(snackBar).closed.then((_) {
      if (mounted) setState(() => _isSnackBarActive = false);
    });
  }

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
        const SnackBar(duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 120, left: 16, right: 16),
          content: Text('Only admin can add products.'),
          backgroundColor: AppColors.secondary,
        ),
      );
      return;
    }
    final result = await context.push(
      '/inventory/${widget.category.id}/add-product',
      extra: widget.category,
    );
    if (mounted) {
      ref.invalidate(categoryProductsProvider(widget.category.name.trim()));
      ref.invalidate(productsProvider);
      ref.invalidate(categoriesProvider);
      ref.read(categoryProductsProvider(widget.category.name.trim()).future).ignore();
      if (result != null) {
        _showLocalSnackBar(
          const SnackBar(duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: 120, left: 16, right: 16),
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Product saved successfully!', style: TextStyle(color: Colors.white)),
              ],
            ),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    }
  }

  Future<void> _deleteProduct(api.Product product) async {
    final role = effectiveUserRole(ref.read(authProvider).user);
    if (role == 'seo_manager') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 120, left: 16, right: 16),
          content: Text('SEO Manager cannot delete products.'),
          backgroundColor: AppColors.secondary,
        ),
      );
      return;
    }
    try {
      await ref.read(productRepositoryProvider).deleteProduct(product.id);
      if (mounted) {
        ref.invalidate(categoryProductsProvider(widget.category.name.trim()));
        ref.invalidate(productsProvider);
        ref.invalidate(categoriesProvider);
        ref.read(categoryProductsProvider(widget.category.name.trim()).future).ignore();
        invalidateAllDashboardProviders(ref);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
            content: Text('${product.name} removed'),
            backgroundColor: AppColors.secondary,
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
          SnackBar(duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
            content: Text(msg),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    }
  }

  Future<void> _editProduct(api.Product product) async {
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
                    fontWeight: FontWeight.w600,
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
                          prefixText: '₹ ',
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
                          style: AppTypography.titleSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w400),
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
                        child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
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
      final price = double.tryParse(priceCtrl.text.trim());
      final stock = int.tryParse(stockCtrl.text.trim());
      await ref.read(productRepositoryProvider).updateProduct(
            id: product.id,
            name: nameCtrl.text.trim(),
            description: descCtrl.text.trim(),
            price: price,
            stock: stock,
          );
      ref.invalidate(categoryProductsProvider(widget.category.name.trim()));
      ref.invalidate(productsProvider);
      ref.invalidate(categoriesProvider);
      ref.read(categoryProductsProvider(widget.category.name.trim()).future).ignore();
      if (mounted) {
        _showLocalSnackBar(
          const SnackBar(
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: 120, left: 16, right: 16),
            content: Text('Product updated successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
            content: Text('Update failed: $e'),
            backgroundColor: AppColors.secondary,
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
        ref.invalidate(categoryProductsProvider(widget.category.name.trim()));
        ref.invalidate(productsProvider);
        ref.invalidate(categoriesProvider);
        ref.read(categoryProductsProvider(widget.category.name.trim()).future).ignore();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
            content: Text(newStatus
                ? '${product.name} activated'
                : '${product.name} deactivated'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
            content: Text('Failed to update status: $e'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    }
  }

  Future<void> _handleEditProduct(api.Product product) async {
    final role = effectiveUserRole(ref.read(authProvider).user);
    final isSeo = role == 'seo_manager' || role == 'seo' || role == 'seo_executive';

    if (isSeo) {
      await _editProduct(product);
    } else {
      final result = await context.push(
        '/inventory/${widget.category.id}/add-product',
        extra: {
          'category': widget.category,
          'editProduct': product,
        },
      );
      if (mounted) {
        ref.invalidate(categoryProductsProvider(widget.category.name.trim()));
        ref.invalidate(productsProvider);
        ref.invalidate(categoriesProvider);
        ref.read(categoryProductsProvider(widget.category.name.trim()).future).ignore();
        if (result != null) {
          _showLocalSnackBar(
            const SnackBar(
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(bottom: 120, left: 16, right: 16),
              content: Text('Product updated successfully!'),
            ),
          );
        }
      }
    }
  }

  void _showProductMenu(BuildContext context, api.Product product) {
    final role = effectiveUserRole(ref.read(authProvider).user);
    final canDelete = role == 'admin' || role == 'super_admin' || role == 'inventory_manager';
    final isSeo = role == 'seo_manager' || role == 'seo' || role == 'seo_executive';
    final canEdit = canDelete || isSeo;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (canDelete) ...[
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    leading: Icon(
                      product.isActive
                          ? Icons.toggle_on_rounded
                          : Icons.toggle_off_rounded,
                      color:
                          product.isActive ? const Color(0xFF10B981) : AppColors.textSecondary,
                      size: 26,
                    ),
                    title: Text(
                      product.isActive
                          ? 'Active (Tap to Deactivate)'
                          : 'Inactive (Tap to Activate)',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _toggleActive(product);
                    },
                  ),
                ],
                if (canEdit) ...[
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    leading: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textPrimary),
                    title: const Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _handleEditProduct(product);
                    },
                  ),
                ],
                if (canDelete) ...[
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    leading: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                    title: const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.error,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      showDialog<void>(
                        context: context,
                        builder: (dctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          title: const Text(
                            'Delete product?',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          content: Text(
                            'Remove "${product.name}" from the store?',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dctx),
                              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w400)),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.error,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                Navigator.pop(dctx);
                                _deleteProduct(product);
                              },
                              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                if (!canDelete && !isSeo) ...[
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'You do not have permission to modify this product.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
              ],
            ),
          ),
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
    final async = ref.watch(categoryProductsProvider(widget.category.name.trim()));

    if (!canAccessInventory) {
      return RoleAccessDeniedView(onGoHome: () => context.go('/dashboard'));
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    final isDesktop = screenWidth >= 900;

    return PopScope(
      canPop: !_isSnackBarActive,
      child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go('/inventory');
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundTertiary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.category.name,
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Enterprise Stock • Real-time Sync',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w400,
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
                  if (canAddProduct) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _navigateToAddProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        'Add Product',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
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
              ref.invalidate(categoryProductsProvider(widget.category.name.trim()));
              ref.invalidate(productsProvider);
              ref.invalidate(categoriesProvider);
              await ref.read(
                categoryProductsProvider(widget.category.name.trim()).future,
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
                            SnackBar(duration: const Duration(seconds: 2),
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

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            Expanded(child: cards[i]),
            if (i < cards.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 42,
              color: AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No products found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try adjusting your search',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary Card ─────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
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

  Widget _buildMarketplacePill(String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
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
                          fontWeight: FontWeight.w500,
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
                              fontWeight: FontWeight.w600,
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
                                    fontWeight: FontWeight.w500,
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
                      if (product.marketplaces.isNotEmpty || product.isFlipkartSynced) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (product.isFlipkartActive)
                              _buildMarketplacePill('Flipkart', const Color(0xFF2874F0)),
                            if (product.isMeeshoActive)
                              _buildMarketplacePill('Meesho', const Color(0xFFE81B63)),
                            if (product.isShopifyActive)
                              _buildMarketplacePill('Shopify', const Color(0xFF008060)),
                            if (product.isZomatoActive)
                              _buildMarketplacePill('Zomato', const Color(0xFFCB202D)),
                            if (product.isSwiggyActive)
                              _buildMarketplacePill('Swiggy', const Color(0xFFFC8019)),
                            if (product.isEatClubActive)
                              _buildMarketplacePill('Eat Club', Colors.deepOrange),
                            if (product.isWooCommerceActive)
                              _buildMarketplacePill('WooCommerce', const Color(0xFF7F54B3)),
                          ],
                        ),
                      ],
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
                            fontWeight: FontWeight.w600,
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
                        fontWeight: FontWeight.w500,
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
