import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/product_model.dart';
import '../../../data/models/cart_model.dart';

/// Cart + checkout draft fields. Persisted in memory via Riverpod for POS session.
class CartState {
  const CartState({
    required this.items,
    this.taxRate = 0.18,
    this.discount = 0.0,
    this.extraCharges = 0.0,
    this.customerName = '',
    this.customerPhone = '',
    this.customerEmail = '',
    this.customerAddress = '',
    this.orderNotes = '',
    this.appliedCouponCode,
    this.couponMinOrderAmount,
    this.couponDescription,
  });

  final List<CartItem> items;
  final double taxRate;
  /// Cart-level discount in currency (not percent).
  final double discount;
  /// Delivery / packing / other fees added after tax.
  final double extraCharges;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String customerAddress;
  final String orderNotes;
  final String? appliedCouponCode;
  final double? couponMinOrderAmount;
  final String? couponDescription;

  double get subtotal =>
      items.fold(0.0, (sum, item) => sum + item.total);

  /// Dynamic GST calculation:
  /// Uses each item's product.taxRate if configured from inventory (> 0),
  /// otherwise falls back to cart-level taxRate.
  double get taxAmount {
    if (items.isEmpty) return 0.0;
    final hasItemTax = items.any((i) => i.product.taxRate > 0);
    if (hasItemTax) {
      return items.fold(0.0, (sum, item) {
        final rate = item.product.taxRate > 0 ? item.taxRateDecimal : taxRate;
        return sum + (item.total * rate);
      });
    }
    return subtotal * taxRate;
  }

  /// Blended / effective tax rate across all items in cart
  double get effectiveTaxRate => subtotal > 0 ? (taxAmount / subtotal) : taxRate;

  /// Subtotal + tax − discount + extra charges (clamped ≥ 0).
  double get total {
    final raw = subtotal + taxAmount - discount + extraCharges;
    return raw < 0 ? 0 : raw;
  }

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  int get lineCount => items.length;

  int getItemQuantity(String productId) {
    final idx = items.indexWhere((i) => i.product.id == productId);
    return idx >= 0 ? items[idx].quantity : 0;
  }

  CartState duplicate() {
    return CartState(
      items: items.map((e) => e.copyWith()).toList(),
      taxRate: taxRate,
      discount: discount,
      extraCharges: extraCharges,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      customerAddress: customerAddress,
      orderNotes: orderNotes,
      appliedCouponCode: appliedCouponCode,
      couponMinOrderAmount: couponMinOrderAmount,
      couponDescription: couponDescription,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((i) => i.toJson()).toList(),
      'taxRate': taxRate,
      'discount': discount,
      'extraCharges': extraCharges,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'customerAddress': customerAddress,
      'orderNotes': orderNotes,
      'appliedCouponCode': appliedCouponCode,
      'couponMinOrderAmount': couponMinOrderAmount,
      'couponDescription': couponDescription,
    };
  }

  factory CartState.fromJson(Map<String, dynamic> json) {
    return CartState(
      items: (json['items'] as List? ?? [])
          .map((i) => CartItem.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
      taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0.18,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      extraCharges: (json['extraCharges'] as num?)?.toDouble() ?? 0.0,
      customerName: json['customerName']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString() ?? '',
      customerEmail: json['customerEmail']?.toString() ?? '',
      customerAddress: json['customerAddress']?.toString() ?? '',
      orderNotes: json['orderNotes']?.toString() ?? '',
      appliedCouponCode: json['appliedCouponCode']?.toString(),
      couponMinOrderAmount: (json['couponMinOrderAmount'] as num?)?.toDouble(),
      couponDescription: json['couponDescription']?.toString(),
    );
  }

  CartState addItem(Product product) {
    if (!product.isInStock) return this;

    final existingIndex = items.indexWhere(
      (item) => item.product.id == product.id,
    );

    double nextTaxRate = taxRate;
    // When adding product with custom GST from inventory:
    // If cart was empty or currently at default, adopt the product's tax rate
    if (product.taxRate > 0 && items.isEmpty) {
      nextTaxRate = product.taxRateDecimal;
    }

    if (existingIndex != -1) {
      final current = items[existingIndex].quantity;
      if (current >= product.stock) return this;
      final updatedItems = List<CartItem>.from(items);
      updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
        quantity: current + 1,
      );
      return _copyWithItems(updatedItems, taxRate: nextTaxRate);
    }

    return _copyWithItems(
      [...items, CartItem(product: product, quantity: 1)],
      taxRate: nextTaxRate,
    );
  }

  CartState updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      return removeItem(productId);
    }

    final updatedItems = <CartItem>[];
    for (final item in items) {
      if (item.product.id == productId) {
        final capped = quantity.clamp(1, item.product.stock);
        updatedItems.add(item.copyWith(quantity: capped));
      } else {
        updatedItems.add(item);
      }
    }

    return _copyWithItems(updatedItems);
  }

  CartState removeItem(String productId) {
    return _copyWithItems(
      items.where((item) => item.product.id != productId).toList(),
    );
  }

  CartState clear() {
    return const CartState(
      items: [],
      taxRate: 0.18,
      discount: 0,
      extraCharges: 0,
      customerName: '',
      customerPhone: '',
      customerEmail: '',
      customerAddress: '',
      orderNotes: '',
      appliedCouponCode: null,
      couponMinOrderAmount: null,
      couponDescription: null,
    );
  }

  CartState updateDiscount(double newDiscount) {
    return CartState(
      items: items,
      taxRate: taxRate,
      discount: newDiscount < 0 ? 0 : newDiscount,
      extraCharges: extraCharges,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      customerAddress: customerAddress,
      orderNotes: orderNotes,
      appliedCouponCode: appliedCouponCode,
      couponMinOrderAmount: couponMinOrderAmount,
      couponDescription: couponDescription,
    );
  }

  CartState applyCoupon({
    required String code,
    required double discount,
    double? minOrderAmount,
    String? description,
  }) {
    return CartState(
      items: items,
      taxRate: taxRate,
      discount: discount < 0 ? 0 : discount,
      extraCharges: extraCharges,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      customerAddress: customerAddress,
      orderNotes: orderNotes,
      appliedCouponCode: code,
      couponMinOrderAmount: minOrderAmount,
      couponDescription: description,
    );
  }

  CartState removeCoupon() {
    return CartState(
      items: items,
      taxRate: taxRate,
      discount: 0.0,
      extraCharges: extraCharges,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      customerAddress: customerAddress,
      orderNotes: orderNotes,
      appliedCouponCode: null,
      couponMinOrderAmount: null,
      couponDescription: null,
    );
  }

  CartState updateTaxRate(double newTaxRate) {
    return CartState(
      items: items,
      taxRate: newTaxRate < 0 ? 0 : newTaxRate,
      discount: discount,
      extraCharges: extraCharges,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      customerAddress: customerAddress,
      orderNotes: orderNotes,
      appliedCouponCode: appliedCouponCode,
      couponMinOrderAmount: couponMinOrderAmount,
      couponDescription: couponDescription,
    );
  }

  CartState updateExtraCharges(double value) {
    return CartState(
      items: items,
      taxRate: taxRate,
      discount: discount,
      extraCharges: value < 0 ? 0 : value,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      customerAddress: customerAddress,
      orderNotes: orderNotes,
      appliedCouponCode: appliedCouponCode,
      couponMinOrderAmount: couponMinOrderAmount,
      couponDescription: couponDescription,
    );
  }

  CartState updateCustomer({
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) {
    return CartState(
      items: items,
      taxRate: taxRate,
      discount: discount,
      extraCharges: extraCharges,
      customerName: name ?? customerName,
      customerPhone: phone ?? customerPhone,
      customerEmail: email ?? customerEmail,
      customerAddress: address ?? customerAddress,
      orderNotes: notes ?? orderNotes,
      appliedCouponCode: appliedCouponCode,
      couponMinOrderAmount: couponMinOrderAmount,
      couponDescription: couponDescription,
    );
  }

  CartState replaceFrom(CartState other) {
    return CartState(
      items: other.items.map((e) => e.copyWith()).toList(),
      taxRate: other.taxRate,
      discount: other.discount,
      extraCharges: other.extraCharges,
      customerName: other.customerName,
      customerPhone: other.customerPhone,
      customerEmail: other.customerEmail,
      customerAddress: other.customerAddress,
      orderNotes: other.orderNotes,
      appliedCouponCode: other.appliedCouponCode,
      couponMinOrderAmount: other.couponMinOrderAmount,
      couponDescription: other.couponDescription,
    );
  }

  CartState _copyWithItems(List<CartItem> nextItems, {double? taxRate}) {
    final nextSubtotal = nextItems.fold(0.0, (sum, item) => sum + item.total);

    // If coupon is applied and new subtotal drops below minOrderAmount, auto-remove coupon
    final shouldRevokeCoupon = appliedCouponCode != null &&
        couponMinOrderAmount != null &&
        nextSubtotal < couponMinOrderAmount!;

    return CartState(
      items: nextItems,
      taxRate: taxRate ?? this.taxRate,
      discount: shouldRevokeCoupon ? 0.0 : discount,
      extraCharges: extraCharges,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      customerAddress: customerAddress,
      orderNotes: orderNotes,
      appliedCouponCode: shouldRevokeCoupon ? null : appliedCouponCode,
      couponMinOrderAmount: shouldRevokeCoupon ? null : couponMinOrderAmount,
      couponDescription: shouldRevokeCoupon ? null : couponDescription,
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState(items: []));

  /// Returns `false` if out of stock or already at max quantity for [product].
  bool tryAddItem(Product product) {
    if (!product.isInStock) return false;
    final idx = state.items.indexWhere((i) => i.product.id == product.id);
    if (idx >= 0 && state.items[idx].quantity >= product.stock) {
      return false;
    }
    state = state.addItem(product);
    return true;
  }

  void addItem(Product product) {
    tryAddItem(product);
  }

  /// Adds [quantity] to the line for [product] (adds line if missing). Clamped to `1..product.stock`.
  void addProductWithQuantity(Product product, int quantity) {
    if (!product.isInStock || quantity <= 0) return;
    
    final idx = state.items.indexWhere((i) => i.product.id == product.id);
    if (idx < 0) {
      final q = quantity.clamp(1, product.stock);
      state = state._copyWithItems([...state.items, CartItem(product: product, quantity: q)]);
    } else {
      final currentQty = state.items[idx].quantity;
      final newQty = (currentQty + quantity).clamp(1, product.stock);
      state = state.updateQuantity(product.id, newQty);
    }
  }

  void updateQuantity(String productId, int quantity) {
    state = state.updateQuantity(productId, quantity);
  }

  void removeItem(String productId) {
    state = state.removeItem(productId);
  }

  void clearCart() {
    state = state.clear();
  }

  void updateDiscount(double discount) {
    state = state.updateDiscount(discount);
  }

  void applyCoupon({
    required String code,
    required double discount,
    double? minOrderAmount,
    String? description,
  }) {
    state = state.applyCoupon(
      code: code,
      discount: discount,
      minOrderAmount: minOrderAmount,
      description: description,
    );
  }

  void removeCoupon() {
    state = state.removeCoupon();
  }

  void updateTaxRate(double taxRate) {
    state = state.updateTaxRate(taxRate);
  }

  void updateExtraCharges(double value) {
    state = state.updateExtraCharges(value);
  }

  void updateCustomer({
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) {
    state = state.updateCustomer(
      name: name,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
    );
  }

  void replaceWith(CartState other) {
    state = state.replaceFrom(other);
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});
