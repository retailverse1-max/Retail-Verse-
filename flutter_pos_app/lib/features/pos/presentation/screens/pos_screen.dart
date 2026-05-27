import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:retail_verse_pos/routes/app_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/core/utils/formatters.dart';
import 'package:retail_verse_pos/core/widgets/product_media_image.dart';
import 'package:retail_verse_pos/data/models/product_model.dart';
import 'package:retail_verse_pos/data/models/cart_model.dart';
import 'package:retail_verse_pos/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:retail_verse_pos/features/pos/providers/cart_provider.dart';
import 'package:retail_verse_pos/features/pos/providers/product_providers.dart';
import 'package:retail_verse_pos/features/notifications/providers/notification_provider.dart';
import 'package:retail_verse_pos/core/widgets/common/bounceable.dart';

class POSScreen extends ConsumerStatefulWidget {
  const POSScreen({super.key});

  @override
  ConsumerState<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends ConsumerState<POSScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _posScaffoldKey = GlobalKey<ScaffoldState>();
  String selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  late AnimationController _rotationController;
  bool isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();
    setState(() => isRefreshing = true);
    _rotationController.repeat();

    try {
      await Future.wait([
        ref.refresh(productsProvider.future),
        ref.refresh(posCategoriesProvider.future),
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inventory refreshed successfully'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        _rotationController.stop();
        _rotationController.reset();
        setState(() => isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final count = cart.itemCount;
    final totalValue = cart.total;
    final isTablet = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      key: _posScaffoldKey,
      backgroundColor: Colors.transparent,
      endDrawer: !isTablet ? Drawer(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Container(
          color: Colors.white,
          child: SafeArea(
            child: _buildCartSidebar(cart, totalValue, count),
          ),
        ),
      ) : null,
      body: Stack(
        children: [
          Container(
            color: const Color(0xFFF8F9FB),
            child: Row(
              children: [
                // ── MAIN CONTENT (MENU & PRODUCTS) ──────────────────
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER WITH MENU ICON
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 40, 16, 4),
                        child: Row(
                          children: [
                            const ResponsiveMenuButton(),
                            if (isTablet) ...[
                              const SizedBox(width: 16),
                              Text(
                                'POS',
                                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildInlineSearchBar(),
                            ),
                            const SizedBox(width: 8),
                            Bounceable(
                              onTap: () {
                                if (!isRefreshing) {
                                  _handleRefresh();
                                }
                              },
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: isRefreshing ? 0.6 : 1.0,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.cardBorder),
                                  ),
                                  child: RotationTransition(
                                    turns: _rotationController,
                                    child: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.textPrimary),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Bounceable(
                              onTap: () => _posScaffoldKey.currentState?.openEndDrawer(),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.cardBorder),
                                    ),
                                    child: const Icon(
                                      Icons.shopping_cart_outlined,
                                      size: 20,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (count > 0)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$count',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // CATEGORIES
                      _buildModernCategoryBar(),
                      const SizedBox(height: 16),

                      // PRODUCT GRID
                      Expanded(
                        child: _buildProductList(context, isTablet),
                      ),
                    ],
                  ),
                ),

                // ── CART SIDEBAR (CURRENT ORDER) ──────────────────
                if (isTablet)
                  Container(
                    width: 320,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(left: BorderSide(color: AppColors.cardBorder.withOpacity(0.5))),
                    ),
                    child: _buildCartSidebar(cart, totalValue, count),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildInlineSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search...',
          hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('grocer') || name.contains('food') || name.contains('eat') || name.contains('veg') || name.contains('shopping')) {
      return Icons.shopping_basket_rounded;
    }
    if (name.contains('sport') || name.contains('gym') || name.contains('fit') || name.contains('ball')) {
      return Icons.sports_basketball_rounded;
    }
    if (name.contains('elect') || name.contains('tech') || name.contains('phone') || name.contains('comp') || name.contains('device')) {
      return Icons.electrical_services_rounded;
    }
    if (name.contains('cloth') || name.contains('wear') || name.contains('shirt') || name.contains('pant') || name.contains('jean')) {
      return Icons.checkroom_rounded;
    }
    if (name.contains('toy') || name.contains('game')) {
      return Icons.toys_rounded;
    }
    if (name.contains('book') || name.contains('read') || name.contains('write')) {
      return Icons.book_rounded;
    }
    if (name.contains('home') || name.contains('furni') || name.contains('deco')) {
      return Icons.home_rounded;
    }
    return Icons.category_rounded;
  }

  Widget _buildShimmerCategoryBar(bool isAllSelected) {
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Row(
        children: [
          // ── FIXED "ALL" BUTTON ──
          Bounceable(
            onTap: () => setState(() => selectedCategory = 'All'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isAllSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isAllSelected ? AppColors.primary : AppColors.cardBorder,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.grid_view_rounded,
                    size: 16,
                    color: isAllSelected ? Colors.white : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'All',
                    style: AppTypography.labelLarge.copyWith(
                      color: isAllSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // ── PLACEHOLDERS ──
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: List.generate(3, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Container(
                      width: 80 + (index * 15.0),
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernCategoryBar() {
    final categoriesAsync = ref.watch(posCategoriesProvider);
    final isAllSelected = selectedCategory == 'All';

    return categoriesAsync.when(
      data: (categoriesList) {
        final otherCategories = categoriesList.map((c) {
          return {
            'name': c.name,
            'icon': _getCategoryIcon(c.name),
          };
        }).toList();

        return Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Row(
            children: [
              // ── FIXED "ALL" BUTTON ──
              Bounceable(
                onTap: () => setState(() => selectedCategory = 'All'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isAllSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isAllSelected ? AppColors.primary : AppColors.cardBorder,
                      width: 1.5,
                    ),
                    boxShadow: isAllSelected ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ] : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.grid_view_rounded,
                        size: 16,
                        color: isAllSelected ? Colors.white : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'All',
                        style: AppTypography.labelLarge.copyWith(
                          color: isAllSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // ── SCROLLABLE OTHER CATEGORIES ──
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 24),
                  child: Row(
                    children: otherCategories.map((cat) {
                      final isSelected = selectedCategory == cat['name'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Bounceable(
                          onTap: () => setState(() => selectedCategory = cat['name'] as String),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.cardBorder,
                                width: 1.5,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ] : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cat['icon'] as IconData,
                                  size: 16,
                                  color: isSelected ? Colors.white : AppColors.textTertiary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  cat['name'] as String,
                                  style: AppTypography.labelLarge.copyWith(
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => _buildShimmerCategoryBar(isAllSelected),
      error: (err, stack) => _buildShimmerCategoryBar(isAllSelected),
    );
  }

  Widget _buildProductList(BuildContext context, bool isTablet) {
    final productsAsync = ref.watch(productsProvider);
    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (products) {
        final filter = GoRouterState.of(context).uri.queryParameters['filter'];
        
        final filtered = products.where((p) {
          if (!p.isActive) return false;
          final matchesSearch = p.name.toLowerCase().contains(searchQuery.toLowerCase());
          final matchesCat = selectedCategory == 'All Menu' || selectedCategory == 'All' || p.category == selectedCategory;
          
          bool matchesFilter = true;
          if (filter == 'low_stock') {
             matchesFilter = p.stock <= p.reorderLevel;
          } else if (filter == 'best_sellers') {
             matchesFilter = p.price > 100;
          }
          
          return matchesSearch && matchesCat && matchesFilter;
        }).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            // Responsive grid: 1 col per ~180px of available width.
            // Caps at min 2, so wide screens get more columns automatically.
            final availableW = constraints.maxWidth;
            final crossCount = (availableW / 180).floor().clamp(2, 6);
            final spacing = availableW > 600 ? 20.0 : 12.0;
            final padding = availableW > 600 ? 24.0 : 12.0;
            // Aspect ratio: image takes ~55% of height, info 45%
            const aspectRatio = 0.75;

            return GridView.builder(
              padding: EdgeInsets.all(padding),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: aspectRatio,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) => _buildUltraPremiumCard(filtered[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildUltraPremiumCard(Product product) {
    final cart = ref.watch(cartProvider);
    final cartItem = cart.items.where((i) => i.product.id == product.id).firstOrNull;
    final inCartQuantity = cartItem?.quantity ?? 0;
    final isOutOfStock = product.stock <= inCartQuantity;

    return Bounceable(
      onTap: () => context.push('/pos/product', extra: product),
      child: Opacity(
        opacity: isOutOfStock ? 0.6 : 1.0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Adapt all sizes to the card's actual rendered width
            final w = constraints.maxWidth;
            final isNarrow = w < 140;
            final isMedium = w >= 140 && w < 190;

            // Responsive values
            final borderR = isNarrow ? 18.0 : 24.0;
            final infoPad = isNarrow ? 8.0 : (isMedium ? 10.0 : 14.0);
            final catSize = isNarrow ? 7.0 : 8.0;
            final nameSize = isNarrow ? 11.0 : (isMedium ? 12.5 : 14.0);
            final stockLabelSize = isNarrow ? 6.0 : 7.0;
            final stockValueSize = isNarrow ? 9.0 : 10.0;
            final btnPad = isNarrow ? 6.0 : (isMedium ? 7.0 : 9.0);
            final btnIconSize = isNarrow ? 14.0 : (isMedium ? 16.0 : 18.0);
            final pricePadH = isNarrow ? 6.0 : 10.0;
            final pricePadV = isNarrow ? 4.0 : 6.0;
            final priceSize = isNarrow ? 10.0 : 12.0;
            final gapAfterCat = isNarrow ? 2.0 : 4.0;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(borderR),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderR),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── IMAGE HEADER (FULL BLEED) ──
                    Expanded(
                      flex: 55,
                      child: Container(
                        width: double.infinity,
                        color: const Color(0xFFF1F5F9),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ProductMediaImage(
                              imageUrl: product.imageUrl,
                              fit: BoxFit.cover,
                            ),
                            if (isOutOfStock)
                              Container(
                                color: Colors.black12,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'OUT OF STOCK',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: isNarrow ? 8.0 : 10.0,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Floating Price Badge
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: pricePadH, vertical: pricePadV),
                                decoration: BoxDecoration(
                                  color: isOutOfStock ? Colors.grey[400] : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)],
                                ),
                                child: Text(
                                  AppFormatters.formatCurrency(product.price),
                                  style: TextStyle(
                                    color: const Color(0xFF1E293B),
                                    fontWeight: FontWeight.w900,
                                    fontSize: priceSize,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── INFO & ACTION SECTION ──
                    Expanded(
                      flex: 45,
                      child: Padding(
                        padding: EdgeInsets.all(infoPad),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Category + Name
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.category.toUpperCase(),
                                  style: TextStyle(
                                    color: isOutOfStock ? Colors.grey : AppColors.primary.withOpacity(0.8),
                                    fontSize: catSize,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                ),
                                SizedBox(height: gapAfterCat),
                                Text(
                                  product.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                    fontSize: nameSize,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),

                            // Stock + Add button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'STOCK',
                                        style: TextStyle(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: stockLabelSize,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${product.stock - inCartQuantity} left',
                                        style: TextStyle(
                                          color: isOutOfStock ? Colors.red : const Color(0xFF64748B),
                                          fontSize: stockValueSize,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Bounceable(
                                  onTap: () {
                                    if (isOutOfStock) {
                                      ref.read(notificationProvider.notifier).requestRestock(product.id, product.name).then((success) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(success
                                                  ? 'Manager notified about ${product.name} stock.'
                                                  : 'Failed to notify manager.'),
                                              backgroundColor: success ? AppColors.primary : AppColors.error,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      });
                                    } else {
                                      ref.read(cartProvider.notifier).addItem(product);
                                      final isTabletW = MediaQuery.of(context).size.width >= 900;
                                      if (!isTabletW) {
                                        _posScaffoldKey.currentState?.openEndDrawer();
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(btnPad),
                                    decoration: BoxDecoration(
                                      color: isOutOfStock ? Colors.amber : AppColors.primary,
                                      borderRadius: BorderRadius.circular(isNarrow ? 8.0 : 10.0),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isOutOfStock ? Colors.amber : AppColors.primary).withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        )
                                      ],
                                    ),
                                    child: Icon(
                                      isOutOfStock ? Icons.notifications_active_rounded : Icons.add_rounded,
                                      color: isOutOfStock ? Colors.black : Colors.white,
                                      size: btnIconSize,
                                    ),
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
          },
        ),
      ),
    );
  }

  Widget _buildCartSidebar(CartState cart, double total, int count) {
    return Column(
      children: [
        // 1. FIXED SIDEBAR HEADER
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Current Order', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900, fontSize: 18)),
              IconButton(
                onPressed: () => ref.read(cartProvider.notifier).clearCart(),
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        // 2. SCROLLABLE PRODUCT LIST
        Expanded(
          child: Column(
            children: [
              // THE ACTUAL LIST
              Expanded(
                child: cart.items.isEmpty
                    ? _buildEmptySidebar()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: cart.items.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _buildSidebarCartItem(cart.items[index]),
                      ),
              ),
            ],
          ),
        ),

        // 3. FIXED TOTALS & PLACE ORDER CARD
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            border: Border(top: BorderSide(color: AppColors.cardBorder.withOpacity(0.5))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSummaryRow('Sub Total', AppFormatters.formatCurrency(cart.subtotal)),
              const SizedBox(height: 4),
              _buildSummaryRow('Tax (11%)', AppFormatters.formatCurrency(cart.taxAmount)),
              const Divider(height: 16),
              _buildSummaryRow('Total', AppFormatters.formatCurrency(cart.total), isTotal: true),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: cart.items.isEmpty ? null : () {
                    final isTablet = MediaQuery.of(context).size.width >= 900;
                    if (!isTablet) {
                      Navigator.of(context).pop(); // Close drawer
                    }
                    context.push('/pos/cart');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED), // Rich premium purple
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownMock(String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTypography.labelSmall),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarCartItem(CartItem item) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ProductMediaImage(imageUrl: item.product.imageUrl, fit: BoxFit.contain),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.product.name, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w900)),
              Text(AppFormatters.formatCurrency(item.product.price), style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
            ],
          ),
        ),
        Row(
          children: [
            _buildQtyBtn(Icons.remove, () => ref.read(cartProvider.notifier).updateQuantity(item.product.id, item.quantity - 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('${item.quantity}', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w900)),
            ),
            _buildQtyBtn(Icons.add, () => ref.read(cartProvider.notifier).updateQuantity(item.product.id, item.quantity + 1)),
          ],
        ),
      ],
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return Bounceable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: isTotal ? AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w900) : AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
        Text(value, style: isTotal ? AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900) : AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildEmptySidebar() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_basket_outlined, size: 48, color: AppColors.textTertiary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Your cart is empty', style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}
