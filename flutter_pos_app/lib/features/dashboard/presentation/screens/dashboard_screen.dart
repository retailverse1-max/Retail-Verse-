import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/core/widgets/product_media_image.dart';
import 'package:retail_verse_pos/data/models/dashboard_stats_model.dart';
import 'package:retail_verse_pos/features/super_admin/presentation/widgets/support_dialog.dart';
import 'package:retail_verse_pos/features/auth/providers/auth_provider.dart';
import '../../../pos/providers/product_providers.dart';
import '../../../notifications/providers/notification_provider.dart';
import '../../providers/dashboard_providers.dart';
import 'package:retail_verse_pos/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:retail_verse_pos/features/dashboard/presentation/widgets/trial_banner.dart';
import 'package:retail_verse_pos/core/widgets/common/bounceable.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final statsAsync = ref.watch(dashboardStatsProvider);
    final productsAsync = ref.watch(dashboardProductsProvider);
    final ordersAsync = ref.watch(dashboardOrdersProvider);

    final isInitialLoading = (statsAsync.isLoading && !statsAsync.hasValue) ||
                             (productsAsync.isLoading && !productsAsync.hasValue) ||
                             (ordersAsync.isLoading && !ordersAsync.hasValue);

    // Removed the full-screen blocking loader to allow the dashboard to open instantly
    // The individual UI components (stats, products, orders) already have their own loading states.

    final userName = user?['name'] ?? 'Admin';
    final stats = statsAsync.asData?.value ?? DashboardStatsModel.empty;
    final searchQuery = ref.watch(dashboardSearchQueryProvider);

    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;

    return PopScope(
      canPop: false,
      // Intercept back navigation. If there is a previous route, pop it; otherwise, show exit confirmation.
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Exit App', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
              content: Text('Do you want to leave the app?', style: AppTypography.bodyMedium),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(c).pop(false),
                  child: Text('No', style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.of(c).pop(true),
                  child: const Text('Yes'),
                ),
              ],
            ),
          );
          if (shouldExit == true) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(dashboardProductsProvider);
          ref.invalidate(dashboardOrdersProvider);
          ref.invalidate(dashboardLowStockProvider);
          try {
            await Future.wait([
              ref.read(dashboardStatsProvider.future),
              ref.read(dashboardProductsProvider.future),
              ref.read(dashboardOrdersProvider.future),
            ]);
          } catch (_) {}
        },
        child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── 1. PREMIUM HERO HEADER ─────────────────────
              SliverToBoxAdapter(
                child: PremiumHeroHeader(
                  userName: userName,
                  totalSales: stats.totalSales,
                  totalOrders: stats.totalOrders,
                ),
              ),

              // ── 2. SEARCH NOT FOUND UI ───────────────────────
              if (searchQuery != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 80, color: AppColors.textTertiary.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'No products found matching "$searchQuery"',
                          style: AppTypography.titleMedium.copyWith(color: AppColors.textTertiary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // ── 3. TRIAL BANNER ────────────────────────────
                if (user != null)
                  TrialBanner(user: user),

                // ── 4. TOP FEATURED PRODUCTS (HORIZONTAL) ─────
              productsAsync.when(
                data: (products) {
                  if (products.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                  
                  final featured = products.take(5).toList();
                  return SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                          child: (width < 600) 
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Featured Products', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900)),
                                      TextButton(
                                        onPressed: () => context.push('/pos'),
                                        child: Text('See All', style: AppTypography.labelLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        ActionChip(
                                          avatar: const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.error),
                                          label: const Text('Low Stock', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12)),
                                          backgroundColor: AppColors.error.withOpacity(0.08),
                                          side: BorderSide(color: AppColors.error.withOpacity(0.2)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          onPressed: () => context.push('/pos?filter=low_stock'),
                                        ),
                                        const SizedBox(width: 8),
                                        ActionChip(
                                          avatar: const Icon(Icons.trending_up_rounded, size: 16, color: AppColors.success),
                                          label: const Text('Best Sellers', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12)),
                                          backgroundColor: AppColors.success.withOpacity(0.08),
                                          side: BorderSide(color: AppColors.success.withOpacity(0.2)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          onPressed: () => context.push('/pos?filter=best_sellers'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Featured Products', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900)),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () => context.push('/pos?filter=low_stock'),
                                    icon: const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error),
                                    label: Text('Low Stock', style: AppTypography.labelSmall.copyWith(color: AppColors.error, fontWeight: FontWeight.bold)),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => context.push('/pos?filter=best_sellers'),
                                    icon: const Icon(Icons.trending_up_rounded, size: 14, color: AppColors.success),
                                    label: Text('Best Sellers', style: AppTypography.labelSmall.copyWith(color: AppColors.success, fontWeight: FontWeight.bold)),
                                  ),
                                  TextButton(
                                    onPressed: () => context.push('/pos'),
                                    child: Text('See All', style: AppTypography.labelLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                        ),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: featured.length,
                            itemBuilder: (context, i) {
                              final p = featured[i];
                              return Bounceable(
                                onTap: () => context.push('/pos/product', extra: p),
                                child: Container(
                                  width: 160,
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: AppColors.shadowSubtle,
                                    border: Border.all(color: AppColors.cardBorder),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          width: double.infinity,
                                          decoration: const BoxDecoration(
                                            color: AppColors.backgroundSecondary,
                                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                            child: ProductMediaImage(
                                              imageUrl: p.imageUrl,
                                              fit: BoxFit.cover,
                                              errorWidget: Center(
                                                child: Icon(
                                                  Icons.inventory_2_outlined,
                                                  color: AppColors.primary.withOpacity(0.4),
                                                  size: 36,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w900)),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('₹${p.price}', style: AppTypography.labelMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w900)),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: p.stock > 10 ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text('${p.stock} left', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: p.stock > 10 ? AppColors.success : AppColors.error)),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))),
                error: (e, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

              // ── 3. LOW STOCK ALERTS (HORIZONTAL) ──────────
              ref.watch(dashboardLowStockProvider).when(
                data: (lowStock) {
                  if (lowStock.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.success.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), shape: BoxShape.circle),
                                child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Stock Levels Healthy', style: AppTypography.titleMedium.copyWith(color: AppColors.success, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('No products are currently running low on stock.', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  
                  return SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle),
                                child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text('Low Stock Alerts', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900)),
                              const Spacer(),
                              Text('${lowStock.length} items', style: AppTypography.labelLarge.copyWith(color: AppColors.error, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: lowStock.length,
                            itemBuilder: (context, i) {
                              final p = lowStock[i];
                              return Bounceable(
                                onTap: () => context.push('/pos/product', extra: p),
                                child: Container(
                                  width: 280,
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: AppColors.error.withOpacity(0.1)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.error.withOpacity(0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: const BoxDecoration(
                                            color: AppColors.backgroundSecondary,
                                            borderRadius: BorderRadius.all(Radius.circular(16)),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: ProductMediaImage(
                                              imageUrl: p.imageUrl,
                                              fit: BoxFit.cover,
                                              errorWidget: Center(
                                                child: Icon(
                                                  Icons.inventory_2_rounded,
                                                  color: AppColors.error.withOpacity(0.4),
                                                  size: 28,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w900)),
                                              Text('Only ${p.stock} remaining', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 8),
                                              GestureDetector(
                                                onTap: () async {
                                                  final success = await ref.read(notificationProvider.notifier).requestRestock(p.id, p.name);
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text(success ? 'Notification sent to Admin for ${p.name}' : 'Failed to send notification'),
                                                        backgroundColor: success ? AppColors.primary : AppColors.error,
                                                        behavior: SnackBarBehavior.floating,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                      ),
                                                    );
                                                  }
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.notifications_active_outlined, color: AppColors.primary, size: 14),
                                                      const SizedBox(width: 6),
                                                      Text('Notify Manager', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
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
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))),
                error: (e, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

              // ── 4. SALES OVERVIEW GRAPH ────────────────────
              ref.watch(dashboardOrdersProvider).when(
                data: (orders) {
                  final now = DateTime.now();
                  final Map<String, double> dailyMap = {};
                  for (int i = 9; i >= 0; i--) {
                    final date = now.subtract(Duration(days: i));
                    final key = "${date.year}-${date.month}-${date.day}";
                    dailyMap[key] = 0.0;
                  }
                  for (final o in orders) {
                    if (o.status == 'completed' || o.status == 'paid') {
                      final key = "${o.createdAt.year}-${o.createdAt.month}-${o.createdAt.day}";
                      if (dailyMap.containsKey(key)) {
                        dailyMap[key] = dailyMap[key]! + o.total;
                      }
                    }
                  }
                  final dataPoints = dailyMap.values.toList();
                  final totalSales = dataPoints.fold(0.0, (a, b) => a + b);
                  
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: ModernLineChart(
                        title: 'Sales Overview',
                        value: '₹${totalSales.toStringAsFixed(2)}',
                        change: '+15.2%',
                        data: dataPoints,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: SizedBox(height: 150, child: Center(child: CircularProgressIndicator()))),
                error: (e, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

              // ── 5. TODAY'S OVERVIEW TITLE ────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Text("Today's Overview", style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900)),
                ),
              ),

              // ── 6. KPI CARDS (RESPONSIVE GRID OR HORIZONTAL SCROLL) ──────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: width >= 1200 ? 4 : (width >= 1000 ? 3 : 2),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: width >= 1200
                        ? 2.2
                        : (width >= 1000
                            ? 2.0
                            : (width >= 800
                                ? 1.7
                                : (width >= 600 ? 1.45 : 1.3))),
                  ),
                  delegate: SliverChildListDelegate([
                    _buildGridKPI(
                      title: 'Inventory Value',
                      value: '₹${(ref.watch(dashboardProductsProvider).value ?? []).fold(0.0, (sum, p) => sum + (p.price * p.stock)).toStringAsFixed(0)}',
                      subtitle: 'Stock Valuation',
                      icon: Icons.account_balance_wallet_rounded,
                      accentColor: AppColors.success,
                      onTap: () => context.push('/inventory'),
                    ),
                    _buildGridKPI(
                      title: 'Total Products',
                      value: '${ref.watch(dashboardProductsProvider).value?.length ?? 0}',
                      subtitle: 'In Inventory',
                      icon: Icons.inventory_rounded,
                      accentColor: AppColors.info,
                      onTap: () => context.push('/products'),
                    ),
                    _buildGridKPI(
                      title: 'Total Sales',
                      value: '₹${stats.totalSales}',
                      subtitle: '+12.5%',
                      icon: Icons.payments_rounded,
                      accentColor: AppColors.primary,
                      onTap: () => context.push('/sales-details'),
                    ),
                    _buildGridKPI(
                      title: 'Orders',
                      value: '${stats.totalOrders}',
                      subtitle: 'Live Now',
                      icon: Icons.receipt_long_rounded,
                      accentColor: AppColors.success,
                      onTap: () => context.push('/orders'),
                    ),
                    _buildGridKPI(
                      title: 'Low Stock',
                      value: '${stats.lowStockItems}',
                      subtitle: 'Needs restock',
                      icon: Icons.inventory_2_rounded,
                      accentColor: AppColors.info,
                      onTap: () => context.push('/inventory'),
                    ),
                    _buildGridKPI(
                      title: 'Customers',
                      value: '${stats.totalCustomers}',
                      subtitle: 'Registered',
                      icon: Icons.people_alt_rounded,
                      accentColor: AppColors.warning,
                      onTap: () => context.push('/customers'),
                    ),
                  ]),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridKPI({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color accentColor,
    VoidCallback? onTap,
  }) {
    return SaaSKPICard(
      title: title,
      value: value,
      subtitle: subtitle,
      icon: icon,
      accentColor: accentColor,
      onTap: onTap,
    );
  }


}

class _BlinkingSupportFAB extends StatefulWidget {
  const _BlinkingSupportFAB();

  @override
  State<_BlinkingSupportFAB> createState() => _BlinkingSupportFABState();
}

class _BlinkingSupportFABState extends State<_BlinkingSupportFAB> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 80), // Offset to not overlap with nav bar
      child: FadeTransition(
        opacity: _controller,
        child: FloatingActionButton(
          heroTag: 'adminSupportFab',
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const SupportDialog(),
            );
          },
          backgroundColor: AppColors.warning,
          shape: const CircleBorder(),
          child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

