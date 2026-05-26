import 'product_model.dart';

/// Cart item model representing a product in the shopping cart
class CartItem {
  final Product product;
  final int quantity;

  CartItem({required this.product, required this.quantity});

  /// Get line total (guards bad / non-finite prices from bad data).
  double get total {
    final p = product.price;
    final q = quantity;
    if (!p.isFinite || q <= 0) return 0;
    return p * q;
  }

  /// Copy with method
  CartItem copyWith({Product? product, int? quantity}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}
