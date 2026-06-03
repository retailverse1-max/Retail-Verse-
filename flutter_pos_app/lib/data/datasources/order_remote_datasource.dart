import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_endpoints.dart';
import '../../core/utils/num_parse.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/api_response_handler.dart';
import '../../core/services/session_service.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';

/// Remote order data source for API communication
class OrderRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  OrderRemoteDataSource({required this.client, required this.baseUrl});

  /// Create a new order via API
  Future<Order> createOrder({
    required List<OrderItem> items,
    required String paymentMethod,
    double discount = 0.0,
    double taxRate = 0.18, // 18% GST default
    double extraCharges = 0.0,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? orderNotes,
    String? paymentStatus,
    String? status,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    String? razorpaySignature,
  }) async {
    try {
      final token = await _getToken();

      // Backend validates stock and recomputes line totals from DB prices.
      final subtotal = items.fold<double>(0.0, (sum, item) => sum + item.total);
      final taxAmount = subtotal * taxRate;
      final extra = extraCharges < 0 ? 0.0 : extraCharges;
      final total = subtotal + taxAmount - discount + extra;

      final payload = {
        'items': items
            .map(
              (item) => {
                'productId': item.product.id,
                'qty': item.quantity,
              },
            )
            .toList(),
        'paymentMethod': _normalizePaymentMethod(paymentMethod),
        'total': total,
        'discount': discount,
        'tax': taxAmount,
        'extraCharges': extra,
        if (customerName != null && customerName.isNotEmpty)
          'customerName': customerName,
        if (customerPhone != null && customerPhone.isNotEmpty)
          'customerPhone': customerPhone,
        if (customerEmail != null && customerEmail.isNotEmpty)
          'customerEmail': customerEmail,
        if (customerAddress != null && customerAddress.isNotEmpty)
          'customerAddress': customerAddress,
        if (orderNotes != null && orderNotes.isNotEmpty) 'notes': orderNotes,
        if (paymentStatus != null) 'paymentStatus': paymentStatus,
        if (status != null) 'status': status,
        if (razorpayOrderId != null) 'razorpayOrderId': razorpayOrderId,
        if (razorpayPaymentId != null) 'razorpayPaymentId': razorpayPaymentId,
        if (razorpaySignature != null) 'razorpaySignature': razorpaySignature,
      };

      debugPrint('CREATE_ORDER_REQUEST: ${jsonEncode(payload)}');

      var response = await client
          .post(
            Uri.parse('$baseUrl${ApiEndpoints.createOrder}'),
            headers: ApiResponseHandler.jsonHeaders(token: token),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      // Some deployments expose POST /orders (without /create). Keep current flow
      // first, and only retry on 404 to avoid breaking existing backend contracts.
      if (response.statusCode == 404) {
        final fallbackPayload = _fallbackOrderPayload(
          items: items,
          paymentMethod: paymentMethod,
          total: total,
          customerName: customerName,
          customerPhone: customerPhone,
          customerAddress: customerAddress,
          orderNotes: orderNotes,
          paymentStatus: paymentStatus,
          status: status,
          razorpayOrderId: razorpayOrderId,
          razorpayPaymentId: razorpayPaymentId,
          razorpaySignature: razorpaySignature,
        );
        debugPrint(
          'CREATE_ORDER_FALLBACK_REQUEST: ${jsonEncode(fallbackPayload)}',
        );
        response = await client
            .post(
              Uri.parse('$baseUrl${ApiEndpoints.orders}'),
              headers: ApiResponseHandler.jsonHeaders(token: token),
              body: jsonEncode(fallbackPayload),
            )
            .timeout(const Duration(seconds: 15));
      }

      ApiResponseHandler.logResponse('CREATE_ORDER_RESPONSE', response);

      final decoded = ApiResponseHandler.decodeJsonResponse(
        response,
        action: 'create order',
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw ApiResponseHandler.errorFromResponse(
          response,
          action: 'create order',
          decodedBody: decoded,
        );
      }

      // Parse the order from response
      final orderData = decoded['order'] ?? decoded['data'];
      if (orderData is! Map<String, dynamic>) {
        throw const ApiException(
          'The server returned an invalid order response.',
        );
      }

      return _parseOrder(orderData);
    } on SocketException catch (error) {
      throw ApiResponseHandler.errorFromException(
        error,
        action: 'create order',
      );
    } on HttpException catch (error) {
      throw ApiResponseHandler.errorFromException(
        error,
        action: 'create order',
      );
    } on FormatException catch (error) {
      throw ApiResponseHandler.errorFromException(
        error,
        action: 'create order',
      );
    }
  }

  /// Update an order or convert quote
  Future<Order> updateOrder({
    required String orderId, // database ObjectId
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
      final token = await _getToken();

      final subtotal = items.fold<double>(0.0, (sum, item) => sum + item.total);
      final taxAmount = subtotal * taxRate;
      final extra = extraCharges < 0 ? 0.0 : extraCharges;
      final total = subtotal + taxAmount - discount + extra;

      final payload = {
        'items': items
            .map(
              (item) => {
                'productId': item.product.id,
                'qty': item.quantity,
              },
            )
            .toList(),
        'paymentMethod': _normalizePaymentMethod(paymentMethod),
        'total': total,
        'discount': discount,
        'tax': taxAmount,
        'status': status.toLowerCase(),
        if (paymentStatus != null) 'paymentStatus': paymentStatus.toLowerCase(),
        if (customerName != null) 'customerName': customerName,
        if (customerPhone != null) 'customerPhone': customerPhone,
        if (customerEmail != null) 'customerEmail': customerEmail,
        if (customerAddress != null) 'customerAddress': customerAddress,
        if (orderNotes != null) 'notes': orderNotes,
        if (converted != null) 'converted': converted,
      };

      debugPrint('UPDATE_ORDER_REQUEST ($orderId): ${jsonEncode(payload)}');

      final response = await client
          .put(
            Uri.parse('$baseUrl${ApiEndpoints.orders}/$orderId'),
            headers: ApiResponseHandler.jsonHeaders(token: token),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      ApiResponseHandler.logResponse('UPDATE_ORDER_RESPONSE', response);

      final decoded = ApiResponseHandler.decodeJsonResponse(
        response,
        action: 'update order',
      );

      if (response.statusCode != 200) {
        throw ApiResponseHandler.errorFromResponse(
          response,
          action: 'update order',
          decodedBody: decoded,
        );
      }

      final orderData = decoded['order'] ?? decoded['data'];
      if (orderData is! Map<String, dynamic>) {
        throw const ApiException(
          'The server returned an invalid order response on update.',
        );
      }

      return _parseOrder(orderData);
    } on SocketException catch (error) {
      throw ApiResponseHandler.errorFromException(
        error,
        action: 'update order',
      );
    } on HttpException catch (error) {
      throw ApiResponseHandler.errorFromException(
        error,
        action: 'update order',
      );
    } on FormatException catch (error) {
      throw ApiResponseHandler.errorFromException(
        error,
        action: 'update order',
      );
    } catch (error) {
      rethrow;
    }
  }

  /// Get all orders
  Future<List<Order>> getOrders({bool ignoreStoreId = false}) async {
    try {
      final token = await _getToken();
      final response = await client
          .get(
            Uri.parse('$baseUrl${ApiEndpoints.orders}'),
            headers: ApiResponseHandler.jsonHeaders(token: token, ignoreStoreId: ignoreStoreId),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = ApiResponseHandler.decodeJsonResponse(
        response,
        action: 'get orders',
      );

      if (response.statusCode != 200) {
        throw ApiResponseHandler.errorFromResponse(
          response,
          action: 'get orders',
          decodedBody: decoded,
        );
      }

      final data = decoded['data'];
      if (data is! List) {
        return [];
      }

      return data.whereType<Map<String, dynamic>>().map(_parseOrder).toList();
    } catch (error) {
      return [];
    }
  }

  /// Get order by ID
  Future<Order?> getOrderById(String id) async {
    try {
      final token = await _getToken();
      final response = await client
          .get(
            Uri.parse(
              '$baseUrl${ApiEndpoints.orderById.replaceFirst(':id', id)}',
            ),
            headers: ApiResponseHandler.jsonHeaders(token: token),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = ApiResponseHandler.decodeJsonResponse(
        response,
        action: 'get order by ID',
      );

      if (response.statusCode != 200) {
        return null;
      }

      final orderData = decoded['data'] ?? decoded['order'];
      if (orderData is! Map<String, dynamic>) {
        return null;
      }

      return _parseOrder(orderData);
    } catch (error) {
      return null;
    }
  }

  /// Parse order from JSON response
  Order _parseOrder(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? [];
    final items = itemsJson.whereType<Map<String, dynamic>>().map((itemJson) {
      final pid = _stringifyId(itemJson['productId']);
      final product = Product(
        id: pid,
        name: itemJson['productName'] ?? itemJson['name'] ?? 'Unknown',
        sku: itemJson['productSku']?.toString() ?? '',
        category: itemJson['category']?.toString() ?? '',
        price: parseMoney(itemJson['price']),
        cost: 0.0,
        stock: 0,
        reorderLevel: 0,
        unit: 'pcs',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return OrderItem(
        product: product,
        quantity: parseIntLoose(itemJson['qty'] ?? itemJson['quantity'], 1),
        price: parseMoney(itemJson['price']),
        total: parseMoney(itemJson['total']),
      );
    }).toList();

    final subtotal = items.fold<double>(0.0, (sum, item) => sum + item.total);
    final oid = _stringifyId(json['_id'] ?? json['id']);
    final orderNum =
        json['orderNumber']?.toString() ?? json['orderId']?.toString() ?? oid;

    return Order(
      id: oid,
      orderId: orderNum,
      dateTime: json['dateTime'] != null
          ? DateTime.parse(json['dateTime'].toString())
          : (json['createdAt'] != null
                ? DateTime.parse(json['createdAt'].toString())
                : DateTime.now()),
      items: items,
      subtotal: subtotal,
      tax: parseMoney(json['tax']),
      discount: parseMoney(json['discount']),
      total: parseMoney(json['total']),
      paymentMethod: _prettyPayment(json['paymentMethod']?.toString() ?? 'cash'),
      status: _prettyStatus(json['status']?.toString() ?? 'completed'),
      customerName: json['customerName']?.toString(),
      customerPhone: json['customerPhone']?.toString(),
      customerEmail: json['customerEmail']?.toString() ?? json['customerEmailAddress']?.toString(),
      customerAddress: json['customerAddress']?.toString(),
      notes: json['notes']?.toString(),
      cashierName: json['createdBy'] is Map<String, dynamic>
          ? (json['createdBy']['name']?.toString())
          : json['cashierName']?.toString(),
      converted: json['converted'] == true,
    );
  }

  static String _normalizePaymentMethod(String raw) {
    final p = raw.toLowerCase().trim();
    if (p == 'cash' || p.contains('cash')) return 'cash';
    if (p == 'upi' || p.contains('upi')) return 'upi';
    if (p == 'card' || p.contains('card')) return 'card';
    if (p == 'razorpay' || p.contains('razorpay')) return 'razorpay';
    if (p == 'other' || p.contains('other')) return 'other';
    return 'cash';
  }

  static String _prettyPayment(String raw) {
    switch (raw.toLowerCase()) {
      case 'upi':
        return 'UPI';
      case 'card':
        return 'Card';
      case 'razorpay':
        return 'Razorpay';
      default:
        return 'Cash';
    }
  }

  static String _prettyStatus(String raw) {
    if (raw.isEmpty) return 'Completed';
    return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
  }

  static String _stringifyId(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is Map && v[r'$oid'] != null) return v[r'$oid'].toString();
    return v.toString();
  }

  static Map<String, dynamic> _fallbackOrderPayload({
    required List<OrderItem> items,
    required String paymentMethod,
    required double total,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? orderNotes,
    String? paymentStatus,
    String? status,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    String? razorpaySignature,
  }) {
    final pm = _normalizePaymentMethod(paymentMethod);
    return {
      'items': items
          .map(
            (item) => {
              'productId': item.product.id,
              'name': item.product.name,
              'price': item.price,
              'quantity': item.quantity,
              'qty': item.quantity,
              'total': item.total,
            },
          )
          .toList(),
      'paymentMethod': pm,
      // POS-friendly fields
      'total': total,
      // Common ecommerce variants for broader compatibility
      'totalPrice': total,
      'paymentStatus': paymentStatus ?? 'paid',
      'status': status ?? 'completed',
      'channel': 'pos',
      if (razorpayOrderId != null) 'razorpayOrderId': razorpayOrderId,
      if (razorpayPaymentId != null) 'razorpayPaymentId': razorpayPaymentId,
      if (razorpaySignature != null) 'razorpaySignature': razorpaySignature,
      if (customerName != null && customerName.trim().isNotEmpty)
        'customerName': customerName.trim(),
      if (customerPhone != null && customerPhone.trim().isNotEmpty)
        'customerPhone': customerPhone.trim(),
      if (customerEmail != null && customerEmail.trim().isNotEmpty)
        'customerEmail': customerEmail.trim(),
      if (orderNotes != null && orderNotes.trim().isNotEmpty)
        'notes': orderNotes.trim(),
      if (customerAddress != null && customerAddress.trim().isNotEmpty)
        'customerAddress': customerAddress.trim(),
      if (customerAddress != null && customerAddress.trim().isNotEmpty)
        'shippingAddress': {
          'fullName': (customerName ?? '').trim(),
          'phone': (customerPhone ?? '').trim(),
          'address': customerAddress.trim(),
          'city': '',
          'state': '',
          'zipCode': '',
          'country': 'India',
        },
    };
  }

  Future<String?> _getToken() => SessionService.getToken();
}
