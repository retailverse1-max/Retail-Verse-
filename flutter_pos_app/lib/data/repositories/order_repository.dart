import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/order_entity.dart';
import '../models/cart_model.dart';
import '../models/sync_queue_entity.dart';
import '../local/order_local_service.dart';
import '../local/product_local_service.dart';
import '../local/sync_queue_local_service.dart';
import '../local/app_database.dart';

/// Repository for managing orders with offline-first architecture
class OrderRepository {
  final OrderLocalService _orderLocalService;
  final ProductLocalService _productLocalService;
  final SyncQueueLocalService _syncQueueService;

  OrderRepository({
    required OrderLocalService orderLocalService,
    required ProductLocalService productLocalService,
    required SyncQueueLocalService syncQueueService,
  }) : _orderLocalService = orderLocalService,
       _productLocalService = productLocalService,
       _syncQueueService = syncQueueService;

  /// Create an offline order with full transaction safety
  ///
  /// This method:
  /// 1. Creates an order in SQLite
  /// 2. Saves order items
  /// 3. Reduces product stock
  /// 4. Adds entry to sync_queue for later backend sync
  ///
  /// All operations happen in a single transaction - either all succeed or all fail
  Future<OrderEntity> createOfflineOrder({
    required List<CartItem> cartItems,
    String? customerName,
    String paymentMethod = 'Cash',
    double discount = 0.0,
    double taxRate = 0.18, // 18% GST default
  }) async {
    if (cartItems.isEmpty) {
      throw Exception('Cart is empty');
    }

    final db = await AppDatabase.database;

    return await db.transaction<OrderEntity>((txn) async {
      try {
        // Step 1: Validate and check stock for all products
        for (final cartItem in cartItems) {
          final product = await _getProductById(txn, cartItem.product.id);

          if (product == null) {
            throw Exception('Product not found: ${cartItem.product.name}');
          }

          if (product.stock < cartItem.quantity) {
            throw Exception(
              'Insufficient stock for ${product.name}. Available: ${product.stock}, Requested: ${cartItem.quantity}',
            );
          }
        }

        // Step 2: Calculate totals
        final subtotal = cartItems.fold<double>(
          0.0,
          (sum, item) => sum + (item.product.price * item.quantity),
        );
        final taxAmount = subtotal * taxRate;
        final totalAmount = subtotal + taxAmount - discount;

        // Step 3: Create Order entity
        final orderId = const Uuid().v4();
        final order = OrderEntity(
          id: orderId,
          customerName: customerName,
          totalAmount: totalAmount,
          status: 'Completed',
          createdAt: DateTime.now(),
          synced: false, // Mark as not synced initially
        );

        // Step 4: Insert order using transaction
        await txn.insert('orders', order.toMap());

        // Step 5: Create and insert order items
        final orderItems = <OrderItemEntity>[];
        for (final cartItem in cartItems) {
          final orderItem = OrderItemEntity(
            id: OrderItemEntity.generateId(),
            orderId: orderId,
            productId: cartItem.product.id,
            quantity: cartItem.quantity,
            price: cartItem.product.price,
          );
          orderItems.add(orderItem);
        }

        // Batch insert order items
        final batch = txn.batch();
        for (final item in orderItems) {
          batch.insert('order_items', item.toMap());
        }
        await batch.commit(noResult: true);

        // Step 6: Reduce product stock
        for (final cartItem in cartItems) {
          final newStock = cartItem.product.stock - cartItem.quantity;
          await txn.update(
            'products',
            {'stock': newStock, 'updated_at': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [cartItem.product.id],
          );
        }

        // Step 7: Create sync queue entry
        final orderPayload = {
          'id': orderId,
          'customerName': customerName,
          'totalAmount': totalAmount,
          'status': order.status,
          'createdAt': order.createdAt.toIso8601String(),
          'paymentMethod': paymentMethod,
          'discount': discount,
          'taxRate': taxRate,
          'items': cartItems
              .map(
                (item) => {
                  'productId': item.product.id,
                  'productName': item.product.name,
                  'quantity': item.quantity,
                  'price': item.product.price,
                  'total': item.product.price * item.quantity,
                },
              )
              .toList(),
        };

        await txn.insert(
          'sync_queue',
          SyncQueueEntity(
            id: SyncQueueEntity.generateId(),
            entityType: 'order',
            entityId: orderId,
            action: 'create',
            payload: jsonEncode(orderPayload),
            createdAt: DateTime.now(),
            status: SyncStatus.pending,
          ).toMap(),
        );

        debugPrint('✅ Offline order created successfully: $orderId');
        debugPrint('   Total: ₹$totalAmount');
        debugPrint('   Items: ${cartItems.length}');
        debugPrint('   Sync queue: pending');

        return order;
      } catch (e) {
        debugPrint('❌ Error creating order: $e');
        // Transaction will automatically rollback on error
        rethrow;
      }
    });
  }

  /// Helper method to get product by ID from transaction
  Future<dynamic> _getProductById(dynamic txn, String productId) async {
    final result = await txn.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );

    if (result.isEmpty) return null;

    // Return raw map - we just need to check existence and stock
    return result.first;
  }

  /// Get recent orders
  Future<List<OrderEntity>> getRecentOrders({int limit = 50}) async {
    return await _orderLocalService.getRecentOrders(limit: limit);
  }

  /// Get today's sales statistics
  Future<Map<String, dynamic>> getTodaySales() async {
    return await _orderLocalService.getTodaySales();
  }

  /// Get order by ID with items
  Future<Map<String, dynamic>?> getOrderWithItems(String orderId) async {
    final order = await _orderLocalService.getOrderById(orderId);
    if (order == null) return null;

    final items = await _orderLocalService.getOrderItems(orderId);

    return {'order': order, 'items': items};
  }

  /// Retry syncing a specific order
  Future<void> retryOrderSync(String orderId) async {
    final db = await AppDatabase.database;

    // Mark order as unsynced
    await db.update(
      'orders',
      {'synced': 0},
      where: 'id = ?',
      whereArgs: [orderId],
    );

    // Add to sync queue
    await _syncQueueService.addQueueItem(
      entityType: 'order',
      entityId: orderId,
      action: 'create',
      payload: {}, // Will be populated by caller if needed
    );
  }
}
