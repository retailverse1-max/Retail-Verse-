import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_response_handler.dart';
import '../models/support_ticket_model.dart';
import '../../../core/services/session_service.dart';

class SupportRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  SupportRemoteDataSource({required this.client, required this.baseUrl});

  Future<SupportStats> getSupportStats(String token) async {
    try {
      String url = '$baseUrl/support/stats';
      if (SessionService.currentStoreId != null) {
        url += '?businessId=${SessionService.currentStoreId}';
      }
      final response = await client.get(
        Uri.parse(url),
        headers: ApiResponseHandler.jsonHeaders(token: token),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return SupportStats.fromJson(decoded['data']);
      }
      return SupportStats.empty();
    } catch (e) {
      return SupportStats.empty();
    }
  }

  Future<List<SupportTicket>> getRecentTickets(String token) async {
    try {
      String url = '$baseUrl/support/tickets';
      if (SessionService.currentStoreId != null) {
        url += '?businessId=${SessionService.currentStoreId}';
      }
      final response = await client.get(
        Uri.parse(url),
        headers: ApiResponseHandler.jsonHeaders(token: token),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List tickets = decoded['tickets'] ?? [];
        return tickets.map((t) => SupportTicket.fromJson(t)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> createTicket({
    required String token,
    required String subject,
    required String message,
    String? userName,
    String? email,
  }) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/support/ticket'),
        headers: ApiResponseHandler.jsonHeaders(token: token),
        body: jsonEncode({
          'subject': subject,
          'message': message,
          'userName': userName,
          'email': email,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateTicketStatus({
    required String token,
    required String ticketId,
    required String status,
  }) async {
    try {
      final response = await client.put(
        Uri.parse('$baseUrl/support/ticket/$ticketId'),
        headers: ApiResponseHandler.jsonHeaders(token: token),
        body: jsonEncode({'status': status}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTicket({
    required String token,
    required String ticketId,
  }) async {
    try {
      final response = await client.delete(
        Uri.parse('$baseUrl/support/ticket/$ticketId'),
        headers: ApiResponseHandler.jsonHeaders(token: token),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
