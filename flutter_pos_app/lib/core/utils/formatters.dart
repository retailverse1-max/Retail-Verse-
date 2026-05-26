import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

/// Formatting utilities for currency, dates, and numbers
class AppFormatters {
  AppFormatters._();

  /// Currency formatter for Indian Rupee
  static String formatCurrency(double amount) {
    final a = amount.isFinite ? amount : 0.0;
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: AppConstants.currencySymbol,
      decimalDigits: 2,
    );
    return formatter.format(a);
  }

  /// Format date as dd MMM yyyy
  static String formatDate(DateTime date) {
    return DateFormat(AppConstants.dateFormat).format(date);
  }

  /// Format time as hh:mm a
  static String formatTime(DateTime time) {
    return DateFormat(AppConstants.timeFormat).format(time);
  }

  /// Format datetime as dd MMM yyyy, hh:mm a
  static String formatDateTime(DateTime dateTime) {
    return DateFormat(AppConstants.dateTimeFormat).format(dateTime);
  }

  /// Format relative time (Today, Yesterday, etc.)
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return formatDate(dateTime);
    }
  }

  /// Format number with commas (e.g., 1,234,567)
  static String formatNumber(int number) {
    final formatter = NumberFormat('#,##,###');
    return formatter.format(number);
  }

  /// Format percentage
  static String formatPercentage(double value, {int decimalPlaces = 0}) {
    return '${value.toStringAsFixed(decimalPlaces)}%';
  }

  /// Parse string to double safely
  static double? parseToDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return double.tryParse(value);
    } catch (e) {
      return null;
    }
  }

  /// Parse string to int safely
  static int? parseToInt(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return int.tryParse(value);
    } catch (e) {
      return null;
    }
  }

  /// Format quantity with unit
  static String formatQuantity(int quantity, String unit) {
    return '$quantity $unit${quantity > 1 ? 's' : ''}';
  }

  /// Format order ID (add leading zeros)
  static String formatOrderId(String orderId) {
    // Remove any prefix like "ORD-"
    final cleanId = orderId.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanId.length >= 6) {
      return '#${cleanId.substring(cleanId.length - 6)}';
    }
    return '#${cleanId.padLeft(6, '0')}';
  }

  /// Format SKU for display
  static String formatSKU(String sku) {
    return sku.toUpperCase();
  }

  /// Truncate text with ellipsis
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Format phone number (Indian format)
  static String formatPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length == 10) {
      return '+91 ${cleaned.substring(0, 5)} ${cleaned.substring(5)}';
    }
    return phone;
  }

  /// Calculate age from birthdate
  static int calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }
}
