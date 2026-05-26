import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/api_endpoints.dart';
import 'api_exception.dart';

class ApiResponseHandler {
  ApiResponseHandler._();

  static Map<String, String> jsonHeaders({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
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
    return Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
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
      return jsonDecode(trimmedBody);
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
        'Unable to reach the backend at ${ApiEndpoints.baseUrl}.\n\n'
        '• Start the Node server on your PC (port 5000).\n'
        '• Phone and PC must be on the same Wi‑Fi.\n'
        '• In Settings → Sync & data, set API URL to your PC\'s current IP '
        '(run ipconfig on Windows or ifconfig / ip on Mac; it may differ from the default in the app).\n'
        '• Allow port 5000 through the PC firewall.\n'
        '• API base URL should be set to https://app-backend-je91.onrender.com/api.',
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
}
