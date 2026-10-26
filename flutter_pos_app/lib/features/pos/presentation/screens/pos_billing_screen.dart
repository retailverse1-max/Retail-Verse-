import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/widgets/product_media_image.dart';
import 'package:retail_verse_pos/core/widgets/product_thumbnail.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/data/models/product_model.dart';
import 'package:retail_verse_pos/data/models/cart_model.dart';
import 'package:retail_verse_pos/data/remote/payment_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../settings/providers/pos_settings_provider.dart';
import '../../providers/order_providers.dart';
import '../../providers/product_providers.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'pos_product_detail_screen.dart';
import '../widgets/invoice_dialog.dart';


/// Cart item for POS
class POSCartItem {
  final Product product;
  int quantity;

  POSCartItem({required this.product, this.quantity = 1});

  double get total => product.price * quantity;

  double get maxQuantity => product.stock.toDouble();
}

/// Production POS Billing Screen with Real Backend Integration
class PosBillingScreen extends ConsumerStatefulWidget {
  const PosBillingScreen({super.key});

  @override
  ConsumerState<PosBillingScreen> createState() => _PosBillingScreenState();
}

class _PosBillingScreenState extends ConsumerState<PosBillingScreen> {
  // State variables
  List<Product> _products = [];
  List<String> _categories = ['All'];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<POSCartItem> _cart = [];
  bool _isLoading = true;
  String? _error;
  String _selectedPaymentMethod = 'Cash';
  bool _isProcessingOrder = false;

  late Razorpay _razorpay;
  final PaymentService _paymentService = PaymentService();

  // ── Hardware Barcode Scanner Engine (e.g. Helett HT20 USB / 2.4G HID) ──
  final StringBuffer _scannerBuffer = StringBuffer();
  DateTime _lastKeystrokeTime = DateTime.now();

  bool _handleHardwareScanKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Only process scanner keys when POS billing screen is the active foreground route
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) {
      return false;
    }

    // Respect user's Barcode Scanner toggle in Settings
    final posSettings = ref.read(posSettingsProvider);
    if (!posSettings.barcodeScannerEnabled) return false;

    final now = DateTime.now();
    final delta = now.difference(_lastKeystrokeTime).inMilliseconds;
    _lastKeystrokeTime = now;

    // Normal human typing gap is 100ms+. Scanners stream at 10-30ms.
    if (delta > 60) {
      _scannerBuffer.clear();
    }

    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_scannerBuffer.length >= 3) {
        final scannedBarcode = _scannerBuffer.toString().trim();
        _scannerBuffer.clear();
        _onHardwareBarcodeScanned(scannedBarcode);
        return true; // Handled, prevent default form submit
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

  Future<void> _onHardwareBarcodeScanned(String barcode) async {
    debugPrint('⚡ [Hardware Scanner] Scanned barcode: $barcode');
    if (!mounted || barcode.isEmpty) return;

    // 1. Existing Cart Check (0ms local state delay)
    final existingCartIndex = _cart.indexWhere(
      (item) => item.product.barcode != null && item.product.barcode!.trim() == barcode,
    );

    if (existingCartIndex != -1) {
      final item = _cart[existingCartIndex];
      if (item.quantity < item.product.stock) {
        setState(() {
          item.quantity++;
        });
        SystemSound.play(SystemSoundType.click);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1200),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${item.product.name} × ${item.quantity} in cart'),
                ),
              ],
            ),
            backgroundColor: AppColors.secondary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text('Cannot exceed available stock (${item.product.stock}) for ${item.product.name}'),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
      return;
    }

    // 2. Check in-memory products list
    Product? matchedProduct;
    try {
      matchedProduct = _products.firstWhere(
        (p) => p.barcode != null && p.barcode!.trim() == barcode,
      );
    } catch (_) {
      matchedProduct = null;
    }

    // 3. If not in memory, query backend API
    if (matchedProduct == null) {
      try {
        final repo = ref.read(productRepositoryProvider);
        matchedProduct = await repo.getProductByBarcode(barcode);
      } catch (e) {
        debugPrint('⚠️ Barcode API lookup failed: $e');
      }
    }

    if (matchedProduct != null) {
      _addToCart(matchedProduct);
      SystemSound.play(SystemSoundType.click);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Added ${matchedProduct.name} to cart (₹${matchedProduct.price.toStringAsFixed(2)})'),
              ),
            ],
          ),
          backgroundColor: AppColors.secondary,
        ),
      );
    } else {
      // Backend / Console log only, suppressed from frontend UI
      debugPrint('⚡ [POS Billing Hardware Scanner] Barcode "$barcode" not found in inventory');
    }
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHardwareScanKey);
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareScanKey);
    _razorpay.clear();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('🔄 Fetching products from backend...');
      final repository = ref.read(productRepositoryProvider);
      final products = await repository.getAllProducts();

      setState(() {
        _products = products;

        // Extract unique categories from real products
        final categorySet = <String>{};
        for (var product in _products) {
          if (product.category.trim().isNotEmpty) {
            categorySet.add(product.category);
          }
        }
        _categories = ['All', ...categorySet];

        _isLoading = false;
        debugPrint(
          '✅ Loaded ${_products.length} products with ${_categories.length - 1} categories',
        );
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });

      debugPrint('❌ Error loading products: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(seconds: 2),
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to load products. Please check your connection.',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<Product> get _filteredProducts {
    return _products.where((product) {
      final matchesCategory =
          _selectedCategory == 'All' ||
          product.category.toLowerCase() == _selectedCategory.toLowerCase();
      final query = _searchQuery.toLowerCase().trim();
      final matchesSearch =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query) ||
          (product.barcode != null && product.barcode!.toLowerCase().contains(query));
      return matchesCategory && matchesSearch;
    }).toList();
  }

  /// Adds [quantity] units to the billing cart (merges with an existing line if any).
  void _addProductWithQuantity(Product product, int quantity) {
    if (!product.isInStock || quantity < 1) return;

    setState(() {
      final existingIndex = _cart.indexWhere(
        (item) => item.product.id == product.id,
      );
      if (existingIndex != -1) {
        final next = _cart[existingIndex].quantity + quantity;
        if (next <= product.stock) {
          _cart[existingIndex].quantity = next;
          debugPrint(
            '✅ Updated ${product.name} qty → ${_cart[existingIndex].quantity}',
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(duration: const Duration(seconds: 2),
              content: Text(
                'Cannot add more than available stock (${product.stock})',
              ),
              backgroundColor: AppColors.secondary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        final q = quantity.clamp(1, product.stock);
        _cart.add(POSCartItem(product: product, quantity: q));
        debugPrint('✅ Added ${product.name} × $q to cart');
      }
    });
  }

  void _addToCart(Product product) => _addProductWithQuantity(product, 1);

  /// Opens detail with [Navigator] (not GoRouter `/pos/product`) so it works even when this
  /// screen is not the `/pos` shell route — `context.push('/pos/product')` can fail or show
  /// the wrong stack next to [POSScreen].
  void _openProductDetail(Product product) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => PosProductDetailScreen(
          product: product,
          onAddToBilling: _addProductWithQuantity,
        ),
      ),
    );
  }

  void _increaseQuantity(String productId) {
    setState(() {
      final item = _cart.firstWhere((item) => item.product.id == productId);
      if (item.quantity < item.product.stock) {
        item.quantity++;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(seconds: 2),
            content: Text(
              'Cannot exceed available stock (${item.product.stock})',
            ),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _decreaseQuantity(String productId) {
    setState(() {
      final index = _cart.indexWhere((item) => item.product.id == productId);
      if (index != -1) {
        if (_cart[index].quantity > 1) {
          _cart[index].quantity--;
        } else {
          _cart.removeAt(index);
          debugPrint('🗑️ Removed item from cart');
        }
      }
    });
  }

  void _removeFromCart(String productId) {
    setState(() {
      _cart.removeWhere((item) => item.product.id == productId);
    });
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
    });
  }

  double get _subtotal {
    return _cart.fold(0, (sum, item) => sum + item.total);
  }

  double get _tax => _subtotal * 0.18; // 18% GST

  double get _total => _subtotal + _tax;

  int get _totalItems => _cart.fold(0, (sum, item) => sum + item.quantity);

  Future<void> _placeOrder({String status = 'completed'}) async {
    if (_cart.isEmpty) {
      _showError('Cart is empty');
      return;
    }

    // Show confirmation dialog if enabled
    if (ref.read(posSettingsProvider).orderConfirmationPopup) {
      final confirmed = await _showOrderConfirmationDialog();
      if (confirmed != true) return;
    }

    setState(() {
      _isProcessingOrder = true;
    });

    try {
      debugPrint('📦 Processing checkout for ${_cart.length} items...');

      if (_selectedPaymentMethod == 'Razorpay') {
        // Step 1: Create Order on Backend for Razorpay
        final orderRes = await _paymentService.createRazorpayOrder(
          amount: _total,
          currency: 'INR',
          receipt: 'pos_${DateTime.now().millisecondsSinceEpoch}',
        );

        final razorpayOrderId = orderRes['razorpayOrderId'];
        final razorpayKeyId = orderRes['keyId'];

        if (razorpayOrderId == null || razorpayKeyId == null) {
          throw Exception('Invalid response from payment server');
        }

        // Step 2: Open Razorpay SDK
        final auth = ref.read(authProvider);
        final user = auth.user ?? {};
        
        var options = {
          'key': razorpayKeyId,
          'amount': orderRes['amount'], // already in paise from backend
          'name': 'Retail Verse',
          'description': 'Order Payment',
          'order_id': razorpayOrderId,
          'retry': {'enabled': true, 'max_count': 1},
          'send_sms_hash': true,
          'prefill': {
            'contact': user['phone'] ?? '',
            'email': user['email'] ?? '',
            'name': user['name'] ?? ''
          },
          'theme': {'color': '#163F6B'}, // primary color
          'external': {
            'wallets': ['paytm']
          }
        };

        _razorpay.open(options);
        // We wait for _handlePaymentSuccess or _handlePaymentError callbacks.
      } else {
        // Cash/Offline Flow
        await _finalizeOrderBackend(paymentStatus: 'paid', status: status);
      }
    } catch (e) {
      debugPrint('❌ Checkout initiation failed: $e');
      _showError('Checkout failed: $e');
      setState(() {
        _isProcessingOrder = false;
      });
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('✅ Razorpay Payment Success: ${response.paymentId}');
    try {
      // Step 3: Verify payment on backend
      final verifyRes = await _paymentService.verifyRazorpayPayment(
        orderId: response.orderId!,
        paymentId: response.paymentId!,
        signature: response.signature!,
      );

      if (verifyRes['success'] == true) {
        // Step 4: Finalize POS order
        await _finalizeOrderBackend(
          paymentStatus: 'paid',
          razorpayOrderId: response.orderId,
          razorpayPaymentId: response.paymentId,
          razorpaySignature: response.signature,
        );
      } else {
        _showError('Payment verification failed. Please check with administrator.');
        setState(() => _isProcessingOrder = false);
      }
    } catch (e) {
      debugPrint('❌ Verification Error: $e');
      _showError('Error verifying payment: $e');
      setState(() => _isProcessingOrder = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('❌ Razorpay Error: ${response.code} - ${response.message}');
    _showError('Payment failed: ${response.message}');
    setState(() => _isProcessingOrder = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('ℹ️ Razorpay Wallet: ${response.walletName}');
    _showError('External wallets are not supported yet.');
    setState(() => _isProcessingOrder = false);
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(duration: const Duration(seconds: 2),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          ),
      );
    }
  }

  Future<void> _finalizeOrderBackend({
    String? paymentStatus,
    String? status,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    String? razorpaySignature,
  }) async {
    try {
      final cartItems = _cart.map((cartItem) {
        return CartItem(
          product: cartItem.product,
          quantity: cartItem.quantity,
        );
      }).toList();

      final notifier = ref.read(orderCreationProvider.notifier);
      final success = await notifier.createOrder(
        cartItems: cartItems,
        paymentMethod: _selectedPaymentMethod,
        taxRate: 0.18,
        paymentStatus: paymentStatus,
        status: status,
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: razorpayPaymentId,
        razorpaySignature: razorpaySignature,
      );

      if (success) {
        final createdOrder = ref.read(orderCreationProvider).createdOrder;
        debugPrint('✅ Order created successfully: ${createdOrder?.id}');

        _clearCart();

        if (mounted) {
          setState(() => _isProcessingOrder = false);
          if (createdOrder != null) {
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                duration: Duration(seconds: 2),
                content: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Order placed successfully!'),
                  ],
                ),
                backgroundColor: AppColors.secondary,
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.go('/pos');
          }
        }
      } else {
        final err = ref.read(orderCreationProvider).error ?? 'Unknown error';
        debugPrint('❌ Failed to create order: $err');
        _showError('Failed to place order: $err');
        if (mounted) {
          setState(() => _isProcessingOrder = false);
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to create order: $e');
      _showError('Failed to place order: $e');
      if (mounted) {
        setState(() => _isProcessingOrder = false);
      }
    }
  }

  Future<bool?> _showOrderConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.shopping_cart_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Place Order',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildSummaryRow('Items:', '$_totalItems'),
            const SizedBox(height: 8),
            _buildSummaryRow('Subtotal:', '₹${_subtotal.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildSummaryRow('Tax (18%):', '₹${_tax.toStringAsFixed(2)}'),
            const Divider(height: 24),
            _buildSummaryRow(
              'Total:',
              '₹${_total.toStringAsFixed(2)}',
              isTotal: true,
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Payment:', _selectedPaymentMethod),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Confirm & Place Order'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w600)
              : AppTypography.bodyMedium,
        ),
        Text(
          value,
          style: isTotal
              ? AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                )
              : AppTypography.bodyMedium,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: _buildAppBar(),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 900;
            final isDesktop = constraints.maxWidth >= 1200;

            if (isDesktop) {
              return _buildDesktopLayout();
            } else if (isTablet) {
              return _buildTabletLayout();
            } else {
              return _buildMobileLayout();
            }
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: context.canPop()
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back',
              onPressed: () => context.pop(),
            )
          : null,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.divider),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Register',
                style: AppTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              Text(
                'Retail Verse',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (_cart.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_totalItems items · ₹${_total.toStringAsFixed(2)}',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadData,
          tooltip: 'Refresh catalog',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(flex: 1, child: _buildCategoryPanel()),
        const VerticalDivider(width: 1, thickness: 1, color: AppColors.divider),
        Expanded(
          flex: 3,
          child: _buildProductWorkspace(
            showSearch: true,
            showCategoryStrip: false,
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: AppColors.divider),
        Expanded(flex: 1, child: _buildCartPanel()),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildProductWorkspace(
            showSearch: true,
            showCategoryStrip: true,
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: AppColors.divider),
        Expanded(flex: 1, child: _buildCartPanel()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Stack(
      children: [
        Column(
          children: [
            _buildMobileSearchBar(),
            _buildMobileCategoryChips(),
            Expanded(
              child: _buildProductWorkspace(
                showSearch: false,
                showCategoryStrip: false,
              ),
            ),
          ],
        ),
        if (_cart.isNotEmpty) _buildMobileCartBottomSheet(),
      ],
    );
  }

  /// Product grid with optional top search / category strip (desktop & tablet).
  Widget _buildProductWorkspace({
    required bool showSearch,
    required bool showCategoryStrip,
  }) {
    return Container(
      color: const Color(0xFFF0F2F5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showSearch || showCategoryStrip)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppColors.divider)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showSearch) _buildPosSearchField(compactTop: true),
                  if (showSearch && showCategoryStrip)
                    const SizedBox(height: 10),
                  if (showCategoryStrip) _buildHorizontalCategoryStrip(),
                ],
              ),
            ),
          Expanded(child: _buildProductGridBody()),
        ],
      ),
    );
  }

  Widget _buildHorizontalCategoryStrip() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected = _selectedCategory == category;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _selectedCategory = category),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer( duration: const Duration(milliseconds: 300), 
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    category,
                    style: AppTypography.labelMedium.copyWith(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryPanel() {
    return Container(
      color: AppColors.primaryDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text(
              'CATEGORIES',
              style: AppTypography.labelSmall.copyWith(
                color: Colors.white.withOpacity(0.65),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _selectedCategory = category),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer( duration: const Duration(milliseconds: 300), 
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white.withOpacity(0.35)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              category == 'All'
                                  ? Icons.grid_view_rounded
                                  : Icons.label_outline_rounded,
                              size: 22,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.55),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                category,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.75),
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white.withOpacity(0.9),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _buildPosSearchField(compactTop: false),
    );
  }

  Widget _buildPosSearchField({required bool compactTop}) {
    return TextField(
      controller: _searchController,
      style: AppTypography.bodyLarge,
      decoration: InputDecoration(
        hintText: 'Search by name or SKU…',
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: AppColors.textTertiary,
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              )
            : null,
        filled: true,
        fillColor: compactTop
            ? AppColors.backgroundSecondary
            : AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border.withOpacity(0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border.withOpacity(0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: compactTop ? 12 : 14,
        ),
        isDense: compactTop,
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
      onSubmitted: (value) {
        if (value.trim().isNotEmpty) {
          _onHardwareBarcodeScanned(value.trim());
          _searchController.clear();
          setState(() => _searchQuery = '');
        }
      },
    );
  }

  Widget _buildMobileCategoryChips() {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;

          return FilterChip(
            label: Text(category),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                _selectedCategory = category;
              });
            },
            backgroundColor: AppColors.background,
            selectedColor: AppColors.primary.withOpacity(0.15),
            checkmarkColor: AppColors.primary,
            labelStyle: TextStyle(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.divider,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGridBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Loading catalog…',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: AppColors.error.withOpacity(0.85),
              ),
              const SizedBox(height: 16),
              Text(
                'Could not load products',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filteredProducts = _filteredProducts;

    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.point_of_sale_rounded,
              size: 64,
              color: AppColors.textTertiary.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No items match',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Adjust search or pick another category'
                  : 'Add products in inventory to sell here',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final extent = w >= 1200
            ? 168.0
            : w >= 900
            ? 156.0
            : 148.0;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: extent,
            childAspectRatio: 0.82,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: filteredProducts.length,
          itemBuilder: (context, index) {
            return _buildProductCard(filteredProducts[index]);
          },
        );
      },
    );
  }

  Widget _buildProductCard(Product product) {
    final isInStock = product.isInStock;
    final isOutOfStock = product.isOutOfStock;
    const radius = 14.0;

    return Material(
      elevation: isOutOfStock ? 0 : 1,
      shadowColor: AppColors.shadowColor,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: () => _openProductDetail(product),
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isOutOfStock
                  ? AppColors.divider
                  : AppColors.border.withOpacity(0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(radius),
                      ),
                      child: SizedBox.expand(
                        child: ProductMediaImage(
                          imageUrl: product.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: ColoredBox(
                            color: AppColors.backgroundSecondary,
                            child: Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary.withOpacity(0.6),
                                ),
                              ),
                            ),
                          ),
                          errorWidget: _buildProductPlaceholder(product),
                        ),
                      ),
                    ),
                    if (isOutOfStock)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.white.withOpacity(0.55),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'OUT OF STOCK',
                                style: AppTypography.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (isInStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: AppColors.primary,
                          shape: const CircleBorder(),
                          elevation: 2,
                          shadowColor: Colors.black.withOpacity(0.2),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _addToCart(product),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.add_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        decoration: isOutOfStock
                            ? TextDecoration.lineThrough
                            : null,
                        color: isOutOfStock
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.sku,
                      style: AppTypography.caption.copyWith(
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '₹${product.price.toStringAsFixed(2)}',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isOutOfStock
                                  ? AppColors.textTertiary
                                  : AppColors.primaryDark,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        _buildStockPill(product, isOutOfStock),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockPill(Product product, bool isOutOfStock) {
    final Color bg;
    final Color fg;
    final String label;
    if (isOutOfStock) {
      bg = AppColors.errorLight;
      fg = AppColors.error;
      label = '0';
    } else if (product.isLowStock) {
      bg = AppColors.warningLight;
      fg = AppColors.warning;
      label = '${product.stock} left';
    } else {
      bg = AppColors.successLight;
      fg = AppColors.success;
      label = '${product.stock} in stock';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _buildProductPlaceholder(Product product) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 40,
            color: AppColors.primary.withOpacity(0.25),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              product.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildCartHeader(),
          Expanded(child: _buildCartItems()),
          _buildCartFooter(),
        ],
      ),
    );
  }

  Widget _buildCartHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shopping_bag_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current sale',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _cart.isEmpty
                      ? 'Tap products to add lines'
                      : '$_totalItems items in cart',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (_cart.isNotEmpty)
            IconButton(
              onPressed: _clearCart,
              tooltip: 'Clear cart',
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.12),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 22),
            ),
        ],
      ),
    );
  }

  Widget _buildCartItems() {
    if (_cart.isEmpty) {
      return Container(
        color: const Color(0xFFF7F8FA),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 56,
                  color: AppColors.textTertiary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No line items yet',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select items from the grid — quantities update here.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: const Color(0xFFF4F6F8),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCustomerSection(),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _cart.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: AppColors.divider.withOpacity(0.5)),
              itemBuilder: (context, index) => _buildCartItem(_cart[index]),
            ),
          ),
          const SizedBox(height: 16),
          _buildPaymentMethodSelector(),
          const SizedBox(height: 16),
          _buildCartTotals(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCustomerSection() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Customer Details',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              InkWell(
                onTap: () {},
                child: Text(
                  'Change',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.info,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Walk-in Customer',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Store Pickup • New Delhi, IN',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartThumb(POSCartItem item) {
    return ProductThumbnail(
      imageUrl: item.product.imageUrl,
      size: 52,
      borderRadius: BorderRadius.circular(10),
    );
  }

  Widget _buildCartItem(POSCartItem item) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCartThumb(item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@ ₹${item.product.price.toStringAsFixed(2)}',
                    style: AppTypography.caption.copyWith(
                      fontFeatures: [FontFeature.tabularFigures()],
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildQtyStepper(item),
                      const Spacer(),
                      Text(
                        '₹${item.total.toStringAsFixed(2)}',
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _removeFromCart(item.product.id),
              icon: const Icon(Icons.close_rounded, size: 20),
              color: AppColors.textTertiary,
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyStepper(POSCartItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _qtyBtn(
            icon: Icons.remove_rounded,
            onTap: () => _decreaseQuantity(item.product.id),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 36),
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _qtyBtn(
            icon: Icons.add_rounded,
            onTap: item.quantity < item.product.stock
                ? () => _increaseQuantity(item.product.id)
                : null,
            enabled: item.quantity < item.product.stock,
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn({
    required IconData icon,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.primary : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildCartFooter() {
    final bool isRazorpay = _selectedPaymentMethod == 'Razorpay';
    
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_cart.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Order Total: ',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '₹${_total.toStringAsFixed(2)}',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.error, // Amazon uses red for total sometimes, or dark
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _cart.isEmpty || _isProcessingOrder
                  ? null
                  : _placeOrder,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.backgroundTertiary,
                disabledForegroundColor: AppColors.textTertiary,
                elevation: 1,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.accent, width: 1),
                ),
              ),
              child: _isProcessingOrder
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isRazorpay ? 'Pay & Place Your Order' : 'Place Your Order',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _cart.isEmpty || _isProcessingOrder
                  ? null
                  : () => _placeOrder(status: 'pending'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Save as Quote',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'By placing your order, you agree to Retail Verse\'s terms and conditions.',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Method',
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          _buildPaymentOption(
            title: 'Razorpay (UPI, Cards, NetBanking)',
            subtitle: 'Secure online payment',
            value: 'Razorpay',
            icon: Icons.account_balance_wallet_rounded,
          ),
          const Divider(height: 24),
          _buildPaymentOption(
            title: 'Cash on Delivery',
            subtitle: 'Pay when items are handed over',
            value: 'Cash',
            icon: Icons.payments_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
  }) {
    final bool selected = _selectedPaymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Radio<String>(
            value: value,
            groupValue: _selectedPaymentMethod,
            activeColor: AppColors.amazonOrange,
            onChanged: (val) {
              if (val != null) setState(() => _selectedPaymentMethod = val);
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

  Widget _buildCartTotals() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _buildTotalRow('Items:', '₹${_subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 6),
          _buildTotalRow('Tax (18% GST):', '₹${_tax.toStringAsFixed(2)}'),
          const SizedBox(height: 6),
          _buildTotalRow('Handling:', '₹0.00'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              height: 1,
              color: AppColors.divider.withOpacity(0.5),
            ),
          ),
          _buildTotalRow(
            'Order Total:',
            '₹${_total.toStringAsFixed(2)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    String value, {
    bool isTotal = false,
    bool isDiscount = false,
  }) {
    final figs = [FontFeature.tabularFigures()];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style:
              (isTotal ? AppTypography.titleMedium : AppTypography.bodyMedium)
                  .copyWith(
                    fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
                    color: isTotal
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
        ),
        Text(
          value,
          style: (isTotal ? AppTypography.titleLarge : AppTypography.bodyMedium)
              .copyWith(
                fontWeight: isDiscount
                    ? FontWeight.w700
                    : (isTotal ? FontWeight.w600 : FontWeight.w600),
                color: isDiscount
                    ? AppColors.success
                    : (isTotal ? AppColors.primaryDark : AppColors.textPrimary),
                fontFeatures: figs,
              ),
        ),
      ],
    );
  }

  Widget _buildMobileCartBottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6F8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildCartHeader(),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildCustomerSection(),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: _cart.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: AppColors.divider.withOpacity(0.5),
                        ),
                        itemBuilder: (context, index) =>
                            _buildCartItem(_cart[index]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPaymentMethodSelector(),
                    const SizedBox(height: 16),
                    _buildCartTotals(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              _buildCartFooter(),
            ],
          ),
        );
      },
    );
  }
}
