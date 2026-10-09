import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/order_model.dart';
import '../../../../data/remote/notification_service.dart';
import '../../../../core/utils/printer_service.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

class InvoiceDialog extends StatefulWidget {
  final Order order;
  final VoidCallback onDone;

  const InvoiceDialog({
    Key? key,
    required this.order,
    required this.onDone,
  }) : super(key: key);

  @override
  State<InvoiceDialog> createState() => _InvoiceDialogState();
}

class _InvoiceDialogState extends State<InvoiceDialog> {
  bool _isActionRunning = false;
  String _actionMessage = '';

  // Helpers to run simulated actions with progress/wow effect
  Future<void> _simulateAction(String title, List<String> steps) async {
    setState(() {
      _isActionRunning = true;
      _actionMessage = steps[0];
    });

    for (int i = 1; i < steps.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() {
        _actionMessage = steps[i];
      });
    }

    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _isActionRunning = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(duration: const Duration(seconds: 2),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text('$title Completed Successfully!'),
          ],
        ),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  final NotificationService _notificationService = NotificationService();
  final PrinterService _printerService = PrinterService();

  Future<void> _onPrintPressed() async {
    setState(() {
      _isActionRunning = true;
      _actionMessage = 'Searching for Bluetooth Printers...';
    });

    try {
      final devices = await _printerService.getDevices();
      if (!mounted) return;
      
      setState(() => _isActionRunning = false);

      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(duration: const Duration(seconds: 2),content: Text('No paired Bluetooth printers found.')),
        );
        return;
      }

      final selectedDevice = await showDialog<BluetoothDevice>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Select Printer'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.print),
                  title: Text(devices[index].name ?? 'Unknown Device'),
                  subtitle: Text(devices[index].address ?? ''),
                  onTap: () => Navigator.pop(ctx, devices[index]),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedDevice != null && mounted) {
        setState(() {
          _isActionRunning = true;
          _actionMessage = 'Connecting to \${selectedDevice.name}...';
        });

        final connected = await _printerService.connect(selectedDevice);
        
        if (connected) {
          if (!mounted) return;
          setState(() => _actionMessage = 'Printing Receipt...');
          
          await _printerService.printReceipt(widget.order);
          
          if (!mounted) return;
          setState(() => _isActionRunning = false);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(duration: const Duration(seconds: 2),
              content: Text('Receipt printed successfully!'),
              backgroundColor: AppColors.secondary,
            ),
          );
          
          // Optional: Disconnect after printing
          await _printerService.disconnect();
        } else {
          if (!mounted) return;
          setState(() => _isActionRunning = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(duration: const Duration(seconds: 2),
              content: Text('Failed to connect to printer.'),
              backgroundColor: AppColors.secondary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(seconds: 2),
            content: Text('Print Error: \$e'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    }
  }

  Future<void> _sendSmsReal(String phone) async {
    setState(() {
      _isActionRunning = true;
      _actionMessage = 'Opening WhatsApp/SMS...';
    });

    try {
      await _notificationService.sendSmsInvoice(phone: phone, order: widget.order);
      if (!mounted) return;
      setState(() => _isActionRunning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(duration: const Duration(seconds: 2),
          content: Text('WhatsApp/SMS opened successfully!'),
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionRunning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(duration: const Duration(seconds: 2),
          content: Text('Failed to send SMS: \$e'),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }

  Future<void> _sendEmailReal(String email) async {
    setState(() {
      _isActionRunning = true;
      _actionMessage = 'Sending Email...';
    });

    try {
      await _notificationService.sendEmailInvoice(email: email, order: widget.order);
      if (!mounted) return;
      setState(() => _isActionRunning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(duration: const Duration(seconds: 2),
          content: Text('Email request sent successfully!'),
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionRunning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(duration: const Duration(seconds: 2),
          content: Text('Failed to send Email: \$e'),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }

  void _onSmsPressed() {
    final phoneCtrl = TextEditingController(text: widget.order.customerPhone ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.sms_rounded, color: AppColors.info, size: 24),
            const SizedBox(width: 8),
            const Text('Send SMS Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter customer mobile number to send the text message invoice:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'e.g. 9876543210',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              final phone = phoneCtrl.text.trim();
              Navigator.pop(ctx);
              if (phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(duration: const Duration(seconds: 2),
                    content: Text('Phone number is required to send SMS.'),
                    backgroundColor: AppColors.secondary,
                  ),
                );
                return;
              }
              _sendSmsReal(phone);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Send SMS'),
          ),
        ],
      ),
    );
  }

  void _onEmailPressed() {
    final emailCtrl = TextEditingController(text: widget.order.customerEmail ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.email_rounded, color: AppColors.warning, size: 24),
            const SizedBox(width: 8),
            const Text('Email PDF Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter customer email address to send the PDF invoice receipt:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'e.g. john@example.com',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              final email = emailCtrl.text.trim();
              Navigator.pop(ctx);
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(duration: const Duration(seconds: 2),
                    content: Text('Email address is required.'),
                    backgroundColor: AppColors.secondary,
                  ),
                );
                return;
              }
              _sendEmailReal(email);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(order.dateTime);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Success Header
                  const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successLight.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Order Placed Successfully!',
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Receipt Ticket Paper
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border.withOpacity(0.8)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            // Store & Receipt Header Info
                            const Text(
                              'RETAIL VERSE STORE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: 1.2,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Receipt / Tax Invoice',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary.withOpacity(0.8),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow('Order ID', order.orderId),
                            _buildInfoRow('Date', formattedDate),
                            if (order.paymentMethod.isNotEmpty)
                              _buildInfoRow('Payment Method', order.paymentMethod.toUpperCase()),
                            if (order.cashierName != null)
                              _buildInfoRow('Billed By', order.cashierName!),

                            const SizedBox(height: 12),
                            const DashedLine(color: AppColors.textTertiary),
                            const SizedBox(height: 12),

                            // Customer Section if available
                            if (order.customerName != null && order.customerName!.isNotEmpty) ...[
                              Text(
                                'CUSTOMER INFO',
                                style: AppTypography.labelLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildInfoRow('Name', order.customerName ?? '—'),
                              if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                                _buildInfoRow('Phone', order.customerPhone ?? '—'),
                              if (order.customerEmail != null && order.customerEmail!.isNotEmpty)
                                _buildInfoRow('Email', order.customerEmail ?? '—'),
                              if (order.customerAddress != null && order.customerAddress!.isNotEmpty)
                                _buildInfoRow('Address', order.customerAddress ?? '—'),
                              const SizedBox(height: 12),
                              const DashedLine(color: AppColors.textTertiary),
                              const SizedBox(height: 12),
                            ],

                            // Items List Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'ITEM',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: AppColors.textSecondary.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'QTY',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: AppColors.textSecondary.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'TOTAL',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: AppColors.textSecondary.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Items Iteration
                            ...order.items.map((item) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.product.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            '₹${item.price.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'x${item.quantity}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        '₹${item.total.toStringAsFixed(2)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),

                            const SizedBox(height: 12),
                            const DashedLine(color: AppColors.textTertiary),
                            const SizedBox(height: 12),

                            // Totals Section
                            _buildAmountRow('Subtotal', order.subtotal),
                            if (order.discount > 0)
                              _buildAmountRow('Discount', -order.discount, isDiscount: true),
                            if (order.tax > 0)
                              _buildAmountRow('GST / Tax', order.tax),
                            if (order.extraCharges > 0)
                              _buildAmountRow('Extra Charges', order.extraCharges),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'GRAND TOTAL',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '₹${order.total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                // Invoice Options label
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'INVOICE OPTIONS',
                    style: AppTypography.labelLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.5,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Row of Print, SMS, Email
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.print_rounded,
                        label: 'Print',
                        color: AppColors.primary,
                        onTap: _onPrintPressed,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.email_rounded,
                        label: 'Email',
                        color: AppColors.accent,
                        onTap: _onEmailPressed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Done Close Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: widget.onDone,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Done, New Sale',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

          // Loading/Action Overlay during print, SMS, email sending simulation
          if (_isActionRunning)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _actionMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          Text(
            isDiscount
                ? '-₹${amount.abs().toStringAsFixed(2)}'
                : '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDiscount ? AppColors.success : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashedLine extends StatelessWidget {
  const DashedLine({Key? key, this.height = 1.2, this.color = Colors.black12}) : super(key: key);
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.5;
        final dashHeight = height;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            );
          }),
        );
      },
    );
  }
}
