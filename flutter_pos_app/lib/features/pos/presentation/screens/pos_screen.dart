import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/core/utils/formatters.dart';
import 'package:retail_verse_pos/core/widgets/product_media_image.dart';
import 'package:retail_verse_pos/data/models/product_model.dart';
import 'package:retail_verse_pos/data/models/cart_model.dart';
import 'package:retail_verse_pos/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:retail_verse_pos/features/pos/providers/cart_provider.dart';
import 'package:retail_verse_pos/features/pos/providers/pos_held_cart_provider.dart';
import 'package:retail_verse_pos/features/pos/providers/product_providers.dart';
import 'package:retail_verse_pos/features/notifications/providers/notification_provider.dart';
import 'package:retail_verse_pos/features/auth/providers/auth_provider.dart';
import 'package:retail_verse_pos/features/settings/providers/pos_settings_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:retail_verse_pos/data/models/order_model.dart';
import 'package:retail_verse_pos/features/pos/providers/whatsapp_pending_orders_provider.dart';
import 'package:retail_verse_pos/core/navigation/role_nav.dart';
import 'package:retail_verse_pos/core/widgets/common/bounceable.dart';

class POSScreen extends ConsumerStatefulWidget {
  const POSScreen({super.key});

  @override
  ConsumerState<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends ConsumerState<POSScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _posScaffoldKey = GlobalKey<ScaffoldState>();
  String selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  late AnimationController _rotationController;
  bool isRefreshing = false;

  final StringBuffer _scannerBuffer = StringBuffer();
  DateTime _lastKeystrokeTime = DateTime.now();

  bool _handleHardwareScanKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

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

  Future<void> _onHardwareBarcodeScanned(String barcode) async {
    debugPrint('⚡ [POSScreen Hardware Scanner] Scanned barcode: $barcode');
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
      } catch (e) {
        debugPrint('⚠️ Barcode API lookup failed: $e');
      }
    }

    if (matchedProduct != null) {
      ref.read(cartProvider.notifier).addItem(matchedProduct);
      if (ref.read(posSettingsProvider).soundOnBilling) {
        SystemSound.play(SystemSoundType.click);
      }
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('${matchedProduct.name} added to cart!')),
            ],
          ),
          backgroundColor: AppColors.secondary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Barcode "$barcode" not found in inventory!')),
            ],
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHardwareScanKey);
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareScanKey);
    _rotationController.dispose();
    _searchController.dispose();
    super.dispose();
  }




  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();
    setState(() => isRefreshing = true);
    _rotationController.repeat();

    try {
      await Future.wait([
        ref.refresh(productsProvider.future),
        ref.refresh(posCategoriesProvider.future),
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(duration: const Duration(seconds: 2),
            content: Text('Inventory refreshed successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(seconds: 2),
            content: Text('Failed to refresh: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } finally {
      if (mounted) {
        _rotationController.stop();
        _rotationController.reset();
        setState(() => isRefreshing = false);
      }
    }
  }

  String _formatHeldTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showHeldCartsSheet(BuildContext context, CartState currentCart) =>
      _showParkedQueueSheet(context, currentCart, initialTab: 0);

  Future<void> _showWhatsAppPendingSheet(BuildContext context) =>
      _showParkedQueueSheet(context, ref.read(cartProvider), initialTab: 1);

  Future<void> _showParkedQueueSheet(
    BuildContext context,
    CartState currentCart, {
    int initialTab = 0,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        int activeTab = initialTab;
        return Consumer(
          builder: (sheetCtx, ref, _) {
            final heldCarts = ref.watch(posHeldCartProvider);
            final whatsappPending = ref.watch(whatsappPendingOrdersProvider);
            final totalParked = heldCarts.length + whatsappPending.length;

            if (totalParked == 0) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF16A34A)),
                    const SizedBox(height: 12),
                    const Text('No Parked Orders', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 6),
                    const Text('All held carts and WhatsApp payments are clear.', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(bottomSheetContext),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            }

            return StatefulBuilder(
              builder: (sCtx, setSheetState) {
                if (activeTab == 0 && heldCarts.isEmpty && whatsappPending.isNotEmpty) {
                  activeTab = 1;
                } else if (activeTab == 1 && whatsappPending.isEmpty && heldCarts.isNotEmpty) {
                  activeTab = 0;
                }

                return Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.82,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1D5DB),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 16, 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.pause_circle_filled_rounded, color: Color(0xFFD97706), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Parked Orders Queue',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF111827)),
                                  ),
                                  Text(
                                    '$totalParked active order${totalParked != 1 ? 's' : ''} on hold',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                              onPressed: () => Navigator.pop(bottomSheetContext),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(9),
                                  onTap: () => setSheetState(() => activeTab = 0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: activeTab == 0 ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9),
                                      boxShadow: activeTab == 0
                                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.pause_circle_rounded,
                                          size: 16,
                                          color: activeTab == 0 ? const Color(0xFFD97706) : const Color(0xFF6B7280),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Held Carts (${heldCarts.length})',
                                          style: TextStyle(
                                            fontWeight: activeTab == 0 ? FontWeight.w700 : FontWeight.w500,
                                            fontSize: 12.5,
                                            color: activeTab == 0 ? const Color(0xFF92400E) : const Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(9),
                                  onTap: () => setSheetState(() => activeTab = 1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: activeTab == 1 ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9),
                                      boxShadow: activeTab == 1
                                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        FaIcon(
                                          FontAwesomeIcons.whatsapp,
                                          size: 15,
                                          color: activeTab == 1 ? const Color(0xFF16A34A) : const Color(0xFF6B7280),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'WhatsApp Pay (${whatsappPending.length})',
                                          style: TextStyle(
                                            fontWeight: activeTab == 1 ? FontWeight.w700 : FontWeight.w500,
                                            fontSize: 12.5,
                                            color: activeTab == 1 ? const Color(0xFF14532D) : const Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                      Flexible(
                        child: activeTab == 0
                            ? (heldCarts.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(32),
                                    child: Center(
                                      child: Text(
                                        'No held carts on hold.',
                                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                    shrinkWrap: true,
                                    itemCount: heldCarts.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (ctx, index) {
                                      final item = heldCarts[index];
                                      return _buildHeldCartCard(context, ref, bottomSheetContext, item, index);
                                    },
                                  ))
                            : (whatsappPending.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(32),
                                    child: Center(
                                      child: Text(
                                        'No WhatsApp payment orders pending.',
                                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                    shrinkWrap: true,
                                    itemCount: whatsappPending.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (ctx, index) {
                                      final order = whatsappPending[index];
                                      return _buildWhatsAppPendingCard(context, ref, bottomSheetContext, order, index);
                                    },
                                  )),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHeldCartCard(
    BuildContext context,
    WidgetRef ref,
    BuildContext sheetContext,
    HeldCartItem item,
    int index,
  ) {
    final c = item.cart;
    final tokenNumber = (index + 1).toString().padLeft(2, '0');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        'TOKEN #$tokenNumber',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        item.referenceLabel,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatHeldTime(item.heldAt),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                visualDensity: VisualDensity.compact,
                tooltip: 'Discard',
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      title: const Text('Discard Held Cart?'),
                      content: Text('Are you sure you want to discard "${item.referenceLabel}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dCtx, true),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                          child: const Text('Discard'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    ref.read(posHeldCartProvider.notifier).removeHeldCart(item.id);
                  }
                },
              ),
            ],
          ),
          if (c.customerName.isNotEmpty || c.customerPhone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text(
                  [if (c.customerName.isNotEmpty) c.customerName, if (c.customerPhone.isNotEmpty) c.customerPhone].join(' • '),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ...c.items.take(4).map((i) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${i.product.name} × ${i.quantity}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF374151)),
                  ),
                );
              }),
              if (c.items.length > 4)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+${c.items.length - 4} more',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${c.itemCount} items',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                  ),
                  Text(
                    '₹${c.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () => _resumeHeldCart(context, ref, sheetContext, item),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Resume Cart', style: TextStyle(fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _resumeHeldCart(
    BuildContext context,
    WidgetRef ref,
    BuildContext sheetContext,
    HeldCartItem heldItem,
  ) async {
    final activeCart = ref.read(cartProvider);

    if (activeCart.items.isNotEmpty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (dCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Current Cart Not Empty'),
          content: Text(
            'Your counter currently has ${activeCart.itemCount} item(s) worth ₹${activeCart.total.toStringAsFixed(2)}.\n\nWhat would you like to do before resuming "${heldItem.referenceLabel}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, 'cancel'),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(dCtx, 'discard'),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
              child: const Text('Discard Current'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dCtx, 'park'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
              child: const Text('Park Current & Resume'),
            ),
          ],
        ),
      );

      if (choice == null || choice == 'cancel') return;

      if (choice == 'park') {
        final label = activeCart.customerName.isNotEmpty
            ? activeCart.customerName
            : 'Counter Cart';
        ref.read(posHeldCartProvider.notifier).holdCart(activeCart, referenceLabel: label);
      }
    }

    ref.read(cartProvider.notifier).replaceWith(heldItem.cart);
    ref.read(posHeldCartProvider.notifier).removeHeldCart(heldItem.id);

    if (sheetContext.mounted) {
      Navigator.pop(sheetContext);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Resumed "${heldItem.referenceLabel}" with ${heldItem.cart.itemCount} item(s).'),
              ),
            ],
          ),
        ),
      );
      context.push('/pos/cart');
    }
  }

  Widget _buildWhatsAppPendingCard(
    BuildContext context,
    WidgetRef ref,
    BuildContext sheetContext,
    Order order,
    int index,
  ) {
    final waToken = (index + 1).toString().padLeft(2, '0');
    final displayId = order.orderId.length > 6
        ? order.orderId.substring(order.orderId.length - 6)
        : order.orderId;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FaIcon(FontAwesomeIcons.whatsapp, size: 12, color: Color(0xFF16A34A)),
                          const SizedBox(width: 4),
                          Text(
                            'WA #$waToken • $displayId',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatHeldTime(order.dateTime),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF), size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: 'Dismiss',
                onPressed: () {
                  ref.read(whatsappPendingOrdersProvider.notifier).removePendingOrder(order.id);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_rounded, size: 15, color: Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Text(
                order.customerName ?? 'Walk-in Customer',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
              ),
              if (order.customerPhone != null && order.customerPhone!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text('•', style: TextStyle(color: Colors.grey.shade400)),
                const SizedBox(width: 8),
                const FaIcon(FontAwesomeIcons.whatsapp, size: 13, color: Color(0xFF16A34A)),
                const SizedBox(width: 4),
                Text(
                  order.customerPhone!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pending Total', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  Text(
                    '₹${order.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(whatsappPendingOrdersProvider.notifier).sendWhatsAppLink(order);
                    },
                    icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 14),
                    label: const Text('Remind', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF16A34A),
                      side: const BorderSide(color: Color(0xFF86EFAC)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      final confirmed = await ref
                          .read(whatsappPendingOrdersProvider.notifier)
                          .markOrderAsPaidAndPrint(order);
                      if (context.mounted && confirmed) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 3),
                            backgroundColor: const Color(0xFF16A34A),
                            behavior: SnackBarBehavior.floating,
                            content: Row(
                              children: [
                                const Icon(Icons.print_rounded, color: Colors.white),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text('Order #${order.orderId} marked Paid! Printing receipt automatically...'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Mark Paid & Print', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final count = cart.itemCount;
    final totalValue = cart.total;
    final isTablet = MediaQuery.of(context).size.width >= 900;
    final heldCarts = ref.watch(posHeldCartProvider);
    final whatsappPending = ref.watch(whatsappPendingOrdersProvider);
    final totalParked = heldCarts.length + whatsappPending.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic _) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          final user = ref.read(authProvider).user;
          final home = initialHomeRouteForUser(user);
          context.go(home);
        }
      },
      child: Scaffold(
      key: _posScaffoldKey,
      backgroundColor: Colors.transparent,
      endDrawer: !isTablet ? Drawer(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Container(
          color: Colors.white,
          child: SafeArea(
            child: _buildCartSidebar(cart, totalValue, count),
          ),
        ),
      ) : null,
      body: Stack(
        children: [
          Container(
            color: const Color(0xFFF8F9FB),
            child: Row(
              children: [
                // ── MAIN CONTENT (MENU & PRODUCTS) ──────────────────
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER WITH MENU ICON
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 40, 16, 4),
                        child: Row(
                          children: [
                            const ResponsiveMenuButton(),
                            if (isTablet) ...[
                              const SizedBox(width: 16),
                              Text(
                                'POS',
                                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildInlineSearchBar(),
                            ),
                            if (totalParked > 0) ...[
                              const SizedBox(width: 8),
                              Bounceable(
                                onTap: () => _showParkedQueueSheet(context, cart),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isTablet ? 12 : 10,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.pause_circle_filled_rounded,
                                            size: 20,
                                            color: Color(0xFFD97706),
                                          ),
                                          if (isTablet) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              'Hold & Pay ($totalParked)',
                                              style: AppTypography.labelMedium.copyWith(
                                                color: const Color(0xFF92400E),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      top: -5,
                                      right: -5,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDC2626),
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.15),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                        child: Center(
                                          child: Text(
                                            '$totalParked',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Bounceable(
                              onTap: () {
                                if (!isRefreshing) {
                                  _handleRefresh();
                                }
                              },
                              child: AnimatedOpacity( duration: const Duration(milliseconds: 300), 
                                opacity: isRefreshing ? 0.6 : 1.0,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.cardBorder),
                                  ),
                                  child: RotationTransition(
                                    turns: _rotationController,
                                    child: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.textPrimary),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Bounceable(
                              onTap: () => _posScaffoldKey.currentState?.openEndDrawer(),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.cardBorder),
                                    ),
                                    child: const Icon(
                                      Icons.shopping_cart_outlined,
                                      size: 20,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (count > 0)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$count',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // CATEGORIES
                      _buildModernCategoryBar(),
                      const SizedBox(height: 16),

                      // PRODUCT GRID
                      Expanded(
                        child: _buildProductList(context, isTablet),
                      ),
                    ],
                  ),
                ),

                // ── CART SIDEBAR (CURRENT ORDER) ──────────────────
                if (isTablet)
                  Container(
                    width: 320,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(left: BorderSide(color: AppColors.cardBorder.withOpacity(0.5))),
                    ),
                    child: _buildCartSidebar(cart, totalValue, count),
                  ),
              ],
            ),
          ),
        ],
      ),
    ));
  }



  Widget _buildInlineSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search...',
          hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('grocer') || name.contains('food') || name.contains('eat') || name.contains('veg') || name.contains('shopping')) {
      return Icons.shopping_basket_rounded;
    }
    if (name.contains('sport') || name.contains('gym') || name.contains('fit') || name.contains('ball')) {
      return Icons.sports_basketball_rounded;
    }
    if (name.contains('elect') || name.contains('tech') || name.contains('phone') || name.contains('comp') || name.contains('device')) {
      return Icons.electrical_services_rounded;
    }
    if (name.contains('cloth') || name.contains('wear') || name.contains('shirt') || name.contains('pant') || name.contains('jean')) {
      return Icons.checkroom_rounded;
    }
    if (name.contains('toy') || name.contains('game')) {
      return Icons.toys_rounded;
    }
    if (name.contains('book') || name.contains('read') || name.contains('write')) {
      return Icons.book_rounded;
    }
    if (name.contains('home') || name.contains('furni') || name.contains('deco')) {
      return Icons.home_rounded;
    }
    return Icons.category_rounded;
  }

  Widget _buildShimmerCategoryBar(bool isAllSelected) {
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Row(
        children: [
          // ── FIXED "ALL" BUTTON ──
          Bounceable(
            onTap: () => setState(() => selectedCategory = 'All'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isAllSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isAllSelected ? AppColors.primary : AppColors.cardBorder,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.grid_view_rounded,
                    size: 16,
                    color: isAllSelected ? Colors.white : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'All',
                    style: AppTypography.labelLarge.copyWith(
                      color: isAllSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // ── PLACEHOLDERS ──
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: List.generate(3, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Container(
                      width: 80 + (index * 15.0),
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernCategoryBar() {
    final categoriesAsync = ref.watch(posCategoriesProvider);
    final isAllSelected = selectedCategory == 'All';

    return categoriesAsync.when(
      data: (categoriesList) {
        final otherCategories = categoriesList.map((c) {
          return {
            'name': c.name,
            'icon': _getCategoryIcon(c.name),
          };
        }).toList();

        return Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Row(
            children: [
              // ── FIXED "ALL" BUTTON ──
              Bounceable(
                onTap: () => setState(() => selectedCategory = 'All'),
                child: AnimatedContainer( duration: const Duration(milliseconds: 300), 
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isAllSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isAllSelected ? AppColors.primary : AppColors.cardBorder,
                      width: 1.5,
                    ),
                    boxShadow: isAllSelected ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ] : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.grid_view_rounded,
                        size: 16,
                        color: isAllSelected ? Colors.white : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'All',
                        style: AppTypography.labelLarge.copyWith(
                          color: isAllSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // ── SCROLLABLE OTHER CATEGORIES ──
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 24),
                  child: Row(
                    children: otherCategories.map((cat) {
                      final isSelected = selectedCategory == cat['name'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Bounceable(
                          onTap: () => setState(() => selectedCategory = cat['name'] as String),
                          child: AnimatedContainer( duration: const Duration(milliseconds: 300), 
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.cardBorder,
                                width: 1.5,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ] : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cat['icon'] as IconData,
                                  size: 16,
                                  color: isSelected ? Colors.white : AppColors.textTertiary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  cat['name'] as String,
                                  style: AppTypography.labelLarge.copyWith(
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => _buildShimmerCategoryBar(isAllSelected),
      error: (err, stack) => _buildShimmerCategoryBar(isAllSelected),
    );
  }

  Widget _buildProductList(BuildContext context, bool isTablet) {
    final productsAsync = ref.watch(productsProvider);
    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString().contains('SocketException') || e.toString().contains('Failed host lookup') ? 'You are offline. Please check your internet connection.' : 'Error: $e')),
      data: (products) {
        final filter = GoRouterState.of(context).uri.queryParameters['filter'];
        
        final filtered = products.where((p) {
          if (!p.isActive) return false;
          final matchesSearch = p.name.toLowerCase().contains(searchQuery.toLowerCase());
          final matchesCat = selectedCategory == 'All Menu' || selectedCategory == 'All' || p.category == selectedCategory;
          
          bool matchesFilter = true;
          if (filter == 'low_stock') {
             matchesFilter = p.stock <= p.reorderLevel;
          } else if (filter == 'best_sellers') {
             matchesFilter = p.price > 100;
          }
          
          return matchesSearch && matchesCat && matchesFilter;
        }).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            // Responsive grid: 1 col per ~180px of available width.
            // Caps at min 2, so wide screens get more columns automatically.
            final availableW = constraints.maxWidth;
            final crossCount = (availableW / 180).floor().clamp(2, 6);
            final spacing = availableW > 600 ? 20.0 : 12.0;
            final padding = availableW > 600 ? 24.0 : 12.0;
            // Aspect ratio: image takes ~55% of height, info 45%
            const aspectRatio = 0.75;

            return GridView.builder(
              padding: EdgeInsets.fromLTRB(padding, padding, padding, padding + 80), // Extra bottom padding for nav bar
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: aspectRatio,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) => _buildUltraPremiumCard(filtered[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildUltraPremiumCard(Product product) {
    final cart = ref.watch(cartProvider);
    final cartItem = cart.items.where((i) => i.product.id == product.id).firstOrNull;
    final inCartQuantity = cartItem?.quantity ?? 0;
    final isOutOfStock = product.stock <= inCartQuantity;

    return Bounceable(
      onTap: () => context.push('/pos/product', extra: product),
      child: Opacity(
        opacity: isOutOfStock ? 0.6 : 1.0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Adapt all sizes to the card's actual rendered width
            final w = constraints.maxWidth;
            final isNarrow = w < 140;
            final isMedium = w >= 140 && w < 190;

            // Responsive values
            final borderR = isNarrow ? 18.0 : 24.0;
            final infoPad = isNarrow ? 8.0 : (isMedium ? 10.0 : 14.0);
            final catSize = isNarrow ? 7.0 : 8.0;
            final nameSize = isNarrow ? 11.0 : (isMedium ? 12.5 : 14.0);
            final stockLabelSize = isNarrow ? 6.0 : 7.0;
            final stockValueSize = isNarrow ? 9.0 : 10.0;
            final btnPad = isNarrow ? 6.0 : (isMedium ? 7.0 : 9.0);
            final btnIconSize = isNarrow ? 14.0 : (isMedium ? 16.0 : 18.0);
            final pricePadH = isNarrow ? 6.0 : 10.0;
            final pricePadV = isNarrow ? 4.0 : 6.0;
            final priceSize = isNarrow ? 10.0 : 12.0;
            final gapAfterCat = isNarrow ? 2.0 : 4.0;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(borderR),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderR),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── IMAGE HEADER (FULL BLEED) ──
                    Expanded(
                      flex: 55,
                      child: Container(
                        width: double.infinity,
                        color: const Color(0xFFF1F5F9),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ProductMediaImage(
                              imageUrl: product.imageUrl,
                              fit: BoxFit.cover,
                            ),
                            if (isOutOfStock)
                              Container(
                                color: Colors.black12,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'OUT OF STOCK',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: isNarrow ? 8.0 : 10.0,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Floating Price Badge
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: pricePadH, vertical: pricePadV),
                                decoration: BoxDecoration(
                                  color: isOutOfStock ? Colors.grey[400] : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)],
                                ),
                                child: Text(
                                  AppFormatters.formatCurrency(product.price),
                                  style: TextStyle(
                                    color: const Color(0xFF1E293B),
                                    fontWeight: FontWeight.w700,
                                    fontSize: priceSize,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── INFO & ACTION SECTION ──
                    Expanded(
                      flex: 45,
                      child: Padding(
                        padding: EdgeInsets.all(infoPad),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Category + Name
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.category.toUpperCase(),
                                  style: TextStyle(
                                    color: isOutOfStock ? Colors.grey : AppColors.primary.withOpacity(0.8),
                                    fontSize: catSize,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                ),
                                SizedBox(height: gapAfterCat),
                                Text(
                                  product.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                    fontSize: nameSize,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),

                            // Stock + Add button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'STOCK',
                                        style: TextStyle(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: stockLabelSize,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${product.stock - inCartQuantity} left',
                                        style: TextStyle(
                                          color: isOutOfStock ? Colors.red : const Color(0xFF64748B),
                                          fontSize: stockValueSize,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  // opaque behavior prevents this tap from bubbling up to the parent card Bounceable
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    if (isOutOfStock) {
                                      ref.read(notificationProvider.notifier).requestRestock(product.id, product.name, isFromPos: true);
                                    } else {
                                      ref.read(cartProvider.notifier).addItem(product);
                                      final isTabletW = MediaQuery.of(context).size.width >= 900;
                                      if (!isTabletW) {
                                        _posScaffoldKey.currentState?.openEndDrawer();
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(btnPad),
                                    decoration: BoxDecoration(
                                      color: isOutOfStock ? Colors.amber : AppColors.primary,
                                      borderRadius: BorderRadius.circular(isNarrow ? 8.0 : 10.0),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isOutOfStock ? Colors.amber : AppColors.primary).withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        )
                                      ],
                                    ),
                                    child: Icon(
                                      isOutOfStock ? Icons.notifications_active_rounded : Icons.add_rounded,
                                      color: isOutOfStock ? Colors.black : Colors.white,
                                      size: btnIconSize,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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

  Widget _buildCartSidebar(CartState cart, double total, int count) {
    return Column(
      children: [
        // 1. FIXED SIDEBAR HEADER
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Current Order', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700, fontSize: 18)),
              IconButton(
                onPressed: () => ref.read(cartProvider.notifier).clearCart(),
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        // 2. SCROLLABLE PRODUCT LIST
        Expanded(
          child: Column(
            children: [
              // THE ACTUAL LIST
              Expanded(
                child: cart.items.isEmpty
                    ? _buildEmptySidebar()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: cart.items.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _buildSidebarCartItem(cart.items[index]),
                      ),
              ),
            ],
          ),
        ),

        // 3. FIXED TOTALS & PLACE ORDER CARD
        Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            border: Border(top: BorderSide(color: AppColors.cardBorder.withOpacity(0.5))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSummaryRow('Sub Total', AppFormatters.formatCurrency(cart.subtotal)),
              const SizedBox(height: 4),
              _buildSummaryRow('Tax (11%)', AppFormatters.formatCurrency(cart.taxAmount)),
              const Divider(height: 16),
              _buildSummaryRow('Total', AppFormatters.formatCurrency(cart.total), isTotal: true),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: cart.items.isEmpty ? null : () {
                    final isTablet = MediaQuery.of(context).size.width >= 900;
                    if (!isTablet) {
                      Navigator.of(context).pop(); // Close drawer
                    }
                    context.push('/pos/cart');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent, // Orange CTA
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarCartItem(CartItem item) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ProductMediaImage(imageUrl: item.product.imageUrl, fit: BoxFit.contain),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.product.name, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
              Text(AppFormatters.formatCurrency(item.product.price), style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
            ],
          ),
        ),
        Row(
          children: [
            _buildQtyBtn(Icons.remove, () => ref.read(cartProvider.notifier).updateQuantity(item.product.id, item.quantity - 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('${item.quantity}', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
            ),
            _buildQtyBtn(Icons.add, () => ref.read(cartProvider.notifier).updateQuantity(item.product.id, item.quantity + 1)),
          ],
        ),
      ],
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return Bounceable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: isTotal ? AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700) : AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
        Text(value, style: isTotal ? AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700) : AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildEmptySidebar() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_basket_outlined, size: 48, color: AppColors.textTertiary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Your cart is empty', style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}
