import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/features/auth/providers/auth_provider.dart';
import 'package:retail_verse_pos/features/inventory/data/models/category_entity.dart';
import 'package:retail_verse_pos/features/inventory/data/local/category_local_service.dart';
import 'package:retail_verse_pos/features/inventory/providers/category_providers.dart';
import 'package:retail_verse_pos/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:retail_verse_pos/routes/app_router.dart';
import 'package:retail_verse_pos/core/navigation/role_nav.dart';

import 'package:retail_verse_pos/features/inventory/data/models/category.dart' as inv;

inv.Category _entityToNavCategory(CategoryEntity e) {
  return inv.Category(
    id: e.id,
    name: e.name,
    subtitle: e.subtitle,
    imagePath: e.imagePath,
    productCount: e.productCount,
  );
}

class InventoryCategoriesScreen extends ConsumerStatefulWidget {
  const InventoryCategoriesScreen({super.key});

  @override
  ConsumerState<InventoryCategoriesScreen> createState() => _InventoryCategoriesScreenState();
}

class _InventoryCategoriesScreenState extends ConsumerState<InventoryCategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final role = effectiveUserRole(user);
    final canManage = role == 'admin' || role == 'super_admin' || role == 'inventory_manager';

    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── PREMIUM APP BAR HEADER ──────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 20, 24, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const ResponsiveMenuButton(),
                        const SizedBox(width: 12),
                        Text(
                          'Inventory',
                          style: AppTypography.headlineMedium.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 22),
                        ),
                        if (canManage) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () async {
                              await context.push('/inventory/categories/add');
                              if (mounted) setState(() {});
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 24),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder.withOpacity(0.8)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    style: AppTypography.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Search categories...',
                      hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ref.watch(categoriesProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) {
                final errStr = err.toString();
                final cleanErr = errStr.contains('SocketException') || errStr.contains('Connection') || errStr.contains('Failed host lookup')
                    ? 'You are offline. Please check your internet connection.'
                    : (errStr.contains('ApiException:') ? errStr.split('ApiException:').last.trim() : errStr);
                return Center(child: Text('Error: $cleanErr'));
              },
              data: (list) {
                final filtered = list.where((c) => c.name.toLowerCase().contains(_query.toLowerCase())).toList();

                if (filtered.isEmpty) return _buildEmptyState();

                return Column(
                  children: [
                    _buildStatsSummary(list),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(categoriesProvider);
                          // wait for a short duration to show the loader
                          await Future.delayed(const Duration(milliseconds: 500));
                        },
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.9,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) => _buildCategoryCard(filtered[index], canManage),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildStatsSummary(List<CategoryEntity> list) {
    final totalProducts = list.fold(0, (sum, c) => sum + c.productCount);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _buildSmallStat('Categories', list.length.toString(), Icons.folder_open_rounded),
          const SizedBox(width: 12),
          _buildSmallStat('Total Items', totalProducts.toString(), Icons.inventory_2_outlined),
        ],
      ),
    );
  }

  Widget _buildSmallStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              '$value $label',
              style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(CategoryEntity category, bool canManage) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
        border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/inventory/${category.id}', extra: _entityToNavCategory(category)),
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.category_rounded, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      category.name,
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w900),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${category.productCount} Items',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (canManage)
                Positioned(
                  top: 4,
                  right: 4,
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: AppColors.textTertiary, size: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onSelected: (v) {
                      if (v == 'edit') {
                        _showEditCategoryDialog(category);
                      } else if (v == 'delete') {
                        _showDeleteConfirmDialog(category);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                            SizedBox(width: 12),
                            Text('Edit Category'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                            SizedBox(width: 12),
                            Text('Delete Category', style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 20,
                )
              ],
            ),
            child: Icon(Icons.category_outlined, size: 64, color: AppColors.primary.withOpacity(0.4)),
          ),
          const SizedBox(height: 24),
          Text(
            'No categories found',
            style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching for a different category',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(CategoryEntity category) {
    final nameC = TextEditingController(text: category.name);
    final subC = TextEditingController(text: category.subtitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Edit Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: const InputDecoration(labelText: 'Category Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: subC,
              decoration: const InputDecoration(labelText: 'Subtitle / Description'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameC.text.trim().isEmpty) return;
              await ref.read(categoryRepositoryProvider).updateCategory(
                category.copyWith(name: nameC.text.trim(), subtitle: subC.text.trim()),
              );
              ref.invalidate(categoriesProvider);
              if (mounted) {
                Navigator.pop(ctx);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Category updated successfully'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(CategoryEntity category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await ref.read(categoryRepositoryProvider).deleteCategory(category.id);
              ref.invalidate(categoriesProvider);
              if (mounted) {
                Navigator.pop(ctx);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Category deleted successfully'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
