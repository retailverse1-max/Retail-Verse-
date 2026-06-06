import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers/api_config_provider.dart';
import '../../../data/datasources/order_remote_datasource.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/order_local_service.dart';
import '../../../data/local/product_local_service.dart';
import '../../../data/local/sync_queue_local_service.dart';
import '../../../data/models/cart_model.dart';
import '../../../data/models/order_model.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/order_entity.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import 'product_providers.dart';

/// ==========================================
/// LOCAL DATABASE / SERVICES PROVIDERS
/// ==========================================

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final orderLocalServiceProvider = Provider<OrderLocalService>((ref) {
  return OrderLocalService();
});

final productLocalServiceProvider = Provider<ProductLocalService>((ref) {
  return ProductLocalService();
});

final syncQueueLocalServiceProvider = Provider<SyncQueueLocalService>((ref) {
  return SyncQueueLocalService();
});

/// ==========================================
/// ORDER REPOSITORY PROVIDER (offline / legacy queue)
/// ==========================================

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(
    orderLocalService: ref.watch(orderLocalServiceProvider),
    productLocalService: ref.watch(productLocalServiceProvider),
    syncQueueService: ref.watch(syncQueueLocalServiceProvider),
  );
});

/// Remote API (Bearer token from session)
final orderRemoteDataSourceProvider = Provider<OrderRemoteDataSource>((ref) {
  ref.watch(apiConfigRefreshProvider);
  return OrderRemoteDataSource(
    client: ref.watch(posHttpClientProvider),
    baseUrl: ApiEndpoints.baseUrl,
  );
});

/// Orders list for Orders screen (GET /orders)
final ordersListProvider = FutureProvider<List<Order>>((ref) async {
  List<Order> remoteOrders = [];
  
  try {
    final remote = ref.watch(orderRemoteDataSourceProvider);
    remoteOrders = await remote.getOrders();
  } catch (e) {
    debugPrint('⚠️ Failed to fetch remote orders: $e');
  }

  // Always fetch offline unsynced orders to show them before they sync
  final localService = ref.watch(orderLocalServiceProvider);
  final localRepo = ref.watch(orderRepositoryProvider);
  
  try {
    // Get unsynced orders from local SQLite
    final unsyncedEntities = await localService.getUnsyncedOrders();
    final localOrders = await Future.wait(unsyncedEntities.map((entity) async {
      // We might need to fetch items from DB if we want full details, 
      // but Orders screen usually just needs the summary.
      // Wait, we can fetch items using localService:
      final itemsEntities = await localService.getOrderItems(entity.id);
      final productLocalService = ref.watch(productLocalServiceProvider);
      
      List<OrderItem> items = [];
      for (var ie in itemsEntities) {
        final product = await productLocalService.getProductById(ie.productId);
        if (product != null) {
          items.add(OrderItem(product: product, quantity: ie.quantity, price: ie.price, total: ie.quantity * ie.price));
        }
      }

      return Order(
        id: entity.id,
        orderId: entity.id,
        dateTime: entity.createdAt,
        items: items,
        subtotal: entity.totalAmount + entity.discount - entity.tax,
        tax: entity.tax,
        discount: entity.discount,
        total: entity.totalAmount,
        paymentMethod: 'Offline/Syncing',
        status: entity.status,
        customerName: entity.customerName ?? 'Walk-In Customer',
      );
    }));

    // If remote fetch failed and there are no unsynced, fallback to recent local orders
    if (remoteOrders.isEmpty && localOrders.isEmpty) {
       final recentEntities = await localService.getRecentOrders(limit: 100);
       final recentOrders = recentEntities.map((entity) => Order(
          id: entity.id,
          orderId: entity.id,
          dateTime: entity.createdAt,
          items: [], 
          subtotal: entity.totalAmount + entity.discount - entity.tax,
          tax: entity.tax,
          discount: entity.discount,
          total: entity.totalAmount,
          paymentMethod: 'Offline',
          status: entity.status,
          customerName: entity.customerName ?? 'Walk-In Customer',
       )).toList();
       return recentOrders;
    }

    // Filter out remote orders that match local IDs (to prevent duplicates if just synced)
    final localOrderIds = localOrders.map((o) => o.id).toSet();
    remoteOrders.removeWhere((o) => localOrderIds.contains(o.id));

    // Prepend local unsynced orders to remote orders
    return [...localOrders, ...remoteOrders]..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    
  } catch (e) {
    debugPrint('⚠️ Failed to fetch local orders: $e');
    return remoteOrders;
  }
});

/// Orders list for Super Admin Orders screen (GET /orders across all stores)
final saOrdersListProvider = FutureProvider<List<Order>>((ref) async {
  final remote = ref.watch(orderRemoteDataSourceProvider);
  return remote.getOrders(ignoreStoreId: true);
});

/// ==========================================
/// ORDER CREATION STATE
/// ==========================================

class OrderCreationState {
  final bool isLoading;
  final String? error;
  final String? orderId;
  final Order? createdOrder;

  const OrderCreationState({
    this.isLoading = false,
    this.error,
    this.orderId,
    this.createdOrder,
  });

  OrderCreationState copyWith({
    bool? isLoading,
    String? error,
    String? orderId,
    Order? createdOrder,
  }) {
    return OrderCreationState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      orderId: orderId ?? this.orderId,
      createdOrder: createdOrder ?? this.createdOrder,
    );
  }
}

/// ==========================================
/// ORDER CREATION NOTIFIER (API checkout)
/// ==========================================

class OrderCreationNotifier extends StateNotifier<OrderCreationState> {
  final Ref ref;

  OrderCreationNotifier(this.ref) : super(const OrderCreationState());

  /// Creates order on backend; server validates stock and deducts inventory.
  Future<bool> createOrder({
    required List<CartItem> cartItems,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? orderNotes,
    String paymentMethod = 'Cash',
    double discount = 0.0,
    double taxRate = 0.18,
    double extraCharges = 0.0,
    String? paymentStatus,
    String? status,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    String? razorpaySignature,
  }) async {
    if (cartItems.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Cart is empty',
      );
      return false;
    }

    final orderItems = cartItems
        .map(
          (c) => OrderItem(
            product: c.product,
            quantity: c.quantity,
            price: c.product.price,
            total: c.total,
          ),
        )
        .toList();

    try {
      state = state.copyWith(isLoading: true, error: null, createdOrder: null);

      final remote = ref.read(orderRemoteDataSourceProvider);

      final order = await remote.createOrder(
        items: orderItems,
        paymentMethod: paymentMethod,
        discount: discount,
        taxRate: taxRate,
        extraCharges: extraCharges,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        customerAddress: customerAddress,
        orderNotes: orderNotes,
        paymentStatus: paymentStatus,
        status: status,
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: razorpayPaymentId,
        razorpaySignature: razorpaySignature,
      ).timeout(const Duration(seconds: 15));

      // Patch extraCharges since the deployed backend might not return it yet
      final fixedOrder = order.copyWith(extraCharges: extraCharges);

      state = state.copyWith(
        isLoading: false,
        orderId: fixedOrder.id,
        createdOrder: fixedOrder,
      );

      ref.invalidate(todaySalesProvider);
      ref.invalidate(recentOrdersProvider);
      ref.invalidate(ordersListProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(recentActivityProvider);
      ref.invalidate(dashboardProductsProvider);
      ref.invalidate(dashboardLowStockProvider);
      ref.invalidate(dashboardOrdersProvider);
      ref.invalidate(productsProvider);

      return true;
    } catch (e) {
      final msg = e is ApiException ? e.message : e.toString();
      
      // Fallback to offline order creation if network error
      final errLower = (e.toString() + ' ' + msg).toLowerCase();
      final isNetworkError = errLower.contains('offline') || 
                             errLower.contains('unreachable') || 
                             errLower.contains('timed out') || 
                             errLower.contains('timeout') ||
                             errLower.contains('network error') ||
                             errLower.contains('socketexception') ||
                             errLower.contains('failed host lookup') ||
                             errLower.contains('connection refused') ||
                             errLower.contains('connection closed') ||
                             errLower.contains('handshakeexception') ||
                             errLower.contains('clientexception') ||
                             errLower.contains('no internet') ||
                             errLower.contains('no address associated') ||
                             errLower.contains('network is unreachable');

      if (isNetworkError) {
        debugPrint('⚠️ Network error detected, falling back to offline order creation...');
        try {
          final repository = ref.read(orderRepositoryProvider);
          final orderEntity = await repository.createOfflineOrder(
            cartItems: cartItems,
            customerName: customerName,
            paymentMethod: paymentMethod,
            discount: discount,
            taxRate: taxRate,
            status: status ?? 'Completed',
          );

          // Map offline OrderEntity to Order model
          final subtotal = cartItems.fold<double>(0, (sum, item) => sum + (item.product.price * item.quantity));
          final tax = subtotal * taxRate;
          
          final fixedOrder = Order(
            id: orderEntity.id,
            orderId: orderEntity.id,
            dateTime: orderEntity.createdAt,
            items: orderItems,
            subtotal: subtotal,
            tax: tax,
            discount: discount,
            total: orderEntity.totalAmount,
            extraCharges: extraCharges,
            paymentMethod: paymentMethod,
            status: status ?? 'Completed',
            customerName: customerName,
            customerPhone: customerPhone,
            customerEmail: customerEmail,
            customerAddress: customerAddress,
            notes: orderNotes,
          );

          state = state.copyWith(
            isLoading: false,
            orderId: fixedOrder.id,
            createdOrder: fixedOrder,
          );

          ref.invalidate(todaySalesProvider);
          ref.invalidate(recentOrdersProvider);
          ref.invalidate(ordersListProvider);
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(recentActivityProvider);
          ref.invalidate(dashboardProductsProvider);
          ref.invalidate(dashboardLowStockProvider);
          ref.invalidate(dashboardOrdersProvider);
          ref.invalidate(productsProvider);

          return true; // Successfully created offline!
        } catch (offlineError) {
          debugPrint('❌ Offline creation also failed: $offlineError');
          state = state.copyWith(
            isLoading: false,
            error: 'Offline order failed: $offlineError',
          );
          return false;
        }
      }

      state = state.copyWith(
        isLoading: false,
        error: msg,
      );
      return false;
    }
  }

  /// Updates order / quote on backend.
  Future<bool> updateOrder({
    required String orderId,
    required List<OrderItem> items,
    required String status,
    required String paymentMethod,
    double discount = 0.0,
    double taxRate = 0.18,
    double extraCharges = 0.0,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? orderNotes,
    String? paymentStatus,
    bool? converted,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null, createdOrder: null);

      final remote = ref.read(orderRemoteDataSourceProvider);
      final order = await remote.updateOrder(
        orderId: orderId,
        items: items,
        status: status,
        paymentMethod: paymentMethod,
        discount: discount,
        taxRate: taxRate,
        extraCharges: extraCharges,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        customerAddress: customerAddress,
        orderNotes: orderNotes,
        paymentStatus: paymentStatus,
        converted: converted,
      ).timeout(const Duration(seconds: 15));

      // Patch extraCharges since the deployed backend might not return it yet
      final fixedOrder = order.copyWith(extraCharges: extraCharges);

      state = state.copyWith(
        isLoading: false,
        orderId: fixedOrder.id,
        createdOrder: fixedOrder,
      );

      ref.invalidate(todaySalesProvider);
      ref.invalidate(recentOrdersProvider);
      ref.invalidate(ordersListProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(recentActivityProvider);
      ref.invalidate(dashboardProductsProvider);
      ref.invalidate(dashboardLowStockProvider);
      ref.invalidate(dashboardOrdersProvider);
      ref.invalidate(productsProvider);

      return true;
    } catch (e) {
      final msg = e is ApiException ? e.message : e.toString();
      
      // Check if it's an offline order (UUID length is 36) or network error
      final isOfflineOrder = orderId.length == 36;
      final errLower = (e.toString() + ' ' + msg).toLowerCase();
      final isNetworkError = errLower.contains('offline') || 
                             errLower.contains('unreachable') || 
                             errLower.contains('timed out') || 
                             errLower.contains('timeout') ||
                             errLower.contains('network error') ||
                             errLower.contains('socketexception') ||
                             errLower.contains('failed host lookup') ||
                             errLower.contains('connection refused') ||
                             errLower.contains('no internet');

      if (isOfflineOrder || isNetworkError) {
        debugPrint('⚠️ Network error or offline order, falling back to local update...');
        try {
          final localService = ref.read(orderLocalServiceProvider);
          
          final existingEntity = await localService.getOrderById(orderId);
          if (existingEntity != null) {
            final subtotal = items.fold<double>(0.0, (sum, i) => sum + i.total);
            final tax = subtotal * taxRate;
            final finalTotal = subtotal + tax + extraCharges - discount;

            final updatedEntity = OrderEntity(
              id: existingEntity.id,
              customerName: customerName ?? existingEntity.customerName,
              totalAmount: finalTotal < 0 ? 0 : finalTotal,
              status: status ?? existingEntity.status,
              synced: false,
              discount: discount,
              tax: tax,
              createdAt: existingEntity.createdAt,
            );

            final updatedItems = items.map<OrderItemEntity>((i) => OrderItemEntity(
              id: OrderItemEntity.generateId(),
              orderId: orderId,
              productId: i.product.id,
              quantity: i.quantity,
              price: i.price,
            )).toList();

            await localService.updateOrderFull(
              orderId: orderId,
              updatedOrder: updatedEntity,
              updatedItems: updatedItems,
            );

            // Fetch to confirm and map to UI state
            final fetchedEntity = await localService.getOrderById(orderId);
            if (fetchedEntity != null) {
              final fixedOrder = Order(
                id: fetchedEntity.id,
                orderId: fetchedEntity.id,
                dateTime: fetchedEntity.createdAt,
                items: items, 
                subtotal: subtotal,
                tax: updatedEntity.tax,
                discount: updatedEntity.discount,
                total: updatedEntity.totalAmount,
                paymentMethod: paymentMethod,
                status: updatedEntity.status,
                customerName: customerName ?? updatedEntity.customerName,
                customerPhone: customerPhone,
                customerEmail: customerEmail,
                customerAddress: customerAddress,
                notes: orderNotes,
              );

              state = state.copyWith(
                isLoading: false,
                orderId: fixedOrder.id,
                createdOrder: fixedOrder,
                error: null, // clear error since we succeeded locally
              );

              ref.invalidate(ordersListProvider);
              ref.invalidate(dashboardOrdersProvider);
              return true;
            }
          }
        } catch (localErr) {
           debugPrint('Local update failed: $localErr');
        }
      }

      state = state.copyWith(
        isLoading: false,
        error: msg,
      );
      return false;
    }
  }

  void clearState() {
    state = const OrderCreationState();
  }
}

/// ==========================================
/// ORDER CREATION PROVIDER
/// ==========================================

final orderCreationProvider =
    StateNotifierProvider<OrderCreationNotifier, OrderCreationState>((ref) {
  return OrderCreationNotifier(ref);
});

/// ==========================================
/// ORDER STATISTICS PROVIDERS (local SQLite)
/// ==========================================

final todaySalesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.getTodaySales();
});

final recentOrdersProvider = FutureProvider<List<dynamic>>((ref) async {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.getRecentOrders(limit: 20);
});
