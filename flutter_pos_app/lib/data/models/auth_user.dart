import 'package:flutter/foundation.dart';

import '../../core/auth/login_role_parser.dart';
import '../../core/network/api_exception.dart';

/// Logged-in user profile from `POST /auth/login` (and compatible register payloads).
class AuthUser {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final bool emailVerified;
  final bool phoneVerified;
  final String role;
  final String? storeId;
  final String? subscriptionPlan;
  final String? subscriptionStatus;
  final String? subscriptionExpiry;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.emailVerified = false,
    this.phoneVerified = false,
    required this.role,
    this.storeId,
    this.subscriptionPlan,
    this.subscriptionStatus,
    this.subscriptionExpiry,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final sid = json['storeId']?.toString().trim();
    final roleParsed = parseRoleFromUserLikeMap(json)?.trim();
    final role = canonicalUiRole(roleParsed) ?? '';
    if (role.isEmpty && kDebugMode) {
      debugPrint(
        '[auth] AuthUser.fromJson: no role field on user map (keys: ${json.keys.toList()})',
      );
    }
    return AuthUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: (json['phone']?.toString().trim().isNotEmpty ?? false)
          ? json['phone']?.toString()
          : null,
      emailVerified: json['emailVerified'] == true,
      phoneVerified: json['phoneVerified'] == true,
      role: role,
      storeId: (sid != null && sid.isNotEmpty && sid != 'null') ? sid : null,
      subscriptionPlan: json['subscriptionPlan']?.toString(),
      subscriptionStatus: json['subscriptionStatus']?.toString(),
      subscriptionExpiry: json['subscriptionExpiry']?.toString(),
    );
  }

  /// Shape expected by screens still using `Map` (`user['name']`, etc.).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        if (phone != null) 'phone': phone,
        'emailVerified': emailVerified,
        'phoneVerified': phoneVerified,
        'role': role,
        if (storeId != null) 'storeId': storeId,
        if (subscriptionPlan != null) 'subscriptionPlan': subscriptionPlan,
        if (subscriptionStatus != null) 'subscriptionStatus': subscriptionStatus,
        if (subscriptionExpiry != null) 'subscriptionExpiry': subscriptionExpiry,
      };
}

/// Parsed login API body: `success`, `token`, `user`.
class AuthLoginResponse {
  final String token;
  final AuthUser user;

  const AuthLoginResponse({required this.token, required this.user});

  factory AuthLoginResponse.fromJson(Map<String, dynamic> json) {
    if (json['success'] == false) {
      throw ApiException(
        json['message']?.toString() ?? 'Login failed',
      );
    }

    final token = json['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const ApiException('Token not received from server');
    }

    final rawUser = json['user'];
    if (rawUser is! Map) {
      throw const ApiException('Invalid user payload from server');
    }

    final full = Map<String, dynamic>.from(json);
    final userMap = Map<String, dynamic>.from(rawUser);
    final resolvedRole = resolveRoleFromLoginResponse(full, token);
    if (resolvedRole != null && resolvedRole.isNotEmpty) {
      userMap['role'] = resolvedRole;
    } else {
      userMap.remove('role');
    }

    if (kDebugMode) {
      debugPrint(
        '[auth] PARSED ROLE: ${resolvedRole ?? "(none)"} (user.role was ${userMap['role']})',
      );
    }

    final user = AuthUser.fromJson(userMap);

    if (user.id.isEmpty) {
      throw const ApiException('Invalid user id from server');
    }

    return AuthLoginResponse(token: token, user: user);
  }
}
