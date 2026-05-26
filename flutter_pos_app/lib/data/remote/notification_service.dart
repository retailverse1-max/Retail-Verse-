import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:retail_verse_pos/data/models/order_model.dart';
import 'package:retail_verse_pos/core/constants/api_endpoints.dart';
import 'package:intl/intl.dart';

class NotificationService {
  Future<void> sendEmailInvoice({
    required String email,
    required Order order,
  }) async {
    try {
      final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(order.dateTime);
      
      String itemsHtml = '';
      for (var item in order.items) {
        itemsHtml += '''
          <tr>
            <td style="padding: 8px; border-bottom: 1px solid #ddd;">\${item.product.name}</td>
            <td style="padding: 8px; border-bottom: 1px solid #ddd; text-align: center;">\${item.quantity}</td>
            <td style="padding: 8px; border-bottom: 1px solid #ddd; text-align: right;">₹\${item.total.toStringAsFixed(2)}</td>
          </tr>
        ''';
      }

      final htmlContent = '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #333;">
          <h2 style="text-align: center; color: #163F6B;">RETAIL VERSE STORE</h2>
          <p style="text-align: center; color: #666;">Receipt / Tax Invoice</p>
          <hr style="border: 1px solid #eee;" />
          <p><strong>Order ID:</strong> \${order.orderId}</p>
          <p><strong>Date:</strong> \$formattedDate</p>
          <p><strong>Payment Method:</strong> \${order.paymentMethod.toUpperCase()}</p>
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
              \$itemsHtml
            </tbody>
          </table>
          <hr style="border: 1px solid #eee;" />
          <p style="text-align: right;"><strong>Subtotal:</strong> ₹\${order.subtotal.toStringAsFixed(2)}</p>
          \${order.discount > 0 ? '<p style="text-align: right; color: green;"><strong>Discount:</strong> -₹\${order.discount.toStringAsFixed(2)}</p>' : ''}
          \${order.tax > 0 ? '<p style="text-align: right;"><strong>Tax:</strong> ₹\${order.tax.toStringAsFixed(2)}</p>' : ''}
          <h3 style="text-align: right; color: #163F6B;">GRAND TOTAL: ₹\${order.total.toStringAsFixed(2)}</h3>
          <p style="text-align: center; margin-top: 30px; font-size: 12px; color: #999;">Thank you for shopping with Retail Verse!</p>
        </div>
      ''';

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final url = Uri.parse('\${ApiEndpoints.baseUrl}/api/notifications/email');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer \$token',
        },
        body: json.encode({
          'to': email,
          'subject': 'Your Receipt from Retail Verse (Order: \${order.orderId})',
          'htmlContent': htmlContent,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send email: \${response.body}');
      }
      debugPrint('📧 Email sent via Node backend successfully.');
    } catch (e) {
      debugPrint('❌ Error sending email: \$e');
      rethrow;
    }
  }

  Future<void> sendSmsInvoice({
    required String phone,
    required Order order,
  }) async {
    try {
      final formattedDate = DateFormat('dd MMM yyyy').format(order.dateTime);
      
      String smsBody = 'Retail Verse Receipt\\n';
      smsBody += 'Order: \${order.orderId}\\n';
      smsBody += 'Date: \$formattedDate\\n\\n';
      
      int maxItems = order.items.length > 3 ? 3 : order.items.length;
      for (int i = 0; i < maxItems; i++) {
        smsBody += '\${order.items[i].product.name} (x\${order.items[i].quantity})\\n';
      }
      if (order.items.length > 3) {
        smsBody += '...and \${order.items.length - 3} more items\\n';
      }
      
      smsBody += '\\nTotal: ₹\${order.total.toStringAsFixed(2)}\\n';
      smsBody += 'Thank you for shopping with us!';

      String toPhone = phone.trim();
      if (!toPhone.startsWith('+')) {
        toPhone = '+91\$toPhone'; // Assume India if no country code provided
      }

      // Try WhatsApp first
      final whatsappUrl = Uri.parse("whatsapp://send?phone=\$toPhone&text=\${Uri.encodeComponent(smsBody)}");
      
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl);
        debugPrint('📱 WhatsApp intent launched successfully.');
      } else {
        // Fallback to regular SMS
        final smsUrl = Uri.parse("sms:\$toPhone?body=\${Uri.encodeComponent(smsBody)}");
        if (await canLaunchUrl(smsUrl)) {
          await launchUrl(smsUrl);
          debugPrint('📱 SMS intent launched successfully.');
        } else {
          throw Exception('Could not launch WhatsApp or SMS. Please install WhatsApp or check your default messaging app.');
        }
      }
    } catch (e) {
      debugPrint('❌ Error sending SMS via URL Launcher: \$e');
      rethrow;
    }
  }
}
