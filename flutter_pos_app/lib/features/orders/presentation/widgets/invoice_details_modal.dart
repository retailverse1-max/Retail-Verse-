import 'dart:io';
import 'package:flutter/material.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/core/utils/formatters.dart';
import 'package:retail_verse_pos/data/models/order_model.dart';
import 'package:retail_verse_pos/core/widgets/common/status_badge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:retail_verse_pos/data/remote/notification_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class InvoiceDetailsModal extends ConsumerWidget {
  final Order order;
  final bool isQuote;

  const InvoiceDetailsModal({
    super.key,
    required this.order,
    this.isQuote = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = isQuote ? 'Quote Details' : 'Invoice Details';
    
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Stack(
        children: [
          // Main Scrollable Content
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildBilledToAndReference(),
                const SizedBox(height: 24),
                _buildItemsList(),
                const SizedBox(height: 24),
                _buildPaymentMethod(),
                const SizedBox(height: 16),
                _buildPaymentStatus(),
                const SizedBox(height: 32),
                _buildActionButtons(context),
              ],
            ),
          ),
          
          // Top Right Close Button
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
              tooltip: 'Close',
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            isQuote ? 'Quote Details' : 'Invoice Details',
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBilledToAndReference() {
    final customerName = order.customerName ?? 'Walk-In Customer';
    final customerEmail = order.customerEmail ?? 'N/A';
    final refTitle = isQuote ? 'QT' : 'INV';

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
          // Billed To
          Text(
            'BILLED TO',
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
              fontWeight: FontWeight.w800,
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
            '$refTitle-${order.orderId}',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Order: ${order.orderId}',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            AppFormatters.formatDateTime(order.dateTime),
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
                    'ITEM',
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
                    'AMOUNT',
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
            itemCount: order.items.length,
            itemBuilder: (context, index) {
              final item = order.items[index];
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
                        style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
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
          
          // Totals
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subtotal', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                Text(
                  AppFormatters.formatCurrency(order.subtotal),
                  style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          if (order.discount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Discount', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                  Text(
                    '- ${AppFormatters.formatCurrency(order.discount)}',
                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800, color: AppColors.error),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tax', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                Text(
                  AppFormatters.formatCurrency(order.tax),
                  style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          if (order.extraCharges > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Extra Charges', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                  Text(
                    '+ ${AppFormatters.formatCurrency(order.extraCharges)}',
                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          if (order.extraCharges <= 0)
            const SizedBox(height: 12),
          
          // Total Amount (Blue Background Area)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F4FA),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
                Text(
                  AppFormatters.formatCurrency(order.total),
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PAYMENT METHOD',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            order.paymentMethod,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PAYMENT STATUS',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          StatusBadge(
            label: order.status,
            type: order.status.toLowerCase() == 'completed'
                ? StatusType.success
                : StatusType.warning,
          ),
        ],
      ),
    );
  }

  Future<void> _downloadPdf(BuildContext context, Order order) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(isQuote ? 'Quote #${order.orderId}' : 'Invoice #${order.orderId}', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Customer: ${order.customerName ?? 'Walk-In'}'),
              if (order.customerEmail != null && order.customerEmail!.isNotEmpty) pw.Text('Email: ${order.customerEmail}'),
              if (order.customerPhone != null && order.customerPhone!.isNotEmpty) pw.Text('Phone: ${order.customerPhone}'),
              pw.Text('Date: ${AppFormatters.formatDateTime(order.dateTime)}'),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Item', 'Qty', 'Price', 'Total'],
                data: order.items.map((item) => [
                  item.product.name,
                  item.quantity.toString(),
                  AppFormatters.formatCurrency(item.price).replaceAll('₹', 'Rs.'),
                  AppFormatters.formatCurrency(item.total).replaceAll('₹', 'Rs.'),
                ]).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Subtotal: ${AppFormatters.formatCurrency(order.subtotal).replaceAll('₹', 'Rs.')}'),
                      pw.Text('Tax: ${AppFormatters.formatCurrency(order.tax).replaceAll('₹', 'Rs.')}'),
                      if (order.discount > 0) pw.Text('Discount: -${AppFormatters.formatCurrency(order.discount).replaceAll('₹', 'Rs.')}'),
                      if (order.extraCharges > 0) pw.Text('Extra Charges: +${AppFormatters.formatCurrency(order.extraCharges).replaceAll('₹', 'Rs.')}'),
                      pw.Divider(),
                      pw.Text('Total: ${AppFormatters.formatCurrency(order.total).replaceAll('₹', 'Rs.')}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                    ]
                  )
                ]
              ),
              pw.SizedBox(height: 40),
              pw.Text('Thank you for your business!', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
            ],
          ),
        ),
      );

      final bytes = await pdf.save();

      Directory? directory;
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          directory = downloadDir;
        } else {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        final prefix = isQuote ? 'Quote' : 'Invoice';
        File file = File('${directory.path}/${prefix}_${order.orderId}.pdf');
        
        try {
          await file.writeAsBytes(bytes);
        } catch (e) {
          // If permission denied on Download dir (Android 13+), fallback to app dir
          if (Platform.isAndroid) {
            final fallbackDir = await getExternalStorageDirectory();
            if (fallbackDir != null) {
              file = File('${fallbackDir.path}/${prefix}_${order.orderId}.pdf');
              await file.writeAsBytes(bytes);
            } else {
              throw e;
            }
          } else {
            throw e;
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF Downloaded to ${file.path}'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        throw Exception("Could not access storage directory");
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () async {
            String? emailToSend = order.customerEmail;
            
            if (emailToSend == null || emailToSend.isEmpty) {
              final emailCtrl = TextEditingController();
              emailToSend = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Enter Email Address'),
                  content: TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'customer@example.com',
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, emailCtrl.text.trim()), child: const Text('Send')),
                  ],
                ),
              );
            }
            
            if (emailToSend == null || emailToSend.isEmpty) return;

            if (context.mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const PopScope(
                  canPop: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            try {
              await NotificationService().sendEmailInvoice(
                email: emailToSend,
                order: order,
              );
              if (context.mounted) {
                Navigator.of(context).pop(); // Pop loading dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email sent successfully!'),
                    backgroundColor: AppColors.success,
                  ),
                );
                Navigator.of(context).pop(); // Close the InvoiceDetailsModal
              }
            } catch (e) {
              if (context.mounted) {
                Navigator.of(context).pop(); // Pop loading dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to send email: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.email_rounded, size: 20),
          label: Text(
            'Email Receipt',
            style: AppTypography.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2), // Blue
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => const PopScope(
                canPop: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
            
            await _downloadPdf(context, order);

            if (context.mounted) {
              Navigator.of(context, rootNavigator: true).pop(); // pop loading
              Navigator.of(context).pop(); // pop modal
            }
          },
          icon: const Icon(Icons.download_rounded, size: 20),
          label: Text(
            'Download PDF',
            style: AppTypography.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0F9D58), // Green
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
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
              Navigator.of(context).pop(); // pop loading
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Receipt Printed')),
              );
              Navigator.of(context).pop(); // pop modal
            }
          },
          icon: const Icon(Icons.print_rounded, size: 20),
          label: Text(
            'Print Receipt',
            style: AppTypography.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1F1F1F), // Black
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
