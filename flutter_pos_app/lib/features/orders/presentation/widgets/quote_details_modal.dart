import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/core/utils/formatters.dart';
import 'package:retail_verse_pos/data/models/order_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:retail_verse_pos/features/pos/providers/order_providers.dart';
import 'package:retail_verse_pos/features/pos/presentation/widgets/invoice_dialog.dart';

class QuoteDetailsModal extends ConsumerWidget {
  final Order quote;

  const QuoteDetailsModal({
    super.key,
    required this.quote,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Stack(
        children: [
          // Main Scrollable Content
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTopBadgeRow(),
                const SizedBox(height: 16),
                _buildHeader(),
                const SizedBox(height: 24),
                _buildPreparedForAndReference(),
                const SizedBox(height: 24),
                _buildItemsList(),
                const SizedBox(height: 32),
                _buildActionButtons(context, ref),
              ],
            ),
          ),
          
          // Top Right Close Button
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
              tooltip: 'Close',
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildTopBadgeRow() {
    final status = quote.status.toUpperCase();
    final isAccepted = status == 'COMPLETED' || status == 'ACCEPTED';
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isAccepted ? AppColors.success.withOpacity(0.1) : AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isAccepted ? AppColors.success.withOpacity(0.3) : AppColors.warning.withOpacity(0.3),
            ),
          ),
          child: Text(
            isAccepted ? 'ACCEPTED' : (status.isEmpty ? 'PENDING' : status),
            style: AppTypography.labelSmall.copyWith(
              color: isAccepted ? AppColors.success : AppColors.warning,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0), // Light Orange
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.description_outlined, color: Color(0xFFE65100)), // Orange Icon
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Quotation Details',
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreparedForAndReference() {
    final customerName = quote.customerName ?? 'Walk-In Customer';
    final customerEmail = quote.customerEmail ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prepared For
          Text(
            'PREPARED FOR',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            customerName,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (customerEmail != 'N/A' && customerEmail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              customerEmail,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 16),
          
          // Reference
          Text(
            'REFERENCE',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'QT-${quote.orderId}',
            style: AppTypography.titleMedium.copyWith(
              color: const Color(0xFFE65100), // Orange
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Valid Until: N/A',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            AppFormatters.formatDateTime(quote.dateTime),
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'PRODUCT',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'QTY',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'ORIGINAL PRICE',
                    textAlign: TextAlign.right,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Items
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: quote.items.length,
            itemBuilder: (context, index) {
              final item = quote.items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        item.product.name,
                        style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '${item.quantity}',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        AppFormatters.formatCurrency(item.total),
                        textAlign: TextAlign.right,
                        style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          const Divider(height: 16, color: AppColors.border),
          
          // Subtotal
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SUBTOTAL', 
                  style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.w700),
                ),
                Text(
                  AppFormatters.formatCurrency(quote.subtotal),
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),

          // Discount
          if (quote.discount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'DISCOUNT', 
                    style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '- ${AppFormatters.formatCurrency(quote.discount)}',
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.error),
                  ),
                ],
              ),
            ),

          // Tax
          if (quote.tax > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TAX', 
                    style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '+ ${AppFormatters.formatCurrency(quote.tax)}',
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            
          // Extra Charges
          if (quote.extraCharges > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'EXTRA CHARGES', 
                    style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '+ ${AppFormatters.formatCurrency(quote.extraCharges)}',
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            
          const SizedBox(height: 12),
          
          // Final Accepted Price (Green Background Area)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FINAL ACCEPTED PRICE',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  AppFormatters.formatCurrency(quote.total),
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Row: Close and Print
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.border, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Close',
                  style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => const PopScope(
                      canPop: false,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                  await Future.delayed(const Duration(seconds: 1));
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Pop loading dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(duration: const Duration(seconds: 2),content: Text('Printing completed')),
                    );
                    Navigator.of(context).pop(); // Close modal
                  }
                },
                icon: const Icon(Icons.print_outlined, size: 20, color: AppColors.textPrimary),
                label: Text(
                  'Print',
                  style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.border, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Edit Button (Added via request)
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop(); // Close modal immediately
            context.push('/quotes/edit/${quote.id}', extra: quote);
          },
          icon: const Icon(Icons.edit_rounded, size: 20),
          label: Text(
            'Edit Quote',
            style: AppTypography.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.textSecondary, // Grey color for Edit
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        
        // Pay Now
        FilledButton.icon(
          onPressed: () {
            _showPaymentSelectionDialog(context, ref);
          },
          icon: const Icon(Icons.payment_rounded, size: 20, color: Colors.black87),
          label: Text(
            'Pay Now',
            style: AppTypography.titleSmall.copyWith(color: Colors.black87, fontWeight: FontWeight.w600),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF4B400), // Yellow color
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        
        // Convert to Invoice
        FilledButton.icon(
          onPressed: () {
            _showPaymentSelectionDialog(context, ref);
          },
          icon: const Icon(Icons.receipt_long_rounded, size: 20),
          label: Text(
            'Convert to Invoice',
            style: AppTypography.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary, // Blue color
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  void _showPaymentSelectionDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.money, color: AppColors.primary),
              ),
              title: const Text('Cash', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _processConversion(context, ref, 'Cash');
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.phone_android, color: AppColors.primary),
              ),
              title: const Text('UPI', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _processConversion(context, ref, 'UPI');
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.credit_card, color: AppColors.primary),
              ),
              title: const Text('Card', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _processConversion(context, ref, 'Card');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processConversion(BuildContext context, WidgetRef ref, String paymentMethod) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    // Using ref.read to access orderCreationProvider logic
    // Ensure you import 'package:retail_verse_pos/features/pos/providers/order_providers.dart' at the top
    final success = await ref.read(orderCreationProvider.notifier).updateOrder(
      orderId: quote.id,
      items: quote.items,
      status: 'completed',
      paymentMethod: paymentMethod,
      paymentStatus: 'paid',
      converted: true,
      customerName: quote.customerName,
      customerPhone: quote.customerPhone,
      customerEmail: quote.customerEmail,
      customerAddress: quote.customerAddress,
      orderNotes: quote.notes,
      extraCharges: quote.extraCharges,
      discount: quote.discount,
    );

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Pop loading dialog
    }

    if (success) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(duration: const Duration(seconds: 2),
            content: Text('Quote successfully converted to Invoice!'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(); // Close QuoteDetailsModal and stay on Quotes screen
      }
    } else {
      if (context.mounted) {
        final errorMsg = ref.read(orderCreationProvider).error ?? 'Conversion failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(seconds: 2),
            content: Text(errorMsg.toString().contains('SocketException') || errorMsg.toString().contains('Failed host lookup') ? 'You are offline. Please check your internet connection.' : 'Error: $errorMsg'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
