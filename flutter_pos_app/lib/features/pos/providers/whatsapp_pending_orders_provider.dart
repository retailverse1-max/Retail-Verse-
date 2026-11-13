import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/branding/app_branding.dart';
import '../../../core/utils/printer_service.dart';
import '../../../data/models/order_model.dart';
import 'order_providers.dart';

/// Manages WhatsApp pending payment orders during counter rush
class WhatsappPendingOrdersNotifier extends StateNotifier<List<Order>> {
  final Ref _ref;

  WhatsappPendingOrdersNotifier(this._ref) : super([]) {
    _loadFromLocal();
  }

  static const String _prefKey = 'rv_whatsapp_pending_orders_v1';

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_prefKey);
      if (str != null && str.isNotEmpty) {
        final list = jsonDecode(str) as List;
        // In local state, we store Order JSONs
        state = list.map((e) => _orderFromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (e) {
      debugPrint('⚠️ Error loading whatsapp pending orders: $e');
    }
  }

  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(state.map((e) => e.toJson()).toList());
      await prefs.setString(_prefKey, encoded);
    } catch (e) {
      debugPrint('⚠️ Error saving whatsapp pending orders: $e');
    }
  }

  void addPendingOrder(Order order) {
    // Avoid duplicate
    state = [order, ...state.where((o) => o.id != order.id && o.orderId != order.orderId)];
    _saveToLocal();
  }

  void removePendingOrder(String id) {
    state = state.where((o) => o.id != id && o.orderId != id).toList();
    _saveToLocal();
  }

  /// Sends or re-sends WhatsApp payment link to customer
  Future<bool> sendWhatsAppLink(Order order, {String? storeName}) async {
    final effectiveStoreName = (storeName != null && storeName.trim().isNotEmpty && storeName != 'RetailVerse')
        ? storeName.trim()
        : AppBranding.currentStoreName;

    String phone = (order.customerPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length == 10) {
      phone = '91$phone';
    }

    final amount = order.total.toStringAsFixed(2);
    final custName = (order.customerName != null && order.customerName!.isNotEmpty)
        ? order.customerName!
        : 'Valued Customer';

    final upiUrl = 'upi://pay?pa=wehexerve@icici&pn=${Uri.encodeComponent(effectiveStoreName)}&am=$amount&cu=INR&tn=${order.orderId}';

    final buffer = StringBuffer();
    buffer.writeln('👋 Hello *$custName*,');
    buffer.writeln('🏬 *${effectiveStoreName.toUpperCase()}*');
    buffer.writeln('Your bill total for Order *#${order.orderId}* is *₹$amount* (${order.itemCount} items).');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📲 *Click link below to pay online (GPay / PhonePe / Paytm):*');
    buffer.writeln(upiUrl);
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('✅ Once paid, your tax invoice will be printed immediately at the cash counter. 🙏');

    final message = Uri.encodeComponent(buffer.toString());
    final url = phone.isNotEmpty
        ? Uri.parse('https://wa.me/$phone?text=$message')
        : Uri.parse('https://api.whatsapp.com/send?text=$message');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
      return true;
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
      return false;
    }
  }

  /// Called when customer pays (or cashier verifies) -> marks paid in backend & triggers auto print!
  Future<bool> markOrderAsPaidAndPrint(Order order) async {
    try {
      // 1. Update backend status
      try {
        final remote = _ref.read(orderRemoteDataSourceProvider);
        await remote.updateOrderStatus(
          order.id,
          status: 'completed',
          paymentStatus: 'paid',
        );
      } catch (err) {
        debugPrint('⚠️ Remote update order status failed: $err');
      }

      // 2. Trigger auto print thermal receipt
      final printer = PrinterService();
      await printer.autoPrintReceipt(order);

      // 3. Remove from pending list
      removePendingOrder(order.id);
      return true;
    } catch (e) {
      debugPrint('Error marking order paid: $e');
      return false;
    }
  }

  Order _orderFromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      dateTime: json['dateTime'] != null ? DateTime.tryParse(json['dateTime'].toString()) ?? DateTime.now() : DateTime.now(),
      items: [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      extraCharges: (json['extraCharges'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod']?.toString() ?? 'WhatsApp',
      status: json['status']?.toString() ?? 'pending',
      paymentStatus: json['paymentStatus']?.toString() ?? 'pending',
      customerName: json['customerName']?.toString(),
      customerPhone: json['customerPhone']?.toString(),
      customerEmail: json['customerEmail']?.toString(),
      customerAddress: json['customerAddress']?.toString(),
      notes: json['notes']?.toString(),
      cashierName: json['cashierName']?.toString(),
      couponCode: json['couponCode']?.toString(),
      rewardCouponCode: json['rewardCouponCode']?.toString(),
      converted: json['converted'] == true,
    );
  }
}

final whatsappPendingOrdersProvider =
    StateNotifierProvider<WhatsappPendingOrdersNotifier, List<Order>>((ref) {
  return WhatsappPendingOrdersNotifier(ref);
});
