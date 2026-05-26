import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_response_handler.dart';
import '../../core/services/session_service.dart';

class AccountService {
  AccountService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String?> _token() => SessionService.getToken();

  Future<Map<String, dynamic>> updateMe({
    required String name,
    required String phone,
  }) async {
    final token = await _token();
    final res = await _client
        .patch(
          Uri.parse('${ApiEndpoints.baseUrl}/auth/me'),
          headers: ApiResponseHandler.jsonHeaders(token: token),
          body: jsonEncode({
            'name': name.trim(),
            'phone': phone.trim(),
          }),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'update account',
    );

    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'update account',
        decodedBody: decoded,
      );
    }

    final data = decoded['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<void> deleteMe() async {
    final token = await _token();
    final res = await _client
        .delete(
          Uri.parse('${ApiEndpoints.baseUrl}/auth/me'),
          headers: ApiResponseHandler.jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'delete account',
    );

    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'delete account',
        decodedBody: decoded,
      );
    }
  }
}

