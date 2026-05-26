import 'package:sqflite/sqflite.dart';
import '../models/order_entity.dart';
import '../local/app_database.dart';

/// Local service for managing orders in SQLite database
class OrderLocalService {
  /// Insert a new order
  Future<int> insertOrder(OrderEntity order) async {
    final db = await AppDatabase.database;
    return await db.insert(
      'orders',
      order.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert order items
  Future<void> insertOrderItems(List<OrderItemEntity> items) async {
    final db = await AppDatabase.database;
    final batch = db.batch();

    for (final item in items) {
      batch.insert(
        'order_items',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get recent orders (default: last 50)
  Future<List<OrderEntity>> getRecentOrders({int limit = 50}) async {
    final db = await AppDatabase.database;

    final result = await db.query(
      'orders',
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return result.map((e) => OrderEntity.fromMap(e)).toList();
  }

  /// Get order by ID
  Future<OrderEntity?> getOrderById(String id) async {
    final db = await AppDatabase.database;

    final result = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return OrderEntity.fromMap(result.first);
  }

  /// Get order items for a specific order
  Future<List<OrderItemEntity>> getOrderItems(String orderId) async {
    final db = await AppDatabase.database;

    final result = await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'id ASC',
    );

    return result.map((e) => OrderItemEntity.fromMap(e)).toList();
  }

  /// Get today's sales summary
  Future<Map<String, dynamic>> getTodaySales() async {
    final db = await AppDatabase.database;

    // Get start of today
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfDayStr = startOfDay.toIso8601String();

    // Get today's orders
    final result = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as orderCount,
        COALESCE(SUM(total_amount), 0) as totalSales
      FROM orders
      WHERE created_at >= ?
    ''',
      [startOfDayStr],
    );

    final orderCount = Sqflite.firstIntValue(result) ?? 0;
    final totalSales = (result.first['totalSales'] as num?)?.toDouble() ?? 0.0;

    return {'orderCount': orderCount, 'totalSales': totalSales};
  }

  /// Get today's order count
  Future<int> getTodayOrderCount() async {
    final db = await AppDatabase.database;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfDayStr = startOfDay.toIso8601String();

    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM orders
      WHERE created_at >= ?
    ''',
      [startOfDayStr],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get orders by status
  Future<List<OrderEntity>> getOrdersByStatus(String status) async {
    final db = await AppDatabase.database;

    final result = await db.query(
      'orders',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );

    return result.map((e) => OrderEntity.fromMap(e)).toList();
  }

  /// Update order status
  Future<int> updateOrderStatus({
    required String orderId,
    required String newStatus,
  }) async {
    final db = await AppDatabase.database;

    return await db.update(
      'orders',
      {'status': newStatus},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  /// Mark order as synced
  Future<int> markOrderAsSynced(String orderId) async {
    final db = await AppDatabase.database;

    return await db.update(
      'orders',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  /// Get unsynced orders
  Future<List<OrderEntity>> getUnsyncedOrders() async {
    final db = await AppDatabase.database;

    final result = await db.query(
      'orders',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );

    return result.map((e) => OrderEntity.fromMap(e)).toList();
  }

  /// Delete order (soft delete not implemented for orders)
  Future<int> deleteOrder(String orderId) async {
    final db = await AppDatabase.database;
    return await db.delete('orders', where: 'id = ?', whereArgs: [orderId]);
  }

  /// Get total orders count
  Future<int> getTotalOrdersCount() async {
    final db = await AppDatabase.database;

    final result = await db.rawQuery('SELECT COUNT(*) as count FROM orders');

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Clear all orders (debug only)
  Future<void> clearOrders() async {
    final db = await AppDatabase.database;
    await db.delete('orders');
  }
}
