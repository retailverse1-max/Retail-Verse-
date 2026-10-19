import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:retail_verse_pos/features/settings/providers/pos_settings_provider.dart';
import 'package:retail_verse_pos/features/settings/domain/models/pos_settings.dart';
import 'package:retail_verse_pos/features/auth/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/order_model.dart';
import '../../../../data/remote/notification_service.dart';
import '../../../../core/utils/printer_service.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../orders/utils/receipt_generator.dart';

class InvoiceDialog extends ConsumerStatefulWidget {
  final Order order;
  final VoidCallback onDone;

  const InvoiceDialog({
    Key? key,
    required this.order,
    required this.onDone,
  }) : super(key: key);

  @override
  ConsumerState<InvoiceDialog> createState() => _InvoiceDialogState();
}

class _InvoiceDialogState extends ConsumerState<InvoiceDialog> {
  bool _isActionRunning = false;
  String _actionMessage = '';

  String _getStoreName() {
    try {
      final posSettings = ref.read(posSettingsProvider);
      if (posSettings.storeName.trim().isNotEmpty) {
        return posSettings.storeName.trim();
      }
      final authUser = ref.read(authProvider).user;
      final busName = authUser?['businessName']?.toString() ??
          authUser?['storeName']?.toString() ??
          authUser?['name']?.toString();
      if (busName != null && busName.trim().isNotEmpty) {
        return busName.trim();
      }
    } catch (_) {}
    return 'My Store';
  }

  final NotificationService _notificationService = NotificationService();
  final PrinterService _printerService = PrinterService();

  Future<void> _onPrintPressed() async {
    final posSettings = ref.read(posSettingsProvider);

    // Check if any paired Bluetooth printer is available
    List<BluetoothDevice> btDevices = [];
    try {
      btDevices = await _printerService.getDevices();
    } catch (_) {}

    // If bluetooth devices exist, offer choice: 80mm Thermal Printer vs Bluetooth Printer
    if (btDevices.isNotEmpty && mounted) {
      final chosen = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheetCtx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.print_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Select Print Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Choose your thermal printer output', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0E7FF),
                    child: Icon(Icons.receipt_long_rounded, color: Color(0xFF4338CA)),
                  ),
                  title: const Text('80mm Thermal Receipt (Supermarket / DMart Standard)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Epson, TVS, USB, LAN, Network & System Thermal Printers', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  tileColor: Colors.grey.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () => Navigator.pop(sheetCtx, '80mm_thermal'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFDCFCE7),
                    child: Icon(Icons.bluetooth_connected_rounded, color: Color(0xFF15803D)),
                  ),
                  title: const Text('Bluetooth Thermal Printer (ESC/POS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('${btDevices.length} paired Bluetooth printer(s) found', style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  tileColor: Colors.grey.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () => Navigator.pop(sheetCtx, 'bluetooth'),
                ),
              ],
            ),
          ),
        ),
      );

      if (chosen == 'bluetooth' && mounted) {
        await _printViaBluetooth(btDevices);
        return;
      }
      if (chosen == null) return; // Dismissed
    }

    // Default: 80mm Supermarket Thermal Roll Print (DMart style)
    await _printVia80mmThermal(posSettings);
  }

  Future<void> _printVia80mmThermal(PosSettings posSettings) async {
    setState(() {
      _isActionRunning = true;
      _actionMessage = 'Generating 80mm Supermarket Bill...';
    });

    try {
      final pdfBytes = await ReceiptGenerator.generateReceiptPdf(
        widget.order,
        settings: posSettings,
      );

      if (!mounted) return;
      setState(() => _isActionRunning = false);

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Bill_${widget.order.orderId}',
        format: PdfPageFormat.roll80, // Standard 80mm Supermarket Thermal Roll
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isActionRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text('Print Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _printViaBluetooth(List<BluetoothDevice> devices) async {
    final selectedDevice = await showDialog<BluetoothDevice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Bluetooth Printer'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: devices.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const Icon(Icons.print_rounded),
                title: Text(devices[index].name ?? 'Unknown Device'),
                subtitle: Text(devices[index].address ?? ''),
                onTap: () => Navigator.pop(ctx, devices[index]),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );

    if (selectedDevice != null && mounted) {
      setState(() {
        _isActionRunning = true;
        _actionMessage = 'Connecting to ${selectedDevice.name}...';
      });

      final connected = await _printerService.connect(selectedDevice);
      if (connected) {
        if (!mounted) return;
        setState(() => _actionMessage = 'Printing Receipt...');
        await _printerService.printReceipt(widget.order, storeName: _getStoreName());
        if (!mounted) return;
        setState(() => _isActionRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 2),
            content: Text('Receipt printed successfully!'),
            backgroundColor: AppColors.secondary,
          ),
        );
        await _printerService.disconnect();
      } else {
        if (!mounted) return;
        setState(() => _isActionRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 2),
            content: Text('Failed to connect to Bluetooth printer.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }



  Future<void> _onWhatsAppPressed() async {
    final order = widget.order;
    String phone = order.customerPhone?.trim() ?? '';
    phone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length == 10) {
      phone = '91$phone';
    }

    final hasRewardCoupon = (order.rewardCouponCode != null && order.rewardCouponCode!.isNotEmpty) ||
        order.subtotal >= 3000 ||
        order.total >= 3000;
    final rewardCode = (order.rewardCouponCode != null && order.rewardCouponCode!.isNotEmpty)
        ? order.rewardCouponCode!
        : 'SAVE300-${order.orderId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').substring(0, 4).toUpperCase()}';

    final storeName = _getStoreName();
    final buffer = StringBuffer();
    buffer.writeln('🏬 *${storeName.toUpperCase()}*');
    buffer.writeln('🧾 *TAX INVOICE / CASH BILL*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('*Order ID:* #${order.orderId}');
    buffer.writeln('*Date:* ${DateFormat('dd MMM yyyy, hh:mm a').format(order.dateTime)}');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('*Items Purchased:*');
    for (final item in order.items) {
      buffer.writeln('• ${item.product.name} × ${item.quantity} = ₹${(item.price * item.quantity).toStringAsFixed(2)}');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('*Subtotal:* ₹${order.subtotal.toStringAsFixed(2)}');
    if (order.discount > 0) {
      buffer.writeln('*Discount:* -₹${order.discount.toStringAsFixed(2)}');
    }
    if (order.tax > 0) {
      buffer.writeln('*GST / Tax:* ₹${order.tax.toStringAsFixed(2)}');
    }
    buffer.writeln('*GRAND TOTAL:* ₹${order.total.toStringAsFixed(2)}');
    buffer.writeln('*Payment Mode:* ${order.paymentMethod.toUpperCase()}');

    if (hasRewardCoupon) {
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('🎉 *CONGRATULATIONS!*');
      buffer.writeln('🎁 *YOU UNLOCKED A ₹300 REWARD COUPON!*');
      buffer.writeln('*Coupon Code:* `$rewardCode`');
      buffer.writeln('*Benefit:* Flat ₹300 OFF on your next shopping of ₹3,000+');
      buffer.writeln('_Valid for 30 days. Show this message at checkout!_');
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Thank you for shopping with us! 🙏');

    final message = Uri.encodeComponent(buffer.toString());
    Uri url;
    if (phone.isNotEmpty) {
      url = Uri.parse('https://wa.me/$phone?text=$message');
    } else {
      url = Uri.parse('https://api.whatsapp.com/send?text=$message');
    }

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp: $e'), backgroundColor: AppColors.error),
        );
      }
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
                            Text(
                              _getStoreName().toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
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
                            if (order.total >= 3000 || order.subtotal >= 3000) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                                ),
                                child: Column(
                                  children: [
                                    const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.card_giftcard_rounded, size: 16, color: Color(0xFFB45309)),
                                        SizedBox(width: 6),
                                        Text(
                                          'NEXT VISIT REWARD COUPON',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFB45309)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      order.rewardCouponCode ??
                                          'SAVE300-${order.orderId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').substring(0, 4).toUpperCase()}',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5, color: Color(0xFF92400E), fontFamily: 'monospace'),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Flat ₹300 OFF on your next order of ₹3,000+',
                                      style: TextStyle(fontSize: 10, color: Color(0xFF78350F), fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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

                // Row of Print, WhatsApp, Email
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
                        icon: FontAwesomeIcons.whatsapp,
                        label: 'WhatsApp',
                        color: const Color(0xFF25D366),
                        onTap: _onWhatsAppPressed,
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
