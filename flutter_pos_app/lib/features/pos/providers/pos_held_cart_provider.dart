import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_response_handler.dart';
import '../../../core/services/session_service.dart';
import 'cart_provider.dart';

/// Represents a single parked/held sale
class HeldCartItem {
  final String id;
  final String referenceLabel;
  final DateTime heldAt;
  final CartState cart;

  HeldCartItem({
    required this.id,
    required this.referenceLabel,
    required this.heldAt,
    required this.cart,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'referenceLabel': referenceLabel,
      'heldAt': heldAt.toIso8601String(),
      'cart': cart.toJson(),
    };
  }

  factory HeldCartItem.fromJson(Map<String, dynamic> json) {
    return HeldCartItem(
      id: json['id']?.toString() ??
          json['_id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      referenceLabel: json['referenceLabel']?.toString() ?? 'Customer Cart',
      heldAt: json['heldAt'] != null
          ? DateTime.tryParse(json['heldAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      cart: CartState.fromJson(Map<String, dynamic>.from(json['cart'] as Map)),
    );
  }
}

/// Multi-customer held carts notifier
class PosHeldCartNotifier extends StateNotifier<List<HeldCartItem>> {
  PosHeldCartNotifier() : super([]) {
    _loadFromLocal();
  }

  static const String _prefKey = 'rv_pos_held_carts_multi_v1';

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_prefKey);
      if (str != null && str.isNotEmpty) {
        final list = jsonDecode(str) as List;
        state = list
            .map((e) => HeldCartItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('⚠️ Error loading held carts from prefs: $e');
    }
  }

  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(state.map((e) => e.toJson()).toList());
      await prefs.setString(_prefKey, encoded);
    } catch (e) {
      debugPrint('⚠️ Error saving held carts to prefs: $e');
    }
  }

  /// Holds current [cart] with an optional user-defined reference label (e.g. "Customer #1", "Rahul - milk").
  void holdCart(CartState cart, {String? referenceLabel}) {
    if (cart.items.isEmpty) return;

    final id = 'HOLD-${DateTime.now().millisecondsSinceEpoch}';
    final label = (referenceLabel != null && referenceLabel.trim().isNotEmpty)
        ? referenceLabel.trim()
        : (cart.customerName.isNotEmpty
            ? cart.customerName
            : 'Customer #${state.length + 1}');

    final item = HeldCartItem(
      id: id,
      referenceLabel: label,
      heldAt: DateTime.now(),
      cart: cart.duplicate(),
    );

    state = [item, ...state];
    _saveToLocal();

    // Background sync to backend (non-blocking for 0ms offline-first latency)
    _syncHoldToBackend(item);
  }

  Future<void> _syncHoldToBackend(HeldCartItem item) async {
    try {
      final token = await SessionService.getToken();
      if (token == null) return;
      await http.post(
        ApiResponseHandler.uri(ApiEndpoints.heldCarts),
        headers: ApiResponseHandler.jsonHeaders(token: token),
        body: jsonEncode({
          'referenceLabel': item.referenceLabel,
          'customerName': item.cart.customerName,
          'customerPhone': item.cart.customerPhone,
          'customerEmail': item.cart.customerEmail,
          'customerAddress': item.cart.customerAddress,
          'orderNotes': item.cart.orderNotes,
          'subtotal': item.cart.subtotal,
          'discount': item.cart.discount,
          'appliedCouponCode': item.cart.appliedCouponCode,
          'taxRate': item.cart.taxRate,
          'extraCharges': item.cart.extraCharges,
          'items': item.cart.items.map((i) => {
            'productId': i.product.id,
            'name': i.product.name,
            'price': i.product.price,
            'quantity': i.quantity,
            'total': i.total,
          }).toList(),
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('⚠️ Sync hold cart to backend skipped: $e');
    }
  }

  void removeHeldCart(String id) {
    state = state.where((item) => item.id != id).toList();
    _saveToLocal();

    // Async sync remove to backend if mongo ID
    _syncDeleteToBackend(id);
  }

  Future<void> _syncDeleteToBackend(String id) async {
    try {
      final token = await SessionService.getToken();
      if (token == null) return;
      await http.delete(
        ApiResponseHandler.uri('${ApiEndpoints.heldCarts}/$id'),
        headers: ApiResponseHandler.jsonHeaders(token: token),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  void clearAll() {
    state = [];
    _saveToLocal();
  }
}

final posHeldCartProvider =
    StateNotifierProvider<PosHeldCartNotifier, List<HeldCartItem>>((ref) {
  return PosHeldCartNotifier();
});
