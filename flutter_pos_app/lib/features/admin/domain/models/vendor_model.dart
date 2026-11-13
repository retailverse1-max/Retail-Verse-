/// Represents a registered Vendor in Retail Verse
class VendorProfile {
  final String id;
  final String name;
  final String companyName;
  final String phone;
  final String email;
  final String category;
  final String address;
  final String? gstin;
  final double rating;
  final bool isActive;
  final DateTime createdAt;

  const VendorProfile({
    required this.id,
    required this.name,
    required this.companyName,
    required this.phone,
    required this.email,
    required this.category,
    required this.address,
    this.gstin,
    this.rating = 4.8,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'companyName': companyName,
        'phone': phone,
        'email': email,
        'category': category,
        'address': address,
        'gstin': gstin,
        'rating': rating,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory VendorProfile.fromJson(Map<String, dynamic> json) => VendorProfile(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        companyName: json['companyName']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        category: json['category']?.toString() ?? 'General Supply',
        address: json['address']?.toString() ?? '',
        gstin: json['gstin']?.toString(),
        rating: (json['rating'] is num) ? (json['rating'] as num).toDouble() : 4.8,
        isActive: json['isActive'] ?? true,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

/// Represents one split line item assigned to a vendor
class VendorSplitItem {
  final String id;
  String vendorId;
  String vendorName;
  int units;
  DateTime targetDeliveryDate;
  String status;

  VendorSplitItem({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.units,
    required this.targetDeliveryDate,
    this.status = 'Allocated',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'vendorId': vendorId,
        'vendorName': vendorName,
        'units': units,
        'targetDeliveryDate': targetDeliveryDate.toIso8601String(),
        'status': status,
      };

  factory VendorSplitItem.fromJson(Map<String, dynamic> json) => VendorSplitItem(
        id: json['id']?.toString() ?? '',
        vendorId: json['vendorId']?.toString() ?? '',
        vendorName: json['vendorName']?.toString() ?? '',
        units: (json['units'] is num) ? (json['units'] as num).toInt() : 0,
        targetDeliveryDate: json['targetDeliveryDate'] != null
            ? DateTime.tryParse(json['targetDeliveryDate'].toString()) ??
                DateTime.now().add(const Duration(days: 5))
            : DateTime.now().add(const Duration(days: 5)),
        status: json['status']?.toString() ?? 'Allocated',
      );
}

/// Represents a confirmed Multi-Vendor Allocation Record / Purchase Order
class VendorAllocationRecord {
  final String id;
  final String productId;
  final String productName;
  final String productSku;
  final int currentStock;
  final int threshold;
  final int totalUnitsNeeded;
  final List<VendorSplitItem> splits;
  final DateTime createdAt;
  final String status; // 'Allocated', 'Confirmed', 'In Transit', 'Fulfilled'

  const VendorAllocationRecord({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.currentStock,
    required this.threshold,
    required this.totalUnitsNeeded,
    required this.splits,
    required this.createdAt,
    this.status = 'Allocated',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'productName': productName,
        'productSku': productSku,
        'currentStock': currentStock,
        'threshold': threshold,
        'totalUnitsNeeded': totalUnitsNeeded,
        'splits': splits.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'status': status,
      };

  factory VendorAllocationRecord.fromJson(Map<String, dynamic> json) =>
      VendorAllocationRecord(
        id: json['id']?.toString() ?? '',
        productId: json['productId']?.toString() ?? '',
        productName: json['productName']?.toString() ?? 'Grocery',
        productSku: json['productSku']?.toString() ?? 'RV-134045-3890',
        currentStock: (json['currentStock'] is num) ? (json['currentStock'] as num).toInt() : 5,
        threshold: (json['threshold'] is num) ? (json['threshold'] as num).toInt() : 5,
        totalUnitsNeeded: (json['totalUnitsNeeded'] is num) ? (json['totalUnitsNeeded'] as num).toInt() : 20,
        splits: (json['splits'] as List<dynamic>?)
                ?.map((e) => VendorSplitItem.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        status: json['status']?.toString() ?? 'Allocated',
      );
}

/// Represents a procurement requirement allocated to a vendor
class VendorRequirementItem {
  final String id;
  final String orderId;
  final String productName;
  final String productSku;
  final String? vendorName;
  final int units;
  final int totalUnitsNeeded;
  final DateTime targetDeliveryDate;
  final String status; // 'Pending', 'Accepted', 'In Transit', 'Received'
  final DateTime createdAt;
  final String triggeredBy;

  const VendorRequirementItem({
    required this.id,
    required this.orderId,
    required this.productName,
    required this.productSku,
    this.vendorName,
    required this.units,
    required this.totalUnitsNeeded,
    required this.targetDeliveryDate,
    required this.status,
    required this.createdAt,
    required this.triggeredBy,
  });

  factory VendorRequirementItem.fromJson(Map<String, dynamic> json) =>
      VendorRequirementItem(
        id: json['id']?.toString() ?? '',
        orderId: json['orderId']?.toString() ?? '',
        productName: json['productName']?.toString() ?? 'Grocery',
        productSku: json['productSku']?.toString() ?? 'RV-134045-3890',
        vendorName: json['vendorName']?.toString(),
        units: (json['units'] is num) ? (json['units'] as num).toInt() : 0,
        totalUnitsNeeded: (json['totalUnitsNeeded'] is num)
            ? (json['totalUnitsNeeded'] as num).toInt()
            : 20,
        targetDeliveryDate: json['targetDeliveryDate'] != null
            ? DateTime.tryParse(json['targetDeliveryDate'].toString()) ??
                DateTime.now().add(const Duration(days: 6))
            : DateTime.now().add(const Duration(days: 6)),
        status: json['status']?.toString() ?? 'Pending',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        triggeredBy: json['triggeredBy']?.toString() ?? 'auto_low_stock',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderId': orderId,
        'productName': productName,
        'productSku': productSku,
        if (vendorName != null) 'vendorName': vendorName,
        'units': units,
        'totalUnitsNeeded': totalUnitsNeeded,
        'targetDeliveryDate': targetDeliveryDate.toIso8601String(),
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'triggeredBy': triggeredBy,
      };

  VendorRequirementItem copyWith({
    String? status,
    String? vendorName,
  }) {
    return VendorRequirementItem(
      id: id,
      orderId: orderId,
      productName: productName,
      productSku: productSku,
      vendorName: vendorName ?? this.vendorName,
      units: units,
      totalUnitsNeeded: totalUnitsNeeded,
      targetDeliveryDate: targetDeliveryDate,
      status: status ?? this.status,
      createdAt: createdAt,
      triggeredBy: triggeredBy,
    );
  }
}

/// Vendor Portal Summary Metrics
class VendorPortalMetrics {
  final int allocatedUnits;
  final int totalRequests;
  final int actionRequired;
  final int inTransit;
  final int fulfilled;

  const VendorPortalMetrics({
    this.allocatedUnits = 0,
    this.totalRequests = 0,
    this.actionRequired = 0,
    this.inTransit = 0,
    this.fulfilled = 0,
  });

  factory VendorPortalMetrics.fromJson(Map<String, dynamic> json) =>
      VendorPortalMetrics(
        allocatedUnits: (json['allocatedUnits'] is num)
            ? (json['allocatedUnits'] as num).toInt()
            : 0,
        totalRequests: (json['totalRequests'] is num)
            ? (json['totalRequests'] as num).toInt()
            : 0,
        actionRequired: (json['actionRequired'] is num)
            ? (json['actionRequired'] as num).toInt()
            : 0,
        inTransit: (json['inTransit'] is num)
            ? (json['inTransit'] as num).toInt()
            : 0,
        fulfilled: (json['fulfilled'] is num)
            ? (json['fulfilled'] as num).toInt()
            : 0,
      );
}

class VendorPortalData {
  final VendorProfile vendor;
  final VendorPortalMetrics metrics;
  final List<VendorRequirementItem> requirements;

  const VendorPortalData({
    required this.vendor,
    required this.metrics,
    required this.requirements,
  });
}

