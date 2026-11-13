import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/core/utils/formatters.dart';
import 'package:retail_verse_pos/data/models/cart_model.dart';
import 'package:retail_verse_pos/data/models/product_model.dart';
import 'package:retail_verse_pos/features/pos/providers/order_providers.dart';
import 'package:retail_verse_pos/features/pos/providers/product_providers.dart';
import 'package:retail_verse_pos/routes/app_router.dart';

class CreateQuoteModal extends ConsumerStatefulWidget {
  const CreateQuoteModal({super.key});

  @override
  ConsumerState<CreateQuoteModal> createState() => _CreateQuoteModalState();
}

class _CreateQuoteModalState extends ConsumerState<CreateQuoteModal> {
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final List<CartItem> _selectedItems = [];
  String? _errorMessage;

  void _addProduct(Product selection) {
    setState(() {
      _errorMessage = null;
      final index = _selectedItems.indexWhere((item) => item.product.id == selection.id);
      if (index >= 0) {
        final current = _selectedItems[index];
        _selectedItems[index] = current.copyWith(quantity: current.quantity + 1);
      } else {
        _selectedItems.add(CartItem(product: selection, quantity: 1));
      }
    });
  }

  void _decrementProduct(CartItem item) {
    setState(() {
      if (item.quantity > 1) {
        final index = _selectedItems.indexOf(item);
        if (index >= 0) {
          _selectedItems[index] = item.copyWith(quantity: item.quantity - 1);
        }
      } else {
        _selectedItems.remove(item);
      }
    });
  }

  void _incrementProduct(CartItem item) {
    setState(() {
      final index = _selectedItems.indexOf(item);
      if (index >= 0) {
        _selectedItems[index] = item.copyWith(quantity: item.quantity + 1);
      }
    });
  }

  void _removeProduct(CartItem item) {
    setState(() {
      _selectedItems.remove(item);
    });
  }

  void _generateQuote() async {
    if (_selectedItems.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one product from the dropdown.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    final custName = _customerNameController.text.trim();

    final success = await ref.read(orderCreationProvider.notifier).createOrder(
          cartItems: _selectedItems,
          customerName: custName.isNotEmpty ? custName : 'Walk-in Customer',
          orderNotes: _notesController.text.trim(),
          paymentMethod: 'Cash',
          paymentStatus: 'pending',
          status: 'pending',
        );

    if (success && mounted) {
      ref.invalidate(ordersListProvider);
      try { ref.invalidate(saOrdersListProvider); } catch (_) {}

      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          content: Text('Quotation generated successfully!'),
        ),
      );
      Navigator.of(context).pop(true);
    } else if (mounted) {
      setState(() {
        _errorMessage = ref.read(orderCreationProvider).error ?? 'Failed to create quote. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productsProvider);
    final isCreating = ref.watch(orderCreationProvider).isLoading;
    final totalItems = _selectedItems.fold<int>(0, (sum, item) => sum + item.quantity);
    final totalAmount = _selectedItems.fold<double>(0.0, (sum, item) => sum + item.total);

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth > 800 ? 600.0 : constraints.maxWidth * 0.95;
            return SizedBox(
              width: width,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Create Quotation', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700)),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Customer Name
                    _buildSectionTitle('CUSTOMER NAME'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _customerNameController,
                      decoration: InputDecoration(
                        hintText: 'Enter customer name',
                        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.cardBorder.withOpacity(0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.cardBorder.withOpacity(0.5)),
                        ),
                        filled: true,
                        fillColor: AppColors.backgroundSecondary.withOpacity(0.3),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Notes
                    _buildSectionTitle('NOTES / MESSAGE'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Add special instructions or terms...',
                        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.cardBorder.withOpacity(0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.cardBorder.withOpacity(0.5)),
                        ),
                        filled: true,
                        fillColor: AppColors.backgroundSecondary.withOpacity(0.3),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Select Product Dropdown
                    _buildSectionTitle('SELECT PRODUCT'),
                    const SizedBox(height: 8),

                    productsState.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Error loading products: $e',
                          style: const TextStyle(color: AppColors.error, fontSize: 12),
                        ),
                      ),
                      data: (products) {
                        if (products.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSecondary.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
                            ),
                            child: const Text(
                              'No products available in inventory.',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          );
                        }

                        return DropdownButtonFormField<String>(
                          value: null,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 26),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          decoration: InputDecoration(
                            hintText: 'Select product from dropdown...',
                            hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.w600),
                            prefixIcon: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.primary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: AppColors.cardBorder.withOpacity(0.5)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: AppColors.cardBorder.withOpacity(0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.primary, width: 2),
                            ),
                            filled: true,
                            fillColor: AppColors.backgroundSecondary.withOpacity(0.3),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          items: products.map((p) {
                            return DropdownMenuItem<String>(
                              value: p.id,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    AppFormatters.formatCurrency(p.price),
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 13),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: p.stock > 0 ? AppColors.success.withOpacity(0.12) : AppColors.error.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Stock: ${p.stock}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: p.stock > 0 ? AppColors.success : AppColors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (selectedId) {
                            if (selectedId != null) {
                              final p = products.firstWhere((item) => item.id == selectedId);
                              _addProduct(p);
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 18),

                    // Order Summary Card
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(16),
                        color: AppColors.backgroundSecondary.withOpacity(0.2),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.textSecondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'ORDER SUMMARY',
                                    style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary, letterSpacing: 1.2),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBorder,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('$totalItems items', style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (_selectedItems.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: const BoxDecoration(
                                      color: AppColors.backgroundSecondary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.inventory_2_outlined, color: AppColors.textTertiary, size: 28),
                                  ),
                                  const SizedBox(height: 10),
                                  Text('No products added yet', style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  const Text('Select products from the dropdown above to add them to this quote', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                                ],
                              ),
                            )
                          else ...[
                            ..._selectedItems.map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.product.name,
                                            style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            AppFormatters.formatCurrency(item.product.price),
                                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.textTertiary, size: 22),
                                          onPressed: () => _decrementProduct(item),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        Text('${item.quantity}', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 22),
                                          onPressed: () => _incrementProduct(item),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                          onPressed: () => _removeProduct(item),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 65,
                                      child: Text(
                                        AppFormatters.formatCurrency(item.total),
                                        style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const Divider(color: AppColors.divider),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                                Text(
                                  AppFormatters.formatCurrency(totalAmount),
                                  style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.error.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: AppTypography.bodySmall.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    FilledButton(
                      onPressed: isCreating ? null : _generateQuote,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isCreating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_rounded, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Generate Quote',
                                  style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTypography.labelSmall.copyWith(
        color: AppColors.textSecondary,
        letterSpacing: 1.2,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
