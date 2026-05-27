import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/core/utils/formatters.dart';
import 'package:retail_verse_pos/core/widgets/common/status_badge.dart';
import 'package:retail_verse_pos/data/models/order_model.dart';
import 'package:retail_verse_pos/features/pos/providers/order_providers.dart';
import 'package:retail_verse_pos/data/providers/auth_provider.dart';
import 'package:retail_verse_pos/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:retail_verse_pos/features/orders/presentation/widgets/create_quote_modal.dart';
import 'package:retail_verse_pos/features/orders/presentation/widgets/invoice_details_modal.dart';
import 'package:retail_verse_pos/features/orders/presentation/widgets/quote_details_modal.dart';
import 'package:retail_verse_pos/routes/app_router.dart';
import 'package:retail_verse_pos/features/super_admin/presentation/screens/sa_shell.dart';

class OrdersListScreen extends ConsumerStatefulWidget {
  final String initialFilter;
  const OrdersListScreen({super.key, this.initialFilter = 'Invoices'});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  late String selectedTab; // 'Invoices' or 'Quotes'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    selectedTab = widget.initialFilter == 'Quotes' ? 'Quotes' : 'Invoices';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Order> _filtered(List<Order> all) {
    return all.where((o) {
      final matchesSearch = o.orderId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          o.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (o.customerName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (o.customerPhone?.contains(_searchQuery) ?? false);

      final isQuote = o.status.toLowerCase() == 'pending';
      final isInvoice = o.status.toLowerCase() == 'completed';

      final matchesTab = selectedTab == 'Invoices' ? isInvoice : isQuote;
      return matchesSearch && matchesTab;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersListProvider);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── MODERN CLEAN HEADER ──────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              color: AppColors.background,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 12,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ResponsiveMenuButton(isSuperAdmin: ref.watch(authProvider.select((s) => s.user?['role'])) == 'super_admin'),
                            const SizedBox(width: 4),
                            Text(
                              'Quotes & Invoices',
                              style: AppTypography.titleLarge.copyWith( // Made text smaller
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selectedTab == 'Quotes')
                              FilledButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => const CreateQuoteModal(),
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Create Quote'),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: selectedTab == 'Invoices'
                            ? 'Search invoices by ID, name, or phone...'
                            : 'Search quotes by ID, name, or phone...',
                        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Segmented Tabs
                  _buildSegmentedTab(),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Statistics Cards
            ordersAsync.when(
              loading: () => const SizedBox(height: 100),
              error: (_, __) => const SizedBox(),
              data: (orders) => _buildStatsRow(orders),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(ordersListProvider.future),
                child: ordersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (orders) {
                    final list = _filtered(orders);
                    if (list.isEmpty) return _buildEmptyState();

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: list.length,
                      itemBuilder: (context, index) => _buildOrderCard(list[index]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedTab() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton('Invoices'),
          ),
          Expanded(
            child: _buildTabButton('Quotes'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tabName) {
    final isSelected = selectedTab == tabName;
    return GestureDetector(
      onTap: () {
        if (selectedTab != tabName) {
          setState(() {
            selectedTab = tabName;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          tabName,
          style: AppTypography.labelLarge.copyWith(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(List<Order> allOrders) {
    final invoices = allOrders.where((o) => o.status.toLowerCase() == 'completed').toList();
    final quotes = allOrders.where((o) => o.status.toLowerCase() == 'pending').toList();

    if (selectedTab == 'Invoices') {
      final totalInvoices = invoices.length;
      final paidCount = invoices.where((o) => o.paymentMethod.toLowerCase() != 'unpaid').length;
      final unpaidCount = totalInvoices - paidCount;
      final totalRevenue = invoices.fold<double>(0.0, (sum, o) => sum + o.total);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 24) / 2;
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCard(
                      'Total Invoices',
                      totalInvoices.toString(),
                      Icons.receipt_long_rounded,
                      AppColors.primary,
                      width: cardWidth,
                    ),
                    _buildStatCard(
                      'Paid Invoices',
                      paidCount.toString(),
                      Icons.check_circle_rounded,
                      AppColors.success,
                      width: cardWidth,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCard(
                      'Unpaid Invoices',
                      unpaidCount.toString(),
                      Icons.hourglass_empty_rounded,
                      AppColors.warning,
                      width: cardWidth,
                    ),
                    _buildStatCard(
                      'Total Revenue',
                      AppFormatters.formatCurrency(totalRevenue),
                      Icons.currency_rupee_rounded,
                      AppColors.info,
                      width: cardWidth,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    } else {
      final totalQuotes = quotes.length;
      final convertedCount = allOrders.where((o) => o.converted).length;
      final openCount = quotes.length;
      final estimatedValue = quotes.fold<double>(0.0, (sum, o) => sum + o.total);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 24) / 2;
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCard(
                      'Total Quotes',
                      totalQuotes.toString(),
                      Icons.description_rounded,
                      AppColors.primary,
                      width: cardWidth,
                    ),
                    _buildStatCard(
                      'Converted Quotes',
                      convertedCount.toString(),
                      Icons.swap_horizontal_circle_rounded,
                      AppColors.success,
                      width: cardWidth,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCard(
                      'Open Quotes',
                      openCount.toString(),
                      Icons.pending_actions_rounded,
                      AppColors.warning,
                      width: cardWidth,
                    ),
                    _buildStatCard(
                      'Estimated Value',
                      AppFormatters.formatCurrency(estimatedValue),
                      Icons.monetization_on_rounded,
                      AppColors.info,
                      width: cardWidth,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final titlePrefix = selectedTab == 'Invoices' ? 'Invoice' : 'Quote';
    final customerLabel = order.customerName ?? 'Walk-In Customer';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (selectedTab == 'Quotes') {
              showDialog(
                context: context,
                builder: (_) => QuoteDetailsModal(quote: order),
              );
            } else {
              showDialog(
                context: context,
                builder: (_) => InvoiceDetailsModal(
                  order: order,
                  isQuote: false,
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$titlePrefix #${order.orderId.substring(order.orderId.length > 8 ? order.orderId.length - 8 : 0)}',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          customerLabel,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    StatusBadge(
                      label: order.status,
                      type: order.status.toLowerCase() == 'completed'
                          ? StatusType.success
                          : StatusType.warning,
                    ),
                  ],
                ),
                const Divider(height: 20, color: AppColors.divider),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          AppFormatters.formatDateTime(order.dateTime),
                          style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Text(
                      AppFormatters.formatCurrency(order.total),
                      style: AppTypography.titleLarge.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
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
            child: Icon(
              selectedTab == 'Invoices' ? Icons.receipt_long_rounded : Icons.description_rounded,
              size: 64,
              color: AppColors.primary.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            selectedTab == 'Invoices' ? 'No invoices found' : 'No quotes found',
            style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or tabs',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
