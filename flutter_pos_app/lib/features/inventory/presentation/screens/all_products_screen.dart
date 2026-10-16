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
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.archive_outlined, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick Stock Inward', style: AppTypography.titleLarge),
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
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: ProductMediaImage(
                            imageUrl: product.imageUrl,
                            width: 48,
                            height: 48,
                          ),
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
                  style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: qtyController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter quantity received',
                    prefixIcon: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Cost Price per Unit (Optional)',
                  style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: costController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'e.g. 12.50',
                    prefixIcon: const Icon(Icons.currency_rupee_rounded, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Batch No / Invoice Ref (Optional)',
                  style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: batchController,
                  decoration: InputDecoration(
                    hintText: 'e.g. BATCH-2026-X',
                    prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isInwarding
                  ? null
                  : () async {
                      final qty = int.tryParse(qtyController.text.trim());
                      if (qty == null || qty <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter valid inward quantity')),
                        );
                        return;
                      }

                      setModalState(() => isInwarding = true);
                      try {
                        final cost = double.tryParse(costController.text.trim());
                        final repo = ref.read(productRepositoryProvider);
                        await repo.quickInward(
                          productId: product.id,
                          barcode: product.barcode,
                          quantity: qty,
                          costPrice: cost,
                          batchNo: batchController.text.trim(),
                        );

                        ref.invalidate(productsProvider);
                        SystemSound.play(SystemSoundType.click);

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              duration: const Duration(seconds: 3),
                              backgroundColor: AppColors.secondary,
                              behavior: SnackBarBehavior.floating,
                              content: Text('✅ Inwarded $qty pcs to ${product.name}! New Stock: ${product.stock + qty} pcs'),
                            ),
                          );
                        }
                      } catch (e) {
                        setModalState(() => isInwarding = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Inward failed: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isInwarding
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm Inward'),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text('New Barcode Detected'),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddProductScreen(initialBarcode: barcode),
                ),
              );
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Register New Product'),
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
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── PREMIUM APP BAR HEADER ──────────────────────
          _buildHeader(context, canAddProduct, isPhone, isTablet, isDesktop),

          // ── SCROLLABLE CONTENT ──────────────────
          Expanded(
              child: productsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) {
                  final errStr = e.toString();
                  final cleanErr = errStr.contains('SocketException') || errStr.contains('Connection') || errStr.contains('Failed host lookup')
                      ? 'You are offline. Please check your internet connection.'
                      : (errStr.contains('ApiException:') ? errStr.split('ApiException:').last.trim() : errStr);
                  return Center(
                    child: Text('Error: $cleanErr', style: const TextStyle(color: AppColors.error)),
                  );
                },
                data: (products) {
                  final filtered = products.where((p) {
                    final query = _searchQuery.toLowerCase().trim();
                    final matchesSearch = query.isEmpty ||
                        p.name.toLowerCase().contains(query) ||
                        p.sku.toLowerCase().contains(query) ||
                        (p.barcode != null && p.barcode!.toLowerCase().contains(query));
                    return matchesSearch;
                  }).toList();

                  // Stats calculation
                  final totalCount = products.length;
                  final lowStockCount = products.where((p) => p.stock <= 10).length;
                  // Heuristic for best sellers: products with price > 100
                  final bestSellersCount = products.where((p) => p.price > 100).length;

                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(productsProvider.future),
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // SUMMARY CARDS
                        SliverToBoxAdapter(
                          child: _buildSummarySection(
                            totalCount: totalCount,
                            bestSellersCount: bestSellersCount,
                            lowStockCount: lowStockCount,
                            isTablet: isTablet,
                          ),
                        ),

                        // PRODUCT GRID
                        if (filtered.isEmpty)
                          SliverFillRemaining(
                            child: _buildEmptyState(),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.only(
                              left: isDesktop ? 32 : (isTablet ? 24 : 16),
                              right: isDesktop ? 32 : (isTablet ? 24 : 16),
                              top: 16,
                              bottom: 100,
                            ),
                            sliver: SliverGrid(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isDesktop ? 4 : (isTablet ? 3 : 2),
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: isDesktop ? 0.72 : (isTablet ? 0.75 : (isPhone && screenWidth < 380 ? 0.62 : 0.68)),
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

  Widget _buildHeader(BuildContext context, bool canAddProduct, bool isPhone, bool isTablet, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isPhone ? 16 : 24,
        MediaQuery.of(context).padding.top + 16,
        isPhone ? 16 : 24,
        20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const ResponsiveMenuButton(),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Products',
                        style: AppTypography.headlineMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Manage your store products',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
              if (canAddProduct)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Quick Inward Button
                    IconButton(
                      tooltip: 'Quick Inward Scanner',
                      onPressed: () {
                        final bcController = TextEditingController();
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('Scan or Enter Barcode for Inward'),
                            content: TextField(
                              controller: bcController,
                              autofocus: true,
                              decoration: const InputDecoration(
                                hintText: 'Scan item barcode...',
                                prefixIcon: Icon(Icons.qr_code_scanner_rounded),
                              ),
                              onSubmitted: (v) {
                                Navigator.pop(ctx);
                                if (v.trim().isNotEmpty) {
                                  _onInventoryBarcodeScanned(v.trim());
                                }
                              },
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  if (bcController.text.trim().isNotEmpty) {
                                    _onInventoryBarcodeScanned(bcController.text.trim());
                                  }
                                },
                                child: const Text('Lookup'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 22),
                      ),
                    ),
                    const SizedBox(width: 8),
                    isPhone
                        // Small phone: icon only
                        ? IconButton(
                            onPressed: () => context.push('/inventory/categories/add'),
                            icon: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                            ),
                          )
                        // Tablet/Desktop: full button
                        : Bounceable(
                            onTap: () => context.push('/inventory/categories/add'),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 14 : 18,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    isTablet ? 'Add' : 'Add Product',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search by name or SKU...',
          hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          _buildSummaryCard(
            'Total Products',
            totalCount.toString(),
            Icons.inventory_2_rounded,
            AppColors.primary,
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            'Best Sellers',
            bestSellersCount.toString(),
            Icons.trending_up_rounded,
            AppColors.success,
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            'Low Stock',
            lowStockCount.toString(),
            Icons.warning_amber_rounded,
            AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
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
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE
            Expanded(
              flex: 12,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: AppColors.backgroundSecondary,
                      child: ProductMediaImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (isOutOfStock)
                      Container(
                        color: Colors.black.withOpacity(0.4),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(8),
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
                    
                    // Flipkart Sync Badge
                    if (product.isFlipkartSynced)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                            ],
                          ),
                          child: const Icon(Icons.shopping_bag, color: Colors.blue, size: 16),
                        ),
                      ),

                    // Price Tag
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
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
                      color: AppColors.primary.withOpacity(0.7),
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
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
          Icon(Icons.inventory_2_outlined, size: 60, color: AppColors.textTertiary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: AppTypography.titleMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search query',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
