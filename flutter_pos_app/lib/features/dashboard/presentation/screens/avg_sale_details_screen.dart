import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../providers/dashboard_providers.dart';

class AvgSaleDetailsScreen extends ConsumerWidget {
  const AvgSaleDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final stats = statsAsync.asData?.value;

    final avgSale = stats?.avgSale ?? 0.0;
    final totalSales = stats?.totalSales ?? 0.0;
    final totalOrders = stats?.totalOrders ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Average Sale Analysis',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── MAIN AVG SALE CARD ─────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF232F3E), Color(0xFF131921)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Average Value Per Sale',
                    style: AppTypography.labelLarge.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppFormatters.formatCurrency(avgSale),
                    style: AppTypography.displaySmall.copyWith(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.trending_up_rounded, color: AppColors.success, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '+4.2% from last month',
                          style: AppTypography.labelSmall.copyWith(color: AppColors.success),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── CALCULATION BREAKDOWN ────────────────────────
            Text(
              'How is it calculated?',
              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildCalcItem(
              title: 'Total Revenue',
              value: AppFormatters.formatCurrency(totalSales),
              icon: Icons.payments_outlined,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            _buildCalcItem(
              title: 'Total Orders Count',
              value: totalOrders.toString(),
              icon: Icons.shopping_cart_outlined,
              color: AppColors.info,
            ),

            const SizedBox(height: 32),

            // ── INSIGHTS SECTION ─────────────────────────────
            Text(
              'Sale Insights',
              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInsightCard(
              title: 'Peak Average Day',
              value: 'Saturday',
              desc: 'Average sale is 15% higher on weekends',
              icon: Icons.star_outline_rounded,
            ),
            const SizedBox(height: 12),
            _buildInsightCard(
              title: 'Most Profitable Hour',
              value: '7 PM - 9 PM',
              desc: 'High value transactions happen in evening',
              icon: Icons.access_time_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalcItem({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
                Text(value, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard({required String title, required String value, required String desc, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryLight.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
                Text(value, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                Text(desc, style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
