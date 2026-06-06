import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../providers/dashboard_providers.dart';

/// A screen that displays the list of sales (transactions).
/// This replaces the missing implementation that caused the compile error.
class SalesDetailsScreen extends ConsumerWidget {
  const SalesDetailsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(dashboardOrdersProvider);
    final sales = salesAsync.asData?.value ?? [];

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
          'Sales Details',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: sales.isEmpty
          ? const Center(
              child: Text('No sales data available.', style: TextStyle(color: Colors.grey)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: sales.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final sale = sales[index];
                // Assuming each sale has id, totalAmount, date, and itemCount fields.
                final amount = sale.total ?? 0.0;
                final date = sale.createdAt;
                final items = sale.items?.length ?? 0;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long, color: AppColors.primary, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sale #${sale.id ?? "-"}', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(AppFormatters.formatCurrency(amount), style: AppTypography.titleSmall.copyWith(color: AppColors.success)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${items} items', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text('${date.day}/${date.month}/${date.year}', style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
