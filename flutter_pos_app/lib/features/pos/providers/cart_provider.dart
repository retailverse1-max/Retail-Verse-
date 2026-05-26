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

  double get subtotal =>
      items.fold(0.0, (sum, item) => sum + item.total);

  double get taxAmount => subtotal * taxRate;

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
    );
  }

  CartState addItem(Product product) {
    if (!product.isInStock) return this;

    final existingIndex = items.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex != -1) {
      final current = items[existingIndex].quantity;
      if (current >= product.stock) return this;
      final updatedItems = List<CartItem>.from(items);
      updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
        quantity: current + 1,
      );
      return _copyWithItems(updatedItems);
    }

    return CartState(
      items: [...items, CartItem(product: product, quantity: 1)],
      taxRate: taxRate,
      discount: discount,
      extraCharges: extraCharges,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      customerAddress: customerAddress,
      orderNotes: orderNotes,
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
    return CartState(
      items: const [],
      taxRate: taxRate,
      discount: 0,
      extraCharges: 0,
      customerName: '',
      customerPhone: '',
      customerEmail: '',
      customerAddress: '',
      orderNotes: '',
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
    );
  }

  CartState _copyWithItems(List<CartItem> nextItems) {
    return CartState(
      items: nextItems,
      taxRate: taxRate,
      discount: discount,
      extraCharges: extraCharges,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      customerAddress: customerAddress,
      orderNotes: orderNotes,
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

  /// Sets line quantity for [product] (adds line if missing). Clamped to `1..product.stock`.
  void addProductWithQuantity(Product product, int quantity) {
    if (!product.isInStock) return;
    final q = quantity.clamp(1, product.stock);
    final idx = state.items.indexWhere((i) => i.product.id == product.id);
    if (idx < 0) {
      state = CartState(
        items: [...state.items, CartItem(product: product, quantity: q)],
        taxRate: state.taxRate,
        discount: state.discount,
        extraCharges: state.extraCharges,
        customerName: state.customerName,
        customerPhone: state.customerPhone,
        customerEmail: state.customerEmail,
        customerAddress: state.customerAddress,
        orderNotes: state.orderNotes,
      );
    } else {
      state = state.updateQuantity(product.id, q);
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
