import '../datasources/dashboard_remote_datasource.dart';
import '../models/dashboard_order_summary_model.dart';
import '../models/dashboard_stats_model.dart';
import '../models/product_model.dart';
import '../models/recent_activity_model.dart';

class DashboardRepository {
  final DashboardRemoteDataSource remoteDataSource;

  DashboardRepository({
    required this.remoteDataSource,
  });

  Future<DashboardStatsModel> getDashboardStats([String? token]) {
    return remoteDataSource.getDashboardStats(token: token);
  }

  Future<List<RecentActivityModel>> getRecentActivities([String? token]) {
    return remoteDataSource.getRecentActivities(token: token);
  }

  Future<List<Product>> getProducts(String token) {
    return remoteDataSource.getProducts(token: token);
  }

  Future<List<Product>> getLowStockProducts(String token) {
    return remoteDataSource.getLowStockProducts(token: token);
  }

  Future<List<DashboardOrderSummaryModel>> getOrders(String token) {
    return remoteDataSource.getOrders(token: token);
  }

  Future<List<dynamic>> getCustomers(String token) {
    return remoteDataSource.getCustomers(token: token);
  }

  Future<bool> addCustomer({
    required String token,
    required String name,
    required String phone,
    String? email,
    String? address,
  }) {
    return remoteDataSource.addCustomer(
      token: token,
      name: name,
      phone: phone,
      email: email,
      address: address,
    );
  }
}
