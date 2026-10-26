import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../routes/app_router.dart';
import '../constants/api_endpoints.dart';
import '../services/session_service.dart';
import 'api_exception.dart';

class ApiResponseHandler {
  ApiResponseHandler._();

  static Map<String, String> jsonHeaders({String? token, bool ignoreStoreId = false}) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (!ignoreStoreId && SessionService.currentStoreId != null && SessionService.currentStoreId!.isNotEmpty)
        'x-client-id': SessionService.currentStoreId!,
    };
  }

  /// No `Authorization` header — use for intentionally public GETs (e.g. dashboard KPIs on LAN).
  static Map<String, String> publicJsonHeaders() {
    return const {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  static Uri uri(String endpoint) {
    var base = ApiEndpoints.baseUrl.trim();
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    var path = endpoint.trim();
    if (!path.startsWith('/')) {
      path = '/$path';
    }
    if (base.endsWith('/api') && path.startsWith('/api/')) {
      path = path.substring(4);
    }
    return Uri.parse('$base$path');
  }

  static void logResponse(String label, http.Response response) {
    debugPrint('$label STATUS: ${response.statusCode}');
    debugPrint('$label BODY: ${response.body}');
  }

  static dynamic decodeJsonResponse(
    http.Response response, {
    required String action,
  }) {
    final trimmedBody = response.body.trim();
    final contentType = response.headers['content-type'] ?? '';

    final isAuthAction = action.toLowerCase().contains('login') ||
        action.toLowerCase().contains('sign in') ||
        action.toLowerCase().contains('register') ||
        action.toLowerCase().contains('sign up');

    if (!isAuthAction && response.statusCode == 401) {
      _handleSessionExpiration();
      throw const ApiException(
        'Your session has expired. Please log in again.',
        statusCode: 401,
      );
    }

    if (trimmedBody.isEmpty) {
      throw ApiException(
        'The server returned an empty response while trying to $action.',
        statusCode: response.statusCode,
      );
    }

    if (_looksLikeHtml(trimmedBody) ||
        !_isLikelyJson(contentType, trimmedBody)) {
      throw ApiException(
        _invalidFormatMessage(response.statusCode),
        statusCode: response.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(trimmedBody);

      // Safety net: some backends return 200 with auth-error messages instead
      // of a proper 401. Catch "user not found", "invalid token", etc. here
      // so the user gets a clean "session expired → /login" redirect instead
      // of a raw error snackbar.
      if (!isAuthAction && decoded is Map<String, dynamic>) {
        final msg = (decoded['message'] ?? decoded['error'] ?? '').toString().toLowerCase();
        if (msg.contains('user not found') ||
            msg.contains('invalid token') ||
            msg.contains('not authorized') ||
            msg.contains('jwt expired') ||
            msg.contains('token expired')) {
          _handleSessionExpiration();
          throw const ApiException(
            'Your session has expired. Please log in again.',
            statusCode: 401,
          );
        }
      }

      return decoded;
    } on FormatException {
      throw ApiException(
        'The server returned data in an unexpected format. Please try again.',
        statusCode: response.statusCode,
      );
    }
  }

  static ApiException errorFromResponse(
    http.Response response, {
    required String action,
    dynamic decodedBody,
  }) {
    final message = _messageFromDecoded(decodedBody);

    final isAuthAction = action.toLowerCase().contains('login') ||
        action.toLowerCase().contains('sign in') ||
        action.toLowerCase().contains('register') ||
        action.toLowerCase().contains('sign up');

    if (!isAuthAction &&
        (response.statusCode == 401 ||
            (message != null &&
                (message.toLowerCase().contains('user not found') ||
                 message.toLowerCase().contains('invalid token') ||
                 message.toLowerCase().contains('not authorized'))))) {
      // Trigger automatic session cleanup and clean user-facing redirect
      _handleSessionExpiration();
      return ApiException(
        'Your session has expired. Please log in again.',
        statusCode: 401,
      );
    }

    if (response.statusCode == 404) {
      return ApiException(
        message ??
            'The requested API endpoint was not found. Check that the backend route is correct.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 500) {
      return ApiException(
        message ?? 'The server hit an error while trying to $action.',
        statusCode: response.statusCode,
      );
    }

    return ApiException(
      message ?? 'Request failed while trying to $action.',
      statusCode: response.statusCode,
    );
  }

  static ApiException errorFromException(
    Object error, {
    required String action,
  }) {
    if (error is ApiException) {
      return error;
    }

    if (error is SocketException) {
      return ApiException(
        'You are currently offline or the backend is unreachable.\n'
        'Orders will be saved locally and synced when you are back online.',
      );
    }

    if (error is TimeoutException) {
      return ApiException(
        'The request timed out while trying to $action. Please try again.',
      );
    }

    if (error is HttpException) {
      return ApiException('Network error while trying to $action.');
    }

    // Catch network-related errors from custom domains (ClientException, HandshakeException, etc.)
    final errStr = error.toString().toLowerCase();
    if (errStr.contains('clientexception') ||
        errStr.contains('handshakeexception') ||
        errStr.contains('connection closed') ||
        errStr.contains('connection refused') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('no address associated') ||
        errStr.contains('network is unreachable') ||
        errStr.contains('connection reset') ||
        errStr.contains('os error')) {
      return ApiException(
        'You are currently offline or the backend is unreachable.\n'
        'Orders will be saved locally and synced when you are back online.',
      );
    }

    return ApiException('Unexpected error while trying to $action: $error');
  }

  static bool _looksLikeHtml(String body) {
    final lower = body.toLowerCase();
    return lower.startsWith('<!doctype html') ||
        lower.startsWith('<html') ||
        lower.contains('<head>') ||
        lower.contains('<body>');
  }

  static bool _isLikelyJson(String contentType, String body) {
    final lowerContentType = contentType.toLowerCase();
    if (lowerContentType.contains('application/json')) {
      return true;
    }

    return body.startsWith('{') || body.startsWith('[');
  }

  static String _invalidFormatMessage(int statusCode) {
    if (statusCode == 404) {
      return 'The API endpoint was not found. The app received an HTML 404 page instead of JSON.';
    }

    if (statusCode >= 500) {
      return 'The server returned an HTML error page instead of JSON. Please try again in a moment.';
    }

    return 'API endpoint not found or server returned HTML. Check backend route.';
  }

  static String? _messageFromDecoded(dynamic decodedBody) {
    if (decodedBody is Map<String, dynamic>) {
      final message = decodedBody['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }

      final error = decodedBody['error'];
      if (error is String && error.trim().isNotEmpty) {
        return error;
      }
    }

    return null;
  }

  static DateTime _lastExpirationTrigger = DateTime(2000);

  static void _handleSessionExpiration() {
    final now = DateTime.now();
    if (now.difference(_lastExpirationTrigger).inSeconds < 5) return;
    _lastExpirationTrigger = now;

    // Clear stale credentials in local storage
    SessionService.clearSession();

    // Show clean user alert and redirect to login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final messenger = scaffoldMessengerKey.currentState;
        messenger?.clearSnackBars();
        messenger?.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            content: const Row(
              children: [
                Icon(Icons.lock_clock_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your session has expired. Please log in again.',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );

        // Safe navigate to login
        appRouter.go('/login');
      } catch (e) {
        debugPrint('Error navigating to login on session expiration: $e');
      }
    });
  }
}
