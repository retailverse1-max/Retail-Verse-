import 'category.dart';

/// Product model for inventory management
class Product {
  final String id;
  final String name;
  final String sku;
  final String imageUrl;
  final int quantity;
  final double price;
  final String description;
  final String categoryId;
  final String categoryName;

  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.imageUrl,
    required this.quantity,
    required this.price,
    required this.description,
    required this.categoryId,
    required this.categoryName,
  });

  /// Check if product is in stock
  bool get isInStock => quantity > 10;

  /// Check if product has low stock
  bool get isLowStock => quantity <= 10 && quantity > 0;

  /// Check if product is out of stock
  bool get isOutOfStock => quantity == 0;

  /// Generate sample products for a category
  static List<Product> getSampleProductsForCategory(Category category) {
    final random = (category.id.hashCode % 100).abs();

    return List.generate(category.productCount, (index) {
      final productIndex = index + 1;
      final stockVariations = [
        random + productIndex * 3,
        random + productIndex * 2,
        random + productIndex,
        0, // Some out of stock
        5, // Some low stock
      ];

      return Product(
        id: '${category.id}-$productIndex',
        name: '${category.name} - Item $productIndex',
        sku:
            '${category.name.substring(0, 3).toUpperCase()}-${1000 + productIndex}',
        imageUrl: 'assets/icons/product.png',
        quantity: stockVariations[index % stockVariations.length],
        price: (99.0 + (productIndex * 49.5)).toDouble(),
        description:
            'High-quality ${category.name.toLowerCase()} component. Professional grade.',
        categoryId: category.id,
        categoryName: category.name,
      );
    });
  }

  /// Get all sample products across all categories
  static List<Product> getAllSampleProducts() {
    final categories = Category.getSampleCategories();
    return categories
        .expand((category) => getSampleProductsForCategory(category))
        .toList();
  }
}
