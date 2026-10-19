import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:retail_verse_pos/data/models/order_model.dart';
import 'package:retail_verse_pos/core/constants/api_endpoints.dart';
import 'package:intl/intl.dart';

import 'package:retail_verse_pos/features/settings/domain/models/pos_settings.dart';

class NotificationService {
  Future<void> sendEmailInvoice({
    required String email,
    required Order order,
    PosSettings? settings,
  }) async {
    try {
      final storeTitle = (settings?.storeName.isNotEmpty ?? false)
          ? settings!.storeName
          : 'Retail Verse';
      final storeAddress = settings?.storeAddress ?? '';
      final gstTaxId = settings?.gstTaxId ?? '';
      final footerNote = (settings?.invoiceFooterNote.isNotEmpty ?? false)
          ? settings!.invoiceFooterNote
          : 'Thank you for your business!';

      final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(order.dateTime);
      
      String itemsHtml = '';
      for (var item in order.items) {
        itemsHtml += '''
          <tr>
            <td style="padding: 8px; border-bottom: 1px solid #ddd;">${item.product.name}</td>
            <td style="padding: 8px; border-bottom: 1px solid #ddd; text-align: center;">${item.quantity}</td>
            <td style="padding: 8px; border-bottom: 1px solid #ddd; text-align: right;">₹${item.total.toStringAsFixed(2)}</td>
          </tr>
        ''';
      }

      final hasRewardCoupon = (order.rewardCouponCode != null && order.rewardCouponCode!.isNotEmpty) ||
          order.subtotal >= 3000 ||
          order.total >= 3000;
      final rewardCode = (order.rewardCouponCode != null && order.rewardCouponCode!.isNotEmpty)
          ? order.rewardCouponCode!
          : 'SAVE300-${order.orderId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').substring(0, 4).toUpperCase()}';

      final rewardCouponHtml = hasRewardCoupon
          ? '''
          <div style="background-color: #FEF3C7; border: 2px dashed #F59E0B; border-radius: 10px; padding: 16px; margin: 20px 0; text-align: center;">
            <p style="margin: 0; color: #B45309; font-size: 13px; font-weight: bold; text-transform: uppercase;">🎉 Congratulations! You unlocked a Reward Coupon!</p>
            <div style="background-color: #92400E; color: #FFFFFF; font-family: monospace; font-size: 20px; font-weight: bold; letter-spacing: 2px; display: inline-block; padding: 6px 16px; border-radius: 6px; margin: 10px 0;">$rewardCode</div>
            <p style="margin: 0; color: #78350F; font-size: 13px; font-weight: bold;">Flat ₹300 OFF on your next order of ₹3,000 or more</p>
            <p style="margin: 4px 0 0 0; color: #92400E; font-size: 11px;">Valid for 30 days. Show this code at checkout on your next visit!</p>
          </div>
          '''
          : '';

      final htmlContent = '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #333;">
          <h2 style="text-align: center; color: #163F6B; margin-bottom: 4px;">$storeTitle</h2>
          ${storeAddress.isNotEmpty ? '<p style="text-align: center; color: #666; margin: 2px 0;">$storeAddress</p>' : ''}
          ${gstTaxId.isNotEmpty ? '<p style="text-align: center; color: #666; margin: 2px 0; font-size: 12px;"><strong>GSTIN:</strong> $gstTaxId</p>' : ''}
          <p style="text-align: center; color: #666; font-weight: bold; margin-top: 6px;">Tax Invoice</p>
          <hr style="border: 1px solid #eee;" />
          <p><strong>Order ID:</strong> ${order.orderId}</p>
          <p><strong>Date:</strong> $formattedDate</p>
          <p><strong>Payment Method:</strong> ${order.paymentMethod.toUpperCase()}</p>
          <hr style="border: 1px solid #eee;" />
          <table style="width: 100%; border-collapse: collapse;">
            <thead>
              <tr style="background-color: #f9f9f9;">
                <th style="padding: 8px; text-align: left;">Item</th>
                <th style="padding: 8px; text-align: center;">Qty</th>
                <th style="padding: 8px; text-align: right;">Total</th>
              </tr>
            </thead>
            <tbody>
              $itemsHtml
            </tbody>
          </table>
          <hr style="border: 1px solid #eee;" />
          <p style="text-align: right;"><strong>Subtotal:</strong> ₹${order.subtotal.toStringAsFixed(2)}</p>
          ${order.discount > 0 ? '<p style="text-align: right; color: green;"><strong>Discount:</strong> -₹${order.discount.toStringAsFixed(2)}</p>' : ''}
          ${order.tax > 0 ? '<p style="text-align: right;"><strong>Tax:</strong> ₹${order.tax.toStringAsFixed(2)}</p>' : ''}
          <h3 style="text-align: right; color: #163F6B;">GRAND TOTAL: ₹${order.total.toStringAsFixed(2)}</h3>
          $rewardCouponHtml
          <p style="text-align: center; margin-top: 30px; font-size: 12px; color: #777;">$footerNote</p>
        </div>
      ''';

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final url = Uri.parse('${ApiEndpoints.baseUrl}/notifications/email');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'to': email,
          'subject': 'Your Receipt & ₹300 Reward Coupon from $storeTitle (Order #${order.orderId})',
          'htmlContent': htmlContent,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send email: ${response.body}');
      }
      debugPrint('📧 Email sent via Node backend successfully.');
    } catch (e) {
      debugPrint('❌ Error sending email: $e');
      rethrow;
    }
  }

  Future<void> sendSmsInvoice({
    required String phone,
    required Order order,
  }) async {
    try {
      final formattedDate = DateFormat('dd MMM yyyy').format(order.dateTime);
      
      final hasRewardCoupon = (order.rewardCouponCode != null && order.rewardCouponCode!.isNotEmpty) ||
          order.subtotal >= 3000 ||
          order.total >= 3000;
      final rewardCode = (order.rewardCouponCode != null && order.rewardCouponCode!.isNotEmpty)
          ? order.rewardCouponCode!
          : 'SAVE300-${order.orderId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').substring(0, 4).toUpperCase()}';

      String smsBody = 'Retail Verse Receipt\n';
      smsBody += 'Order: ${order.orderId}\n';
      smsBody += 'Date: $formattedDate\n\n';
      
      int maxItems = order.items.length > 3 ? 3 : order.items.length;
      for (int i = 0; i < maxItems; i++) {
        smsBody += '${order.items[i].product.name} (x${order.items[i].quantity})\n';
      }
      if (order.items.length > 3) {
        smsBody += '...and ${order.items.length - 3} more items\n';
      }
      
      smsBody += '\nTotal: ₹${order.total.toStringAsFixed(2)}\n';
      if (hasRewardCoupon) {
        smsBody += '\n🎁 YOU UNLOCKED ₹300 REWARD COUPON!\nCode: $rewardCode\nFlat ₹300 OFF on next shopping of ₹3,000+ (Valid 30 days)\n';
      }
      smsBody += 'Thank you for shopping with us!';

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final url = Uri.parse('${ApiEndpoints.baseUrl}/notifications/sms');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'phone': phone,
          'content': smsBody,
        }),
      );

      if (response.statusCode != 200) {
        final errorMsg = json.decode(response.body)['message'] ?? 'Unknown error';
        throw Exception('Failed to send SMS via backend: $errorMsg');
      }
      debugPrint('📱 SMS sent via Node backend successfully.');
    } catch (e) {
      debugPrint('❌ Error sending SMS: $e');
      rethrow;
    }
  }
}
