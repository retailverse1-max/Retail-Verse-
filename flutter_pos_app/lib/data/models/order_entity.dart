import 'package:uuid/uuid.dart';

/// Order model for SQLite storage
class OrderEntity {
  final String id;
  final String? customerName;
  final double totalAmount;
  final String status;
  final DateTime createdAt;
  final bool synced;

  OrderEntity({
    required this.id,
    this.customerName,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.synced = false,
  });

  /// Convert to Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_name': customerName,
      'total_amount': totalAmount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  /// Create from Map (SQLite)
  factory OrderEntity.fromMap(Map<String, dynamic> map) {
    return OrderEntity(
      id: map['id'] ?? '',
      customerName: map['customer_name'],
      totalAmount: (map['total_amount'] ?? 0).toDouble(),
      status: map['status'] ?? 'Pending',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      synced: (map['synced'] ?? 0) == 1,
    );
  }

  /// Copy with method
  OrderEntity copyWith({
    String? id,
    String? customerName,
    double? totalAmount,
    String? status,
    DateTime? createdAt,
    bool? synced,
  }) {
    return OrderEntity(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
    );
  }

  @override
  String toString() =>
      'OrderEntity(id: $id, customerName: $customerName, totalAmount: $totalAmount, status: $status, synced: $synced)';
}

/// Order Item model for SQLite storage
class OrderItemEntity {
  final String id;
  final String orderId;
  final String productId;
  final int quantity;
  final double price;

  OrderItemEntity({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.price,
  });

  /// Convert to Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'price': price,
    };
  }

  /// Create from Map (SQLite)
  factory OrderItemEntity.fromMap(Map<String, dynamic> map) {
    return OrderItemEntity(
      id: map['id'] ?? '',
      orderId: map['order_id'] ?? '',
      productId: map['product_id'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] ?? 0).toDouble(),
    );
  }

  /// Generate unique ID
  static String generateId() => const Uuid().v4();

  @override
  String toString() =>
      'OrderItemEntity(id: $id, orderId: $orderId, productId: $productId, quantity: $quantity, price: $price)';
}
