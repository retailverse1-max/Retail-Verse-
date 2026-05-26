import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_response_handler.dart';
import '../../core/services/session_service.dart';

/// Admin-only `/api/users` API (also served at `/api/admin/users`).
class AdminUsersService {
  AdminUsersService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String?> _token() => SessionService.getToken();

  Future<List<Map<String, dynamic>>> listUsers() async {
    final token = await _token();
    final res = await _client
        .get(
          Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.superAdminUsers}'),
          headers: ApiResponseHandler.jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'list staff users',
    );

    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'list staff users',
        decodedBody: decoded,
      );
    }

    final data = decoded['data'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> createStaff({
    required String name,
    required String email,
    String? phone,
    required String password,
    required String role,
  }) async {
    final token = await _token();
    final res = await _client
        .post(
          Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.superAdminUsers}'),
          headers: ApiResponseHandler.jsonHeaders(token: token),
          body: jsonEncode({
            'name': name.trim(),
            'email': email.trim(),
            if (phone != null) 'phone': phone.trim(),
            'password': password,
            'role': role.trim(),
          }),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'create staff user',
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'create staff user',
        decodedBody: decoded,
      );
    }
  }

  Future<void> updateUserRole({
    required String userId,
    required String role,
  }) async {
    final token = await _token();
    final uri = Uri.parse(
      '${ApiEndpoints.baseUrl}${ApiEndpoints.superAdminUsers}/$userId/role',
    );
    final res = await _client
        .patch(
          uri,
          headers: ApiResponseHandler.jsonHeaders(token: token),
          body: jsonEncode({'role': role.trim()}),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'update user role',
    );

    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'update user role',
        decodedBody: decoded,
      );
    }
  }

  Future<void> setUserActive({
    required String userId,
    required bool isActive,
  }) async {
    final token = await _token();
    final uri = Uri.parse(
      '${ApiEndpoints.baseUrl}${ApiEndpoints.superAdminUsers}/$userId/status',
    );
    final res = await _client
        .patch(
          uri,
          headers: ApiResponseHandler.jsonHeaders(token: token),
          body: jsonEncode({'isActive': isActive}),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'update user status',
    );

    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'update user status',
        decodedBody: decoded,
      );
    }
  }

  Future<void> deleteUser({required String userId}) async {
    final token = await _token();
    final uri = Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.superAdminUsers}/$userId');
    final res = await _client
        .delete(
          uri,
          headers: ApiResponseHandler.jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'delete user',
    );

    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'delete user',
        decodedBody: decoded,
      );
    }
  }
}
