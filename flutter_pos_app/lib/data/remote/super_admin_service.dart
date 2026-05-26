import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_response_handler.dart';
import '../../core/services/session_service.dart';

class SuperAdminService {
  SuperAdminService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String?> _token() => SessionService.getToken();

  Future<Map<String, dynamic>> getAnalyticsSummary() async {
    final token = await _token();
    final res = await _client
        .get(
          ApiResponseHandler.uri(ApiEndpoints.superAdminAnalyticsSummary),
          headers: ApiResponseHandler.jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'load super admin analytics',
    );
    print('SUPER_ADMIN_ANALYTICS: $decoded');
    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'load super admin analytics',
        decodedBody: decoded,
      );
    }
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<List<Map<String, dynamic>>> listBusinesses() async {
    final token = await _token();
    final res = await _client
        .get(
          ApiResponseHandler.uri(ApiEndpoints.superAdminBusinesses),
          headers: ApiResponseHandler.jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'list businesses',
    );
    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'list businesses',
        decodedBody: decoded,
      );
    }
    final data = (decoded as Map)['data'];
    if (data is! List) return [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> createBusiness({
    required String businessName,
    String ownerName = '',
    String ownerEmail = '',
    String phone = '',
    String address = '',
    String businessType = '',
    String notes = '',
    String status = 'active',
    String subscriptionPlan = 'free',
    String subscriptionStatus = 'active',
  }) async {
    final token = await _token();
    final url = ApiResponseHandler.uri(ApiEndpoints.superAdminBusinesses);
    final body = jsonEncode({
      'businessName': businessName.trim(),
      'ownerName': ownerName.trim(),
      'ownerEmail': ownerEmail.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'businessType': businessType.trim(),
      'notes': notes.trim(),
      'status': status.trim().toLowerCase(),
      'subscriptionPlan': subscriptionPlan.trim().toLowerCase(),
      'subscriptionStatus': subscriptionStatus.trim().toLowerCase(),
    });

    print('SUPER ADMIN ACTION: POST $url');
    print('BODY: $body');

    final res = await _client
        .post(
          url,
          headers: ApiResponseHandler.jsonHeaders(token: token),
          body: body,
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'create business',
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'create business',
        decodedBody: decoded,
      );
    }
  }

  Future<void> updateBusiness(String id, Map<String, dynamic> data) async {
    final token = await _token();
    final url = ApiResponseHandler.uri('${ApiEndpoints.superAdminBusinesses}/$id');
    print('SUPER ADMIN ACTION: PUT $url');
    final res = await _client
        .put(
          url,
          headers: ApiResponseHandler.jsonHeaders(token: token),
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'update business',
    );
    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'update business',
        decodedBody: decoded,
      );
    }
  }

  Future<void> deleteBusiness(String id) async {
    final token = await _token();
    final url = ApiResponseHandler.uri('${ApiEndpoints.superAdminBusinesses}/$id');
    print('SUPER ADMIN ACTION: DELETE $url');
    final res = await _client
        .delete(
          url,
          headers: ApiResponseHandler.jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'delete business',
    );
    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'delete business',
        decodedBody: decoded,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getTopPerformanceStores() async {
    final token = await _token();
    final res = await _client
        .get(
          ApiResponseHandler.uri(ApiEndpoints.superAdminTopPerformance),
          headers: ApiResponseHandler.jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'load top performance stores',
    );
    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'load top performance stores',
        decodedBody: decoded,
      );
    }
    final data = (decoded as Map)['data'];
    if (data is! List) return [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> listUsers({String? businessId}) async {
    final token = await _token();
    final uri = Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.superAdminUsers}')
        .replace(queryParameters: {
      if (businessId != null && businessId.trim().isNotEmpty)
        'businessId': businessId.trim(),
    });

    print('TEAM ACTION REQUEST: GET $uri');

    final res = await _client
        .get(uri, headers: ApiResponseHandler.jsonHeaders(token: token))
        .timeout(const Duration(seconds: 20));

    print('TEAM ACTION RESPONSE: ${res.statusCode} ${res.body}');

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'list platform users',
    );
    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'list platform users',
        decodedBody: decoded,
      );
    }
    final data = (decoded as Map)['data'];
    if (data is! List) return [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) async {
    final token = await _token();
    final uri = Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.superAdminUsers}');
    final body = jsonEncode({
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'role': role.trim(),
      if (phone != null) 'phone': phone.trim(),
    });

    print('TEAM ACTION REQUEST: POST $uri BODY $body');

    final res = await _client
        .post(
          uri,
          headers: ApiResponseHandler.jsonHeaders(token: token),
          body: body,
        )
        .timeout(const Duration(seconds: 20));

    print('TEAM ACTION RESPONSE: ${res.statusCode} ${res.body}');

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'create user',
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'create user',
        decodedBody: decoded,
      );
    }
  }

  Future<void> updateUserStatus({
    required String userId,
    required bool isActive,
  }) async {
    final token = await _token();
    final uri = Uri.parse(
      '${ApiEndpoints.baseUrl}${ApiEndpoints.superAdminUsers}/$userId/status',
    );
    final body = jsonEncode({'isActive': isActive});

    print('TEAM ACTION REQUEST: PATCH $uri BODY $body');

    final res = await _client
        .patch(
          uri,
          headers: ApiResponseHandler.jsonHeaders(token: token),
          body: body,
        )
        .timeout(const Duration(seconds: 20));

    print('TEAM ACTION RESPONSE: ${res.statusCode} ${res.body}');

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'update user active',
    );
    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'update user active',
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
    final body = jsonEncode({'role': role.trim()});

    print('TEAM ACTION REQUEST: PATCH $uri BODY $body');

    final res = await _client
        .patch(
          uri,
          headers: ApiResponseHandler.jsonHeaders(token: token),
          body: body,
        )
        .timeout(const Duration(seconds: 20));

    print('TEAM ACTION RESPONSE: ${res.statusCode} ${res.body}');

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

  Future<void> deleteUser({required String userId}) async {
    final token = await _token();
    final uri = Uri.parse(
      '${ApiEndpoints.baseUrl}${ApiEndpoints.superAdminUsers}/$userId',
    );

    print('TEAM ACTION REQUEST: DELETE $uri');

    final res = await _client
        .delete(
          uri,
          headers: ApiResponseHandler.jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 20));

    print('TEAM ACTION RESPONSE: ${res.statusCode} ${res.body}');

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

  Future<List<Map<String, dynamic>>> listSubscriptionPlans() async {
    final token = await _token();
    final res = await _client
        .get(
          ApiResponseHandler.uri(ApiEndpoints.superAdminSubscriptionPlans),
          headers: ApiResponseHandler.jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'list subscription plans',
    );
    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'list subscription plans',
        decodedBody: decoded,
      );
    }
    final data = (decoded as Map)['data'];
    if (data is! List) return [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> listAuditLogs({int limit = 100}) async {
    final token = await _token();
    final uri = Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.superAdminAuditLogs}')
        .replace(queryParameters: {'limit': '$limit'});

    final res = await _client
        .get(uri, headers: ApiResponseHandler.jsonHeaders(token: token))
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'list audit logs',
    );
    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'list audit logs',
        decodedBody: decoded,
      );
    }
    final data = (decoded as Map)['data'];
    if (data is! List) return [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> listCustomDomains() async {
    try {
      final token = await _token();
      final res = await _client
          .get(
            ApiResponseHandler.uri(ApiEndpoints.superAdminCustomDomains),
            headers: ApiResponseHandler.jsonHeaders(token: token),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = ApiResponseHandler.decodeJsonResponse(
        res,
        action: 'list custom domains',
      );
      if (res.statusCode != 200) {
        // Soft fail for custom domains to avoid breaking business screen
        return [];
      }
      final data = (decoded as Map)['data'];
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      // Ignore errors for this non-critical list
      return [];
    }
  }

  Future<Map<String, dynamic>> addCustomDomain({
    required String businessId,
    required String domain,
  }) async {
    final token = await _token();
    final res = await _client
        .post(
          ApiResponseHandler.uri(ApiEndpoints.superAdminCustomDomains),
          headers: ApiResponseHandler.jsonHeaders(token: token),
          body: jsonEncode({
            'businessId': businessId.trim(),
            'domain': domain.trim(),
          }),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'add custom domain',
    );
    if (res.statusCode != 201) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'add custom domain',
        decodedBody: decoded,
      );
    }
    return Map<String, dynamic>.from((decoded as Map)['data']);
  }

  Future<void> verifyCustomDomain(String domainId) async {
    final token = await _token();
    final res = await _client
        .post(
          Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.superAdminCustomDomains}/$domainId/verify'),
          headers: ApiResponseHandler.jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'verify custom domain',
    );
    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'verify custom domain',
        decodedBody: decoded,
      );
    }
  }

  Future<void> activateCustomDomain(String domainId) async {
    final token = await _token();
    final res = await _client
        .patch(
          Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.superAdminCustomDomains}/$domainId/active'),
          headers: ApiResponseHandler.jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'activate custom domain',
    );
    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'activate custom domain',
        decodedBody: decoded,
      );
    }
  }

  Future<void> deleteCustomDomain(String domainId) async {
    final token = await _token();
    final res = await _client
        .delete(
          Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.superAdminCustomDomains}/$domainId'),
          headers: ApiResponseHandler.jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'delete custom domain',
    );
    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'delete custom domain',
        decodedBody: decoded,
      );
    }
  }

  Future<String> fixBusinessesData() async {
    final token = await _token();
    final res = await _client
        .get(
          ApiResponseHandler.uri('/super-admin/fix-data'),
          headers: ApiResponseHandler.jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'fix business data',
    );
    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'fix business data',
        decodedBody: decoded,
      );
    }
    return decoded['message']?.toString() ?? 'Fixed successfully';
  }

  Future<Map<String, dynamic>> getBusinessDetails(String id) async {
    final token = await _token();
    final res = await _client
        .get(
          ApiResponseHandler.uri('${ApiEndpoints.superAdminBusinesses}/$id'),
          headers: ApiResponseHandler.jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'get business details',
    );
    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'get business details',
        decodedBody: decoded,
      );
    }
    return decoded['data'] as Map<String, dynamic>;
  }

  Future<void> broadcastEmergency({required String message, String priority = 'high'}) async {
    final token = await _token();
    final res = await _client
        .post(
          ApiResponseHandler.uri(ApiEndpoints.superAdminBroadcast),
          headers: ApiResponseHandler.jsonHeaders(token: token),
          body: jsonEncode({'message': message, 'priority': priority}),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'broadcast emergency',
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'broadcast emergency',
        decodedBody: decoded,
      );
    }
  }
}
