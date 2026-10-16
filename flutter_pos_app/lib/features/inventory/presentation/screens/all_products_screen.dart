import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/product_media_image.dart';
import '../../../../core/widgets/common/bounceable.dart';
import '../../../../data/models/product_model.dart';
import '../../../pos/providers/product_providers.dart';
import '../../../../core/navigation/role_nav.dart';
import '../../../auth/providers/auth_provider.dart';
import 'package:retail_verse_pos/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'add_product_screen.dart';

class AllProductsScreen extends ConsumerStatefulWidget {
  const AllProductsScreen({super.key});

  @override
  ConsumerState<AllProductsScreen> createState() => _AllProductsScreenState();
}

class _AllProductsScreenState extends ConsumerState<AllProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Hardware Barcode Scanner Engine (Shipment Inwarding) ──
  final StringBuffer _scannerBuffer = StringBuffer();
  DateTime _lastKeystrokeTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHardwareScanKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareScanKey);
    _searchController.dispose();
    super.dispose();
  }

  bool _handleHardwareScanKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final now = DateTime.now();
    final delta = now.difference(_lastKeystrokeTime).inMilliseconds;
    _lastKeystrokeTime = now;

    if (delta > 60) {
      _scannerBuffer.clear();
    }

    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_scannerBuffer.length >= 3) {
        final scannedBarcode = _scannerBuffer.toString().trim();
        _scannerBuffer.clear();
        _onInventoryBarcodeScanned(scannedBarcode);
        return true;
      }
      _scannerBuffer.clear();
    } else {
      final character = event.character;
      if (character != null && character.isNotEmpty && character.codeUnitAt(0) >= 32) {
        _scannerBuffer.write(character);
      }
    }
    return false;
  }

  Future<void> _onInventoryBarcodeScanned(String barcode) async {
    debugPrint('📦 [Inventory Scanner] Inward barcode: $barcode');
    if (!mounted || barcode.isEmpty) return;

    final productsAsync = ref.read(productsProvider);
    final products = productsAsync.value ?? [];

    Product? matchedProduct;
    try {
      matchedProduct = products.firstWhere(
        (p) => p.barcode != null && p.barcode!.trim() == barcode,
      );
    } catch (_) {
      matchedProduct = null;
    }

    if (matchedProduct == null) {
      try {
        final repo = ref.read(productRepositoryProvider);
        matchedProduct = await repo.getProductByBarcode(barcode);
      } catch (_) {}
    }

    if (matchedProduct != null) {
      SystemSound.play(SystemSoundType.click);
      _showQuickInwardDialog(matchedProduct);
    } else {
      _showUnregisteredBarcodeDialog(barcode);
    }
  }

  void _showQuickInwardDialog(Product product) {
    final qtyController = TextEditingController(text: '10');
    final costController = TextEditingController(
      text: product.cost > 0 ? product.cost.toStringAsFixed(2) : '',
    );
    final batchController = TextEditingController();
    bool isInwarding = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.archive_outlined, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Stock Inward',
                      style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      product.barcode != null && product.barcode!.isNotEmpty
                          ? 'Barcode: ${product.barcode}'
                          : 'SKU: ${product.sku}',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: ProductMediaImage(imageUrl: product.imageUrl, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text('Current Stock: ', style: AppTypography.bodySmall),
                                Text(
                                  '${product.stock} pcs',
                                  style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: product.stock <= 10 ? AppColors.error : AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Inward Quantity *',
                  style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: qtyController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter quantity received',
                    prefixIcon: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Cost Price per Unit (Optional)',
                  style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: costController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'e.g. 12.50',
                    prefixIcon: const Icon(Icons.currency_rupee_rounded, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Batch No / Invoice Ref (Optional)',
                  style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: batchController,
                  decoration: InputDecoration(
                    hintText: 'e.g. BATCH-2026-X',
                    prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isInwarding ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            ),
            ElevatedButton(
              onPressed: isInwarding
                  ? null
                  : () async {
                      final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                      if (qty <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 2),
                            content: const Text('Please enter a valid inward quantity'),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                        return;
                      }

                      setModalState(() => isInwarding = true);

                      try {
                        final repo = ref.read(productRepositoryProvider);
                        final newStock = product.stock + qty;
                        final cost = double.tryParse(costController.text.trim());

                        await repo.updateProduct(
                          id: product.id,
                          stock: newStock,
                          cost: cost != null && cost > 0 ? cost : product.cost,
                        );

                        ref.invalidate(productsProvider);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              duration: const Duration(seconds: 2),
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Inwarded +$qty pcs for ${product.name}! Stock is now $newStock pcs.'),
                                ],
                              ),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      } catch (e) {
                        setModalState(() => isInwarding = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              duration: const Duration(seconds: 2),
                              content: Text('Failed to update stock: $e'),
                              backgroundColor: AppColors.error,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isInwarding
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm Inward', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnregisteredBarcodeDialog(String barcode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.help_outline_rounded, color: Color(0xFFD97706), size: 24),
            ),
            const SizedBox(width: 12),
            Text('Barcode Not Found', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scanned Barcode: $barcode', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('This product does not exist in your inventory database yet. Would you like to register it as a new product?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddProductScreen(initialBarcode: barcode),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Register New Product', style: TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _showManualInwardBarcodeDialog() {
    final bcController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text(
          'Quick Inward Scanner',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: bcController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Scan or type barcode...',
            prefixIcon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
          onSubmitted: (v) {
            Navigator.pop(ctx);
            if (v.trim().isNotEmpty) {
              _onInventoryBarcodeScanned(v.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (bcController.text.trim().isNotEmpty) {
                _onInventoryBarcodeScanned(bcController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Lookup', style: TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    final isDesktop = screenWidth >= 900;
    final role = effectiveUserRole(ref.watch(authProvider).user);
    final canAddProduct = role == 'admin' || role == 'inventory_manager';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundTertiary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Navigator.of(context).canPop()
                        ? InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: AppColors.textPrimary,
                                size: 20,
                              ),
                            ),
                          )
                        : const ResponsiveMenuButton(color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Products',
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Enterprise Stock • Real-time Sync',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (canAddProduct) ...[
                    IconButton(
                      tooltip: 'Quick Inward Scanner',
                      onPressed: _showManualInwardBarcodeDialog,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundTertiary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AddProductScreen()),
                        );
                        ref.invalidate(productsProvider);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        'Add Product',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search by name, SKU or barcode...',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
              ),
              error: (e, _) {
                final errStr = e.toString();
                final cleanErr = errStr.contains('SocketException') ||
                        errStr.contains('Connection') ||
                        errStr.contains('Failed host lookup')
                    ? 'You are offline. Please check your internet connection.'
                    : (errStr.contains('ApiException:') ? errStr.split('ApiException:').last.trim() : errStr);
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'Error: $cleanErr',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
              data: (products) {
                final filtered = products.where((p) {
                  final query = _searchQuery.toLowerCase().trim();
                  return query.isEmpty ||
                      p.name.toLowerCase().contains(query) ||
                      p.sku.toLowerCase().contains(query) ||
                      (p.barcode != null && p.barcode!.toLowerCase().contains(query));
                }).toList();

                final totalCount = products.length;
                final lowStockCount = products.where((p) => p.stock <= 10).length;
                final bestSellersCount = products.where((p) => p.price > 100).length;

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => ref.refresh(productsProvider.future),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildSummarySection(
                          totalCount: totalCount,
                          bestSellersCount: bestSellersCount,
                          lowStockCount: lowStockCount,
                          isTablet: isTablet,
                        ),
                      ),
                      if (filtered.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.only(
                            left: isDesktop ? 32 : (isTablet ? 24 : 16),
                            right: isDesktop ? 32 : (isTablet ? 24 : 16),
                            top: 8,
                            bottom: 100,
                          ),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isDesktop ? 4 : (isTablet ? 3 : 2),
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: isDesktop ? 0.76 : (isTablet ? 0.78 : (isPhone && screenWidth < 380 ? 0.65 : 0.72)),
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildProductCard(filtered[index]),
                              childCount: filtered.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection({
    required int totalCount,
    required int bestSellersCount,
    required int lowStockCount,
    required bool isTablet,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          _buildSummaryCard(
            'Total Products',
            totalCount.toString(),
            Icons.inventory_2_rounded,
            AppColors.primary,
            const Color(0xFFEFF6FF),
          ),
          const SizedBox(width: 10),
          _buildSummaryCard(
            'Best Sellers',
            bestSellersCount.toString(),
            Icons.trending_up_rounded,
            AppColors.success,
            const Color(0xFFECFDF5),
          ),
          const SizedBox(width: 10),
          _buildSummaryCard(
            'Low Stock',
            lowStockCount.toString(),
            Icons.warning_amber_rounded,
            AppColors.error,
            const Color(0xFFFEF2F2),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final isOutOfStock = product.stock == 0;

    return Bounceable(
      onTap: () => context.push('/pos/product', extra: product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE
            Expanded(
              flex: 11,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: const Color(0xFFF8FAFC),
                      child: ProductMediaImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (isOutOfStock)
                      Container(
                        color: Colors.black.withValues(alpha: 0.35),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'OUT OF STOCK',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (product.isFlipkartSynced)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: const Icon(Icons.shopping_bag, color: Colors.blue, size: 14),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          AppFormatters.formatCurrency(product.price),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // INFO
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.category.toUpperCase(),
                    style: TextStyle(
                      color: AppColors.primary.withValues(alpha: 0.8),
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product.name,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'STOCK',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 7,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${product.stock} units',
                            style: TextStyle(
                              color: isOutOfStock ? AppColors.error : AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 16),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 54,
              color: AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No products found',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search query',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
