import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/api_endpoints.dart';
import '../../data/local/sync_queue_local_service.dart';
import '../../data/local/order_local_service.dart';
import '../../data/models/sync_queue_entity.dart';
import '../network/api_response_handler.dart';
import 'session_service.dart';

/// Sync Service - Handles synchronization of local data with backend API
///
/// TODO: Implement actual API integration for these methods
/// This is a foundation layer ready for backend integration
class SyncService {
  final SyncQueueLocalService _syncQueueService;
  final OrderLocalService _orderLocalService;
  final http.Client _httpClient;

  SyncService({
    required SyncQueueLocalService syncQueueService,
    required OrderLocalService orderLocalService,
    http.Client? httpClient,
  }) : _syncQueueService = syncQueueService,
       _orderLocalService = orderLocalService,
       _httpClient = httpClient ?? http.Client();

  /// Initialize and start sync process
  Future<void> initialize() async {
    debugPrint('SyncService initialized');
    // Auto-sync on initialization if online
    await processSyncQueue();
  }

  /// Process all pending items in sync queue
  Future<void> processSyncQueue() async {
    try {
      final pendingItems = await _syncQueueService.getPendingItems();

      if (pendingItems.isEmpty) {
        debugPrint('No pending items to sync');
        return;
      }

      debugPrint('Processing ${pendingItems.length} sync queue items');

      for (final item in pendingItems) {
        await _processSingleItem(item);
      }
    } catch (e) {
      debugPrint('Error processing sync queue: $e');
    }
  }

  /// Process a single sync queue item
  Future<void> _processSingleItem(SyncQueueEntity item) async {
    try {
      // Mark as syncing
      await _syncQueueService.markAsSyncing(item.id);

      bool success = false;

      // Route to appropriate handler based on entity type
      switch (item.entityType) {
        case 'order':
          success = await _syncOrder(item);
          break;
        case 'product':
          success = await _syncProduct(item);
          break;
        case 'inventory_movement':
          success = await _syncInventoryMovement(item);
          break;
        default:
          debugPrint('Unknown entity type: ${item.entityType}');
          success = false;
      }

      if (success) {
        await _syncQueueService.markAsSynced(item.id);
        debugPrint('Successfully synced item: ${item.id}');
      } else {
        await _syncQueueService.incrementRetry(item.id);
        debugPrint(
          'Failed to sync item: ${item.id}, retry count: ${item.retryCount + 1}',
        );
      }
    } catch (e) {
      debugPrint('Error processing item ${item.id}: $e');
      await _syncQueueService.incrementRetry(item.id);
    }
  }

  /// Sync order to backend
  ///
  /// TODO: Implement actual API call
  /// Expected implementation:
  /// ```dart
  /// final response = await http.post(
  ///   Uri.parse('$baseUrl/orders'),
  ///   headers: {'Content-Type': 'application/json'},
  ///   body: item.payload,
  /// );
  /// return response.statusCode == 201;
  /// ```
  Future<bool> _syncOrder(SyncQueueEntity item) async {
    debugPrint('Syncing order: ${item.entityId}');

    final orderData = jsonDecode(item.payload) as Map<String, dynamic>;
    final itemsRaw = orderData['items'] as List<dynamic>? ?? [];
    if (itemsRaw.isEmpty) {
      debugPrint('Sync order skipped: no items in payload');
      return false;
    }

    final items = itemsRaw.map((e) {
      final m = e as Map<String, dynamic>;
      return {
        'productId': m['productId'],
        'qty': m['quantity'] ?? m['qty'] ?? 1,
      };
    }).toList();

    final token = await SessionService.getToken();
    final rawPm = orderData['paymentMethod']?.toString() ?? 'cash';
    final pm = _normalizePayment(rawPm);
    final totalVal = orderData['totalAmount'] ?? orderData['total'];
    final total = totalVal is num ? totalVal.toDouble() : double.tryParse('$totalVal') ?? 0.0;

    try {
      final response = await _httpClient
          .post(
            Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.createOrder}'),
            headers: ApiResponseHandler.jsonHeaders(token: token),
            body: jsonEncode({
              'items': items,
              'paymentMethod': pm,
              'total': total,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _orderLocalService.markOrderAsSynced(item.entityId);
        return true;
      }
      debugPrint(
        'Sync order failed: ${response.statusCode} ${response.body}',
      );
      return false;
    } catch (e) {
      debugPrint('Sync order error: $e');
      return false;
    }
  }

  static String _normalizePayment(String raw) {
    final p = raw.toLowerCase();
    if (p.contains('upi')) return 'upi';
    if (p.contains('card')) return 'card';
    return 'cash';
  }

  /// Sync product to backend
  ///
  /// TODO: Implement actual API call
  /// Expected endpoint: POST /products or PUT /products/:id
  Future<bool> _syncProduct(SyncQueueEntity item) async {
    debugPrint('Syncing product: ${item.entityId}');
    jsonDecode(item.payload) as Map<String, dynamic>;
    await Future.delayed(const Duration(milliseconds: 300));
    return true;
  }

  /// Sync inventory movement to backend
  ///
  /// TODO: Implement actual API call
  /// Expected endpoint: POST /inventory/movements/sync
  Future<bool> _syncInventoryMovement(SyncQueueEntity item) async {
    debugPrint('Syncing inventory movement: ${item.entityId}');
    jsonDecode(item.payload) as Map<String, dynamic>;
    await Future.delayed(const Duration(milliseconds: 300));
    return true;
  }

  /// Manually trigger sync for specific order
  Future<void> syncOrderManually(String orderId) async {
    final order = await _orderLocalService.getOrderById(orderId);
    if (order == null) {
      debugPrint('Order not found: $orderId');
      return;
    }

    // Add to sync queue if not already pending
    await _syncQueueService.addQueueItem(
      entityType: 'order',
      entityId: orderId,
      action: 'create',
      payload: {
        'id': orderId,
        'customerName': order.customerName,
        'totalAmount': order.totalAmount,
        'status': order.status,
        'createdAt': order.createdAt.toIso8601String(),
      },
    );

    // Process immediately
    await processSyncQueue();
  }

  /// Get sync statistics
  Future<Map<String, int>> getSyncStats() async {
    final pending = await _syncQueueService.getPendingCount();
    final total = await _syncQueueService.getTotalCount();
    final failed = await _syncQueueService.getFailedItems().then(
      (items) => items.length,
    );

    return {
      'pending': pending,
      'total': total,
      'failed': failed,
      'synced': total - pending - failed,
    };
  }

  /// Clear old synced items (cleanup)
  Future<void> cleanupSyncedItems() async {
    final removed = await _syncQueueService.clearSyncedItems();
    debugPrint('Cleared $removed synced items from queue');
  }

  /// Retry all failed items
  Future<void> retryAllFailed() async {
    final failedItems = await _syncQueueService.getFailedItems();

    for (final item in failedItems) {
      await _syncQueueService.retryFailedItem(item.id);
    }

    debugPrint('Retrying ${failedItems.length} failed items');

    // Process the queue
    await processSyncQueue();
  }
}
