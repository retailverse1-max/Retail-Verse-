import '../models/product_model.dart';

/// Abstract interface for product data source
abstract class IProductDataSource {
  Future<List<Product>> getAllProducts();
  Future<Product?> getProductById(String id);
  Future<Product?> getProductByBarcode(String barcode);
  Future<List<Product>> searchProducts(String query);
  Future<List<Product>> getProductsByCategory(String category);
  Future<List<Product>> getLowStockProducts(int threshold);
  Future<void> updateProductStock(String id, int quantity);
  Future<Product> createProduct({
    required String name,
    required String sku,
    required double price,
    double cost = 0,
    int stock = 0,
    String barcode = '',
    String category = '',
    String? imageBase64,
    String? description,
  });
  Future<Product> updateProduct({
    required String id,
    String? name,
    String? sku,
    double? price,
    double? cost,
    int? stock,
    String? barcode,
    String? category,
    String? imageBase64,
    String? description,
    bool? isActive,
  });
  Future<Map<String, dynamic>> quickInward({
    String? barcode,
    String? productId,
    required int quantity,
    double? costPrice,
    String? batchNo,
    String? expiryDate,
  });
  Future<void> deleteProduct(String id);
}
