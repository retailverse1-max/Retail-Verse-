class DashboardOrderItemModel {
  final String productId;
  final String name;
  final int quantity;
  final double price;
  final double total;

  const DashboardOrderItemModel({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
  });

  factory DashboardOrderItemModel.fromJson(Map<String, dynamic> json) {
    final rawPid = json['productId'];
    String pid = '';
    if (rawPid is Map && rawPid[r'$oid'] is String) {
      pid = rawPid[r'$oid'] as String;
    } else if (rawPid != null) {
      pid = rawPid.toString();
    }
    return DashboardOrderItemModel(
      productId: pid,
      name: json['name']?.toString() ?? 'Unknown Product',
      quantity: (json['qty'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DashboardOrderSummaryModel {
  final String id;
  final String orderNumber;
  final double total;
  final String paymentMethod;
  final String status;
  final DateTime createdAt;
  final String createdByName;
  final List<DashboardOrderItemModel> items;

  const DashboardOrderSummaryModel({
    required this.id,
    required this.orderNumber,
    required this.total,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    required this.createdByName,
    required this.items,
  });

  factory DashboardOrderSummaryModel.fromJson(Map<String, dynamic> json) {
    final createdBy = json['createdBy'];
    final itemList = json['items'];

    return DashboardOrderSummaryModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? 'Order',
      total: (json['total'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['paymentMethod']?.toString() ?? 'cash',
      status: json['status']?.toString() ?? 'completed',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      createdByName: createdBy is Map<String, dynamic>
          ? createdBy['name']?.toString() ?? 'Store User'
          : 'Store User',
      items: itemList is List
          ? itemList
              .whereType<Map>()
              .map((e) {
                try {
                  return DashboardOrderItemModel.fromJson(
                    Map<String, dynamic>.from(e),
                  );
                } catch (_) {
                  return null;
                }
              })
              .whereType<DashboardOrderItemModel>()
              .toList()
          : const [],
    );
  }

  static DashboardOrderSummaryModel? tryFromJson(Map<String, dynamic> json) {
    try {
      return DashboardOrderSummaryModel.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static List<DashboardOrderSummaryModel> listFromJson(dynamic data) {
    if (data is! List) return [];
    final out = <DashboardOrderSummaryModel>[];
    for (final e in data) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final o = tryFromJson(m);
      if (o != null) out.add(o);
    }
    return out;
  }
}
