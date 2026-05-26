import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_response_handler.dart';
import '../models/notification_model.dart';

class NotificationRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  NotificationRemoteDataSource({required this.client, required this.baseUrl});

  Future<List<AppNotification>> getNotifications({
    required String token,
    bool unreadOnly = false,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl${ApiEndpoints.notifications}?unreadOnly=$unreadOnly',
      );
      final response = await client
          .get(
            uri,
            headers: ApiResponseHandler.jsonHeaders(token: token),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];
      final decoded = ApiResponseHandler.decodeJsonResponse(
        response,
        action: 'load notifications',
      );
      if (decoded is! Map<String, dynamic>) return [];
      final data = decoded['data'];
      if (data is! List) return [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> markAsRead({
    required String token,
    required String id,
  }) async {
    try {
      final response = await client.patch(
        Uri.parse('$baseUrl${ApiEndpoints.notifications}/$id/read'),
        headers: ApiResponseHandler.jsonHeaders(token: token),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to mark notification');
      }
    } catch (_) {
      // non-fatal for UI flow
    }
  }

  Future<bool> requestRestock({
    required String token,
    required String productId,
    String? note,
  }) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl${ApiEndpoints.notificationRestockRequest}'),
        headers: ApiResponseHandler.jsonHeaders(token: token),
        body: jsonEncode({
          'productId': productId,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        }),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
