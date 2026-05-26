import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../models/auth_user.dart';

/// Authentication service for handling login and registration API calls
///
/// Features:
/// - Comprehensive error handling for network issues
/// - HTML response detection (catches wrong endpoints)
/// - Timeout handling (15 seconds default)
/// - Safe JSON parsing with fallback messages
/// - Detailed logging for debugging
class AuthService {
  final http.Client _client;
  // Render cold starts can take longer on first hit.
  static const Duration _authTimeout = Duration(seconds: 25);

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  Future<http.Response> _postWithRetry({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) async {
    Future<http.Response> sendOnce() {
      return _client
          .post(
            uri,
            headers: headers,
            body: body,
          )
          .timeout(_authTimeout);
    }

    try {
      return await sendOnce();
    } on TimeoutException {
      // Retry once for transient network stalls.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      return sendOnce();
    } on SocketException {
      // Retry once for flaky Wi-Fi handoff.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      return sendOnce();
    }
  }

  Future<http.Response> _postAuthWithBaseFallback({
    required String endpoint,
    required String requestBody,
  }) async {
    final candidates = ApiEndpoints.authFallbackBaseUrls;
    Object? lastError;

    for (final base in candidates) {
      final uri = Uri.parse('$base$endpoint');
      try {
        final response = await _postWithRetry(
          uri: uri,
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        );

        // Reaching server (even with 4xx auth errors) means URL works.
        if (base != ApiEndpoints.baseUrl) {
          await ApiEndpoints.setPersistedBaseUrl(base);
          if (kDebugMode) {
            debugPrint('AuthService: switched API URL to $base');
          }
        }
        return response;
      } on TimeoutException catch (e) {
        lastError = e;
      } on SocketException catch (e) {
        lastError = e;
      }
    }

    if (lastError is TimeoutException) throw lastError;
    if (lastError is SocketException) throw lastError;
    throw TimeoutException('No reachable auth endpoint');
  }

  /// Safe JSON decoder that handles HTML responses and parsing errors
  dynamic _safeJsonDecode(String body) {
    final trimmedBody = body.trim();

    // Check for HTML response (indicates wrong endpoint or server error)
    if (trimmedBody.toLowerCase().startsWith('<!doctype html>') ||
        trimmedBody.toLowerCase().startsWith('<html') ||
        trimmedBody.toLowerCase().startsWith('<head')) {
      print('❌ AuthService: Server returned HTML instead of JSON');
      final previewLength = trimmedBody.length > 200 ? 200 : trimmedBody.length;
      print('Response preview: ${trimmedBody.substring(0, previewLength)}');
      throw const ApiException(
        'Invalid API response. Server returned HTML. Check backend route or ensure server is running correctly.',
      );
    }

    // Check for empty response
    if (trimmedBody.isEmpty) {
      throw const ApiException('Server returned empty response');
    }

    try {
      return jsonDecode(body);
    } catch (e) {
      print('❌ AuthService: Failed to parse JSON response');
      print('Response body: $body');
      print('Error: $e');
      throw ApiException('Failed to parse server response: $e');
    }
  }

  /// Register a new user
  ///
  /// Throws:
  /// - ApiException with 'Server unreachable' if backend is not accessible
  /// - ApiException with timeout message if request takes too long
  /// - ApiException with backend error message if registration fails
  Future<Map<String, dynamic>> registerUser({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.register}');
      final requestBody = jsonEncode({
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'password': password.trim(),
      });

      print('🔵 AuthService [Register]');
      print('  URL: $uri');
      print('  Request Body: $requestBody');

      final response = await _postAuthWithBaseFallback(
        endpoint: ApiEndpoints.register,
        requestBody: requestBody,
      );

      print('🔵 AuthService [Register Response]');
      print('  Status Code: ${response.statusCode}');
      print('  Response Body: ${response.body}');

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ AuthService: Registration successful');
        return decoded;
      } else {
        print(
          '❌ AuthService: Registration failed with status ${response.statusCode}',
        );
        // Safely extract error message from response
        final errorMessage = decoded['message'] != null
            ? decoded['message'].toString()
            : 'Registration failed with status: ${response.statusCode}';
        throw ApiException(errorMessage, statusCode: response.statusCode);
      }
    } on SocketException catch (e) {
      print('❌ AuthService: SocketException - Server unreachable');
      print('  Error: ${e.message}');
      print('  This usually means:');
      print('    - Backend server is temporarily unreachable');
      print('    - Internet connection is unstable');
      print('    - Hosted backend is waking from sleep');
      throw const ApiException(
        'Server unreachable. Please check internet and try again in a few seconds.',
      );
    } on TimeoutException catch (e) {
      print('❌ AuthService: TimeoutException - Connection timed out');
      print('  Error: ${e.message}');
      throw ApiException(
        'Connection timed out while contacting ${ApiEndpoints.baseUrl}. '
        'Hosted server may be waking up. Please retry.',
      );
    } on ApiException catch (e) {
      // Re-throw ApiException as-is
      print('❌ AuthService: ApiException - ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ AuthService: Unexpected error - $e');
      print('  Type: ${e.runtimeType}');
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  /// Login an existing user
  ///
  /// Throws:
  /// - ApiException with 'Server unreachable' if backend is not accessible
  /// - ApiException with timeout message if request takes too long
  /// - ApiException with backend error message if login fails
  Future<AuthLoginResponse> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.login}');
      final requestBody = jsonEncode({
        'email': email.trim(),
        'password': password.trim(),
      });

      print('🔵 AuthService [Login]');
      print('  URL: $uri');
      print('  Request Body: $requestBody');

      final response = await _postAuthWithBaseFallback(
        endpoint: ApiEndpoints.login,
        requestBody: requestBody,
      );

      print('🔵 AuthService [Login Response]');
      print('  Status Code: ${response.statusCode}');
      print('  Response Body: ${response.body}');

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ AuthService: Login successful');
        if (decoded is! Map) {
          throw const ApiException('Invalid login response from server');
        }
        final map = Map<String, dynamic>.from(decoded);
        if (kDebugMode) {
          final u = map['user'];
          debugPrint('LOGIN RESPONSE keys: ${map.keys.toList()}');
          if (u is Map) {
            final userMap = Map<String, dynamic>.from(u);
            debugPrint(
              'LOGIN RESPONSE user map keys: ${userMap.keys.toList()} '
              'user.role=${userMap['role']}',
            );
          } else {
            debugPrint('LOGIN RESPONSE user: (not a map) $u');
          }
          debugPrint('LOGIN RESPONSE top-level role: ${map['role']}');
        }
        return AuthLoginResponse.fromJson(map);
      } else {
        print('❌ AuthService: Login failed with status ${response.statusCode}');
        // Safely extract error message from response
        final errorMessage = decoded['message'] != null
            ? decoded['message'].toString()
            : 'Login failed with status: ${response.statusCode}';
        throw ApiException(errorMessage, statusCode: response.statusCode);
      }
    } on SocketException catch (e) {
      print('❌ AuthService: SocketException - Server unreachable');
      print('  Error: ${e.message}');
      print('  This usually means:');
      print('    - Backend server is temporarily unreachable');
      print('    - Internet connection is unstable');
      print('    - Hosted backend is waking from sleep');
      throw const ApiException(
        'Server unreachable. Please check internet and try again in a few seconds.',
      );
    } on TimeoutException catch (e) {
      print('❌ AuthService: TimeoutException - Connection timed out');
      print('  Error: ${e.message}');
      throw ApiException(
        'Connection timed out while contacting ${ApiEndpoints.baseUrl}. '
        'Hosted server may be waking up. Please retry.',
      );
    } on ApiException catch (e) {
      // Re-throw ApiException as-is
      print('❌ AuthService: ApiException - ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ AuthService: Unexpected error - $e');
      print('  Type: ${e.runtimeType}');
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  /// Login with Google Email (verified via Firebase)
  Future<AuthLoginResponse> loginWithGoogle({required String email}) async {
    try {
      final requestBody = jsonEncode({'email': email.trim()});
      final response = await _postAuthWithBaseFallback(
        endpoint: ApiEndpoints.googleLogin,
        requestBody: requestBody,
      );

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return AuthLoginResponse.fromJson(Map<String, dynamic>.from(decoded));
      } else {
        final errorMessage = decoded['message'] ?? 'Google login failed';
        throw ApiException(errorMessage.toString(), statusCode: response.statusCode);
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Google login failed: $e');
    }
  }

  /// Login with Phone Number (verified via Firebase)
  Future<AuthLoginResponse> loginWithPhone({required String phone}) async {
    try {
      final requestBody = jsonEncode({'phone': phone.trim()});
      final response = await _postAuthWithBaseFallback(
        endpoint: '/auth/phone-login',
        requestBody: requestBody,
      );

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return AuthLoginResponse.fromJson(Map<String, dynamic>.from(decoded));
      } else {
        final errorMessage = decoded['message'] ?? 'Phone login failed';
        throw ApiException(errorMessage.toString(), statusCode: response.statusCode);
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Phone login failed: $e');
    }
  }

  Future<void> sendOtp({required String phone}) async {
    try {
      final requestBody = jsonEncode({'phone': phone.trim()});
      final response = await _postAuthWithBaseFallback(
        endpoint: '/auth/send-otp',
        requestBody: requestBody,
      );
      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      final errorMessage = decoded['message'] != null
          ? decoded['message'].toString()
          : 'OTP send failed with status: ${response.statusCode}';
      throw ApiException(errorMessage, statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to send OTP: $e');
    }
  }

  Future<AuthLoginResponse> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final requestBody = jsonEncode({'phone': phone.trim(), 'otp': otp.trim()});
      final response = await _postAuthWithBaseFallback(
        endpoint: '/auth/verify-otp',
        requestBody: requestBody,
      );
      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is! Map) {
          throw const ApiException('Invalid OTP verify response from server');
        }
        final map = Map<String, dynamic>.from(decoded);
        return AuthLoginResponse.fromJson(map);
      }
      final errorMessage = decoded['message'] != null
          ? decoded['message'].toString()
          : 'OTP verify failed with status: ${response.statusCode}';
      throw ApiException(errorMessage, statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to verify OTP: $e');
    }
  }
}
