import '../models/product_model.dart';
import '../datasources/product_data_source.dart';
import '../local/product_local_service.dart';

/// Product repository for business logic
class ProductRepository {
  final IProductDataSource dataSource;

  ProductRepository({required this.dataSource});

  Future<List<Product>> getAllProducts() async {
    return await dataSource.getAllProducts();
  }

  Future<Product?> getProductById(String id) async {
    return await dataSource.getProductById(id);
  }

  Future<List<Product>> searchProducts(String query) async {
    return await dataSource.searchProducts(query);
  }

  Future<List<Product>> getProductsByCategory(String category) async {
    return await dataSource.getProductsByCategory(category);
  }

  Future<List<Product>> getLowStockProducts(int threshold) async {
    return await dataSource.getLowStockProducts(threshold);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    return await dataSource.getProductByBarcode(barcode);
  }

  Future<Map<String, dynamic>> quickInward({
    String? barcode,
    String? productId,
    required int quantity,
    double? costPrice,
    String? batchNo,
    String? expiryDate,
  }) async {
    return await dataSource.quickInward(
      barcode: barcode,
      productId: productId,
      quantity: quantity,
      costPrice: costPrice,
      batchNo: batchNo,
      expiryDate: expiryDate,
    );
  }

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
    String? dimensions,
    List<String>? marketplaces,
    double? taxRate,
  }) async {
    final product = await dataSource.createProduct(
      name: name,
      sku: sku,
      price: price,
      cost: cost,
      stock: stock,
      barcode: barcode,
      category: category,
      imageBase64: imageBase64,
      description: description,
      dimensions: dimensions,
      marketplaces: marketplaces,
      taxRate: taxRate,
    );
    try {
      await ProductLocalService().insertProduct(product);
    } catch (_) {}
    return product;
  }

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
    double? taxRate,
    String? dimensions,
    List<String>? marketplaces,
  }) async {
    final product = await dataSource.updateProduct(
      id: id,
      name: name,
      sku: sku,
      price: price,
      cost: cost,
      stock: stock,
      barcode: barcode,
      category: category,
      imageBase64: imageBase64,
      description: description,
      isActive: isActive,
      taxRate: taxRate,
      dimensions: dimensions,
      marketplaces: marketplaces,
    );
    try {
      await ProductLocalService().updateProduct(product);
    } catch (_) {}
    return product;
  }

  Future<void> deleteProduct(String id) async {
    try {
      await ProductLocalService().deleteProduct(id);
    } catch (_) {}
    return await dataSource.deleteProduct(id);
  }
}
