/// Application-wide constants for Retail Verse
class AppConstants {
  AppConstants._();

  // App Information
  static const String appName = 'Retail Verse';
  static const String appVersion = '1.0.0';
  static const String appSubtitle = 'Retail Verse - Professional Billing';

  /// Primary brand logo (see `pubspec.yaml` assets)
  static const String logoAsset = 'assets/images/logopos.png';

  // Session & Auth
  static const String authTokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const int sessionTimeoutMinutes = 30;

  // Pagination
  static const int defaultPageSize = 20;
  static const int ordersPageSize = 15;
  static const int productsPageSize = 30;

  // Tax Configuration (default)
  static const double defaultTaxRate = 0.18; // 18% GST

  // Low Stock Threshold
  static const int defaultLowStockThreshold = 10;

  // Date Formats
  static const String dateFormat = 'dd MMM yyyy';
  static const String timeFormat = 'hh:mm a';
  static const String dateTimeFormat = 'dd MMM yyyy, hh:mm a';

  // Currency
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';

  // Animation Durations (milliseconds)
  static const int splashDuration = 1500;
  static const int fadeDuration = 300;
  static const int dialogDuration = 250;
  static const int snackbarDuration = 3000;

  // Breakpoints (in pixels)
  static const double tabletBreakpoint = 600.0;
  static const double desktopBreakpoint = 1024.0;

  // Cache Duration
  static const int cacheDurationHours = 24;

  // API Timeout (for future use)
  static const int apiTimeoutSeconds = 30;

  // Image Cache
  static const int imageCacheSize = 100;
  static const int imageCacheSizeBytes = 50 * 1024 * 1024; // 50MB

  // Validation Patterns
  static const String emailPattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
  static const String phonePattern = r'^[0-9]{10}$';

  // Order Statuses
  static const String orderStatusPending = 'Pending';
  static const String orderStatusCompleted = 'Completed';
  static const String orderStatusCancelled = 'Cancelled';

  // Payment Methods
  static const String paymentMethodCash = 'Cash';
  static const String paymentMethodCard = 'Card';
  static const String paymentMethodUPI = 'UPI';

  // Stock Adjustment Reasons
  static const List<String> stockAdjustmentReasons = [
    'Damaged',
    'Expired',
    'Return',
    'Found',
    'Restock',
    'Other',
  ];

  // Categories (sample for mock data)
  static const List<String> productCategories = [
    'Groceries',
    'Beverages',
    'Dairy',
    'Snacks',
    'Household',
    'Personal Care',
    'Frozen Foods',
    'Bakery',
  ];

  // Dashboard Stats Refresh Interval (ms)
  static const int statsRefreshInterval = 60000; // 1 minute

  // Search Debounce Delay (ms)
  static const int searchDebounceDelay = 300;

  // Cart Limits
  static const int maxCartItems = 100;
  static const int maxQuantityPerItem = 99;

  // Discount Limits
  static const double maxDiscountPercentage = 50.0;
}
