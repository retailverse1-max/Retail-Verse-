import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_endpoints.dart';
import '../../core/utils/product_media_url.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/api_response_handler.dart';
import '../../core/services/session_service.dart';
import '../models/product_model.dart';
import '../local/product_local_service.dart';
import 'product_data_source.dart';

/// Remote product data source for API communication
class ProductRemoteDataSource implements IProductDataSource {
  final http.Client client;
  final String baseUrl;

  ProductRemoteDataSource({required this.client, required this.baseUrl});

  @override
  Future<List<Product>> getAllProducts() async {
    try {
      final token = await _getToken();
      String url = '$baseUrl${ApiEndpoints.products}?limit=1000';
      if (SessionService.currentStoreId != null) {
        url += '&businessId=${SessionService.currentStoreId}';
      }
      final response = await client
          .get(
            Uri.parse(url),
            headers: ApiResponseHandler.jsonHeaders(token: token),
          )
          .timeout(const Duration(seconds: 15));

      ApiResponseHandler.logResponse('POS_PRODUCTS', response);

      final decoded = ApiResponseHandler.decodeJsonResponse(
        response,
        action: 'load POS products',
      );

      if (response.statusCode != 200) {
        throw ApiResponseHandler.errorFromResponse(
          response,
          action: 'load POS products',
          decodedBody: decoded,
        );
      }

      if (decoded is! Map<String, dynamic>) {
        throw const ApiException(
          'The server returned an unexpected products response.',
        );
      }

      final data = decoded['data'];
      if (data is! List) {
        throw const ApiException(
          'The products response did not contain a valid list.',
        );
      }

      final list = Product.listFromJson(data);
      if (list.isNotEmpty) {
        try {
          await ProductLocalService().insertProducts(list);
        } catch (_) {}
      }
      if (kDebugMode && list.isNotEmpty) {
        final p0 = list.first;
        final resolved = resolveProductImageUrl(p0.imageUrl);
        debugPrint(
          '[POS products] n=${list.length} first="${p0.name}" '
          'raw=${p0.imageUrl ?? "(null)"} resolved=$resolved',
        );
      }
      return list;
    } on SocketException catch (error) {
      throw ApiResponseHandler.errorFromException(
        error,
        action: 'load POS products',
      );
    } on HttpException catch (error) {
      throw ApiResponseHandler.errorFromException(
        error,
        action: 'load POS products',
      );
    } on FormatException catch (error) {
      throw ApiResponseHandler.errorFromException(
        error,
        action: 'load POS products',
      );
    } catch (error) {
      throw ApiResponseHandler.errorFromException(
        error,
        action: 'load POS products',
      );
    }
  }

  @override
  Future<Product?> getProductById(String id) async {
    try {
      final token = await _getToken();
      final response = await client
          .get(
            Uri.parse(
              '$baseUrl${ApiEndpoints.productById.replaceFirst(':id', id)}',
            ),
            headers: ApiResponseHandler.jsonHeaders(token: token),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = ApiResponseHandler.decodeJsonResponse(
        response,
        action: 'get product by ID',
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = decoded['data'] ?? decoded;
      if (data is! Map<String, dynamic>) {
        return null;
      }

      return Product.fromJson(data);
    } catch (error) {
      return null;
    }
  }

  @override
  Future<Product?> getProductByBarcode(String barcode) async {
    try {
      final token = await _getToken();
      final url = '$baseUrl/products/barcode/${Uri.encodeComponent(barcode.trim())}';
      final response = await client
          .get(
            Uri.parse(url),
            headers: ApiResponseHandler.jsonHeaders(token: token),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = ApiResponseHandler.decodeJsonResponse(
        response,
        action: 'get product by barcode',
      );

      final data = decoded is Map<String, dynamic> ? (decoded['data'] ?? decoded) : null;
      if (data is! Map<String, dynamic>) {
        return null;
      }

      return Product.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> quickInward({
    String? barcode,
    String? productId,
    required int quantity,
    double? costPrice,
    String? batchNo,
    String? expiryDate,
  }) async {
    final token = await _getToken();
    final body = {
      if (barcode != null) 'barcode': barcode,
      if (productId != null) 'productId': productId,
      'quantity': quantity,
      if (costPrice != null) 'costPrice': costPrice,
      if (batchNo != null) 'batchNo': batchNo,
      if (expiryDate != null) 'expiryDate': expiryDate,
    };
    final response = await client.post(
      Uri.parse('$baseUrl/inventory/inward'),
      headers: ApiResponseHandler.jsonHeaders(token: token),
      body: jsonEncode(body),
    );
    final decoded = ApiResponseHandler.decodeJsonResponse(
      response,
      action: 'quick inward inventory',
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded is Map<String, dynamic> ? decoded : {'success': true};
    } else {
      throw ApiResponseHandler.errorFromResponse(
        response,
        action: 'quick inward inventory',
        decodedBody: decoded,
      );
    }
  }

  @override
  Future<List<Product>> searchProducts(String query) async {
    try {
      final token = await _getToken();
      final response = await client
          .get(
            Uri.parse('$baseUrl${ApiEndpoints.searchProducts}?query=$query'),
            headers: ApiResponseHandler.jsonHeaders(token: token),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = ApiResponseHandler.decodeJsonResponse(
        response,
        action: 'search products',
      );

      if (response.statusCode != 200) {
        throw ApiResponseHandler.errorFromResponse(
          response,
          action: 'search products',
          decodedBody: decoded,
        );
      }

      final data = decoded['data'];
      if (data is! List) {
        return [];
      }

      return data
          .whereType<Map<String, dynamic>>()
          .map(Product.fromJson)
          .toList();
    } catch (error) {
      return [];
    }
  }

  @override
  Future<List<Product>> getProductsByCategory(String category) async {
    final products = await getAllProducts();
    final cleanCat = category.trim().toLowerCase();
    if (cleanCat.isEmpty || cleanCat == 'all') {
      return products;
    }
    return products.where((p) {
      final pCat = p.category.trim().toLowerCase();
      if (pCat == cleanCat) return true;
      if (pCat.isNotEmpty && cleanCat.isNotEmpty) {
        if (pCat.startsWith(cleanCat) || cleanCat.startsWith(pCat)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  @override
  Future<List<Product>> getLowStockProducts(int threshold) async {
    try {
      final token = await _getToken();
      final response = await client
          .get(
            Uri.parse('$baseUrl${ApiEndpoints.lowStock}'),
            headers: ApiResponseHandler.jsonHeaders(token: token),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = ApiResponseHandler.decodeJsonResponse(
        response,
        action: 'load low stock products',
      );

      if (response.statusCode != 200) {
        throw ApiResponseHandler.errorFromResponse(
          response,
          action: 'load low stock products',
          decodedBody: decoded,
        );
      }

      final data = decoded['data'];
      if (data is! List) {
        return [];
      }

      return data
          .whereType<Map<String, dynamic>>()
          .map(Product.fromJson)
          .toList();
    } catch (error) {
      return [];
    }
  }

  @override
  Future<void> updateProductStock(String id, int quantity) async {
    try {
      final token = await _getToken();
      final response = await client
          .post(
            Uri.parse('$baseUrl${ApiEndpoints.adjustStock}'),
            headers: ApiResponseHandler.jsonHeaders(token: token),
            body: jsonEncode({
              'productId': id,
              'operation': quantity >= 0 ? 'add' : 'reduce',
              'quantity': quantity.abs(),
              'reason': 'pos_adjust',
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw ApiResponseHandler.errorFromResponse(
          response,
          action: 'update product stock',
        );
      }
    } catch (error) {
      rethrow;
    }
  }

  @override
  Future<Product> createProduct({
    required String name,
    required String sku,
    required double price,
    double cost = 0,
    int stock = 0,
    String barcode = '',
    String category = '',
    String? imageBase64,
    String? description,
    String? dimensions,
    List<String>? marketplaces,
    double? taxRate,
  }) async {
    final token = await _getToken();
    final payload = <String, dynamic>{
      'name': name,
      'sku': sku,
      'price': price,
      'cost': cost,
      'stock': stock,
      'barcode': barcode,
      'category': category,
      if (taxRate != null) 'taxRate': taxRate,
    };
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      payload['imageBase64'] = imageBase64;
    }
    if (description != null && description.trim().isNotEmpty) {
      payload['description'] = description.trim();
    }
    if (dimensions != null && dimensions.trim().isNotEmpty) {
      payload['dimensions'] = dimensions.trim();
    }
    if (marketplaces != null && marketplaces.isNotEmpty) {
      payload['marketplaces'] = marketplaces;
    }
    final response = await client
        .post(
          Uri.parse('$baseUrl${ApiEndpoints.products}'),
          headers: ApiResponseHandler.jsonHeaders(token: token),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      response,
      action: 'create product',
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        response,
        action: 'create product',
        decodedBody: decoded,
      );
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Invalid create product response.');
    }
    return Product.fromJson(data);
  }

  @override
  Future<Product> updateProduct({
    required String id,
    String? name,
    String? sku,
    double? price,
    double? cost,
    int? stock,
    String? barcode,
    String? category,
    String? imageBase64,
    String? description,
    bool? isActive,
    double? taxRate,
    String? dimensions,
    List<String>? marketplaces,
  }) async {
    final token = await _getToken();
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (sku != null) body['sku'] = sku;
    if (price != null) body['price'] = price;
    if (cost != null) body['cost'] = cost;
    if (stock != null) body['stock'] = stock;
    if (barcode != null) body['barcode'] = barcode;
    if (category != null) body['category'] = category;
    if (description != null) body['description'] = description;
    if (isActive != null) body['isActive'] = isActive;
    if (taxRate != null) body['taxRate'] = taxRate;
    if (dimensions != null) body['dimensions'] = dimensions;
    if (marketplaces != null) body['marketplaces'] = marketplaces;
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      body['imageBase64'] = imageBase64;
    }

    final response = await client
        .put(
          Uri.parse('$baseUrl${ApiEndpoints.productById.replaceFirst(':id', id)}'),
          headers: ApiResponseHandler.jsonHeaders(token: token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      response,
      action: 'update product',
    );

    if (response.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        response,
        action: 'update product',
        decodedBody: decoded,
      );
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Invalid update product response.');
    }
    return Product.fromJson(data);
  }

  @override
  Future<void> deleteProduct(String id) async {
    final token = await _getToken();
    final url =
        '$baseUrl${ApiEndpoints.productById.replaceFirst(':id', id)}';
    if (kDebugMode) {
      debugPrint('[deleteProduct] DELETE $url');
    }
    final response = await client
        .delete(
          Uri.parse(url),
          headers: ApiResponseHandler.jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 15));

    if (kDebugMode) {
      final b = response.body;
      debugPrint(
        '[deleteProduct] status=${response.statusCode} len=${b.length} '
        '${b.length > 160 ? "${b.substring(0, 160)}…" : b}',
      );
    }

    if (response.statusCode == 204) {
      return;
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = response.body.trim();
      if (body.isEmpty) return;
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['ok'] == false) {
          throw ApiException(
            decoded['message']?.toString() ?? 'Delete failed',
            statusCode: response.statusCode,
          );
        }
      } catch (e) {
        if (e is ApiException) rethrow;
        // Success with non-JSON body — still OK.
      }
      return;
    }

    final decoded = ApiResponseHandler.decodeJsonResponse(
      response,
      action: 'delete product',
    );
    throw ApiResponseHandler.errorFromResponse(
      response,
      action: 'delete product',
      decodedBody: decoded,
    );
  }

  Future<String?> _getToken() => SessionService.getToken();
}
