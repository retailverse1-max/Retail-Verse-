import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/category_entity.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/session_service.dart';

class CategoryRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  CategoryRemoteDataSource({required this.client, required this.baseUrl});

  Future<Map<String, String>> _getHeaders() async {
    final token = await SessionService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  String _appendBusinessId(String url) {
    if (SessionService.currentStoreId != null) {
      final sep = url.contains('?') ? '&' : '?';
      return '$url${sep}businessId=${SessionService.currentStoreId}';
    }
    return url;
  }

  Future<List<CategoryEntity>> getCategories() async {
    final response = await client.get(
      Uri.parse(_appendBusinessId('$baseUrl/categories')),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = json.decode(response.body);
      final List<dynamic> data = body['data'] ?? [];
      return data.map((json) => CategoryEntity.fromJson(json)).toList();
    } else {
      throw ApiException(
        'Failed to get categories',
        statusCode: response.statusCode,
      );
    }
  }

  Future<CategoryEntity> createCategory(CategoryEntity category) async {
    final response = await client.post(
      Uri.parse('$baseUrl/categories'),
      headers: await _getHeaders(),
      body: json.encode(category.toJson()),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final Map<String, dynamic> body = json.decode(response.body);
      return CategoryEntity.fromJson(body['data'] ?? body);
    } else {
      throw ApiException(
        'Failed to create category',
        statusCode: response.statusCode,
      );
    }
  }

  Future<CategoryEntity> updateCategory(CategoryEntity category) async {
    final response = await client.put(
      Uri.parse('$baseUrl/categories/${category.id}'),
      headers: await _getHeaders(),
      body: json.encode(category.toJson()),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = json.decode(response.body);
      return CategoryEntity.fromJson(body['data'] ?? body);
    } else {
      throw ApiException(
        'Failed to update category',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> deleteCategory(String id) async {
    final response = await client.delete(
      Uri.parse('$baseUrl/categories/$id'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ApiException(
        'Failed to delete category',
        statusCode: response.statusCode,
      );
    }
  }
}
