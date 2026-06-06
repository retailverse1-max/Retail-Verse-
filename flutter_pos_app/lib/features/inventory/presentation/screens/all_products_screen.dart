import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/product_media_image.dart';
import '../../../../core/widgets/common/bounceable.dart';
import '../../../../data/models/product_model.dart';
import '../../../pos/providers/product_providers.dart';
import '../../../../core/navigation/role_nav.dart';
import '../../../auth/providers/auth_provider.dart';
import 'package:retail_verse_pos/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:retail_verse_pos/routes/app_router.dart';

class AllProductsScreen extends ConsumerStatefulWidget {
  const AllProductsScreen({super.key});

  @override
  ConsumerState<AllProductsScreen> createState() => _AllProductsScreenState();
}

class _AllProductsScreenState extends ConsumerState<AllProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    final isDesktop = screenWidth >= 900;
    final role = effectiveUserRole(ref.watch(authProvider).user);
    final canAddProduct = role == 'admin' || role == 'super_admin' || role == 'inventory_manager';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── PREMIUM APP BAR HEADER ──────────────────────
          _buildHeader(context, canAddProduct, isPhone, isTablet, isDesktop),

          // ── SCROLLABLE CONTENT ──────────────────
          Expanded(
              child: productsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) {
                  final errStr = e.toString();
                  final cleanErr = errStr.contains('SocketException') || errStr.contains('Connection') || errStr.contains('Failed host lookup')
                      ? 'You are offline. Please check your internet connection.'
                      : (errStr.contains('ApiException:') ? errStr.split('ApiException:').last.trim() : errStr);
                  return Center(
                    child: Text('Error: $cleanErr', style: const TextStyle(color: AppColors.error)),
                  );
                },
                data: (products) {
                  final filtered = products.where((p) {
                    final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        p.sku.toLowerCase().contains(_searchQuery.toLowerCase());
                    return matchesSearch;
                  }).toList();

                  // Stats calculation
                  final totalCount = products.length;
                  final outOfStockCount = products.where((p) => p.stock == 0).length;
                  // Heuristic for best sellers: products with price > 1000 or some other criteria
                  final bestSellersCount = products.where((p) => p.price > 1000 && p.stock > 0).length;

                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(productsProvider.future),
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // SUMMARY CARDS
                        SliverToBoxAdapter(
                          child: _buildSummarySection(
                            totalCount: totalCount,
                            bestSellersCount: bestSellersCount,
                            outOfStockCount: outOfStockCount,
                            isTablet: isTablet,
                          ),
                        ),

                        // PRODUCT GRID
                        if (filtered.isEmpty)
                          SliverFillRemaining(
                            child: _buildEmptyState(),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.only(
                              left: isDesktop ? 32 : (isTablet ? 24 : 16),
                              right: isDesktop ? 32 : (isTablet ? 24 : 16),
                              top: 16,
                              bottom: 100,
                            ),
                            sliver: SliverGrid(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isDesktop ? 4 : (isTablet ? 3 : 2),
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: isDesktop ? 0.72 : (isTablet ? 0.75 : (isPhone && screenWidth < 380 ? 0.62 : 0.68)),
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildProductCard(filtered[index]),
                                childCount: filtered.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildHeader(BuildContext context, bool canAddProduct, bool isPhone, bool isTablet, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isPhone ? 16 : 24,
        MediaQuery.of(context).padding.top + 16,
        isPhone ? 16 : 24,
        20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const ResponsiveMenuButton(),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Products',
                        style: AppTypography.headlineMedium.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Manage your store products',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
              if (canAddProduct)
                isPhone
                  // Small phone: icon only
                  ? IconButton(
                      onPressed: () => context.push('/inventory/categories/add'),
                      icon: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                      ),
                    )
                  // Tablet/Desktop: full button
                  : Bounceable(
                      onTap: () => context.push('/inventory/categories/add'),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 14 : 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              isTablet ? 'Add' : 'Add Product',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search by name or SKU...',
          hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildSummarySection({
    required int totalCount,
    required int bestSellersCount,
    required int outOfStockCount,
    required bool isTablet,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          _buildSummaryCard(
            'Total Products',
            totalCount.toString(),
            Icons.inventory_2_rounded,
            AppColors.primary,
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            'Best Sellers',
            bestSellersCount.toString(),
            Icons.auto_graph_rounded,
            AppColors.success,
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            'Out of Stock',
            outOfStockCount.toString(),
            Icons.block_rounded,
            AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final isOutOfStock = product.stock == 0;
    
    return Bounceable(
      onTap: () => context.push('/pos/product', extra: product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE
            Expanded(
              flex: 12,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: AppColors.backgroundSecondary,
                      child: ProductMediaImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (isOutOfStock)
                      Container(
                        color: Colors.black.withOpacity(0.4),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'OUT OF STOCK',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Price Tag
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          AppFormatters.formatCurrency(product.price),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // INFO
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.category.toUpperCase(),
                    style: TextStyle(
                      color: AppColors.primary.withOpacity(0.7),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'STOCK',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${product.stock} units',
                            style: TextStyle(
                              color: isOutOfStock ? AppColors.error : AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 16),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 60, color: AppColors.textTertiary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: AppTypography.titleMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search query',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
