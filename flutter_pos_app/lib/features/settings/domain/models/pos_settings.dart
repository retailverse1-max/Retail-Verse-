import 'dart:convert';

import '../../../../core/utils/num_parse.dart';

/// Serializable POS / shop preferences. Persisted locally; map to API later via [toJson].
class PosSettings {
  const PosSettings({
    // Business
    required this.storeName,
    required this.storeAddress,
    required this.storePhone,
    required this.gstTaxId,
    required this.currencyCode,
    required this.timeZone,
    required this.businessLogoPath,
    // POS
    required this.barcodeScannerEnabled,
    required this.soundOnBilling,
    required this.orderConfirmationPopup,
    required this.receiptSize,
    required this.defaultPaymentMethod,
    required this.discountEnabled,
    required this.taxEnabled,
    required this.lowStockAlertsPos,
    // Billing
    required this.invoicePrefix,
    required this.autoInvoiceNumber,
    required this.showTaxOnBill,
    required this.showShopLogoOnInvoice,
    required this.invoiceFooterNote,
    required this.printReceipt,
    required this.shareDigitalReceipt,
    // Inventory
    required this.lowStockThreshold,
    required this.stockTrackingEnabled,
    required this.allowNegativeStock,
    required this.autoSyncInventory,
    // Notifications
    required this.notifyOrderSuccess,
    required this.notifyLowStock,
    required this.notifyDailySales,
    required this.notifySyncFailure,
    // Sync meta (last sync is updated by app actions)
    required this.lastSyncAtIso,
    required this.autoSyncEnabled,
    required this.offlineModeHintSeen,
    // Security
    required this.appLockEnabled,
    required this.pinConfigured,
    required this.biometricLoginEnabled,
    required this.autoLogoutMinutes,
    required this.sessionManagementEnabled,
    // Theme / app
    required this.darkMode,
    required this.languageCode,
    required this.fontScale,
  });

  final String storeName;
  final String storeAddress;
  final String storePhone;
  final String gstTaxId;
  final String currencyCode;
  final String timeZone;
  final String businessLogoPath;

  final bool barcodeScannerEnabled;
  final bool soundOnBilling;
  final bool orderConfirmationPopup;
  /// `58mm` | `80mm` | `a4`
  final String receiptSize;
  final String defaultPaymentMethod;
  final bool discountEnabled;
  final bool taxEnabled;
  final bool lowStockAlertsPos;

  final String invoicePrefix;
  final bool autoInvoiceNumber;
  final bool showTaxOnBill;
  final bool showShopLogoOnInvoice;
  final String invoiceFooterNote;
  final bool printReceipt;
  final bool shareDigitalReceipt;

  final int lowStockThreshold;
  final bool stockTrackingEnabled;
  final bool allowNegativeStock;
  final bool autoSyncInventory;

  final bool notifyOrderSuccess;
  final bool notifyLowStock;
  final bool notifyDailySales;
  final bool notifySyncFailure;

  final String? lastSyncAtIso;
  final bool autoSyncEnabled;
  final bool offlineModeHintSeen;

  final bool appLockEnabled;
  final bool pinConfigured;
  final bool biometricLoginEnabled;
  final int autoLogoutMinutes;
  final bool sessionManagementEnabled;

  final bool darkMode;
  final String languageCode;
  final double fontScale;

  static PosSettings defaults() => const PosSettings(
        storeName: 'My Store',
        storeAddress: '',
        storePhone: '',
        gstTaxId: '',
        currencyCode: 'INR',
        timeZone: 'Asia/Kolkata',
        businessLogoPath: '',
        barcodeScannerEnabled: true,
        soundOnBilling: true,
        orderConfirmationPopup: true,
        receiptSize: '80mm',
        defaultPaymentMethod: 'Cash',
        discountEnabled: true,
        taxEnabled: true,
        lowStockAlertsPos: true,
        invoicePrefix: 'INV',
        autoInvoiceNumber: true,
        showTaxOnBill: true,
        showShopLogoOnInvoice: true,
        invoiceFooterNote: 'Thank you for your business.',
        printReceipt: true,
        shareDigitalReceipt: true,
        lowStockThreshold: 10,
        stockTrackingEnabled: true,
        allowNegativeStock: false,
        autoSyncInventory: true,
        notifyOrderSuccess: true,
        notifyLowStock: true,
        notifyDailySales: false,
        notifySyncFailure: true,
        lastSyncAtIso: null,
        autoSyncEnabled: true,
        offlineModeHintSeen: false,
        appLockEnabled: false,
        pinConfigured: false,
        biometricLoginEnabled: false,
        autoLogoutMinutes: 30,
        sessionManagementEnabled: true,
        darkMode: false,
        languageCode: 'en',
        fontScale: 1.0,
      );

  PosSettings copyWith({
    String? storeName,
    String? storeAddress,
    String? storePhone,
    String? gstTaxId,
    String? currencyCode,
    String? timeZone,
    String? businessLogoPath,
    bool? barcodeScannerEnabled,
    bool? soundOnBilling,
    bool? orderConfirmationPopup,
    String? receiptSize,
    String? defaultPaymentMethod,
    bool? discountEnabled,
    bool? taxEnabled,
    bool? lowStockAlertsPos,
    String? invoicePrefix,
    bool? autoInvoiceNumber,
    bool? showTaxOnBill,
    bool? showShopLogoOnInvoice,
    String? invoiceFooterNote,
    bool? printReceipt,
    bool? shareDigitalReceipt,
    int? lowStockThreshold,
    bool? stockTrackingEnabled,
    bool? allowNegativeStock,
    bool? autoSyncInventory,
    bool? notifyOrderSuccess,
    bool? notifyLowStock,
    bool? notifyDailySales,
    bool? notifySyncFailure,
    String? lastSyncAtIso,
    bool? autoSyncEnabled,
    bool? offlineModeHintSeen,
    bool? appLockEnabled,
    bool? pinConfigured,
    bool? biometricLoginEnabled,
    int? autoLogoutMinutes,
    bool? sessionManagementEnabled,
    bool? darkMode,
    String? languageCode,
    double? fontScale,
  }) {
    return PosSettings(
      storeName: storeName ?? this.storeName,
      storeAddress: storeAddress ?? this.storeAddress,
      storePhone: storePhone ?? this.storePhone,
      gstTaxId: gstTaxId ?? this.gstTaxId,
      currencyCode: currencyCode ?? this.currencyCode,
      timeZone: timeZone ?? this.timeZone,
      businessLogoPath: businessLogoPath ?? this.businessLogoPath,
      barcodeScannerEnabled: barcodeScannerEnabled ?? this.barcodeScannerEnabled,
      soundOnBilling: soundOnBilling ?? this.soundOnBilling,
      orderConfirmationPopup:
          orderConfirmationPopup ?? this.orderConfirmationPopup,
      receiptSize: receiptSize ?? this.receiptSize,
      defaultPaymentMethod: defaultPaymentMethod ?? this.defaultPaymentMethod,
      discountEnabled: discountEnabled ?? this.discountEnabled,
      taxEnabled: taxEnabled ?? this.taxEnabled,
      lowStockAlertsPos: lowStockAlertsPos ?? this.lowStockAlertsPos,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      autoInvoiceNumber: autoInvoiceNumber ?? this.autoInvoiceNumber,
      showTaxOnBill: showTaxOnBill ?? this.showTaxOnBill,
      showShopLogoOnInvoice:
          showShopLogoOnInvoice ?? this.showShopLogoOnInvoice,
      invoiceFooterNote: invoiceFooterNote ?? this.invoiceFooterNote,
      printReceipt: printReceipt ?? this.printReceipt,
      shareDigitalReceipt: shareDigitalReceipt ?? this.shareDigitalReceipt,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      stockTrackingEnabled: stockTrackingEnabled ?? this.stockTrackingEnabled,
      allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
      autoSyncInventory: autoSyncInventory ?? this.autoSyncInventory,
      notifyOrderSuccess: notifyOrderSuccess ?? this.notifyOrderSuccess,
      notifyLowStock: notifyLowStock ?? this.notifyLowStock,
      notifyDailySales: notifyDailySales ?? this.notifyDailySales,
      notifySyncFailure: notifySyncFailure ?? this.notifySyncFailure,
      lastSyncAtIso: lastSyncAtIso ?? this.lastSyncAtIso,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      offlineModeHintSeen: offlineModeHintSeen ?? this.offlineModeHintSeen,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      pinConfigured: pinConfigured ?? this.pinConfigured,
      biometricLoginEnabled:
          biometricLoginEnabled ?? this.biometricLoginEnabled,
      autoLogoutMinutes: autoLogoutMinutes ?? this.autoLogoutMinutes,
      sessionManagementEnabled:
          sessionManagementEnabled ?? this.sessionManagementEnabled,
      darkMode: darkMode ?? this.darkMode,
      languageCode: languageCode ?? this.languageCode,
      fontScale: fontScale ?? this.fontScale,
    );
  }

  Map<String, dynamic> toJson() => {
        'storeName': storeName,
        'storeAddress': storeAddress,
        'storePhone': storePhone,
        'gstTaxId': gstTaxId,
        'currencyCode': currencyCode,
        'timeZone': timeZone,
        'businessLogoPath': businessLogoPath,
        'barcodeScannerEnabled': barcodeScannerEnabled,
        'soundOnBilling': soundOnBilling,
        'orderConfirmationPopup': orderConfirmationPopup,
        'receiptSize': receiptSize,
        'defaultPaymentMethod': defaultPaymentMethod,
        'discountEnabled': discountEnabled,
        'taxEnabled': taxEnabled,
        'lowStockAlertsPos': lowStockAlertsPos,
        'invoicePrefix': invoicePrefix,
        'autoInvoiceNumber': autoInvoiceNumber,
        'showTaxOnBill': showTaxOnBill,
        'showShopLogoOnInvoice': showShopLogoOnInvoice,
        'invoiceFooterNote': invoiceFooterNote,
        'printReceipt': printReceipt,
        'shareDigitalReceipt': shareDigitalReceipt,
        'lowStockThreshold': lowStockThreshold,
        'stockTrackingEnabled': stockTrackingEnabled,
        'allowNegativeStock': allowNegativeStock,
        'autoSyncInventory': autoSyncInventory,
        'notifyOrderSuccess': notifyOrderSuccess,
        'notifyLowStock': notifyLowStock,
        'notifyDailySales': notifyDailySales,
        'notifySyncFailure': notifySyncFailure,
        'lastSyncAtIso': lastSyncAtIso,
        'autoSyncEnabled': autoSyncEnabled,
        'offlineModeHintSeen': offlineModeHintSeen,
        'appLockEnabled': appLockEnabled,
        'pinConfigured': pinConfigured,
        'biometricLoginEnabled': biometricLoginEnabled,
        'autoLogoutMinutes': autoLogoutMinutes,
        'sessionManagementEnabled': sessionManagementEnabled,
        'darkMode': darkMode,
        'languageCode': languageCode,
        'fontScale': fontScale,
      };

  factory PosSettings.fromJson(Map<String, dynamic> j) {
    PosSettings d() => PosSettings.defaults();
    final def = d();
    return PosSettings(
      storeName: j['storeName'] as String? ?? def.storeName,
      storeAddress: j['storeAddress'] as String? ?? def.storeAddress,
      storePhone: j['storePhone'] as String? ?? def.storePhone,
      gstTaxId: j['gstTaxId'] as String? ?? def.gstTaxId,
      currencyCode: j['currencyCode'] as String? ?? def.currencyCode,
      timeZone: j['timeZone'] as String? ?? def.timeZone,
      businessLogoPath:
          j['businessLogoPath'] as String? ?? def.businessLogoPath,
      barcodeScannerEnabled:
          j['barcodeScannerEnabled'] as bool? ?? def.barcodeScannerEnabled,
      soundOnBilling: j['soundOnBilling'] as bool? ?? def.soundOnBilling,
      orderConfirmationPopup:
          j['orderConfirmationPopup'] as bool? ?? def.orderConfirmationPopup,
      receiptSize: j['receiptSize'] as String? ?? def.receiptSize,
      defaultPaymentMethod:
          j['defaultPaymentMethod'] as String? ?? def.defaultPaymentMethod,
      discountEnabled: j['discountEnabled'] as bool? ?? def.discountEnabled,
      taxEnabled: j['taxEnabled'] as bool? ?? def.taxEnabled,
      lowStockAlertsPos:
          j['lowStockAlertsPos'] as bool? ?? def.lowStockAlertsPos,
      invoicePrefix: j['invoicePrefix'] as String? ?? def.invoicePrefix,
      autoInvoiceNumber:
          j['autoInvoiceNumber'] as bool? ?? def.autoInvoiceNumber,
      showTaxOnBill: j['showTaxOnBill'] as bool? ?? def.showTaxOnBill,
      showShopLogoOnInvoice:
          j['showShopLogoOnInvoice'] as bool? ?? def.showShopLogoOnInvoice,
      invoiceFooterNote:
          j['invoiceFooterNote'] as String? ?? def.invoiceFooterNote,
      printReceipt: j['printReceipt'] as bool? ?? def.printReceipt,
      shareDigitalReceipt:
          j['shareDigitalReceipt'] as bool? ?? def.shareDigitalReceipt,
      lowStockThreshold:
          (j['lowStockThreshold'] as num?)?.toInt() ?? def.lowStockThreshold,
      stockTrackingEnabled:
          j['stockTrackingEnabled'] as bool? ?? def.stockTrackingEnabled,
      allowNegativeStock:
          j['allowNegativeStock'] as bool? ?? def.allowNegativeStock,
      autoSyncInventory:
          j['autoSyncInventory'] as bool? ?? def.autoSyncInventory,
      notifyOrderSuccess:
          j['notifyOrderSuccess'] as bool? ?? def.notifyOrderSuccess,
      notifyLowStock: j['notifyLowStock'] as bool? ?? def.notifyLowStock,
      notifyDailySales:
          j['notifyDailySales'] as bool? ?? def.notifyDailySales,
      notifySyncFailure:
          j['notifySyncFailure'] as bool? ?? def.notifySyncFailure,
      lastSyncAtIso: j['lastSyncAtIso'] as String?,
      autoSyncEnabled: j['autoSyncEnabled'] as bool? ?? def.autoSyncEnabled,
      offlineModeHintSeen:
          j['offlineModeHintSeen'] as bool? ?? def.offlineModeHintSeen,
      appLockEnabled: j['appLockEnabled'] as bool? ?? def.appLockEnabled,
      pinConfigured: j['pinConfigured'] as bool? ?? def.pinConfigured,
      biometricLoginEnabled:
          j['biometricLoginEnabled'] as bool? ?? def.biometricLoginEnabled,
      autoLogoutMinutes:
          (j['autoLogoutMinutes'] as num?)?.toInt() ?? def.autoLogoutMinutes,
      sessionManagementEnabled: j['sessionManagementEnabled'] as bool? ??
          def.sessionManagementEnabled,
      darkMode: j['darkMode'] as bool? ?? def.darkMode,
      languageCode: j['languageCode'] as String? ?? def.languageCode,
      fontScale: parseDoubleLoose(j['fontScale'], def.fontScale).clamp(0.8, 2.0),
    );
  }

  static PosSettings decode(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return PosSettings.fromJson(map);
    } catch (_) {
      return PosSettings.defaults();
    }
  }

  String encode() => jsonEncode(toJson());
}
