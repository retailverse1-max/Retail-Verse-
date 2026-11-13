import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/network/api_response_handler.dart';
import '../models/support_ticket_model.dart';
import '../../../core/services/session_service.dart';

class SupportRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  SupportRemoteDataSource({required this.client, required this.baseUrl});

  Future<SupportStats> getSupportStats(String token) async {
    try {
      String query = '';
      if (SessionService.currentStoreId != null) {
        query = '?businessId=${SessionService.currentStoreId}';
      }
      // Production backend uses /support/tickets/stats; fallback to /support/stats
      var response = await client.get(
        Uri.parse('$baseUrl/support/tickets/stats$query'),
        headers: ApiResponseHandler.jsonHeaders(token: token),
      );

      if (response.statusCode == 404) {
        response = await client.get(
          Uri.parse('$baseUrl/support/stats$query'),
          headers: ApiResponseHandler.jsonHeaders(token: token),
        );
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['data'] != null) {
          return SupportStats.fromJson(decoded['data']);
        }
      }
      return SupportStats.empty();
    } catch (e) {
      return SupportStats.empty();
    }
  }

  Future<List<SupportTicket>> getRecentTickets(String token) async {
    try {
      String query = '';
      if (SessionService.currentStoreId != null) {
        query = '?businessId=${SessionService.currentStoreId}';
      }

      // Production endpoint for logged-in user tickets is /support/tickets/my
      var response = await client.get(
        Uri.parse('$baseUrl/support/tickets/my$query'),
        headers: ApiResponseHandler.jsonHeaders(token: token),
      );

      if (response.statusCode == 404) {
        response = await client.get(
          Uri.parse('$baseUrl/support/tickets$query'),
          headers: ApiResponseHandler.jsonHeaders(token: token),
        );
      }

      if (response.statusCode == 404) {
        response = await client.get(
          Uri.parse('$baseUrl/support/ticket$query'),
          headers: ApiResponseHandler.jsonHeaders(token: token),
        );
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List tickets = decoded['data'] ?? decoded['tickets'] ?? [];
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
    String? issueType,
  }) async {
    try {
      final body = jsonEncode({
        'subject': subject,
        'description': message,
        'message': message,
        'issueType': issueType ?? 'other',
        if (userName != null && userName.isNotEmpty) 'userName': userName,
        if (email != null && email.isNotEmpty) ...{
          'email': email,
          'userEmail': email,
          'customerEmail': email,
        },
        if (SessionService.currentStoreId != null)
          'storeId': SessionService.currentStoreId,
        'priority': 'normal',
      });

      // Production backend mounts POST /support/tickets; fallback to /support/ticket
      var response = await client.post(
        Uri.parse('$baseUrl/support/tickets'),
        headers: ApiResponseHandler.jsonHeaders(token: token),
        body: body,
      );

      if (response.statusCode == 404) {
        response = await client.post(
          Uri.parse('$baseUrl/support/ticket'),
          headers: ApiResponseHandler.jsonHeaders(token: token),
          body: body,
        );
      }

      return response.statusCode == 200 || response.statusCode == 201;
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
      final body = jsonEncode({'status': status});
      var response = await client.put(
        Uri.parse('$baseUrl/support/tickets/$ticketId'),
        headers: ApiResponseHandler.jsonHeaders(token: token),
        body: body,
      );

      if (response.statusCode == 404) {
        response = await client.put(
          Uri.parse('$baseUrl/support/ticket/$ticketId'),
          headers: ApiResponseHandler.jsonHeaders(token: token),
          body: body,
        );
      }

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
      var response = await client.delete(
        Uri.parse('$baseUrl/support/tickets/$ticketId'),
        headers: ApiResponseHandler.jsonHeaders(token: token),
      );

      if (response.statusCode == 404) {
        response = await client.delete(
          Uri.parse('$baseUrl/support/ticket/$ticketId'),
          headers: ApiResponseHandler.jsonHeaders(token: token),
        );
      }

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
