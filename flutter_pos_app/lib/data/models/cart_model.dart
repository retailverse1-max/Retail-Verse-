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

  /// Effective tax rate in decimal (e.g. 0.18 for 18%)
  double get taxRateDecimal => product.taxRateDecimal;

  /// Effective tax rate in percent (e.g. 18.0)
  double get taxRatePercent => product.taxRatePercent;

  /// Line tax amount based on product's GST rate from inventory
  double get taxAmount => total * taxRateDecimal;

  /// Line total including tax
  double get totalWithTax => total + taxAmount;

  /// Copy with method
  CartItem copyWith({Product? product, int? quantity}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'quantity': quantity,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(Map<String, dynamic>.from(json['product'] as Map)),
      quantity: json['quantity'] is int
          ? json['quantity'] as int
          : int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
    );
  }
}
