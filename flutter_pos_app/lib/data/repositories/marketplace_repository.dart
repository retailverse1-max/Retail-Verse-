import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/network/api_response_handler.dart';

class MarketplaceRepository {
  Future<Map<String, dynamic>> connectFlipkart({
    required String appId,
    required String appSecret,
    required String token, // Auth token for backend
  }) async {
    final response = await http.post(
      ApiResponseHandler.uri('/marketplace/flipkart/connect'),
      headers: ApiResponseHandler.jsonHeaders(token: token),
      body: jsonEncode({
        'appId': appId,
        'appSecret': appSecret,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponseHandler.decodeJsonResponse(response, action: 'connect Flipkart');
    } else {
      final decoded = _tryDecode(response.body);
      throw ApiResponseHandler.errorFromResponse(response, action: 'connect Flipkart', decodedBody: decoded);
    }
  }

  Future<Map<String, dynamic>> pushProductToFlipkart({
    required String productId,
    required String token,
  }) async {
    final response = await http.post(
      ApiResponseHandler.uri('/marketplace/flipkart/products/push'),
      headers: ApiResponseHandler.jsonHeaders(token: token),
      body: jsonEncode({
        'productId': productId,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponseHandler.decodeJsonResponse(response, action: 'push product to Flipkart');
    } else {
      final decoded = _tryDecode(response.body);
      throw ApiResponseHandler.errorFromResponse(response, action: 'push product to Flipkart', decodedBody: decoded);
    }
  }

  Future<Map<String, dynamic>> pushBulkProductsToFlipkart({
    required List<String> productIds,
    required String token,
  }) async {
    final response = await http.post(
      ApiResponseHandler.uri('/marketplace/flipkart/products/bulk-push'),
      headers: ApiResponseHandler.jsonHeaders(token: token),
      body: jsonEncode({
        'productIds': productIds,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponseHandler.decodeJsonResponse(response, action: 'bulk push products to Flipkart');
    } else {
      final decoded = _tryDecode(response.body);
      throw ApiResponseHandler.errorFromResponse(response, action: 'bulk push products to Flipkart', decodedBody: decoded);
    }
  }

  Future<List<dynamic>> fetchCategoryMappings(String token) async {
    final response = await http.get(
      ApiResponseHandler.uri('/marketplace/flipkart/category-mappings'),
      headers: ApiResponseHandler.jsonHeaders(token: token),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = ApiResponseHandler.decodeJsonResponse(response, action: 'fetch category mappings');
      return data['data'] ?? [];
    } else {
      final decoded = _tryDecode(response.body);
      throw ApiResponseHandler.errorFromResponse(response, action: 'fetch category mappings', decodedBody: decoded);
    }
  }

  Future<Map<String, dynamic>> saveCategoryMapping({
    required String token,
    required String retailCategoryId,
    required String platformCategoryId,
    required String platformCategoryName,
  }) async {
    final response = await http.post(
      ApiResponseHandler.uri('/marketplace/flipkart/category-mappings'),
      headers: ApiResponseHandler.jsonHeaders(token: token),
      body: jsonEncode({
        'retailCategoryId': retailCategoryId,
        'platformCategoryId': platformCategoryId,
        'platformCategoryName': platformCategoryName,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponseHandler.decodeJsonResponse(response, action: 'save category mapping');
    } else {
      final decoded = _tryDecode(response.body);
      throw ApiResponseHandler.errorFromResponse(response, action: 'save category mapping', decodedBody: decoded);
    }
  }

  Future<Map<String, dynamic>> connectShopify({
    required String storeUrl,
    required String accessToken,
    required String token,
  }) async {
    final response = await http.post(
      ApiResponseHandler.uri('/marketplace/shopify/connect'),
      headers: ApiResponseHandler.jsonHeaders(token: token),
      body: jsonEncode({
        'storeUrl': storeUrl,
        'accessToken': accessToken,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponseHandler.decodeJsonResponse(response, action: 'connect Shopify');
    } else {
      final decoded = _tryDecode(response.body);
      throw ApiResponseHandler.errorFromResponse(response, action: 'connect Shopify', decodedBody: decoded);
    }
  }

  Future<Map<String, dynamic>> connectMeesho({
    required String supplierId,
    required String phoneNumber,
    String? apiKey,
    required String token,
  }) async {
    final response = await http.post(
      ApiResponseHandler.uri('/marketplace/meesho/connect'),
      headers: ApiResponseHandler.jsonHeaders(token: token),
      body: jsonEncode({
        'supplierId': supplierId,
        'phoneNumber': phoneNumber,
        if (apiKey != null && apiKey.isNotEmpty) 'apiKey': apiKey,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponseHandler.decodeJsonResponse(response, action: 'connect Meesho');
    } else {
      final decoded = _tryDecode(response.body);
      throw ApiResponseHandler.errorFromResponse(response, action: 'connect Meesho', decodedBody: decoded);
    }
  }

  Future<Map<String, dynamic>> getMeeshoStatus({
    required String token,
  }) async {
    final response = await http.get(
      ApiResponseHandler.uri('/marketplace/meesho/status'),
      headers: ApiResponseHandler.jsonHeaders(token: token),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponseHandler.decodeJsonResponse(response, action: 'get Meesho status');
    } else {
      final decoded = _tryDecode(response.body);
      throw ApiResponseHandler.errorFromResponse(response, action: 'get Meesho status', decodedBody: decoded);
    }
  }

  Future<Map<String, dynamic>> disconnectMeesho({
    required String token,
  }) async {
    final response = await http.post(
      ApiResponseHandler.uri('/marketplace/meesho/disconnect'),
      headers: ApiResponseHandler.jsonHeaders(token: token),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponseHandler.decodeJsonResponse(response, action: 'disconnect Meesho');
    } else {
      final decoded = _tryDecode(response.body);
      throw ApiResponseHandler.errorFromResponse(response, action: 'disconnect Meesho', decodedBody: decoded);
    }
  }

  Future<Map<String, dynamic>> pushProductToMeesho({
    required String productId,
    required String token,
  }) async {
    final response = await http.post(
      ApiResponseHandler.uri('/marketplace/meesho/products/push'),
      headers: ApiResponseHandler.jsonHeaders(token: token),
      body: jsonEncode({
        'productId': productId,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponseHandler.decodeJsonResponse(response, action: 'push product to Meesho');
    } else {
      final decoded = _tryDecode(response.body);
      throw ApiResponseHandler.errorFromResponse(response, action: 'push product to Meesho', decodedBody: decoded);
    }
  }

  /// 1-Click Universal Marketplace Statuses
  Future<Map<String, dynamic>> getAllStatuses({required String token}) async {
    final response = await http.get(
      ApiResponseHandler.uri('/marketplace/statuses'),
      headers: ApiResponseHandler.jsonHeaders(token: token),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = ApiResponseHandler.decodeJsonResponse(response, action: 'get marketplace statuses');
      return data['data'] ?? {};
    } else {
      final decoded = _tryDecode(response.body);
      throw ApiResponseHandler.errorFromResponse(response, action: 'get marketplace statuses', decodedBody: decoded);
    }
  }

  /// 1-Click Universal Connect (Direct Portal Navigation & Activate)
  Future<Map<String, dynamic>> quickConnect({
    required String platform,
    String? storeName,
    required String token,
  }) async {
    final response = await http.post(
      ApiResponseHandler.uri('/marketplace/quick-connect'),
      headers: ApiResponseHandler.jsonHeaders(token: token),
      body: jsonEncode({
        'platform': platform,
        if (storeName != null) 'storeName': storeName,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponseHandler.decodeJsonResponse(response, action: 'quick-connect $platform');
    } else {
      final decoded = _tryDecode(response.body);
      throw ApiResponseHandler.errorFromResponse(response, action: 'quick-connect $platform', decodedBody: decoded);
    }
  }

  /// Universal Disconnect
  Future<Map<String, dynamic>> disconnectPlatform({
    required String platform,
    required String token,
  }) async {
    final response = await http.post(
      ApiResponseHandler.uri('/marketplace/disconnect'),
      headers: ApiResponseHandler.jsonHeaders(token: token),
      body: jsonEncode({
        'platform': platform,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponseHandler.decodeJsonResponse(response, action: 'disconnect $platform');
    } else {
      final decoded = _tryDecode(response.body);
      throw ApiResponseHandler.errorFromResponse(response, action: 'disconnect $platform', decodedBody: decoded);
    }
  }

  /// Universal Sync Product to Platforms
  Future<Map<String, dynamic>> syncProductToPlatforms({
    required String productId,
    required List<String> platforms,
    required String token,
  }) async {
    final response = await http.post(
      ApiResponseHandler.uri('/marketplace/sync-product'),
      headers: ApiResponseHandler.jsonHeaders(token: token),
      body: jsonEncode({
        'productId': productId,
        'platforms': platforms,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponseHandler.decodeJsonResponse(response, action: 'sync product to marketplaces');
    } else {
      final decoded = _tryDecode(response.body);
      throw ApiResponseHandler.errorFromResponse(response, action: 'sync product to marketplaces', decodedBody: decoded);
    }
  }

  /// Sync all store products across connected platforms (or a single platform)
  Future<Map<String, dynamic>> syncAllProducts({
    String? platform,
    required String token,
  }) async {
    final response = await http.post(
      ApiResponseHandler.uri('/marketplace/sync-all'),
      headers: ApiResponseHandler.jsonHeaders(token: token),
      body: jsonEncode({
        if (platform != null) 'platform': platform,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponseHandler.decodeJsonResponse(response, action: 'sync all products to marketplaces');
    } else {
      final decoded = _tryDecode(response.body);
      throw ApiResponseHandler.errorFromResponse(response, action: 'sync all products to marketplaces', decodedBody: decoded);
    }
  }

  dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}
