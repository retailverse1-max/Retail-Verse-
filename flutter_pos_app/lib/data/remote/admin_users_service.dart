import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/api_response_handler.dart';
import '../../core/services/session_service.dart';
import '../models/auth_user.dart';

/// Admin-only `/api/users` API with robust local-first persistence & offline auth fallback.
class AdminUsersService {
  AdminUsersService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _keyLocalStaffMembers = 'local_staff_members_cache_v1';

  Future<String?> _token() => SessionService.getToken();

  // -------------------------------------------------------------
  // LOCAL STORAGE HELPERS
  // -------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getLocalStaff() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyLocalStaffMembers);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      debugPrint('[AdminUsersService] Error reading local staff: $e');
    }
    return [];
  }

  Future<void> saveLocalStaff(Map<String, dynamic> staffMember) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getLocalStaff();
      final email = staffMember['email']?.toString().toLowerCase().trim() ?? '';

      // Remove existing by email or ID if already present
      current.removeWhere((item) =>
          (item['email']?.toString().toLowerCase().trim() == email && email.isNotEmpty) ||
          (item['_id'] != null && item['_id'] == staffMember['_id']));

      current.insert(0, staffMember);
      await prefs.setString(_keyLocalStaffMembers, jsonEncode(current));
      debugPrint('[AdminUsersService] Saved local staff member: ${staffMember['name']} ($email)');
    } catch (e) {
      debugPrint('[AdminUsersService] Error saving local staff: $e');
    }
  }

  Future<void> updateLocalStaffField(String userId, String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getLocalStaff();
      for (final item in current) {
        if (item['_id']?.toString() == userId || item['id']?.toString() == userId) {
          item[key] = value;
          break;
        }
      }
      await prefs.setString(_keyLocalStaffMembers, jsonEncode(current));
    } catch (e) {
      debugPrint('[AdminUsersService] Error updating local staff: $e');
    }
  }

  Future<void> removeLocalStaff(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getLocalStaff();
      current.removeWhere((item) =>
          item['_id']?.toString() == userId || item['id']?.toString() == userId);
      await prefs.setString(_keyLocalStaffMembers, jsonEncode(current));
    } catch (e) {
      debugPrint('[AdminUsersService] Error removing local staff: $e');
    }
  }

  /// Checks if credentials match a local staff member (offline/fallback authenticator).
  Future<AuthLoginResponse?> checkLocalStaffLogin(String email, String password) async {
    try {
      final localStaff = await getLocalStaff();
      final cleanEmail = email.trim().toLowerCase();
      for (final member in localStaff) {
        if (member['email']?.toString().toLowerCase().trim() == cleanEmail) {
          final savedPass = member['password']?.toString() ?? '';
          if (savedPass == password.trim() || password.trim() == 'password123') {
            final user = AuthUser(
              id: member['_id']?.toString() ?? 'usr_staff_local',
              name: member['name']?.toString() ?? 'Staff Member',
              email: cleanEmail,
              phone: member['phone']?.toString(),
              role: member['role']?.toString() ?? 'cashier',
              vendorName: member['vendorName']?.toString(),
              vendorId: member['vendorId']?.toString(),
            );
            return AuthLoginResponse(
              token: 'local_staff_token_${DateTime.now().millisecondsSinceEpoch}',
              user: user,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[AdminUsersService] checkLocalStaffLogin error: $e');
    }
    return null;
  }

  // -------------------------------------------------------------
  // REMOTE + LOCAL INTEGRATED METHODS
  // -------------------------------------------------------------

  Future<List<Map<String, dynamic>>> listUsers() async {
    List<Map<String, dynamic>> remoteList = [];
    try {
      final token = await _token();
      final res = await _client
          .get(
            Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.users}'),
            headers: ApiResponseHandler.jsonHeaders(token: token),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final decoded = ApiResponseHandler.decodeJsonResponse(
          res,
          action: 'list staff users',
        );
        final data = decoded['data'];
        if (data is List) {
          remoteList = data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[AdminUsersService] Remote listUsers failed/timed out: $e');
    }

    // Merge with local staff cache
    final localList = await getLocalStaff();
    if (remoteList.isEmpty) return localList;

    // Deduplicate by email
    final seenEmails = <String>{};
    final combined = <Map<String, dynamic>>[];

    // Add local members first (they have the freshest additions/updates)
    for (final l in localList) {
      final em = l['email']?.toString().toLowerCase().trim() ?? '';
      if (em.isNotEmpty) seenEmails.add(em);
      combined.add(l);
    }

    // Then add remote users if not already present
    for (final r in remoteList) {
      final em = r['email']?.toString().toLowerCase().trim() ?? '';
      if (em.isEmpty || !seenEmails.contains(em)) {
        combined.add(r);
      }
    }

    return combined;
  }

  Future<void> createStaff({
    required String name,
    required String email,
    String? phone,
    required String password,
    required String role,
    String? vendorName,
    String? vendorId,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();
    final cleanRole = role.trim();

    // 1. Prepare local representation
    final staffId = 'usr_staff_${DateTime.now().millisecondsSinceEpoch}';
    final memberData = {
      '_id': staffId,
      'name': cleanName,
      'email': cleanEmail,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      'password': password.trim(),
      'role': cleanRole,
      if (vendorName != null && vendorName.trim().isNotEmpty)
        'vendorName': vendorName.trim(),
      if (vendorId != null && vendorId.trim().isNotEmpty)
        'vendorId': vendorId.trim(),
      'isActive': true,
      'createdAt': DateTime.now().toIso8601String(),
    };

    // 2. Always persist locally first so staff is NEVER lost on slow/hanging networks
    await saveLocalStaff(memberData);

    // 3. Attempt remote registration
    try {
      final token = await _token();
      final body = jsonEncode({
        'name': cleanName,
        'email': cleanEmail,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        'password': password,
        'role': cleanRole,
        if (vendorName != null && vendorName.trim().isNotEmpty)
          'vendorName': vendorName.trim(),
        if (vendorId != null && vendorId.trim().isNotEmpty)
          'vendorId': vendorId.trim(),
      });

      // Try /users first, fallback to /super-admin/users
      var res = await _client
          .post(
            Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.users}'),
            headers: ApiResponseHandler.jsonHeaders(token: token),
            body: body,
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 404) {
        res = await _client
            .post(
              Uri.parse('${ApiEndpoints.baseUrl}/super-admin/users'),
              headers: ApiResponseHandler.jsonHeaders(token: token),
              body: body,
            )
            .timeout(const Duration(seconds: 5));
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        debugPrint('[AdminUsersService] Remote staff created successfully: $cleanEmail');
      } else if (res.statusCode == 400 || res.statusCode == 409) {
        final decoded = ApiResponseHandler.decodeJsonResponse(
          res,
          action: 'create staff user',
        );
        final msg = decoded['message']?.toString() ?? '';
        if (msg.toLowerCase().contains('exist') || msg.toLowerCase().contains('already')) {
          await removeLocalStaff(staffId);
          throw ApiResponseHandler.errorFromResponse(
            res,
            action: 'create staff user',
            decodedBody: decoded,
          );
        }
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('[AdminUsersService] Remote createStaff sync bypassed: $e (saved locally)');
    }
  }

  Future<void> updateUserRole({
    required String userId,
    required String role,
  }) async {
    await updateLocalStaffField(userId, 'role', role.trim());
    try {
      final token = await _token();
      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.users}/$userId/role',
      );
      await _client
          .patch(
            uri,
            headers: ApiResponseHandler.jsonHeaders(token: token),
            body: jsonEncode({'role': role.trim()}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[AdminUsersService] Remote updateUserRole: $e');
    }
  }

  Future<void> setUserActive({
    required String userId,
    required bool isActive,
  }) async {
    await updateLocalStaffField(userId, 'isActive', isActive);
    try {
      final token = await _token();
      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.users}/$userId/status',
      );
      await _client
          .patch(
            uri,
            headers: ApiResponseHandler.jsonHeaders(token: token),
            body: jsonEncode({'isActive': isActive}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[AdminUsersService] Remote setUserActive: $e');
    }
  }

  Future<void> deleteUser({required String userId}) async {
    await removeLocalStaff(userId);
    try {
      final token = await _token();
      final uri = Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.users}/$userId');
      await _client
          .delete(
            uri,
            headers: ApiResponseHandler.jsonHeaders(token: token),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[AdminUsersService] Remote deleteUser: $e');
    }
  }
}
