import 'package:flutter/material.dart';

import '../../../data/models/dashboard_stats_model.dart';
import '../../../data/repositories/dashboard_repository.dart';

class DashboardProvider extends ChangeNotifier {
  final DashboardRepository repository;

  DashboardProvider(this.repository);

  bool isLoading = false;
  String? error;

  double totalSales = 0;
  double todaySales = 0;
  int totalOrders = 0;
  int totalCustomers = 0;
  int lowStockItems = 0;

  Future<void> loadDashboard({required String token}) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      final DashboardStatsModel stats =
          await repository.getDashboardStats(token);

      totalSales = stats.totalSales;
      todaySales = stats.todaySales;
      totalOrders = stats.totalOrders;
      totalCustomers = stats.totalCustomers;
      lowStockItems = stats.lowStockItems;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh({required String token}) async {
    await loadDashboard(token: token);
  }
}