import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_endpoints.dart';
import '../../../core/navigation/role_nav.dart';
import '../../../core/providers/api_config_provider.dart';
import '../../../data/datasources/dashboard_remote_datasource.dart';
import '../../../data/datasources/notification_remote_datasource.dart';
import '../../../data/models/dashboard_order_summary_model.dart';
import '../../../data/models/dashboard_stats_model.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/recent_activity_model.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/repositories/dashboard_repository.dart';
import '../../../data/local/product_local_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../pos/providers/product_providers.dart';
import '../../pos/providers/order_providers.dart';
import '../../../core/services/session_service.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

final dashboardSearchQueryProvider = StateProvider<String?>((ref) => null);

final dashboardRemoteDataSourceProvider = Provider<DashboardRemoteDataSource>((
  ref,
) {
  ref.watch(apiConfigRefreshProvider);
  return DashboardRemoteDataSource(
    client: ref.read(httpClientProvider),
    baseUrl: ApiEndpoints.baseUrl,
  );
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  // watch (not read): new remote datasource when API base URL / client refreshes
  return DashboardRepository(
    remoteDataSource: ref.watch(dashboardRemoteDataSourceProvider),
  );
});

final dashboardNotificationRemoteDataSourceProvider =
    Provider<NotificationRemoteDataSource>((ref) {
  ref.watch(apiConfigRefreshProvider);
  return NotificationRemoteDataSource(
    client: ref.read(httpClientProvider),
    baseUrl: ApiEndpoints.baseUrl,
  );
});

/// Call after login, session restore, or API URL change so lists refetch with fresh token/URL.
void invalidateAllDashboardProviders(WidgetRef ref) {
  ref.invalidate(dashboardStatsProvider);
  ref.invalidate(recentActivityProvider);
  ref.invalidate(dashboardProductsProvider);
  ref.invalidate(dashboardLowStockProvider);
  ref.invalidate(dashboardOrdersProvider);
  ref.invalidate(dashboardNotificationsProvider);
  ref.invalidate(productsProvider);
}

final dashboardStatsProvider = FutureProvider<DashboardStatsModel>((ref) async {
  var token = ref.watch(authProvider.select((s) => s.token));
  if (token == null || token.isEmpty) {
    token = await SessionService.getToken();
  }
  final repository = ref.watch(dashboardRepositoryProvider);

  if (kDebugMode) {
    final t = token;
    debugPrint(
      'dashboardStatsProvider: GET /dashboard/stats '
      '(token: ${t != null && t.isNotEmpty ? "yes" : "no"})',
    );
  }

  // 1. Fetch remote stats (or cached)
  DashboardStatsModel remoteStats = DashboardStatsModel.empty;
  try {
    remoteStats = await repository.getDashboardStats(token);
  } catch (_) {}

  // 2. Compute local orders stats from SQLite (so local/offline/POS orders are ALWAYS included!)
  double localTotalSales = 0.0;
  int localTotalOrders = 0;
  double localTodaySales = 0.0;
  double localMonthSales = 0.0;

  try {
    final localService = ref.watch(orderLocalServiceProvider);
    final totalSummary = await localService.getTotalSalesSummary();
    final todaySummary = await localService.getTodaySales();
    final monthSummary = await localService.getMonthSales();

    localTotalSales = (totalSummary['totalSales'] as num?)?.toDouble() ?? 0.0;
    localTotalOrders = (totalSummary['orderCount'] as num?)?.toInt() ?? 0;
    localTodaySales = (todaySummary['totalSales'] as num?)?.toDouble() ?? 0.0;
    localMonthSales = (monthSummary['totalSales'] as num?)?.toDouble() ?? 0.0;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('dashboardStatsProvider: local stats error: $e');
    }
  }

  // 3. Hybrid merge:
  // Use math.max so whether data is remote, local, or newly placed, Revenue & Orders will NEVER be 0 if orders exist!
  final totalSales = math.max(remoteStats.totalSales, localTotalSales);
  final totalOrders = math.max(remoteStats.totalOrders, localTotalOrders);
  final todaySales = math.max(remoteStats.todaySales, localTodaySales);
  final monthlySales = math.max(remoteStats.monthlySales, math.max(totalSales, localMonthSales));
  final avgSale = totalOrders > 0 ? (totalSales / totalOrders) : 0.0;

  return remoteStats.copyWith(
    totalSales: totalSales,
    totalOrders: totalOrders,
    todaySales: todaySales,
    monthlySales: monthlySales,
    avgSale: avgSale,
  );
});

final recentActivityProvider = FutureProvider<List<RecentActivityModel>>((
  ref,
) async {
  var token = ref.watch(authProvider.select((s) => s.token));
  if (token == null || token.isEmpty) {
    token = await SessionService.getToken();
  }
  final repository = ref.watch(dashboardRepositoryProvider);

  return repository.getRecentActivities(token);
});

final dashboardProductsProvider = FutureProvider<List<Product>>((ref) async {
  var token = ref.watch(authProvider.select((s) => s.token));
  if (token == null || token.isEmpty) {
    token = await SessionService.getToken();
  }
  final repository = ref.watch(dashboardRepositoryProvider);

  // 1. Fetch from remote if token is available
  if (token != null && token.isNotEmpty) {
    try {
      final remote = await repository.getProducts(token);
      // Sync local DB with remote products for this user
      try {
        await ProductLocalService().clearProducts();
        if (remote.isNotEmpty) {
          await ProductLocalService().insertProducts(remote);
        }
      } catch (_) {}
      return remote;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('dashboardProductsProvider: fallback to local DB due to error: $e');
      }
    }
  }

  // 2. Fallback to local products only if offline / remote call failed
  try {
    final localProducts = await ProductLocalService().getAllProducts();
    if (localProducts.isNotEmpty) {
      return localProducts;
    }
  } catch (_) {}

  return [];
});

final dashboardLowStockProvider = FutureProvider<List<Product>>((ref) async {
  try {
    final products = await ref.watch(dashboardProductsProvider.future);
    final low = products.where((p) => p.stock <= 10).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));
    return low;
  } catch (_) {
    return [];
  }
});

final dashboardOrdersProvider =
    FutureProvider<List<DashboardOrderSummaryModel>>((ref) async {
      var token = ref.watch(authProvider.select((s) => s.token));
      if (token == null || token.isEmpty) {
        token = await SessionService.getToken();
      }
      final user = ref.watch(authProvider.select((s) => s.user));
      final role = effectiveUserRole(user);

      final repository = ref.watch(dashboardRepositoryProvider);
      List<DashboardOrderSummaryModel> remoteOrders = [];

      if (token != null && token.isNotEmpty && canLoadDashboardOrders(role)) {
        try {
          remoteOrders = await repository.getOrders(token);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('dashboardOrdersProvider: empty after error: $e');
          }
        }
      }

      try {
        final localService = ref.watch(orderLocalServiceProvider);
        
        // Fetch both unsynced AND recent local orders (up to 200)
        final unsyncedEntities = await localService.getUnsyncedOrders();
        final recentEntities = await localService.getRecentOrders(limit: 200);

        final Map<String, dynamic> localEntityMap = {};
        for (final e in recentEntities) {
          localEntityMap[e.id] = e;
        }
        for (final e in unsyncedEntities) {
          localEntityMap[e.id] = e;
        }

        final localOrders = localEntityMap.values.map((entity) => DashboardOrderSummaryModel(
          id: entity.id,
          orderNumber: entity.id.length > 8 ? entity.id.substring(0, 8) : entity.id,
          createdByName: entity.customerName ?? 'Walk-In Customer',
          total: entity.totalAmount,
          paymentMethod: 'cash',
          status: entity.status,
          createdAt: entity.createdAt,
          items: [],
        )).toList();

        final localIds = localOrders.map((o) => o.id).toSet();
        remoteOrders.removeWhere((o) => localIds.contains(o.id));

        return [...localOrders, ...remoteOrders]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } catch (e) {
        return remoteOrders;
      }
    });

final dashboardNotificationsProvider = FutureProvider<List<AppNotification>>((
  ref,
) async {
  final token = ref.watch(authProvider.select((s) => s.token));
  if (token == null || token.isEmpty) return [];
  final remote = ref.watch(dashboardNotificationRemoteDataSourceProvider);
  return remote.getNotifications(token: token);
});

final unreadDashboardNotificationsCountProvider = Provider<int>((ref) {
  final list = ref.watch(dashboardNotificationsProvider).asData?.value ?? const [];
  return list.where((n) => !n.isRead).length;
});

/// Monthly Sales, Profit & Loss computed from real order data.
/// Sales  = sum of valid orders (completed, paid, offline, sale) this calendar month
/// Loss   = sum of cancelled orders this calendar month
/// Profit = Sales - (estimated cost: 60% of sales as fallback when cost=0)
final monthlyStatsProvider = Provider<({double sales, double profit, double loss})>((ref) {
  final ordersAsync = ref.watch(dashboardOrdersProvider);
  final orders = ordersAsync.asData?.value ?? [];

  final now = DateTime.now();
  final monthOrders = orders.where((o) {
    return o.createdAt.year == now.year && o.createdAt.month == now.month;
  }).toList();

  // Sales = valid completed/paid/offline orders total (exclude pending quotes & cancelled)
  final sales = monthOrders
      .where((o) {
        final st = o.status.toLowerCase();
        return st != 'pending' && st != 'cancelled' && st != 'refunded';
      })
      .fold(0.0, (sum, o) => sum + o.total);

  // Loss = cancelled orders total
  final loss = monthOrders
      .where((o) {
        final st = o.status.toLowerCase();
        return st == 'cancelled' || st == 'refunded';
      })
      .fold(0.0, (sum, o) => sum + o.total);

  // Profit = Sales minus estimated cost
  // If order items have cost data we use it, else assume 65% gross margin
  double totalCost = 0.0;
  for (final o in monthOrders.where((o) {
    final st = o.status.toLowerCase();
    return st != 'pending' && st != 'cancelled' && st != 'refunded';
  })) {
    final itemCost = o.items.isNotEmpty
        ? o.items.fold(0.0, (s, i) => s + (i.price * 0.6 * i.quantity))
        : (o.total * 0.6);
    totalCost += itemCost;
  }
  final profit = (sales - totalCost).clamp(0.0, double.infinity);

  return (sales: sales, profit: profit, loss: loss);
});

final customersProvider = FutureProvider<List<CustomerModel>>((ref) async {
  final token = ref.watch(authProvider.select((s) => s.token));
  if (token == null || token.isEmpty) return [];
  
  final dataSource = ref.watch(dashboardRemoteDataSourceProvider);
  return dataSource.getCustomers(token: token);
});
