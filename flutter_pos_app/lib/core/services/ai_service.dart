import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../constants/api_endpoints.dart';

/// Result model for AI scan
class AIScanResult {
  final String productName;
  final String description;
  final String? suggestedCategory;
  final List<String> tags;
  final double confidence;
  final double? priceEstimate;

  AIScanResult({
    required this.productName,
    required this.description,
    this.suggestedCategory,
    this.tags = const [],
    this.confidence = 0.0,
    this.priceEstimate,
  });

  factory AIScanResult.fromJson(Map<String, dynamic> json) {
    return AIScanResult(
      productName: json['name'] ?? 'Unknown Product',
      description: json['description'] ?? '',
      suggestedCategory: json['category'],
      tags: List<String>.from(json['tags'] ?? []),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      priceEstimate: json['priceEstimate'] != null
          ? (json['priceEstimate']).toDouble()
          : null,
    );
  }
}

/// AI Service for product image analysis
class AIService {
  AIService._();

  /// Analyze product image using real backend Gemini integration
  static Future<AIScanResult> analyzeProductImage({
    required File imageFile,
    String? categoryContext,
  }) async {
    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/ai/product-scan');
      final request = http.MultipartRequest('POST', uri);
      
      // Explicitly deduce file extension for MediaType to prevent generic application/octet-stream issues
      final fileExtension = imageFile.path.split('.').last.toLowerCase();
      String mimeSubtype = 'jpeg';
      if (fileExtension == 'png') {
        mimeSubtype = 'png';
      } else if (fileExtension == 'webp') {
        mimeSubtype = 'webp';
      } else if (fileExtension == 'gif') {
        mimeSubtype = 'gif';
      }
      
      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType('image', mimeSubtype),
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          throw Exception("Connection timeout while contacting AI service (Server might be waking up).");
        },
      );

      final response = await http.Response.fromStream(streamedResponse);
      final jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        return AIScanResult.fromJson(jsonResponse['data']);
      } else if (response.statusCode == 503) {
        throw Exception(jsonResponse['message'] ?? "AI service is not configured on the backend.");
      } else if (response.statusCode == 429) {
        throw Exception("AI rate limit exceeded. Please try again later.");
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to analyze image');
      }
    } on SocketException {
      throw Exception("No internet connection to reach AI service.");
    } catch (e) {
      debugPrint('❌ AI Scan Error: $e');
      rethrow;
    }
  }

  /// Extract text from image using OCR
  static Future<String?> extractTextFromImage({required File imageFile}) async {
    // TODO: Implement OCR integration
    debugPrint('OCR feature ready for integration');
    return null;
  }

  /// Suggest similar products based on image
  static Future<List<Map<String, dynamic>>> suggestSimilarProducts({
    required File imageFile,
  }) async {
    // TODO: Implement visual similarity search
    debugPrint('Similar product suggestion ready for integration');
    return [];
  }

  /// Validate image quality before upload
  static Future<bool> validateImageQuality({
    required File imageFile,
    double minResolution = 0.5, // MP
    double maxFileSize = 10.0, // MB
  }) async {
    try {
      final fileSize = await imageFile.length();
      final sizeInMB = fileSize / (1024 * 1024);

      if (sizeInMB > maxFileSize) {
        debugPrint('Image too large: ${sizeInMB.toStringAsFixed(2)}MB');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Image validation error: $e');
      return false;
    }
  }
}
