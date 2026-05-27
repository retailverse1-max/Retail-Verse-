import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:retail_verse_pos/data/remote/payment_service.dart';
import 'package:retail_verse_pos/features/auth/providers/auth_provider.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/data/remote/notification_service.dart';
import 'package:retail_verse_pos/core/theme/app_theme.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/core/utils/formatters.dart';
import 'package:retail_verse_pos/features/pos/providers/cart_provider.dart';
import 'package:retail_verse_pos/features/pos/providers/order_providers.dart';
import 'package:retail_verse_pos/features/pos/providers/pos_held_cart_provider.dart';
import 'package:retail_verse_pos/features/pos/presentation/widgets/invoice_dialog.dart';
import 'package:retail_verse_pos/features/pos/presentation/widgets/pos_cart_line_tile.dart';
import 'package:retail_verse_pos/features/pos/presentation/widgets/card_payment_simulation_dialog.dart';
import 'package:retail_verse_pos/features/pos/presentation/widgets/upi_payment_simulation_dialog.dart';
import 'package:retail_verse_pos/features/dashboard/providers/dashboard_providers.dart';
import 'package:retail_verse_pos/data/models/customer_model.dart';

/// Full checkout: lines, totals, customer, payment, place order.
class PosCartScreen extends ConsumerStatefulWidget {
  const PosCartScreen({super.key});

  @override
  ConsumerState<PosCartScreen> createState() => _PosCartScreenState();
}

class _PosCartScreenState extends ConsumerState<PosCartScreen> {
  late final TextEditingController _discountCtrl;
  late final TextEditingController _extraCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _cashReceivedCtrl;
  late final FocusNode _addressFocus;

  String _paymentMethod = 'Cash';
  bool _controllersBound = false;
  late Razorpay _razorpay;
  final PaymentService _paymentService = PaymentService();
  bool _isProcessingRazorpay = false;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _addressFocus = FocusNode();
    _discountCtrl = TextEditingController();
    _extraCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _cashReceivedCtrl = TextEditingController();

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('✅ Razorpay Success: ${response.paymentId}');
    try {
      final verifyRes = await _paymentService.verifyRazorpayPayment(
        orderId: response.orderId!,
        paymentId: response.paymentId!,
        signature: response.signature!,
      );

      if (verifyRes['success'] == true) {
        await _executeOrderPlacement(
          paymentStatus: 'paid',
          razorpayOrderId: response.orderId,
          razorpayPaymentId: response.paymentId,
          razorpaySignature: response.signature,
        );
      } else {
        _showError('Payment verification failed on server.');
      }
    } catch (e) {
      _showError('Payment verification error: $e');
    } finally {
      setState(() => _isProcessingRazorpay = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('❌ Razorpay Error: ${response.code} - ${response.message}');
    _showError('Payment failed: ${response.message}');
    setState(() => _isProcessingRazorpay = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showError('External wallet selected: ${response.walletName}');
    setState(() => _isProcessingRazorpay = false);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _extraCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _cashReceivedCtrl.dispose();
    _addressFocus.dispose();
    _razorpay.clear();
    super.dispose();
  }

  void _syncControllersFromCart(CartState cart) {
    if (cart.items.isEmpty) return;
    if (_controllersBound) return;
    _discountCtrl.text =
        cart.discount > 0 ? cart.discount.toStringAsFixed(2) : '';
    _extraCtrl.text =
        cart.extraCharges > 0 ? cart.extraCharges.toStringAsFixed(2) : '';
    _nameCtrl.text = cart.customerName;
    _phoneCtrl.text = cart.customerPhone;
    _emailCtrl.text = cart.customerEmail;
    _addressCtrl.text = cart.customerAddress;
    _notesCtrl.text = cart.orderNotes;
    _cashReceivedCtrl.text = cart.total > 0 ? cart.total.toStringAsFixed(2) : '';
    _controllersBound = true;
  }

  void _applyDiscount() {
    final v = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    ref.read(cartProvider.notifier).updateDiscount(v < 0 ? 0 : v);
  }

  void _applyExtra() {
    final v = double.tryParse(_extraCtrl.text.trim()) ?? 0;
    ref.read(cartProvider.notifier).updateExtraCharges(v < 0 ? 0 : v);
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear cart?'),
        content: const Text('All line items and checkout fields will be reset.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      ref.read(cartProvider.notifier).clearCart();
      _discountCtrl.clear();
      _extraCtrl.clear();
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _emailCtrl.clear();
      _addressCtrl.clear();
      _notesCtrl.clear();
      _cashReceivedCtrl.clear();
      setState(() => _controllersBound = false);
    }
  }

  Future<void> _launchUPI() async {
    final updated = ref.read(cartProvider);
    final amount = updated.total.toStringAsFixed(2);
    // Standard UPI deep link
    final upiUrl = 'upi://pay?pa=wehexerve@icici&pn=RetailVerse&am=$amount&cu=INR';
    final uri = Uri.parse(upiUrl);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError('No UPI apps found on this device');
      }
    } catch (e) {
      _showError('Could not launch UPI: $e');
    }
  }

  Future<void> _placeOrder() async {
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) return;

    ref.read(cartProvider.notifier).updateCustomer(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
        );
    _applyDiscount();
    _applyExtra();

    final updated = ref.read(cartProvider);

    if (_paymentMethod == 'Cash') {
      final received = double.tryParse(_cashReceivedCtrl.text.trim()) ?? 0;
      if (received < updated.total) {
        _showError('Received amount must be at least ${AppFormatters.formatCurrency(updated.total)}');
        return;
      }
    }

    // Direct UPI Flow
    if (_paymentMethod == 'UPI') {
      final upiOk = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => UpiPaymentSimulationDialog(amount: updated.total),
      );
      if (upiOk != true || !mounted) return;
      await _executeOrderPlacement();
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm ${_paymentMethod == 'Cash' ? 'Cash' : _paymentMethod} Order'),
        content: Text(
          'Total ${AppFormatters.formatCurrency(updated.total)} · '
          '${updated.itemCount} items',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Place'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    if (_paymentMethod == 'Razorpay') {
      setState(() => _isProcessingRazorpay = true);
      try {
        final orderRes = await _paymentService.createRazorpayOrder(
          amount: updated.total,
          currency: 'INR',
          receipt: 'cart_${DateTime.now().millisecondsSinceEpoch}',
        );

        final razorpayOrderId = orderRes['razorpayOrderId'];
        final razorpayKeyId = orderRes['keyId'];

        if (razorpayOrderId == null || razorpayKeyId == null) {
          throw Exception(orderRes['message'] ?? 'Invalid payment server response');
        }

        final auth = ref.read(authProvider);
        final user = auth.user ?? {};

        var options = {
          'key': razorpayKeyId,
          'amount': orderRes['amount'],
          'name': 'Retail Verse',
          'description': 'Order Payment',
          'order_id': razorpayOrderId,
          'retry': {'enabled': true, 'max_count': 1},
          'send_sms_hash': true,
          'prefill': {
            'contact': _phoneCtrl.text.isNotEmpty ? _phoneCtrl.text : (user['phone'] ?? ''),
            'email': user['email'] ?? '',
            'name': _nameCtrl.text.isNotEmpty ? _nameCtrl.text : (user['name'] ?? '')
          },
          'theme': {'color': '#163F6B'},
          'external': {
            'wallets': ['paytm']
          }
        };

        _razorpay.open(options);
      } catch (e) {
        _showError('Checkout initiation failed: $e');
        setState(() => _isProcessingRazorpay = false);
      }
      return;
    }

    if (_paymentMethod == 'Card') {
      final cardOk = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => CardPaymentSimulationDialog(amount: updated.total),
      );
      if (cardOk != true || !mounted) return;
    }

    await _executeOrderPlacement();
  }

  Future<void> _executeOrderPlacement({
    String? paymentStatus,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    String? razorpaySignature,
  }) async {
    if (!mounted) return;
    final updated = ref.read(cartProvider);
    final notifier = ref.read(orderCreationProvider.notifier);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success = await notifier.createOrder(
      cartItems: updated.items,
      customerName: updated.customerName.isEmpty ? null : updated.customerName,
      customerPhone: updated.customerPhone.isEmpty ? null : updated.customerPhone,
      customerEmail: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      customerAddress:
          updated.customerAddress.isEmpty ? null : updated.customerAddress,
      orderNotes: updated.orderNotes.isEmpty ? null : updated.orderNotes,
      paymentMethod: _paymentMethod,
      discount: updated.discount,
      taxRate: updated.taxRate,
      extraCharges: updated.extraCharges,
      paymentStatus: paymentStatus,
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
    );

    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    if (!mounted) return;

    if (success) {
      ref.read(cartProvider.notifier).clearCart();
      setState(() => _controllersBound = false);
      
      final createdOrder = ref.read(orderCreationProvider).createdOrder;
      if (createdOrder != null) {
        if (createdOrder.customerPhone != null && createdOrder.customerPhone!.isNotEmpty) {
                // Auto-send SMS invoice after order is placed
                await _notificationService.sendSmsInvoice(phone: createdOrder.customerPhone!, order: createdOrder);
              }
              await showDialog<void>(
          context: context,
          barrierColor: Colors.black.withOpacity(0.8),
          barrierDismissible: false,
          builder: (ctx) => InvoiceDialog(
            order: createdOrder,
            onDone: () {
              Navigator.pop(ctx);
              if (context.mounted) context.go('/pos');
            },
          ),
        );
      } else {
        // No full order object — show quick success and go to POS
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text('Order placed successfully!'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
          context.go('/pos');
        }
      }
    } else {
      final err = ref.read(orderCreationProvider).error ?? 'Unknown error';
      _showError('Order failed: $err');
    }
  }

  void _holdSale() {
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) return;
    ref.read(cartProvider.notifier).updateCustomer(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
        );
    _applyDiscount();
    _applyExtra();
    final snap = ref.read(cartProvider);
    ref.read(posHeldCartProvider.notifier).holdSnapshot(snap);
    ref.read(cartProvider.notifier).clearCart();
    setState(() => _controllersBound = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sale held — recall from the billing screen'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    _syncControllersFromCart(cart);

    final maxW = MediaQuery.sizeOf(context).width >= 600 ? 640.0 : double.infinity;
    final muted = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF9AA5B1)
        : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: Text('Checkout', style: AppTypography.headlineSmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/pos');
            }
          },
        ),
      ),
      body: cart.items.isEmpty
          ? _EmptyCart(onContinue: () => context.pop())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  children: [
                    _CheckoutHero(totalLabel: AppFormatters.formatCurrency(cart.total)),
                    const SizedBox(height: 16),
                    _buildCustomerCard(),
                    const SizedBox(height: 16),
                    Text(
                      '${cart.itemCount} items · ${cart.lineCount} lines',
                      style: AppTypography.bodySmall.copyWith(color: muted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ...cart.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PosCartLineTile(
                          item: item,
                          onIncrement: () => ref
                              .read(cartProvider.notifier)
                              .updateQuantity(
                                item.product.id,
                                item.quantity + 1,
                              ),
                          onDecrement: () => ref
                              .read(cartProvider.notifier)
                              .updateQuantity(
                                item.product.id,
                                item.quantity - 1,
                              ),
                          onRemove: () => ref
                              .read(cartProvider.notifier)
                              .removeItem(item.product.id),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    _SectionTitle('Order summary', Icons.receipt_long_rounded),
                    const SizedBox(height: 8),
                    _SummaryCard(
                      child: Column(
                        children: [
                          _sumRow('Subtotal', AppFormatters.formatCurrency(cart.subtotal)),
                          _sumRow(
                            'Tax (${(cart.taxRate * 100).toStringAsFixed(0)}%)',
                            AppFormatters.formatCurrency(cart.taxAmount),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tax preset',
                            style: AppTypography.labelSmall.copyWith(color: muted),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _TaxChip(
                                label: '0%',
                                selected: cart.taxRate == 0,
                                onTap: () => ref
                                    .read(cartProvider.notifier)
                                    .updateTaxRate(0),
                              ),
                              _TaxChip(
                                label: '5%',
                                selected: (cart.taxRate - 0.05).abs() < 0.001,
                                onTap: () => ref
                                    .read(cartProvider.notifier)
                                    .updateTaxRate(0.05),
                              ),
                              _TaxChip(
                                label: '12%',
                                selected: (cart.taxRate - 0.12).abs() < 0.001,
                                onTap: () => ref
                                    .read(cartProvider.notifier)
                                    .updateTaxRate(0.12),
                              ),
                              _TaxChip(
                                label: '18%',
                                selected: (cart.taxRate - 0.18).abs() < 0.001,
                                onTap: () => ref
                                    .read(cartProvider.notifier)
                                    .updateTaxRate(0.18),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          TextField(
                            controller: _discountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Discount amount',
                              prefixText: '₹ ',
                              isDense: true,
                            ),
                            onEditingComplete: _applyDiscount,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _extraCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Delivery / extra charges',
                              prefixText: '₹ ',
                              isDense: true,
                            ),
                            onEditingComplete: _applyExtra,
                          ),
                          const Divider(height: 24),
                          _sumRow(
                            'Payable',
                            AppFormatters.formatCurrency(cart.total),
                            emphasize: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionTitle('Customer & delivery', Icons.local_shipping_outlined),
                    const SizedBox(height: 8),
                    _SummaryCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Material(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _addressFocus.requestFocus(),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.add_location_alt_outlined,
                                      color: AppColors.primary,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Delivery address',
                                            style: AppTypography.titleSmall
                                                .copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            'Tap to enter street, city, PIN',
                                            style: AppTypography.bodySmall
                                                .copyWith(color: muted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Customer name',
                              isDense: true,
                            ),
                            textCapitalization: TextCapitalization.words,
                            onChanged: (v) => ref
                                .read(cartProvider.notifier)
                                .updateCustomer(name: v),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              isDense: true,
                            ),
                            onChanged: (v) => ref
                                .read(cartProvider.notifier)
                                .updateCustomer(phone: v),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _addressCtrl,
                            focusNode: _addressFocus,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Full address',
                              hintText: 'Street, area, city, postal code',
                              alignLabelWithHint: true,
                              isDense: true,
                            ),
                            onChanged: (v) => ref
                                .read(cartProvider.notifier)
                                .updateCustomer(address: v),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _notesCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Notes / instructions',
                              alignLabelWithHint: true,
                              isDense: true,
                            ),
                            onChanged: (v) => ref
                                .read(cartProvider.notifier)
                                .updateCustomer(notes: v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionTitle('Payment', Icons.payments_rounded),
                    const SizedBox(height: 8),
                    _SummaryCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildPaymentOption(
                            title: 'Razorpay (UPI, Cards, NetBanking)',
                            subtitle: 'Secure online payment',
                            value: 'Razorpay',
                            icon: Icons.account_balance_wallet_rounded,
                          ),
                          const Divider(height: 20),
                          _buildPaymentOption(
                            title: 'Cash on Delivery',
                            subtitle: 'Pay when items are handed over',
                            value: 'Cash',
                            icon: Icons.payments_outlined,
                          ),
                          const Divider(height: 20),
                          _buildPaymentOption(
                            title: 'Card Payment',
                            subtitle: 'External terminal payment',
                            value: 'Card',
                            icon: Icons.credit_card_rounded,
                          ),
                          const Divider(height: 20),
                          _buildPaymentOption(
                            title: 'Direct UPI',
                            subtitle: 'External QR/UPI payment',
                            value: 'UPI',
                            icon: Icons.qr_code_scanner_rounded,
                          ),
                          if (_paymentMethod == 'Cash') ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _cashReceivedCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Amount received',
                                prefixText: '₹ ',
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 8),
                            Builder(builder: (context) {
                              final received = double.tryParse(
                                    _cashReceivedCtrl.text.trim(),
                                  ) ??
                                  0;
                              final change = received - cart.total;
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: change >= 0
                                      ? AppColors.successLight
                                      : AppColors.errorLight,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.borderRadiusMD,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Change / balance',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: change >= 0
                                            ? AppColors.success
                                            : AppColors.error,
                                      ),
                                    ),
                                    Text(
                                      change >= 0
                                          ? AppFormatters.formatCurrency(change)
                                          : 'Short by ${AppFormatters.formatCurrency(-change)}',
                                      style: AppTypography.titleSmall.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: change >= 0
                                            ? AppColors.success
                                            : AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ] else ...[
                            const SizedBox(height: 8),
                            Text(
                              'Complete ${_paymentMethod.toLowerCase()} payment on your terminal, then confirm below.',
                              style: AppTypography.bodySmall.copyWith(
                                color: muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _holdSale,
                      icon: const Icon(Icons.pause_circle_outline_rounded),
                      label: const Text('Hold sale'),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: cart.items.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: AppColors.divider.withOpacity(0.8)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: ref.watch(orderCreationProvider).isLoading || _isProcessingRazorpay
                            ? null
                            : _placeOrder,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.amazonYellow,
                          foregroundColor: Colors.black87,
                          elevation: 1,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: AppColors.amazonOrange, width: 1),
                          ),
                        ),
                        child: ref.watch(orderCreationProvider).isLoading || _isProcessingRazorpay
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black87,
                                ),
                              )
                            : Text(
                                'Place Your Order · ${AppFormatters.formatCurrency(cart.total)}',
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.pop(),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Continue shopping'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _confirmClear,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Clear cart'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCustomerCard() {
    final cart = ref.watch(cartProvider);
    final isWalkIn = cart.customerName.isEmpty && cart.customerPhone.isEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
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
                'Customer Info',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w900),
              ),
              TextButton.icon(
                onPressed: () async {
                  // Navigate to customers screen to select one
                  final nameVal = Uri.encodeComponent(_nameCtrl.text.trim());
                  final phoneVal = Uri.encodeComponent(_phoneCtrl.text.trim());
                  final addressVal = Uri.encodeComponent(_addressCtrl.text.trim());
                  final result = await context.push<CustomerModel>(
                    '/customers?select=true&name=$nameVal&phone=$phoneVal&address=$addressVal',
                  );
                  if (result != null && mounted) {
                    ref.read(cartProvider.notifier).updateCustomer(
                      name: result.name,
                      phone: result.phone,
                      address: result.address ?? '',
                    );
                    setState(() {
                      _nameCtrl.text = result.name;
                      _phoneCtrl.text = result.phone;
                      _emailCtrl.text = result.email ?? '';
                      _addressCtrl.text = result.address ?? '';
                    });
                  }
                },
                icon: const Icon(Icons.person_search_rounded, size: 18),
                label: const Text('Select Customer'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  backgroundColor: AppColors.primary.withOpacity(0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isWalkIn ? Colors.grey.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isWalkIn ? Icons.person_outline_rounded : Icons.person_rounded,
                  color: isWalkIn ? Colors.grey : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isWalkIn ? 'Walk-in Customer' : cart.customerName,
                      style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isWalkIn ? 'No details added yet' : cart.customerPhone,
                      style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (!isWalkIn)
                IconButton(
                  onPressed: () {
                    ref.read(cartProvider.notifier).updateCustomer(
                      name: '',
                      phone: '',
                      address: '',
                    );
                    _nameCtrl.clear();
                    _phoneCtrl.clear();
                    _emailCtrl.clear();
                    _addressCtrl.clear();
                  },
                  icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // Quick Edit Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showCustomerDetailsSheet(context),
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: Text(isWalkIn ? 'Add Walk-in Details' : 'Edit Customer Info'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomerDetailsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Customer Details',
                style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter walk-in customer information for this order',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              _buildSheetField(
                label: 'Customer Name',
                controller: _nameCtrl,
                icon: Icons.person_outline_rounded,
                hint: 'e.g. John Doe',
              ),
              const SizedBox(height: 20),
              _buildSheetField(
                label: 'Phone Number',
                controller: _phoneCtrl,
                icon: Icons.phone_iphone_rounded,
                hint: 'e.g. 9876543210',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              _buildSheetField(
                label: 'Email (Optional)',
                controller: _emailCtrl,
                icon: Icons.email_outlined,
                hint: 'e.g. customer@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              _buildSheetField(
                label: 'Delivery Address',
                controller: _addressCtrl,
                icon: Icons.location_on_outlined,
                hint: 'Street, City, PIN...',
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              _buildSheetField(
                label: 'Order Notes',
                controller: _notesCtrl,
                icon: Icons.note_alt_outlined,
                hint: 'Any special instructions?',
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () async {
                    final name = _nameCtrl.text.trim();
                    final phone = _phoneCtrl.text.trim();
                    final email = _emailCtrl.text.trim();
                    final address = _addressCtrl.text.trim();
                    final notes = _notesCtrl.text.trim();

                    if (name.isEmpty || phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Name and Phone are required'), backgroundColor: AppColors.error),
                      );
                      return;
                    }

                    // 1. Show loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      // 2. Save to Remote DB
                      final token = ref.read(authProvider).token;
                      if (token != null && token.isNotEmpty) {
                        final repo = ref.read(dashboardRepositoryProvider);
                        await repo.addCustomer(
                          token: token,
                          name: name,
                          phone: phone,
                          email: email.isNotEmpty ? email : null,
                          address: address,
                        );
                        ref.invalidate(customersProvider);
                        ref.invalidate(dashboardStatsProvider);
                      }

                      // 3. Update Cart State
                      ref.read(cartProvider.notifier).updateCustomer(
                        name: name,
                        phone: phone,
                        address: address,
                        notes: notes,
                      );

                      if (mounted) {
                        Navigator.pop(context); // Close loading dialog
                        Navigator.pop(context); // Close bottom sheet
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Customer details saved successfully!',
                              style: AppTypography.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.pop(context); // Close loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error saving details: $e'),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Save Customer Details', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20, color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.backgroundSecondary.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
  }) {
    final bool selected = _paymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Radio<String>(
            value: value,
            groupValue: _paymentMethod,
            activeColor: AppColors.amazonOrange,
            onChanged: (val) {
              if (val != null) setState(() => _paymentMethod = val);
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            icon,
            size: 20,
            color: selected ? AppColors.amazonOrange : AppColors.textTertiary,
          ),
        ],
      ),
    );
  }

  Widget _sumRow(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: emphasize
                ? AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                  )
                : AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
          ),
          Text(
            value,
            style: emphasize
                ? AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  )
                : AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Top-of-checkout banner: total + ecommerce-style hierarchy.
class _CheckoutHero extends StatelessWidget {
  const _CheckoutHero({required this.totalLabel});

  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Grand Total:',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Text(
            totalLabel,
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.error,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 72,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'Cart is empty',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add products from the billing screen.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.storefront_rounded),
              label: const Text('Back to products'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.icon);

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TaxChip extends StatelessWidget {
  const _TaxChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryLight.withValues(alpha: 0.35),
      checkmarkColor: AppColors.primary,
    );
  }
}
