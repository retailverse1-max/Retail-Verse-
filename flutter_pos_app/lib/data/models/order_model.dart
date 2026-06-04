import 'package:uuid/uuid.dart';
import '../models/product_model.dart';

/// Order item model
class OrderItem {
  final Product product;
  final int quantity;
  final double price;
  final double total;

  OrderItem({
    required this.product,
    required this.quantity,
    required this.price,
    required this.total,
  });

  Map<String, dynamic> toJson() {
    return {
      'productId': product.id,
      'productName': product.name,
      'quantity': quantity,
      'price': price,
      'total': total,
    };
  }
}

/// Order model representing a completed transaction
class Order {
  final String id;
  final String orderId;
  final DateTime dateTime;
  final List<OrderItem> items;
  final double subtotal;
  final double tax;
  final double discount;
  final double total;
  final double extraCharges;
  final String paymentMethod;
  final String status;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerAddress;
  final String? notes;
  final String? cashierName;
  final bool converted;

  Order({
    required this.id,
    required this.orderId,
    required this.dateTime,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.total,
    this.extraCharges = 0.0,
    required this.paymentMethod,
    this.status = 'Completed',
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerAddress,
    this.notes,
    this.cashierName,
    this.converted = false,
  });

  /// Get item count
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'dateTime': dateTime.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'total': total,
      'extraCharges': extraCharges,
      'paymentMethod': paymentMethod,
      'status': status,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'customerAddress': customerAddress,
      'notes': notes,
      'cashierName': cashierName,
      'converted': converted,
    };
  }

  Order copyWith({
    String? id,
    String? orderId,
    DateTime? dateTime,
    List<OrderItem>? items,
    double? subtotal,
    double? tax,
    double? discount,
    double? total,
    double? extraCharges,
    String? paymentMethod,
    String? status,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? notes,
    String? cashierName,
    bool? converted,
  }) {
    return Order(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      dateTime: dateTime ?? this.dateTime,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      extraCharges: extraCharges ?? this.extraCharges,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      customerAddress: customerAddress ?? this.customerAddress,
      notes: notes ?? this.notes,
      cashierName: cashierName ?? this.cashierName,
      converted: converted ?? this.converted,
    );
  }
}
