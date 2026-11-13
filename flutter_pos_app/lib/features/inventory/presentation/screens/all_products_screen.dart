import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
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

  // ── Hardware Barcode Scanner Engine (Automatic Product Lookup) ──
  final StringBuffer _scannerBuffer = StringBuffer();
  DateTime _lastKeystrokeTime = DateTime.now();
  bool _isCameraScanning = false;

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

    // Only process scanner keys when this screen is the active foreground route
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) {
      return false;
    }

    final now = DateTime.now();
    final delta = now.difference(_lastKeystrokeTime).inMilliseconds;
    _lastKeystrokeTime = now;

    // Fast keystrokes typical of barcode scanners (inter-character delay < 80ms)
    if (delta > 80) {
      _scannerBuffer.clear();
    }

    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_scannerBuffer.length >= 3) {
        final scannedBarcode = _scannerBuffer.toString().trim();
        _scannerBuffer.clear();
        _handleBarcodeSearch(scannedBarcode);
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

  Future<bool> _ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (status.isGranted) return true;
    if (!mounted) return false;
    final blocked = status.isPermanentlyDenied;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        content: Text(
          blocked
              ? 'Camera permission denied permanently. Please enable in Settings.'
              : 'Camera permission is required to scan product barcodes.',
        ),
        backgroundColor: AppColors.error,
        action: blocked
            ? SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              )
            : null,
      ),
    );
    return false;
  }

  Future<void> _scanBarcodeWithCamera() async {
    if (_isCameraScanning) return;
    final hasPermission = await _ensureCameraPermission();
    if (!hasPermission) return;

    setState(() => _isCameraScanning = true);

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 90,
      );

      if (photo != null) {
        final inputImage = InputImage.fromFilePath(photo.path);
        final barcodeScanner = BarcodeScanner();
        final List<Barcode> barcodes = await barcodeScanner.processImage(inputImage);
        await barcodeScanner.close();

        if (barcodes.isNotEmpty) {
          final rawValue = barcodes.first.rawValue;
          if (rawValue != null && rawValue.trim().isNotEmpty) {
            final barcode = rawValue.trim();
            debugPrint('⚡ [Products Camera Scan] Detected barcode: $barcode');
            await _handleBarcodeSearch(barcode);
            return;
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              content: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Barcode could not be detected. Please align barcode properly and try again.'),
                  ),
                ],
              ),
              backgroundColor: Color(0xFFD97706),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error scanning barcode with camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            content: Text('Camera scan error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCameraScanning = false);
      }
    }
  }

  Future<void> _handleBarcodeSearch(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return;

    debugPrint('🔍 [Product Scanner] Searching barcode: $cleanBarcode');

    setState(() {
      _searchController.text = cleanBarcode;
      _searchQuery = cleanBarcode;
    });

    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);

    final products = ref.read(productsProvider).value ?? [];
    Product? matched;
    try {
      matched = products.firstWhere(
        (p) =>
            (p.barcode != null &&
                p.barcode!.trim().toLowerCase() == cleanBarcode.toLowerCase()) ||
            p.sku.trim().toLowerCase() == cleanBarcode.toLowerCase(),
      );
    } catch (_) {
      matched = null;
    }

    if (matched == null) {
      try {
        final repo = ref.read(productRepositoryProvider);
        matched = await repo.getProductByBarcode(cleanBarcode);
        if (matched != null) {
          ref.invalidate(productsProvider);
        }
      } catch (e) {
        debugPrint('⚠️ Remote barcode lookup failed: $e');
      }
    }

    if (!mounted) return;

    if (matched != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Found: ${matched.name} (Qty: ${matched.stock})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFD97706),
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('No product found for barcode: $cleanBarcode'),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Add Product',
            textColor: Colors.white,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddProductScreen(initialBarcode: cleanBarcode),
                ),
              ).then((_) => ref.invalidate(productsProvider));
            },
          ),
        ),
      );
    }
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
                  const ResponsiveMenuButton(color: AppColors.textPrimary),
                  const SizedBox(width: 8),
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
                      tooltip: 'Scan Barcode with Camera',
                      onPressed: _scanBarcodeWithCamera,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundTertiary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: _isCameraScanning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            : const Icon(
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
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) {
                    _handleBarcodeSearch(v.trim());
                  }
                },
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search by name, SKU or barcode...',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                      IconButton(
                        tooltip: 'Scan Barcode',
                        icon: _isCameraScanning
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            : const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 20),
                        onPressed: _scanBarcodeWithCamera,
                      ),
                    ],
                  ),
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
                  if (query.isEmpty) return true;
                  final nameMatch = p.name.toLowerCase().contains(query);
                  final skuMatch = p.sku.toLowerCase().contains(query);
                  final barcodeMatch = p.barcode != null &&
                      (p.barcode!.toLowerCase().trim().contains(query) ||
                          query.contains(p.barcode!.toLowerCase().trim()));
                  return nameMatch || skuMatch || barcodeMatch;
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
                    if (product.marketplaces.isNotEmpty || product.isFlipkartSynced)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (product.isFlipkartActive)
                              _buildMiniMarketplaceBadge(Icons.shopping_bag, const Color(0xFF2874F0), 'Flipkart & Shopsy'),
                            if (product.isMeeshoActive)
                              _buildMiniMarketplaceBadge(Icons.storefront, const Color(0xFFE81B63), 'Meesho'),
                            if (product.isShopifyActive)
                              _buildMiniMarketplaceBadge(Icons.shop_two, const Color(0xFF008060), 'Shopify'),
                            if (product.isZomatoActive)
                              _buildMiniMarketplaceBadge(Icons.restaurant, const Color(0xFFCB202D), 'Zomato'),
                            if (product.isSwiggyActive)
                              _buildMiniMarketplaceBadge(Icons.delivery_dining, const Color(0xFFFC8019), 'Swiggy'),
                            if (product.isEatClubActive)
                              _buildMiniMarketplaceBadge(Icons.flatware, Colors.deepOrange, 'Eat Club'),
                            if (product.isWooCommerceActive)
                              _buildMiniMarketplaceBadge(Icons.language, const Color(0xFF7F54B3), 'WooCommerce'),
                          ],
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

  Widget _buildMiniMarketplaceBadge(IconData icon, Color color, String tooltip) {
    return Container(
      margin: const EdgeInsets.only(right: 3),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Tooltip(
        message: 'Synced to $tooltip',
        child: Icon(icon, color: color, size: 12),
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
