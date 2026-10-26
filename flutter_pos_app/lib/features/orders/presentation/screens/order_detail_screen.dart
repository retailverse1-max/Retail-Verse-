import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/core/theme/app_theme.dart';
import 'package:retail_verse_pos/core/utils/formatters.dart';
import 'package:retail_verse_pos/data/models/order_model.dart';
import 'package:retail_verse_pos/features/pos/providers/order_providers.dart';
import 'package:retail_verse_pos/features/orders/utils/receipt_generator.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:retail_verse_pos/features/settings/providers/pos_settings_provider.dart';
import 'package:retail_verse_pos/core/utils/printer_service.dart';
import 'package:retail_verse_pos/features/auth/providers/auth_provider.dart';
import 'package:pdf/pdf.dart';

/// Order detail screen - Invoice style view
class OrderDetailScreen extends ConsumerWidget {
  final Order order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(posSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: Text(order.status == 'Pending' ? 'Quote Details' : 'Order Details', style: AppTypography.headlineMedium),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: AppColors.primary),
            onPressed: () async {
              try {
                final printerService = PrinterService();
                if (await printerService.isConnected() || await printerService.autoConnect()) {
                  final authUser = ref.read(authProvider).user;
                  await printerService.printReceipt(
                    order,
                    settings: settings,
                    authUser: authUser,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(duration: Duration(seconds: 2), content: Text('Receipt printed on thermal printer!')),
                    );
                  }
                  return;
                }

                final pdfData = await ReceiptGenerator.generateReceiptPdf(
                  order,
                  settings: settings,
                );
                await Printing.layoutPdf(
                  onLayout: (format) async => pdfData,
                  name: 'Receipt_${order.orderId}.pdf',
                  format: settings.receiptSize == '58mm' ? PdfPageFormat.roll57 : PdfPageFormat.roll80,
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(duration: const Duration(seconds: 2), content: Text('Error printing receipt: $e')),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: AppColors.primary),
            onPressed: () {
              final text = 'Receipt for Order #${order.orderId}\n'
                  'Date: ${AppFormatters.formatDateTime(order.dateTime)}\n'
                  'Total: ${AppFormatters.formatCurrency(order.total)}\n'
                  'Thank you for your business!';
              Share.share(text, subject: 'Order Receipt ${order.orderId}');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header Card
            _buildHeaderCard(),

            const SizedBox(height: 16),

            // Items List
            _buildItemsList(),

            const SizedBox(height: 16),

            // Totals Section
            _buildTotalsSection(),

            const SizedBox(height: 24),

            // Action Buttons
            _buildActionButtons(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLG),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.orderId,
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: order.status == 'Completed'
                      ? AppColors.successLight
                      : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusSM),
                ),
                child: Text(
                  order.status,
                  style: AppTypography.labelSmall.copyWith(
                    color: order.status == 'Completed'
                        ? AppColors.success
                        : AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date & Time',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppFormatters.formatDateTime(order.dateTime),
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Method',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _getPaymentIcon(order.paymentMethod),
                        const SizedBox(width: 8),
                        Text(
                          order.paymentMethod,
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (order.cashierName != null) ...[
            const SizedBox(height: 12),
            Text(
              'Cashier: ${order.cashierName}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _getPaymentIcon(String method) {
    IconData icon;
    switch (method) {
      case 'Cash':
        icon = Icons.money;
        break;
      case 'Card':
        icon = Icons.credit_card;
        break;
      case 'UPI':
        icon = Icons.phone_android;
        break;
      default:
        icon = Icons.payment;
    }
    return Icon(icon, size: 18, color: AppColors.primary);
  }

  Widget _buildItemsList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLG),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Items',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: order.items.length,
            separatorBuilder: (context, index) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final item = order.items[index];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(
                        AppTheme.borderRadiusMD,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${item.quantity}x',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SKU: ${item.product.sku}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Text(
                    AppFormatters.formatCurrency(item.total),
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLG),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTotalRow(
            'Subtotal',
            AppFormatters.formatCurrency(order.subtotal),
          ),
          const SizedBox(height: 8),
          _buildTotalRow('Tax (18%)', AppFormatters.formatCurrency(order.tax)),
          if (order.extraCharges > 0) ...[
            const SizedBox(height: 8),
            _buildTotalRow(
              'Extra Charges',
              '+${AppFormatters.formatCurrency(order.extraCharges)}',
            ),
          ],
          if (order.discount > 0) ...[
            const SizedBox(height: 8),
            _buildTotalRow(
              'Discount',
              '-${AppFormatters.formatCurrency(order.discount)}',
            ),
          ],
          const Divider(height: 24),
          _buildTotalRow(
            'Grand Total',
            AppFormatters.formatCurrency(order.total),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)
              : AppTypography.bodyLarge,
        ),
        Text(
          value,
          style: isTotal
              ? AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                )
              : AppTypography.bodyLarge,
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    if (order.status == 'Pending') {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.push('/quotes/edit/${order.id}', extra: order);
                  },
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Edit Quote / Bargain'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showPaymentSelectionDialog(context, ref),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Convert to Invoice'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(duration: const Duration(seconds: 2),content: Text('Invoice will be downloaded...')),
              );
            },
            icon: const Icon(Icons.download),
            label: const Text('Download Invoice'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final success = await ref.read(orderCreationProvider.notifier).updateOrder(
      orderId: order.id,
      items: order.items,
      status: 'completed',
      paymentMethod: paymentMethod,
      paymentStatus: 'paid',
      converted: true,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      customerEmail: order.customerEmail,
      customerAddress: order.customerAddress,
      orderNotes: order.notes,
      extraCharges: order.extraCharges,
      discount: order.discount,
    );

    if (context.mounted) {
      Navigator.pop(context); // Pop loading dialog
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
        context.pop(); // Pop OrderDetailScreen
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
