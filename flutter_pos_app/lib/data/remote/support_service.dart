import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_response_handler.dart';
import '../../core/services/session_service.dart';

class SupportService {
  SupportService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String?> _token() => SessionService.getToken();

  Future<Map<String, dynamic>> createSupportTicket({
    required String subject,
    required String message,
    String? userName,
    String? email,
    String? role,
    String? businessName,
    String? storeId,
    String? issueType,
  }) async {
    final token = await _token();
    final res = await _client
        .post(
          ApiResponseHandler.uri(ApiEndpoints.zendeskTicket),
          headers: ApiResponseHandler.jsonHeaders(token: token),
          body: jsonEncode({
            'subject': subject,
            'description': message,
            'message': message,
            'issueType': issueType ?? 'other',
            'userName': userName,
            'userEmail': email,
            'email': email,
            'role': role,
            'businessName': businessName,
            'storeId': storeId,
            'priority': 'normal',
          }),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'create support ticket',
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'create support ticket',
        decodedBody: decoded,
      );
    }
    return Map<String, dynamic>.from(decoded as Map);
  }
}
