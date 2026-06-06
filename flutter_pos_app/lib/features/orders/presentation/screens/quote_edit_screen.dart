import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/core/utils/formatters.dart';
import 'package:retail_verse_pos/data/models/order_model.dart';
import 'package:retail_verse_pos/data/models/product_model.dart';
import 'package:retail_verse_pos/features/pos/providers/order_providers.dart';
import 'package:retail_verse_pos/features/pos/providers/product_providers.dart';

class QuoteEditScreen extends ConsumerStatefulWidget {
  final Order order;
  const QuoteEditScreen({super.key, required this.order});

  @override
  ConsumerState<QuoteEditScreen> createState() => _QuoteEditScreenState();
}

class _QuoteEditScreenState extends ConsumerState<QuoteEditScreen> {
  late List<OrderItem> _items;
  double _discount = 0.0;
  double _extraCharges = 0.0;
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _extraChargesController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _productSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _items = List<OrderItem>.from(widget.order.items);
    _discount = widget.order.discount;
    _extraCharges = widget.order.extraCharges;
    _discountController.text = _discount > 0 ? _discount.toStringAsFixed(2) : '';
    _extraChargesController.text = _extraCharges > 0 ? _extraCharges.toStringAsFixed(2) : '';
  }

  @override
  void dispose() {
    _discountController.dispose();
    _extraChargesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  double get _subtotal {
    return _items.fold<double>(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  double get _tax {
    return _subtotal * 0.18;
  }

  double get _total {
    final t = _subtotal + _tax + _extraCharges - _discount;
    return t < 0 ? 0.0 : t;
  }

  void _addItem(Product product) {
    setState(() {
      final index = _items.indexWhere((item) => item.product.id == product.id);
      if (index >= 0) {
        final existing = _items[index];
        _items[index] = OrderItem(
          product: existing.product,
          quantity: existing.quantity + 1,
          price: existing.price,
          total: existing.price * (existing.quantity + 1),
        );
      } else {
        _items.add(OrderItem(
          product: product,
          quantity: 1,
          price: product.price,
          total: product.price,
        ));
      }
      _productSearchQuery = '';
      _searchController.clear();
    });
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final currentQty = _items[index].quantity;
      final newQty = currentQty + delta;
      if (newQty <= 0) {
        _items.removeAt(index);
      } else {
        final item = _items[index];
        _items[index] = OrderItem(
          product: item.product,
          quantity: newQty,
          price: item.price,
          total: item.price * newQty,
        );
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _saveQuote() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot save an empty quote'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    // Adding a small delay of 0.5 seconds as requested
    final results = await Future.wait([
      ref.read(orderCreationProvider.notifier).updateOrder(
        orderId: widget.order.id,
        items: _items,
        status: 'pending',
        paymentMethod: widget.order.paymentMethod,
        paymentStatus: 'pending',
        converted: false,
        customerName: widget.order.customerName,
        customerPhone: widget.order.customerPhone,
        customerEmail: widget.order.customerEmail,
        customerAddress: widget.order.customerAddress,
        orderNotes: widget.order.notes,
        discount: _discount,
        extraCharges: _extraCharges,
      ),
      Future.delayed(const Duration(milliseconds: 500)),
    ]);
    
    final success = results[0] as bool;

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Pop loading dialog
    }

    if (success) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote updated successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop(true); // Return success to reload details
      }
    } else {
      if (context.mounted) {
        final errorMsg = ref.read(orderCreationProvider).error ?? 'Failed to update quote';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg.toString().contains('SocketException') || errorMsg.toString().contains('Failed host lookup') ? 'You are offline. Please check your internet connection.' : 'Error: $errorMsg'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Edit Quote', style: AppTypography.headlineMedium),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Card
                    _buildCustomerCard(),
                    const SizedBox(height: 16),

                    // Product search bar to add items
                    _buildProductSearchBar(productsAsync),
                    const SizedBox(height: 16),

                    // Current Items Title
                    Text(
                      'Quote Items',
                      style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // Items List
                    _buildItemsList(),
                    const SizedBox(height: 16),

                    // Bargaining and Totals Card
                    _buildTotalsCard(),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.order.customerName ?? 'Walk-In Customer',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (widget.order.customerPhone != null && widget.order.customerPhone!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone_outlined, color: AppColors.textSecondary, size: 16),
                const SizedBox(width: 8),
                Text(
                  widget.order.customerPhone!,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
          if (widget.order.customerEmail != null && widget.order.customerEmail!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.email_outlined, color: AppColors.textSecondary, size: 16),
                const SizedBox(width: 8),
                Text(
                  widget.order.customerEmail!,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductSearchBar(AsyncValue<List<Product>> productsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 6,
              )
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _productSearchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search product to add to Quote...',
              hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (_productSearchQuery.isNotEmpty)
          productsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Error loading products: $e'),
            ),
            data: (products) {
              final matches = products
                  .where((p) =>
                      p.name.toLowerCase().contains(_productSearchQuery.toLowerCase()) ||
                      p.sku.toLowerCase().contains(_productSearchQuery.toLowerCase()))
                  .take(5)
                  .toList();

              if (matches.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No products match search'),
                );
              }

              return Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final p = matches[index];
                    return ListTile(
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('SKU: ${p.sku} | Price: ${AppFormatters.formatCurrency(p.price)}'),
                      trailing: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                      onTap: () => _addItem(p),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            Icon(Icons.shopping_bag_outlined, color: AppColors.textTertiary, size: 48),
            const SizedBox(height: 12),
            Text(
              'No items in this quote',
              style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppFormatters.formatCurrency(item.price),
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.textSecondary),
                    onPressed: () => _updateQuantity(index, -1),
                  ),
                  Text(
                    item.quantity.toString(),
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                    onPressed: () => _updateQuantity(index, 1),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                onPressed: () => _removeItem(index),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotalsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Bargain / Apply Discount',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _extraChargesController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              setState(() {
                _extraCharges = double.tryParse(v) ?? 0.0;
              });
            },
            decoration: InputDecoration(
              labelText: 'Extra Charges (Rs.)',
              hintText: 'e.g. 50',
              prefixText: '₹ ',
              labelStyle: TextStyle(color: AppColors.primary),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.cardBorder, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _discountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              setState(() {
                _discount = double.tryParse(v) ?? 0.0;
              });
            },
            decoration: InputDecoration(
              labelText: 'Discount Amount (Rs.)',
              hintText: 'e.g. 150',
              prefixText: '₹ ',
              labelStyle: TextStyle(color: AppColors.primary),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.cardBorder, width: 1.5),
              ),
            ),
          ),
          const Divider(height: 24, color: AppColors.divider),
          _buildRow('Subtotal', AppFormatters.formatCurrency(_subtotal)),
          const SizedBox(height: 6),
          _buildRow('Tax (18%)', AppFormatters.formatCurrency(_tax)),
          if (_extraCharges > 0) ...[
            const SizedBox(height: 6),
            _buildRow('Extra Charges', '+ ${AppFormatters.formatCurrency(_extraCharges)}'),
          ],
          if (_discount > 0) ...[
            const SizedBox(height: 6),
            _buildRow('Discount', '- ${AppFormatters.formatCurrency(_discount)}', isNegative: true),
          ],
          const Divider(height: 24, color: AppColors.divider),
          _buildRow('Grand Total', AppFormatters.formatCurrency(_total), isTotal: true),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isTotal = false, bool isNegative = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)
              : AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: isTotal
              ? AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)
              : AppTypography.bodyMedium.copyWith(
                  color: isNegative ? AppColors.error : AppColors.textPrimary,
                  fontWeight: isNegative ? FontWeight.bold : FontWeight.normal,
                ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _saveQuote,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Quote'),
            ),
          ),
        ],
      ),
    );
  }
}
