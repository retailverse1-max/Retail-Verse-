import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists auth after login: [token], [userId], [userName], [userEmail], [userRole] (+ optional [storeId]).
class SessionService {
  static String? currentStoreId;

  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _userPhoneKey = 'user_phone';
  static const String _userRoleKey = 'user_role';
  static const String _storeIdKey = 'store_id';
  static const String _subscriptionPlanKey = 'subscription_plan';
  static const String _subscriptionStatusKey = 'subscription_status';
  static const String _subscriptionExpiryKey = 'subscription_expiry';

  /// Keys for [readPersistedAuth] / [restoreFromStorage] consumers.
  static const String persistedTokenKey = 'token';
  static const String persistedUserIdKey = 'userId';
  static const String persistedUserNameKey = 'userName';
  static const String persistedUserEmailKey = 'userEmail';
  static const String persistedUserPhoneKey = 'userPhone';
  static const String persistedUserRoleKey = 'userRole';
  static const String persistedStoreIdKey = 'storeId';
  static const String persistedSubscriptionPlanKey = 'subscriptionPlan';
  static const String persistedSubscriptionStatusKey = 'subscriptionStatus';
  static const String persistedSubscriptionExpiryKey = 'subscriptionExpiry';

  static Future<void> saveSession({
    required String token,
    String? userId,
    String? userName,
    String? userEmail,
    String? userPhone,
    String? userRole,
    String? storeId,
    String? subscriptionPlan,
    String? subscriptionStatus,
    String? subscriptionExpiry,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_tokenKey, token);

    // Persist role only when login supplied one — never write a fake "cashier" placeholder.
    final trimmed = userRole?.trim().toLowerCase();
    if (trimmed != null && trimmed.isNotEmpty) {
      await prefs.setString(_userRoleKey, trimmed);
    } else {
      await prefs.remove(_userRoleKey);
    }

    if (userId != null) {
      await prefs.setString(_userIdKey, userId);
    }
    if (userName != null) {
      await prefs.setString(_userNameKey, userName);
    }
    if (userEmail != null) {
      await prefs.setString(_userEmailKey, userEmail);
    }
    if (userPhone != null) {
      final t = userPhone.trim();
      if (t.isNotEmpty) {
        await prefs.setString(_userPhoneKey, t);
      } else {
        await prefs.remove(_userPhoneKey);
      }
    }
    if (storeId != null) {
      await prefs.setString(_storeIdKey, storeId);
      currentStoreId = storeId;
    }
    if (subscriptionPlan != null) {
      await prefs.setString(_subscriptionPlanKey, subscriptionPlan);
    }
    if (subscriptionStatus != null) {
      await prefs.setString(_subscriptionStatusKey, subscriptionStatus);
    }
    if (subscriptionExpiry != null) {
      await prefs.setString(_subscriptionExpiryKey, subscriptionExpiry);
    }

    if (kDebugMode) {
      debugPrint(
        'SessionService: session saved (token length ${token.length}, role: ${trimmed ?? "(cleared)"})',
      );
    }
  }

  /// One SharedPreferences read for token + user profile (use after cold start or for role checks).
  static Future<Map<String, String?>> readPersistedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    currentStoreId = prefs.getString(_storeIdKey);
    return {
      persistedTokenKey: prefs.getString(_tokenKey),
      persistedUserIdKey: prefs.getString(_userIdKey),
      persistedUserNameKey: prefs.getString(_userNameKey),
      persistedUserEmailKey: prefs.getString(_userEmailKey),
      persistedUserPhoneKey: prefs.getString(_userPhoneKey),
      persistedUserRoleKey: prefs.getString(_userRoleKey),
      persistedStoreIdKey: currentStoreId,
      persistedSubscriptionPlanKey: prefs.getString(_subscriptionPlanKey),
      persistedSubscriptionStatusKey: prefs.getString(_subscriptionStatusKey),
      persistedSubscriptionExpiryKey: prefs.getString(_subscriptionExpiryKey),
    };
  }

  /// Last saved role from login (persisted). Same storage as [getUserRole].
  static Future<String?> getPersistedUserRole() => getUserRole();

  /// Whether the persisted role matches [role] (case-insensitive).
  static Future<bool> persistedRoleEquals(String role) async {
    final saved = await getUserRole();
    if (saved == null || saved.isEmpty) return false;
    return saved.toLowerCase() == role.trim().toLowerCase();
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  static Future<String?> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userPhoneKey);
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  static Future<String?> getStoreId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storeIdKey);
  }

  static Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey)?.trim();
    // Ignore whitespace-only / garbage keys so cold start can reach login.
    return token != null && token.length >= 8;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userPhoneKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_storeIdKey);
    await prefs.remove(_subscriptionPlanKey);
    await prefs.remove(_subscriptionStatusKey);
    await prefs.remove(_subscriptionExpiryKey);
    currentStoreId = null;
    if (kDebugMode) {
      debugPrint('SessionService: session cleared');
    }
  }
}