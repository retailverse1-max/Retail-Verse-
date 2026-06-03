import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// API base URL and paths for backend communication.
///
/// Call [initialize] from `main()` before `runApp`.
///
/// Default backend for all platforms:
/// `https://app-backend-je91.onrender.com/api`
///
/// Override: Settings → API URL, or `--dart-define=API_BASE_URL=https://.../api`
class ApiEndpoints {
  ApiEndpoints._();

  /// Bump when clearing bad saved URLs; v1/v2/v3 removed on startup.
  static const String _prefsKey = 'api_base_url_override_v4';

  /// Build-time override (CI / staging).
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const String _hostedBaseUrl =
      'https://app-backend-je91.onrender.com/api';

  static String _resolvedBaseUrl = '';

  /// Must be awaited from `main()` before UI uses API.
  static Future<void> initialize() async {
    if (_envBaseUrl.isNotEmpty) {
      final envNormalized = _normalizeApiBaseUrl(_envBaseUrl);
      _resolvedBaseUrl =
          _isLocalOrPrivateUrl(envNormalized) ? _hostedBaseUrl : envNormalized;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_base_url_override');
    await prefs.remove('api_base_url_override_v2');
    await prefs.remove('api_base_url_override_v3');

    final saved = prefs.getString(_prefsKey)?.trim();
    if (saved != null && saved.isNotEmpty) {
      final normalized = _normalizeApiBaseUrl(saved);
      if (_isLocalOrPrivateUrl(normalized)) {
        await prefs.remove(_prefsKey);
        _resolvedBaseUrl = _hostedBaseUrl;
      } else if (normalized != _hostedBaseUrl && !normalized.contains('localhost') && !normalized.contains('127.0.0.1')) {
        // Clear stale remote URLs to force the new active production backend
        await prefs.remove(_prefsKey);
        _resolvedBaseUrl = _hostedBaseUrl;
      } else {
        _resolvedBaseUrl = normalized;
      }
    } else {
      _resolvedBaseUrl = _hostedBaseUrl;
    }

    debugPrint('🚀 API Base URL Initialized: $_resolvedBaseUrl');
  }

  /// User override from Settings (persisted). Pass `null` or empty to clear.
  static Future<void> setPersistedBaseUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      await prefs.remove(_prefsKey);
      await initialize();
      return;
    }
    final normalized = _normalizeApiBaseUrl(url.trim());
    if (_isLocalOrPrivateUrl(normalized)) {
      await prefs.remove(_prefsKey);
      _resolvedBaseUrl = _hostedBaseUrl;
      return;
    }
    await prefs.setString(_prefsKey, normalized);
    _resolvedBaseUrl = normalized;
  }

  static String _normalizeApiBaseUrl(String input) {
    var s = input.trim();
    if (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (!s.endsWith('/api')) {
      s = '$s/api';
    }
    return s;
  }

  static bool _isLocalOrPrivateUrl(String input) {
    final lower = input.toLowerCase();
    return lower.contains('localhost') ||
        lower.contains('10.0.2.2') ||
        lower.contains('127.0.0.1') ||
        lower.contains('192.168.');
  }

  /// Effective API root, e.g. `https://app-backend-je91.onrender.com/api`
  static String get baseUrl {
    if (_resolvedBaseUrl.isNotEmpty) {
      if (!_isLocalOrPrivateUrl(_resolvedBaseUrl) && _resolvedBaseUrl != _hostedBaseUrl) {
        return _hostedBaseUrl;
      }
      return _resolvedBaseUrl;
    }
    if (_envBaseUrl.isNotEmpty) {
      return _normalizeApiBaseUrl(_envBaseUrl);
    }
    return _hostedBaseUrl;
  }

  /// Candidate API roots for auth fallback when a stale URL times out.
  /// Ordered by preference: current effective URL first, then hosted default.
  static List<String> get authFallbackBaseUrls {
    final seen = <String>{};
    final out = <String>[];
    void add(String v) {
      final n = _normalizeApiBaseUrl(v);
      if (seen.add(n)) out.add(n);
    }

    add(baseUrl);
    add(_hostedBaseUrl);
    return out;
  }

  /// Root URL for health checks (`GET /` → "POS Backend running").
  static Uri healthCheckUri() {
    final u = Uri.parse(baseUrl);
    return Uri(scheme: u.scheme, host: u.host, port: u.port, path: '/');
  }

  /// `scheme://host:port` without path — for static files served outside `/api` (e.g. `/uploads/...`).
  static String get serverOrigin => Uri.parse(baseUrl).origin;

  // Authentication endpoints
  static const String login = '/auth/login';
  static const String googleLogin = '/auth/google-login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';

  static const String products = '/products';
  static const String productById = '/products/:id';
  static const String searchProducts = '/products/search';

  static const String categories = '/categories';
  static const String categoryById = '/categories/:id';

  static const String orders = '/orders';
  static const String orderById = '/orders/:id';
  static const String createOrder = '/orders/create';
  static const String cancelOrder = '/orders/:id/cancel';

  static const String inventory = '/inventory';
  static const String adjustStock = '/inventory/adjust';
  static const String lowStock = '/inventory/low-stock';
  static const String notifications = '/notifications';
  static const String notificationRestockRequest =
      '/notifications/restock-request';

  static const String dashboardStats = '/dashboard/stats';
  static const String recentActivities = '/dashboard/recent-activities';

  static const String settings = '/settings';
  static const String storeInfo = '/settings/store';

  /// Admin / super_admin staff management (`GET/POST /users`, `PUT .../role`).
  static const String users = '/users';

  /// Alias for [users] (legacy path was `/admin/users`).
  static const String adminUsers = '/users';

  // Super Admin SaaS control panel (platform-level)
  static const String superAdminRoot = '/super-admin';
  static const String superAdminHealth = '/super-admin/health';
  static const String superAdminBusinesses = '/super-admin/businesses';
  static const String superAdminUsers = '/super-admin/users';
  static const String superAdminSubscriptionPlans = '/super-admin/subscription-plans';
  static const String superAdminAnalyticsSummary = '/super-admin/analytics/summary';
  static const String superAdminAuditLogs = '/super-admin/audit-logs';
  static const String superAdminCustomDomains = '/super-admin/custom-domains';
  static const String superAdminTopPerformance = '/super-admin/performance/top-stores';
  static const String superAdminBroadcast = '/super-admin/broadcast';

  // Razorpay and Support
  static const String razorpayCreateOrder = '/payments/razorpay/create-order';
  static const String razorpayVerify = '/payments/razorpay/verify';
  static const String zendeskTicket = '/support/ticket';
}
