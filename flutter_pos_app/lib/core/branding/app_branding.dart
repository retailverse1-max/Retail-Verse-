import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/settings/domain/models/pos_settings.dart';
import '../../features/settings/providers/pos_settings_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../navigation/role_nav.dart';

/// Central branding management for Multi-Tenant White-Labeling.
///
/// When the store owner sets "Store name" in Settings (e.g. "Dazy Homes"):
/// - All occurrences of "Retail Verse" / "RetailVerse" across all user-facing
///   portals (admin, cashier, inventory, vendor, customer, billing, login) are
///   dynamically replaced by that store name.
/// - The Super Admin portal retains "Retail Verse Platform" / "Retail Verse"
///   for master platform administration.
class AppBranding {
  static const String defaultPlatformName = 'Retail Verse';
  static const String _keyStoreBrandingName = 'custom_store_branding_name_v1';

  /// Synchronous ValueNotifier for widgets that need real-time brand updates
  static final ValueNotifier<String> storeNameNotifier =
      ValueNotifier<String>(defaultPlatformName);

  static String _currentName = defaultPlatformName;
  static String? _currentRole;

  /// Update the current active user role (e.g. from auth or navigation)
  static void updateRole(String? role) {
    _currentRole = role;
  }

  /// Active user role in session
  static String? get currentRole => _currentRole;

  /// Returns current store name synchronously
  static String get currentStoreName => getStoreName();

  /// Initialize branding on app launch from SharedPreferences
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_keyStoreBrandingName);
      if (saved != null &&
          saved.trim().isNotEmpty &&
          saved.trim() != 'My Store' &&
          saved.trim() != defaultPlatformName) {
        _currentName = saved.trim();
        storeNameNotifier.value = _currentName;
        return;
      }

      // Check PosSettings storage
      final rawSettings = prefs.getString('pos_app_settings_json_v1');
      if (rawSettings != null && rawSettings.isNotEmpty) {
        final decoded = PosSettings.decode(rawSettings);
        final name = decoded.storeName.trim();
        if (name.isNotEmpty &&
            name != 'My Store' &&
            name != defaultPlatformName) {
          _currentName = name;
          storeNameNotifier.value = _currentName;
          await prefs.setString(_keyStoreBrandingName, _currentName);
          return;
        }
      }

      _currentName = defaultPlatformName;
      storeNameNotifier.value = defaultPlatformName;
    } catch (e) {
      debugPrint('[AppBranding] Init error: $e');
    }
  }

  /// Update the store name everywhere in real-time
  static Future<void> setStoreName(String newName) async {
    final trimmed = newName.trim();
    final isCustom = trimmed.isNotEmpty &&
        trimmed != 'My Store' &&
        trimmed != defaultPlatformName;
    final effective = isCustom ? trimmed : defaultPlatformName;

    _currentName = effective;
    storeNameNotifier.value = effective;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (isCustom) {
        await prefs.setString(_keyStoreBrandingName, trimmed);
      } else {
        await prefs.remove(_keyStoreBrandingName);
      }
    } catch (e) {
      debugPrint('[AppBranding] setStoreName error: $e');
    }
  }

  /// Reset branding back to platform default (used on logout)
  static Future<void> resetToDefault() async {
    _currentName = defaultPlatformName;
    storeNameNotifier.value = defaultPlatformName;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyStoreBrandingName);
    } catch (e) {
      debugPrint('[AppBranding] resetToDefault error: $e');
    }
  }

  /// Helper to check if role is Super Admin
  static bool isSuperAdmin(String? role) {
    if (role == null) return false;
    final r = role.trim().toLowerCase();
    return r == 'super_admin' || r == 'superadmin' || r == 'super_administrator';
  }

  /// Get the store name considering the user role:
  /// - If [role] or active session is `super_admin`: ALWAYS returns 'Retail Verse'.
  /// - Otherwise: returns custom store name (e.g. 'Dazy Homes'), or fallback.
  static String getStoreName({String? role, String? fallback}) {
    final effective = role ?? _currentRole;
    if (effective != null && isSuperAdmin(effective)) {
      return defaultPlatformName;
    }
    if (_currentName.isNotEmpty &&
        _currentName != 'My Store' &&
        _currentName != defaultPlatformName) {
      return _currentName;
    }
    return fallback ?? defaultPlatformName;
  }

  /// Formats any brand string template:
  /// Replaces 'Retail Verse' and 'RetailVerse' with the active store name (unless superadmin).
  static String format(String template, {String? role}) {
    final effective = role ?? _currentRole;
    if (isSuperAdmin(effective)) {
      return template;
    }
    final brand = getStoreName(role: effective);
    return template
        .replaceAll('Retail Verse', brand)
        .replaceAll('RetailVerse', brand);
  }
}

/// Riverpod provider for reactive UI listening to branding changes
final appBrandingProvider = Provider<String>((ref) {
  final settings = ref.watch(posSettingsProvider);
  final authState = ref.watch(authProvider);
  final role = authState.user != null ? effectiveUserRole(authState.user!) : null;
  AppBranding.updateRole(role);

  if (AppBranding.isSuperAdmin(role)) {
    return AppBranding.defaultPlatformName;
  }

  final candidate = settings.storeName.trim();
  if (candidate.isNotEmpty &&
      candidate != 'My Store' &&
      candidate != AppBranding.defaultPlatformName) {
    AppBranding.storeNameNotifier.value = candidate;
    return candidate;
  }

  if (AppBranding._currentName.isNotEmpty &&
      AppBranding._currentName != 'My Store' &&
      AppBranding._currentName != AppBranding.defaultPlatformName) {
    return AppBranding._currentName;
  }

  AppBranding.storeNameNotifier.value = AppBranding.defaultPlatformName;
  return AppBranding.defaultPlatformName;
});
