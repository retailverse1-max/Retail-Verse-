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
  final remote = ref.watch(orderRemoteDataSourceProvider);
  return remote.getOrders();
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
    try {
      state = state.copyWith(isLoading: true, error: null, createdOrder: null);

      if (cartItems.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Cart is empty',
        );
        return false;
      }

      final remote = ref.read(orderRemoteDataSourceProvider);
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
      );

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
      );

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
