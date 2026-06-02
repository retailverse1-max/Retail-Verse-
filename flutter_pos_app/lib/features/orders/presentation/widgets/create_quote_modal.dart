import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/core/utils/formatters.dart';
import 'package:retail_verse_pos/data/models/cart_model.dart';
import 'package:retail_verse_pos/data/models/product_model.dart';
import 'package:retail_verse_pos/features/pos/providers/order_providers.dart';
import 'package:retail_verse_pos/features/pos/providers/product_providers.dart';

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

  void _generateQuote() async {
    if (_selectedItems.isEmpty) {
      setState(() {
      _errorMessage = 'Please add at least one product.';
    });
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    final success = await ref.read(orderCreationProvider.notifier).createOrder(
          cartItems: _selectedItems,
          customerName: _customerNameController.text.trim(),
          orderNotes: _notesController.text.trim(),
          paymentMethod: 'Cash',
          paymentStatus: 'pending',
          status: 'pending',
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quotation created successfully!')),
      );
      Navigator.of(context).pop();
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth > 800 ? 600.0 : constraints.maxWidth * 0.9;
          return SizedBox(
            width: width,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Create Quotation', style: AppTypography.titleLarge),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Notes
                  _buildSectionTitle('NOTES / MESSAGE'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Add Products Search
                  _buildSectionTitle('ADD PRODUCTS'),
                  const SizedBox(height: 8),
                  productsState.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error loading products', style: TextStyle(color: AppColors.error)),
                    data: (products) {
                      return Autocomplete<Product>(
                        displayStringForOption: (Product option) => option.name,
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<Product>.empty();
                          }
                          return products.where((Product product) {
                            return product.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                product.sku.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        onSelected: (Product selection) {
                          setState(() {
                            final index = _selectedItems.indexWhere((item) => item.product.id == selection.id);
                            if (index >= 0) {
                              final current = _selectedItems[index];
                              _selectedItems[index] = current.copyWith(quantity: current.quantity + 1);
                            } else {
                              _selectedItems.add(CartItem(product: selection, quantity: 1));
                            }
                          });
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              hintText: 'Search products...',
                              hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
                              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary),
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),

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
                                Text('ORDER SUMMARY', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary, letterSpacing: 1.2)),
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
                        const SizedBox(height: 16),
                        if (_selectedItems.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundSecondary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.inventory_2_outlined, color: AppColors.textTertiary, size: 32),
                                ),
                                const SizedBox(height: 12),
                                Text('No products added yet', style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary)),
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
                                        Text(item.product.name, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                                        Text(AppFormatters.formatCurrency(item.product.price), style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: AppColors.textTertiary),
                                        onPressed: () {
                                          setState(() {
                                            if (item.quantity > 1) {
                                              final index = _selectedItems.indexOf(item);
                                              _selectedItems[index] = item.copyWith(quantity: item.quantity - 1);
                                            } else {
                                              _selectedItems.remove(item);
                                            }
                                          });
                                        },
                                      ),
                                      Text('${item.quantity}', style: AppTypography.titleMedium),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                                        onPressed: () {
                                          setState(() {
                                            final index = _selectedItems.indexOf(item);
                                            _selectedItems[index] = item.copyWith(quantity: item.quantity + 1);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      AppFormatters.formatCurrency(item.total),
                                      style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          const Divider(color: AppColors.divider),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                              Text(AppFormatters.formatCurrency(totalAmount), style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900, color: AppColors.primary)),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
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
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text('Generate Quote', style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Cancel', style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  ),
          ],
        ),
      ),
    );
  }, // close builder function
), // close LayoutBuilder
); // close Dialog
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
