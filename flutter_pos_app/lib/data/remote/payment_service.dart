import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_response_handler.dart';
import '../../core/services/session_service.dart';

class PaymentService {
  PaymentService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String?> _token() => SessionService.getToken();

  Future<Map<String, dynamic>> createRazorpayOrder({
    required double amount,
    required String currency,
    required String receipt,
  }) async {
    final token = await _token();
    final res = await _client
        .post(
          ApiResponseHandler.uri(ApiEndpoints.razorpayCreateOrder),
          headers: ApiResponseHandler.jsonHeaders(token: token),
          body: jsonEncode({
            'amount': amount,
            'currency': currency,
            'receipt': receipt,
          }),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'create razorpay order',
    );
    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'create razorpay order',
        decodedBody: decoded,
      );
    }
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<Map<String, dynamic>> verifyRazorpayPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final token = await _token();
    final res = await _client
        .post(
          ApiResponseHandler.uri(ApiEndpoints.razorpayVerify),
          headers: ApiResponseHandler.jsonHeaders(token: token),
          body: jsonEncode({
            'razorpay_order_id': orderId,
            'razorpay_payment_id': paymentId,
            'razorpay_signature': signature,
          }),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = ApiResponseHandler.decodeJsonResponse(
      res,
      action: 'verify razorpay payment',
    );
    if (res.statusCode != 200) {
      throw ApiResponseHandler.errorFromResponse(
        res,
        action: 'verify razorpay payment',
        decodedBody: decoded,
      );
    }
    return Map<String, dynamic>.from(decoded as Map);
  }
}
