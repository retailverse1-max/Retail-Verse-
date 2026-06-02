import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_response_handler.dart';
import '../models/dashboard_order_summary_model.dart';
import '../models/dashboard_stats_model.dart';
import '../models/product_model.dart';
import '../models/recent_activity_model.dart';
import '../models/customer_model.dart';

class DashboardRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  DashboardRemoteDataSource({required this.client, required this.baseUrl});

  /// Never throws — returns [DashboardStatsModel.empty] on any failure so the UI never
  /// shows "Access denied" / load-failed from Riverpod [AsyncError].
  Future<DashboardStatsModel> getDashboardStats({String? token}) async {
    try {
      final response = await client
          .get(
            Uri.parse('$baseUrl${ApiEndpoints.dashboardStats}'),
            // ✅ FIX: Send token so backend doesn't return 401
            headers: token != null && token.isNotEmpty
                ? ApiResponseHandler.jsonHeaders(token: token)
                : ApiResponseHandler.publicJsonHeaders(),
          )
          .timeout(const Duration(seconds: 20));

      ApiResponseHandler.logResponse('DASHBOARD_STATS', response);

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
            'DASHBOARD_STATS: HTTP ${response.statusCode} → zeros '
            '(body: ${response.body.length > 120 ? "${response.body.substring(0, 120)}…" : response.body})',
          );
        }
        return DashboardStatsModel.empty;
      }

      final decoded = ApiResponseHandler.decodeJsonResponse(
        response,
        action: 'load dashboard stats',
      );

      if (decoded is! Map<String, dynamic>) {
        return DashboardStatsModel.empty;
      }

      final data = decoded['data'] ?? decoded;
      if (data is! Map<String, dynamic>) {
        return DashboardStatsModel.empty;
      }

      final model = DashboardStatsModel.fromJson(data);
      if (kDebugMode) {
        debugPrint(
          'Dashboard stats parsed → totalSales=${model.totalSales}, '
          'totalOrders=${model.totalOrders}, customers=${model.totalCustomers}',
        );
      }
      return model;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('DASHBOARD_STATS: non-fatal $e\n$st');
      }
      return DashboardStatsModel.empty;
    }
  }

  /// Never throws — returns an empty list on failure (same rationale as [getDashboardStats]).
  Future<List<RecentActivityModel>> getRecentActivities({String? token}) async {
    try {
      final response = await client
          .get(
            Uri.parse('$baseUrl${ApiEndpoints.recentActivities}'),
            headers: ApiResponseHandler.publicJsonHeaders(),
          )
          .timeout(const Duration(seconds: 20));

      ApiResponseHandler.logResponse('RECENT_ACTIVITIES', response);

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('RECENT_ACTIVITIES: HTTP ${response.statusCode} → []');
        }
        return [];
      }

      final decoded = ApiResponseHandler.decodeJsonResponse(
        response,
        action: 'load recent activities',
      );

      if (decoded is! Map<String, dynamic>) {
        return [];
      }

      final data = decoded['data'];
      if (data is! List) {
        return [];
      }

      return data
          .whereType<Map<String, dynamic>>()
          .map(RecentActivityModel.fromJson)
          .toList();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('RECENT_ACTIVITIES: non-fatal $e\n$st');
      }
      return [];
    }
  }

  /// Dashboard-only: never throws — empty list on 401/403/network so the home screen
  /// never surfaces `Access Denied` from Riverpod.
  Future<List<Product>> getProducts({required String token}) async {
    try {
      final response = await client
          .get(
            Uri.parse('$baseUrl${ApiEndpoints.products}'),
            headers: ApiResponseHandler.jsonHeaders(token: token),
          )
          .timeout(const Duration(seconds: 15));

      ApiResponseHandler.logResponse('PRODUCTS', response);

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
            'PRODUCTS (dashboard): HTTP ${response.statusCode} → []',
          );
        }
        return [];
      }

      final decoded = ApiResponseHandler.decodeJsonResponse(
        response,
        action: 'load products',
      );

      if (decoded is! Map<String, dynamic>) {
        return [];
      }

      final data = decoded['data'];
      if (data is! List) {
        return [];
      }

      return Product.listFromJson(data);
    } catch (error, st) {
      if (kDebugMode) {
        debugPrint('PRODUCTS (dashboard): non-fatal $error\n$st');
      }
      return [];
    }
  }

  /// Never throws — used by dashboard only; falls back via provider when empty.
  Future<List<Product>> getLowStockProducts({required String token}) async {
    try {
      final response = await client
          .get(
            Uri.parse('$baseUrl${ApiEndpoints.lowStock}'),
            headers: ApiResponseHandler.jsonHeaders(token: token),
          )
          .timeout(const Duration(seconds: 15));

      ApiResponseHandler.logResponse('LOW_STOCK', response);

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
            'LOW_STOCK (dashboard): HTTP ${response.statusCode} → []',
          );
        }
        return [];
      }

      final decoded = ApiResponseHandler.decodeJsonResponse(
        response,
        action: 'load low stock products',
      );

      if (decoded is! Map<String, dynamic>) {
        return [];
      }

      final data = decoded['data'];
      if (data is! List) {
        return [];
      }

      return Product.listFromJson(data);
    } catch (error, st) {
      if (kDebugMode) {
        debugPrint('LOW_STOCK (dashboard): non-fatal $error\n$st');
      }
      return [];
    }
  }

  /// Never throws — empty list on 403/network so dashboard charts degrade gracefully.
  Future<List<DashboardOrderSummaryModel>> getOrders({
    required String token,
  }) async {
    try {
      final response = await client
          .get(
            Uri.parse('$baseUrl${ApiEndpoints.orders}'),
            headers: ApiResponseHandler.jsonHeaders(token: token),
          )
          .timeout(const Duration(seconds: 15));

      ApiResponseHandler.logResponse('ORDERS', response);

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
            'ORDERS (dashboard): HTTP ${response.statusCode} → []',
          );
        }
        return [];
      }

      final decoded = ApiResponseHandler.decodeJsonResponse(
        response,
        action: 'load orders',
      );

      if (decoded is! Map<String, dynamic>) {
        return [];
      }

      final data = decoded['data'];
      if (data is! List) {
        return [];
      }

      return DashboardOrderSummaryModel.listFromJson(data);
    } catch (error, st) {
      if (kDebugMode) {
        debugPrint('ORDERS (dashboard): non-fatal $error\n$st');
      }
      return [];
    }
  }

  Future<List<CustomerModel>> getCustomers({required String token}) async {
    try {
      final response = await client
          .get(
            Uri.parse('$baseUrl/dashboard/customers'),
            headers: ApiResponseHandler.jsonHeaders(token: token),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];

      final decoded = ApiResponseHandler.decodeJsonResponse(response, action: 'load customers');
      final data = decoded['data'];
      if (data is! List) return [];

      return data.map((e) => CustomerModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> addCustomer({
    required String token,
    required String name,
    required String phone,
    String? email,
    String? address,
  }) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/dashboard/customers'),
        headers: ApiResponseHandler.jsonHeaders(token: token),
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'email': email,
          'address': address,
        }),
      );

      debugPrint('ADD_CUSTOMER RESPONSE: ${response.statusCode} -> ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      }

      String errMsg = 'Server returned status ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          if (decoded.containsKey('message') && decoded['message'] != null) {
            errMsg = decoded['message'].toString();
          } else if (decoded.containsKey('error') && decoded['error'] != null) {
            errMsg = decoded['error'].toString();
          }
        }
      } catch (_) {}

      throw Exception(errMsg);
    } catch (e) {
      debugPrint('ADD_CUSTOMER ERROR: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception(e.toString());
    }
  }

  Future<bool> recordPaymentIn({
    required String token,
    required double amount,
    required String method,
    String? remarks,
  }) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/orders/payment'),
        headers: ApiResponseHandler.jsonHeaders(token: token),
        body: jsonEncode({
          'amount': amount,
          'method': method,
          'remarks': remarks,
          'type': 'payment_in',
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      }

      String errMsg = 'Server returned status ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['message'] != null) {
          errMsg = decoded['message'].toString();
        }
      } catch (_) {}

      throw Exception(errMsg);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(e.toString());
    }
  }
}
