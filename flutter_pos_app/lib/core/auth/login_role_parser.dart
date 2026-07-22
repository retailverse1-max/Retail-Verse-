import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Maps legacy / human-readable role strings to the canonical roles used by routing.
String? canonicalUiRole(String? raw) {
  if (raw == null) return null;
  var s = raw.trim().toLowerCase();
  if (s.isEmpty || s == 'null') return null;
  s = s.replaceAll(RegExp(r'[\s-]+'), '_');
  if (s == 'superadmin') s = 'super_admin';
  if (s == 'inventory' || s == 'stock_manager') s = 'inventory_manager';
  if (s == 'seo' || s == 'seo manager') s = 'seo_manager';
  if (s == 'client') s = 'admin';
  if (s == 'employee') s = 'cashier';
  const known = {'super_admin', 'admin', 'cashier', 'inventory_manager', 'seo_manager', 'customer', 'user'};
  if (known.contains(s)) return s;
  return null;
}

/// Best-effort role from nested `user` map (handles alternate key casing).
String? parseRoleFromUserLikeMap(Map<String, dynamic> map) {
  const keys = [
    'role',
    'userRole',
    'user_role',
    'Role',
    'UserRole',
  ];
  for (final key in keys) {
    final v = map[key];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') continue;
    return s;
  }
  return null;
}

/// Reads `role` from JWT payload (no signature verify — display / restore only).
String? decodeJwtRoleClaim(String? token) {
  if (token == null || token.isEmpty) return null;
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final normalized = base64Url.normalize(parts[1]);
    final jsonStr = utf8.decode(base64Url.decode(normalized));
    final obj = jsonDecode(jsonStr);
    if (obj is! Map) return null;
    final m = Map<String, dynamic>.from(obj);
    final r = m['role'] ?? m['userRole'];
    if (r == null) return null;
    final s = r.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    return s;
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[auth] decodeJwtRoleClaim failed: $e\n$st');
    }
    return null;
  }
}

/// Picks role from full login JSON: `user` object, top-level fields, then JWT.
/// Returns `null` when nothing usable is found (caller must not persist a fake role).
String? resolveRoleFromLoginResponse(
  Map<String, dynamic> json,
  String token,
) {
  Map<String, dynamic> userMap = {};
  final rawUser = json['user'];
  if (rawUser is Map) {
    userMap = Map<String, dynamic>.from(rawUser as Map);
  }

  var role = parseRoleFromUserLikeMap(userMap);
  if (role == null || role.isEmpty) {
    final top = json['role'] ?? json['userRole'];
    if (top != null) {
      final s = top.toString().trim();
      if (s.isNotEmpty && s.toLowerCase() != 'null') role = s;
    }
  }
  if (role == null || role.isEmpty) {
    role = decodeJwtRoleClaim(token);
  }

  final normalized = role?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    if (kDebugMode) {
      debugPrint(
        '[auth] WARNING: role missing after login parse (user keys: ${userMap.keys.toList()})',
      );
    }
    return null;
  }
  return canonicalUiRole(normalized);
}
