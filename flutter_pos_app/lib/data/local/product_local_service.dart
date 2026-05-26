import 'package:sqflite/sqflite.dart';
import '../models/product_model.dart';
import 'app_database.dart';

class ProductLocalService {
  /// Insert single product
  Future<int> insertProduct(Product product) async {
    final db = await AppDatabase.database;
    return await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple products (fast)
  Future<void> insertProducts(List<Product> products) async {
    final db = await AppDatabase.database;
    final batch = db.batch();

    for (final product in products) {
      batch.insert(
        'products',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get all products
  Future<List<Product>> getAllProducts() async {
    final db = await AppDatabase.database;

    final result = await db.query(
      'products',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'name ASC',
    );

    return result.map((e) => Product.fromMap(e)).toList();
  }

  /// Get product by id
  Future<Product?> getProductById(String id) async {
    final db = await AppDatabase.database;

    final result = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return Product.fromMap(result.first);
  }

  /// Search product
  Future<List<Product>> searchProducts(String keyword) async {
    final db = await AppDatabase.database;

    final result = await db.query(
      'products',
      where: 'is_deleted = 0 AND name LIKE ?',
      whereArgs: ['%$keyword%'],
      orderBy: 'name ASC',
    );

    return result.map((e) => Product.fromMap(e)).toList();
  }

  /// Update full product
  Future<int> updateProduct(Product product) async {
    final db = await AppDatabase.database;

    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  /// Update stock
  Future<int> updateStock({
    required String productId,
    required int newStock,
  }) async {
    final db = await AppDatabase.database;

    return await db.update(
      'products',
      {
        'stock': newStock,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  /// Reduce stock (sale ke time)
  Future<int> reduceStock({
    required String productId,
    required int quantity,
  }) async {
    final db = await AppDatabase.database;

    final result = await db.query(
      'products',
      columns: ['stock'],
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );

    if (result.isEmpty) {
      throw Exception('Product not found');
    }

    final currentStock = result.first['stock'] as int;
    final updatedStock = currentStock - quantity;

    if (updatedStock < 0) {
      throw Exception('Insufficient stock');
    }

    return await db.update(
      'products',
      {
        'stock': updatedStock,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  /// Total products count
  Future<int> getTotalProductsCount() async {
    final db = await AppDatabase.database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE is_deleted = 0',
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Low stock count
  Future<int> getLowStockCount() async {
    final db = await AppDatabase.database;

    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM products
      WHERE is_deleted = 0 AND stock <= reorder_level
    ''');

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Low stock products
  Future<List<Product>> getLowStockProducts() async {
    final db = await AppDatabase.database;

    final result = await db.rawQuery('''
      SELECT *
      FROM products
      WHERE is_deleted = 0 AND stock <= reorder_level
      ORDER BY stock ASC
    ''');

    return result.map((e) => Product.fromMap(e)).toList();
  }

  /// Total inventory value
  Future<double> getTotalInventoryValue() async {
    final db = await AppDatabase.database;

    final result = await db.rawQuery('''
      SELECT SUM(price * stock) as total
      FROM products
      WHERE is_deleted = 0
    ''');

    final value = result.first['total'];
    if (value == null) return 0.0;
    return (value as num).toDouble();
  }

  /// Clear table (debug only)
  Future<void> clearProducts() async {
    final db = await AppDatabase.database;
    await db.delete('products');
  }
}