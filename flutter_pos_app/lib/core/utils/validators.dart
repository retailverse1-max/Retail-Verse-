import '../constants/app_constants.dart';

/// Validation utilities for forms and user input
class AppValidators {
  AppValidators._();

  /// Validate email address
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(AppConstants.emailPattern);
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }

    return null;
  }

  /// Validate password
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 5) {
      return 'Password must be at least 5 characters';
    }

    return null;
  }

  /// Validate required field
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate phone number (Indian format)
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    final phoneRegex = RegExp(AppConstants.phonePattern);
    if (!phoneRegex.hasMatch(value.replaceAll(RegExp(r'[^0-9]'), ''))) {
      return 'Please enter a valid 10-digit phone number';
    }

    return null;
  }

  /// Validate quantity (positive integer)
  static String? validateQuantity(String? value) {
    if (value == null || value.isEmpty) {
      return 'Quantity is required';
    }

    final quantity = int.tryParse(value);
    if (quantity == null) {
      return 'Please enter a valid number';
    }

    if (quantity <= 0) {
      return 'Quantity must be greater than 0';
    }

    if (quantity > AppConstants.maxQuantityPerItem) {
      return 'Maximum quantity is $AppConstants.maxQuantityPerItem';
    }

    return null;
  }

  /// Validate price (positive decimal)
  static String? validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'Price is required';
    }

    final price = double.tryParse(value);
    if (price == null) {
      return 'Please enter a valid price';
    }

    if (price < 0) {
      return 'Price cannot be negative';
    }

    return null;
  }

  /// Validate discount percentage
  static String? validateDiscount(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }

    final discount = double.tryParse(value);
    if (discount == null) {
      return 'Please enter a valid number';
    }

    if (discount < 0) {
      return 'Discount cannot be negative';
    }

    if (discount > AppConstants.maxDiscountPercentage) {
      return 'Maximum discount is ${AppConstants.maxDiscountPercentage}%';
    }

    return null;
  }

  /// Validate stock adjustment quantity
  static String? validateStockAdjustment(String? value) {
    if (value == null || value.isEmpty) {
      return 'Quantity is required';
    }

    final quantity = int.tryParse(value);
    if (quantity == null) {
      return 'Please enter a valid number';
    }

    if (quantity <= 0) {
      return 'Quantity must be greater than 0';
    }

    return null;
  }

  /// Validate search query
  static String? validateSearchQuery(String? value) {
    if (value != null && value.length > 100) {
      return 'Search query is too long';
    }
    return null;
  }

  /// Check if string is numeric
  static bool isNumeric(String value) {
    return double.tryParse(value) != null;
  }

  /// Check if string is integer
  static bool isInteger(String value) {
    return int.tryParse(value) != null;
  }

  /// Validate date is not in future
  static String? validateDateNotInFuture(DateTime date, String fieldName) {
    if (date.isAfter(DateTime.now())) {
      return '$fieldName cannot be in the future';
    }
    return null;
  }

  /// Validate date range
  static String? validateDateRange(DateTime start, DateTime end) {
    if (start.isAfter(end)) {
      return 'Start date must be before end date';
    }
    return null;
  }
}
