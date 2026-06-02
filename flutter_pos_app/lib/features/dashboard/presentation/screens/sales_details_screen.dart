import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common/modern_search_bar.dart';
import '../../providers/dashboard_providers.dart';
import '../../../../features/auth/providers/auth_provider.dart';

class SalesDetailsScreen extends ConsumerStatefulWidget {
  const SalesDetailsScreen({super.key});

  @override
  ConsumerState<SalesDetailsScreen> createState() => _SalesDetailsScreenState();
}

enum DateFilter { allTime, today, last7Days, thisMonth }

class _SalesDetailsScreenState extends ConsumerState<SalesDetailsScreen> {
  final _searchController = TextEditingController();
  DateFilter _dateFilter = DateFilter.allTime;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showDateFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select Time Period',
                    style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  _buildFilterOption('All Time', DateFilter.allTime),
                  _buildFilterOption('Today', DateFilter.today),
                  _buildFilterOption('Last 7 Days', DateFilter.last7Days),
                  _buildFilterOption('This Month', DateFilter.thisMonth),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(String label, DateFilter filter) {
    final isSelected = _dateFilter == filter;
    return ListTile(
      title: Text(
        label,
        style: AppTypography.titleMedium.copyWith(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
      onTap: () {
        setState(() {
          _dateFilter = filter;
        });
        Navigator.pop(context);
      },
    );
  }

  String _getDateFilterLabel() {
    switch (_dateFilter) {
      case DateFilter.allTime:
        return 'All Time';
      case DateFilter.today:
        return 'Today';
      case DateFilter.last7Days:
        return 'Last 7 Days';
      case DateFilter.thisMonth:
        return 'This Month';
    }
  }

  bool _matchesDateFilter(DateTime date) {
    final now = DateTime.now();
    switch (_dateFilter) {
      case DateFilter.allTime:
        return true;
      case DateFilter.today:
        return date.year == now.year && date.month == now.month && date.day == now.day;
      case DateFilter.last7Days:
        return date.isAfter(now.subtract(const Duration(days: 7)));
      case DateFilter.thisMonth:
        return date.year == now.year && date.month == now.month;
    }
  }

  void _showQuickActionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Text('Quick Actions', style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  _buildQuickActionBtn(Icons.person_add_rounded, 'Add Customer', () {
                    Navigator.pop(context);
                    context.push('/add-customer');
                  }),
                  _buildQuickActionBtn(Icons.inventory_2_rounded, 'Inventory', () {
                    Navigator.pop(context);
                    context.push('/inventory');
                  }),
                  _buildQuickActionBtn(Icons.receipt_long_rounded, 'Quotes / Invoices', () {
                    Navigator.pop(context);
                    context.push('/orders');
                  }),
                  _buildQuickActionBtn(Icons.settings_rounded, 'Settings', () {
                    Navigator.pop(context);
                    context.push('/settings');
                  }),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(dashboardOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Transactions',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── MODERN SEARCH BAR ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: ModernSearchBar(
              controller: _searchController,
              hintText: 'Search transactions...',
              onChanged: (v) => setState(() {}),
              onFilterTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Advanced filters coming soon!')),
                );
              },
            ),
          ),

          // ── DATE FILTER ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 18),
                    ),
                    Text(
                      _getDateFilterLabel(),
                      style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8), // Replaces Spacer/Expanded to prevent full stretch
                    GestureDetector(
                      onTap: _showDateFilterModal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sync_rounded, color: AppColors.primary, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Change',
                              style: AppTypography.labelLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── TRANSACTIONS LIST ───────────────────────────────
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                final filteredOrders = orders.where((o) {
                  // Date Filter
                  if (!_matchesDateFilter(o.createdAt)) return false;

                  // Text Search
                  final query = _searchController.text.toLowerCase();
                  if (query.isEmpty) return true;

                  final matchesOrderNumber = o.orderNumber.toLowerCase().contains(query);
                  final matchesPaymentMethod = o.paymentMethod.toLowerCase().contains(query);
                  final matchesProducts = o.items.any((item) => item.name.toLowerCase().contains(query));

                  return matchesOrderNumber || matchesPaymentMethod || matchesProducts;
                }).toList();

                if (filteredOrders.isEmpty) {
                  return const Center(child: Text('No transactions found'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: filteredOrders.length,
                  separatorBuilder: (_, __) => Divider(color: AppColors.border.withOpacity(0.3), height: 32),
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    return InkWell(
                      onTap: () {
                        // Normally context.push('/order-detail/${order.id}', extra: order);
                        // Using a snackbar until backend Order retrieval mapping is decided
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Details for Sale #${order.orderNumber.split('-').last} coming soon!')),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sale #${order.orderNumber.split('-').last}',
                                    style: AppTypography.labelMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${order.paymentMethod.toUpperCase()} Sale',
                                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppFormatters.formatDateTime(order.createdAt),
                                    style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  AppFormatters.formatCurrency(order.total),
                                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.successLight,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Paid',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, __) => Center(child: Text('Error: $e')),
            ),
          ),

          // ── BOTTOM BUTTONS ──────────────────────────────────
          SafeArea(
            bottom: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -4), blurRadius: 10),
                ],
              ),
              child: Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Payment In feature is coming soon!', style: AppTypography.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.account_balance_wallet_rounded, size: 22, color: Colors.white),
                      label: Text('Payment In', style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    GestureDetector(
                      onTap: _showQuickActionsModal,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.add, color: AppColors.primary, size: 28),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.push('/pos');
                      },
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 22, color: Colors.white),
                      label: Text('New Sale', style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
