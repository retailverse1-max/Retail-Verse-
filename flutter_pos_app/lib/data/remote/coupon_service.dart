import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_response_handler.dart';
import '../../core/services/session_service.dart';
import '../models/coupon_model.dart';

class CouponService {
  CouponService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Default promotional coupons available in store
  static final List<CouponModel> _defaultCoupons = [
    CouponModel(
      code: 'WELCOME100',
      description: 'Flat ₹100 OFF on orders of ₹1,000 and above',
      discountType: 'flat',
      discountValue: 100,
      minOrderAmount: 1000,
    ),
    CouponModel(
      code: 'SAVE300',
      description: 'Flat ₹300 OFF on orders of ₹3,000 and above',
      discountType: 'flat',
      discountValue: 300,
      minOrderAmount: 3000,
    ),
    CouponModel(
      code: 'SUPER10',
      description: '10% OFF on orders of ₹1,500 and above (Max ₹500)',
      discountType: 'percentage',
      discountValue: 10,
      maxDiscountAmount: 500,
      minOrderAmount: 1500,
    ),
  ];

  static List<CouponModel> _cachedCoupons = [];

  Future<String?> _token() => SessionService.getToken();

  /// Validate coupon code against backend, with graceful offline/catalog fallback
  Future<CouponValidationResult> validateCoupon({
    required String code,
    required double cartSubtotal,
    String? customerPhone,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      return CouponValidationResult(
        isValid: false,
        message: 'Please enter a coupon code.',
      );
    }

    try {
      final token = await _token();
      final res = await _client
          .post(
            ApiResponseHandler.uri(ApiEndpoints.validateCoupon),
            headers: ApiResponseHandler.jsonHeaders(token: token),
            body: jsonEncode({
              'code': cleanCode,
              'cartSubtotal': cartSubtotal,
              if (customerPhone != null && customerPhone.isNotEmpty)
                'customerPhone': customerPhone,
            }),
          )
          .timeout(const Duration(seconds: 4));

      // Successfully validated by backend
      if (res.statusCode == 200) {
        final decoded = ApiResponseHandler.decodeJsonResponse(
          res,
          action: 'validate coupon',
        );
        return CouponValidationResult.fromJson(
          Map<String, dynamic>.from(decoded as Map),
        );
      }

      // If backend returns 404 (endpoint not mounted yet on deployed server)
      // or server 500/502/503 or HTML error, fall back to built-in catalog validation
      final rawBody = res.body.toLowerCase();
      if (res.statusCode == 404 ||
          res.statusCode >= 500 ||
          rawBody.contains('not found') ||
          rawBody.contains('cannot post') ||
          rawBody.contains('<!doctype html>')) {
        debugPrint('⚠️ Remote coupon endpoint unavailable (${res.statusCode}). Validating from local catalog.');
        return _validateFromCatalog(cleanCode, cartSubtotal);
      }

      // Legitimate business response from backend (e.g. 400 Bad Request: specific coupon error)
      final decoded = ApiResponseHandler.decodeJsonResponse(
        res,
        action: 'validate coupon',
      );
      final msg = (decoded is Map && decoded['message'] != null)
          ? decoded['message'].toString()
          : 'Coupon "$cleanCode" is invalid or expired.';
      return CouponValidationResult(
        isValid: false,
        message: msg,
      );
    } catch (e) {
      debugPrint('⚠️ Remote coupon validation failed: $e. Falling back to local catalog.');
      return _validateFromCatalog(cleanCode, cartSubtotal);
    }
  }

  /// Validates a coupon using the active store offers and promotional catalog
  CouponValidationResult _validateFromCatalog(String cleanCode, double cartSubtotal) {
    // Combine defaults and any coupons loaded from server
    final pool = <String, CouponModel>{};
    for (final c in _defaultCoupons) {
      pool[c.code.toUpperCase()] = c;
    }
    for (final c in _cachedCoupons) {
      pool[c.code.toUpperCase()] = c;
    }

    CouponModel? matched = pool[cleanCode];

    // Support receipt reward slip coupons formatted like SAVE300-XXXX
    if (matched == null && cleanCode.startsWith('SAVE300-')) {
      matched = CouponModel(
        code: cleanCode,
        description: 'Flat ₹300 OFF on orders of ₹3,000 and above (Reward Slip)',
        discountType: 'flat',
        discountValue: 300,
        minOrderAmount: 3000,
      );
    }

    if (matched == null) {
      return CouponValidationResult(
        isValid: false,
        message: 'Coupon "$cleanCode" is invalid or expired.',
      );
    }

    if (cartSubtotal < matched.minOrderAmount) {
      final diff = matched.minOrderAmount - cartSubtotal;
      return CouponValidationResult(
        isValid: false,
        code: matched.code,
        minOrderAmount: matched.minOrderAmount,
        message:
            'Coupon "${matched.code}" requires a minimum order of ₹${matched.minOrderAmount.toStringAsFixed(0)} (Add ₹${diff.toStringAsFixed(0)} more to unlock).',
      );
    }

    double discount = 0.0;
    if (matched.discountType == 'percentage') {
      discount = (cartSubtotal * matched.discountValue) / 100;
      if (matched.maxDiscountAmount != null && matched.maxDiscountAmount! > 0) {
        discount = min(discount, matched.maxDiscountAmount!);
      }
    } else {
      discount = min(matched.discountValue, cartSubtotal);
    }

    return CouponValidationResult(
      isValid: true,
      code: matched.code,
      calculatedDiscount: discount,
      minOrderAmount: matched.minOrderAmount,
      description: matched.description,
      message: 'Coupon "${matched.code}" applied! You saved ₹${discount.toStringAsFixed(2)}.',
    );
  }

  /// Fetch currently active promotional coupons
  Future<List<CouponModel>> getActiveCoupons() async {
    try {
      final token = await _token();
      final res = await _client
          .get(
            ApiResponseHandler.uri(ApiEndpoints.activeCoupons),
            headers: ApiResponseHandler.jsonHeaders(token: token),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final decoded = ApiResponseHandler.decodeJsonResponse(
          res,
          action: 'get active coupons',
        );
        if (decoded is Map && decoded['coupons'] is List) {
          final list = decoded['coupons'] as List;
          final loaded = list
              .map((c) => CouponModel.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList();
          if (loaded.isNotEmpty) {
            _cachedCoupons = loaded;
            return loaded;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to fetch active coupons from remote: $e');
    }

    // Return default active coupons if offline or fetch failed
    _cachedCoupons = List.from(_defaultCoupons);
    return _cachedCoupons;
  }
}
