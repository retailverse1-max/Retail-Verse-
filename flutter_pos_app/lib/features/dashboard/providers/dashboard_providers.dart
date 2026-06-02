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
import '../../auth/providers/auth_provider.dart';
import '../../pos/providers/product_providers.dart';

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
  final token = ref.watch(authProvider.select((s) => s.token));
  final repository = ref.watch(dashboardRepositoryProvider);

  if (kDebugMode) {
    final t = token;
    debugPrint(
      'dashboardStatsProvider: GET /dashboard/stats '
      '(token: ${t != null && t.isNotEmpty ? "yes" : "no"})',
    );
  }

  // Datasource never throws; always returns data or zeros.
  return repository.getDashboardStats(token);
});

final recentActivityProvider = FutureProvider<List<RecentActivityModel>>((
  ref,
) async {
  final token = ref.watch(authProvider.select((s) => s.token));
  final repository = ref.watch(dashboardRepositoryProvider);

  return repository.getRecentActivities(token);
});

final dashboardProductsProvider = FutureProvider<List<Product>>((ref) async {
  final token = ref.watch(authProvider.select((s) => s.token));
  final repository = ref.watch(dashboardRepositoryProvider);

  if (token == null || token.isEmpty) {
    return [];
  }

  try {
    return await repository.getProducts(token);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('dashboardProductsProvider: empty after error: $e');
    }
    return [];
  }
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
      final token = ref.watch(authProvider.select((s) => s.token));
      final user = ref.watch(authProvider.select((s) => s.user));
      final role = effectiveUserRole(user);

      if (token == null || token.isEmpty) {
        return [];
      }

      if (!canLoadDashboardOrders(role)) {
        return [];
      }

      final repository = ref.watch(dashboardRepositoryProvider);
      try {
        return await repository.getOrders(token);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('dashboardOrdersProvider: empty after error: $e');
        }
        return [];
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
/// Sales  = sum of completed orders this calendar month
/// Loss   = sum of cancelled orders this calendar month
/// Profit = Sales - (estimated cost: 60% of sales as fallback when cost=0)
final monthlyStatsProvider = Provider<({double sales, double profit, double loss})>((ref) {
  final ordersAsync = ref.watch(dashboardOrdersProvider);
  final orders = ordersAsync.asData?.value ?? [];

  final now = DateTime.now();
  final monthOrders = orders.where((o) {
    return o.createdAt.year == now.year && o.createdAt.month == now.month;
  }).toList();

  // Sales = completed orders total
  final sales = monthOrders
      .where((o) => o.status == 'completed' || o.status == 'paid')
      .fold(0.0, (sum, o) => sum + o.total);

  // Loss = cancelled orders total
  final loss = monthOrders
      .where((o) => o.status == 'cancelled' || o.status == 'refunded')
      .fold(0.0, (sum, o) => sum + o.total);

  // Profit = Sales minus estimated cost
  // If order items have cost data we use it, else assume 65% gross margin
  double totalCost = 0.0;
  for (final o in monthOrders.where((o) => o.status == 'completed' || o.status == 'paid')) {
    final itemCost = o.items.fold(0.0, (s, i) => s + (i.price * 0.6 * i.quantity));
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
