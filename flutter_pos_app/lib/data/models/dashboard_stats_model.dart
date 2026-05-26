class DashboardStatsModel {
  final double totalSales;
  final double todaySales;
  final double monthlySales;
  final double avgSale;
  final int totalOrders;
  final int totalCustomers;
  final int lowStockItems;

  static final DashboardStatsModel empty = DashboardStatsModel(
    totalSales: 0,
    todaySales: 0,
    monthlySales: 0,
    avgSale: 0,
    totalOrders: 0,
    totalCustomers: 0,
    lowStockItems: 0,
  );

  DashboardStatsModel({
    required this.totalSales,
    required this.todaySales,
    required this.monthlySales,
    required this.avgSale,
    required this.totalOrders,
    required this.totalCustomers,
    required this.lowStockItems,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return DashboardStatsModel(
      totalSales:    (json['totalSales']    as num?)?.toDouble() ?? 0,
      todaySales:    (json['todaySales']    as num?)?.toDouble() ?? 0,
      monthlySales:  (json['monthlySales']  as num?)?.toDouble() ?? 0,
      avgSale:       (json['avgSale']       as num?)?.toDouble() ?? 0,
      totalOrders:   (json['totalOrders']   as num?)?.toInt()    ?? 0,
      totalCustomers:(json['totalCustomers']as num?)?.toInt()    ?? 0,
      lowStockItems: (json['lowStockItems'] as num?)?.toInt()    ?? 0,
    );
  }
}