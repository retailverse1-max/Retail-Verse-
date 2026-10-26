import 'dart:io';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import 'package:retail_verse_pos/data/models/order_model.dart';
import 'package:retail_verse_pos/features/settings/domain/models/pos_settings.dart';
import 'package:retail_verse_pos/features/orders/utils/receipt_generator.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  static const String _prefKeyPrinterAddress = 'saved_thermal_printer_address';
  static const String _prefKeyPrinterName = 'saved_thermal_printer_name';

  /// Request Bluetooth permissions required on Android 12+ (API 31+) & older versions
  Future<bool> requestBluetoothPermissions() async {
    if (!Platform.isAndroid) return true;
    try {
      final statuses = await [
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.bluetooth,
        Permission.locationWhenInUse,
      ].request();

      final connectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? true;
      final btGranted = statuses[Permission.bluetooth]?.isGranted ?? true;
      return connectGranted || btGranted;
    } catch (e) {
      debugPrint('Bluetooth permission request failed: $e');
      return true;
    }
  }

  /// Get list of paired / bonded Bluetooth devices (requests permissions first)
  Future<List<BluetoothDevice>> getDevices() async {
    await requestBluetoothPermissions();
    try {
      final devices = await bluetooth.getBondedDevices();
      return devices;
    } on PlatformException catch (e) {
      debugPrint('Error getting bonded devices: $e');
      return [];
    } catch (e) {
      debugPrint('Error getting bonded devices: $e');
      return [];
    }
  }

  /// Check if bluetooth is currently connected (with fast timeout so UI never hangs)
  Future<bool> isConnected() async {
    try {
      final status = await bluetooth.isConnected.timeout(
        const Duration(milliseconds: 400),
        onTimeout: () => false,
      );
      return status == true;
    } catch (_) {
      return false;
    }
  }

  /// Get saved printer address from SharedPreferences
  Future<String?> getSavedPrinterAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefKeyPrinterAddress);
    } catch (_) {
      return null;
    }
  }

  /// Get saved printer name from SharedPreferences
  Future<String?> getSavedPrinterName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefKeyPrinterName);
    } catch (_) {
      return null;
    }
  }

  /// Save printer details to SharedPreferences
  Future<void> savePrinter(BluetoothDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (device.address != null) {
        await prefs.setString(_prefKeyPrinterAddress, device.address!);
      }
      if (device.name != null) {
        await prefs.setString(_prefKeyPrinterName, device.name!);
      }
    } catch (e) {
      debugPrint('Error saving printer: $e');
    }
  }

  /// Connect to a specific Bluetooth printer and save it as default
  Future<bool> connect(BluetoothDevice device) async {
    try {
      final alreadyConnected = await isConnected();
      if (alreadyConnected) {
        await savePrinter(device);
        return true;
      }
      await bluetooth.connect(device).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('Bluetooth connect timeout for ${device.name}');
          return null;
        },
      );
      final connected = await isConnected();
      if (connected) {
        await savePrinter(device);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error connecting to printer ${device.name}: $e');
      return false;
    }
  }

  /// Auto-connect to saved printer, or the only paired Bluetooth printer
  Future<bool> autoConnect() async {
    try {
      if (await isConnected()) {
        return true;
      }

      final devices = await getDevices().timeout(
        const Duration(seconds: 3),
        onTimeout: () => [],
      );
      if (devices.isEmpty) return false;

      // Check saved printer MAC address
      final savedAddress = await getSavedPrinterAddress();
      if (savedAddress != null && savedAddress.isNotEmpty) {
        final match = devices.where((d) => d.address == savedAddress).firstOrNull;
        if (match != null) {
          final connected = await connect(match);
          if (connected) return true;
        }
      }

      // If only one bonded device exists (common for thermal printers), auto-connect
      if (devices.length == 1) {
        return await connect(devices.first);
      }

      return false;
    } catch (e) {
      debugPrint('AutoConnect failed: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await bluetooth.disconnect();
    } catch (_) {}
  }

  /// Print image bytes directly to thermal printer
  Future<bool> printImageBytes(Uint8List bytes) async {
    if (!await isConnected()) {
      final connected = await autoConnect();
      if (!connected) return false;
    }
    try {
      await bluetooth.printImageBytes(bytes);
      return true;
    } catch (e) {
      debugPrint('Error printing image bytes: $e');
      return false;
    }
  }

  /// Prints barcode sticker directly to the thermal printer
  /// Prints barcode sticker directly to the thermal printer
  Future<bool> printBarcodeStickerDirect({
    required Uint8List pngBytes,
    int count = 1,
  }) async {
    if (!await isConnected()) {
      final connected = await autoConnect();
      if (!connected) return false;
    }

    try {
      for (int i = 0; i < count; i++) {
        await bluetooth.printImageBytes(pngBytes);
        await Future.delayed(const Duration(milliseconds: 150));
        await _safePrintNewLine();
        await Future.delayed(const Duration(milliseconds: 250));
      }
      await _safePrintNewLine();
      await _safePrintNewLine();
      return true;
    } catch (e) {
      debugPrint('Error printing barcode sticker: $e');
      return false;
    }
  }

  /// Print receipt as a high-resolution monochrome raster bitmap image.
  /// Works with 100% of Bluetooth thermal printers without code-page or unicode issues.
  Future<bool> printReceiptRaster({
    required Order order,
    PosSettings? settings,
  }) async {
    if (!await isConnected()) {
      final connected = await autoConnect();
      if (!connected) return false;
    }

    try {
      final pdfBytes = await ReceiptGenerator.generateReceiptPdf(
        order,
        settings: settings,
      );
      final rasterPages = Printing.raster(pdfBytes, pages: [0], dpi: 203);
      final firstPage = await rasterPages.first;
      final pngBytes = await firstPage.toPng();

      await bluetooth.printImageBytes(pngBytes);
      await _safePrintNewLine();
      await _safePrintNewLine();
      await _safePrintNewLine();
      if (settings?.receiptSize == '80mm') {
        try {
          await bluetooth.paperCut();
        } catch (_) {}
      }
      return true;
    } catch (e) {
      debugPrint('Error printing raster receipt: $e');
      return false;
    }
  }

  Future<void> _safePrintCustom(String message, int size, int align) async {
    try {
      // Replace multi-byte Rupee symbol with clean ASCII 'Rs.' so generic printers do not choke
      final sanitized = message.replaceAll('₹', 'Rs.');
      await bluetooth.printCustom(sanitized, size, align);
      await Future.delayed(const Duration(milliseconds: 25));
    } catch (e) {
      debugPrint('SafePrintCustom error: $e');
    }
  }

  Future<void> _safePrintLeftRight(String left, String right, int size) async {
    try {
      final sanitizedLeft = left.replaceAll('₹', 'Rs.');
      final sanitizedRight = right.replaceAll('₹', 'Rs.');
      await bluetooth.printLeftRight(sanitizedLeft, sanitizedRight, size);
      await Future.delayed(const Duration(milliseconds: 25));
    } catch (e) {
      debugPrint('SafePrintLeftRight error: $e');
    }
  }

  Future<void> _safePrintNewLine() async {
    try {
      await bluetooth.printNewLine();
      await Future.delayed(const Duration(milliseconds: 20));
    } catch (_) {}
  }

  /// Auto-print POS receipt upon order placement
  Future<bool> autoPrintReceipt(Order order, {PosSettings? settings, String? storeName}) async {
    try {
      final connected = await autoConnect();
      if (connected) {
        await printReceipt(order, settings: settings, storeName: storeName);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Auto-print receipt failed: $e');
      return false;
    }
  }

  /// Print full thermal receipt matching the real Indian retail supermarket format
  Future<void> printReceipt(
    Order order, {
    PosSettings? settings,
    String? storeName,
    Map<String, dynamic>? authUser,
  }) async {
    bool connected = await isConnected();
    if (!connected) {
      connected = await autoConnect();
      if (!connected) {
        throw Exception('Thermal printer not connected. Please pair and select printer.');
      }
    }

    // Resolve store header info
    String finalStoreName = (storeName != null && storeName.trim().isNotEmpty)
        ? storeName.trim().toUpperCase()
        : (settings?.storeName.trim().isNotEmpty ?? false)
            ? settings!.storeName.trim().toUpperCase()
            : (authUser?['businessName']?.toString().trim().toUpperCase() ??
               authUser?['storeName']?.toString().trim().toUpperCase() ??
               authUser?['name']?.toString().trim().toUpperCase() ??
               'RETAIL VERSE STORE');

    String? gstNumber = (settings?.gstTaxId.trim().isNotEmpty ?? false)
        ? settings!.gstTaxId.trim().toUpperCase()
        : (authUser?['gstin']?.toString().trim().toUpperCase() ??
           authUser?['gstNumber']?.toString().trim().toUpperCase());

    String? storeAddress = (settings?.storeAddress.trim().isNotEmpty ?? false)
        ? settings!.storeAddress.trim()
        : authUser?['address']?.toString().trim();

    String? storePhone = (settings?.storePhone.trim().isNotEmpty ?? false)
        ? settings!.storePhone.trim()
        : (authUser?['phone']?.toString().trim() ?? authUser?['mobile']?.toString().trim());

    final formattedDate = DateFormat('dd/MM/yy').format(order.dateTime);
    final formattedTime = DateFormat('HH:mm:ss').format(order.dateTime);
    final totalQty = order.items.fold<num>(0, (sum, it) => sum + it.quantity);
    final paymentMethod = order.paymentMethod.trim().toUpperCase();

    // 1. Store Header (Centered, bold/large)
    await _safePrintCustom(finalStoreName, 2, 1);

    if (gstNumber != null && gstNumber.isNotEmpty) {
      await _safePrintCustom("GSTIN-$gstNumber", 0, 1);
    }
    final fssai = authUser?['fssai']?.toString().trim() ?? authUser?['fssaiNumber']?.toString().trim();
    if (fssai != null && fssai.isNotEmpty) {
      await _safePrintCustom("FSSAI-$fssai", 0, 1);
    }

    if (storeAddress != null && storeAddress.isNotEmpty) {
      final addrLines = _wrapText(storeAddress, 32);
      for (final line in addrLines) {
        await _safePrintCustom(line, 0, 1);
      }
    }

    if (storePhone != null && storePhone.isNotEmpty) {
      await _safePrintCustom("Phone :$storePhone", 0, 1);
    }

    await _safePrintCustom("TAX INVOICE", 1, 1);
    await _safePrintCustom(paymentMethod.isEmpty ? "CASH" : paymentMethod, 1, 1);

    // 2. Order Metadata
    final billNoStr = "BILL NO.: ${order.orderId}";
    final dateStr = "DATE : $formattedDate";
    await _safePrintLeftRight(billNoStr, dateStr, 0);

    final timeStr = "TIME : $formattedTime";
    final cashierStr = "CASHIER : ${order.cashierName ?? 'Staff'}";
    await _safePrintLeftRight(timeStr, cashierStr, 0);

    if (order.customerName != null && order.customerName!.isNotEmpty) {
      await _safePrintCustom("Customer: ${order.customerName} (${order.customerPhone ?? ''})", 0, 0);
    }

    // 3. Items Table Header
    await _safePrintCustom("--------------------------------", 0, 1);
    await _safePrintLeftRight("S.N DESCRIPTION", "AMT.", 0);
    await _safePrintCustom("    QTY    MRP   OUR PRICE", 0, 0);
    await _safePrintCustom("--------------------------------", 0, 1);

    // 4. Item Rows
    int itemIndex = 1;
    for (var item in order.items) {
      final name = item.product.name.trim().toUpperCase();
      await _safePrintCustom("$itemIndex $name", 0, 0);

      final qtyStr = item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2);
      final priceStr = item.price.toStringAsFixed(2);
      final totalStr = item.total.toStringAsFixed(2);

      final leftDetails = "   $qtyStr x Rs.$priceStr";
      await _safePrintLeftRight(leftDetails, totalStr, 0);
      itemIndex++;
    }

    await _safePrintCustom("--------------------------------", 0, 1);

    // 5. Totals & Net Payable
    final totalQtyStr = "Total Qty.   $totalQty";
    final subtotalStr = "Subtotal  Rs.${order.subtotal.toStringAsFixed(2)}";
    await _safePrintLeftRight(totalQtyStr, subtotalStr, 0);

    if (order.discount > 0) {
      await _safePrintLeftRight("DISCOUNT", "-Rs.${order.discount.toStringAsFixed(2)}", 0);
    }
    if (order.tax > 0) {
      await _safePrintLeftRight("GST/TAX (INCL.)", "Rs.${order.tax.toStringAsFixed(2)}", 0);
    }

    // AMT TO PAY (Size 1 Bold)
    await _safePrintLeftRight("AMT TO PAY", "Rs.${order.total.toStringAsFixed(2)}", 1);

    // Amount in words
    final words = _numberToWords(order.total.round());
    await _safePrintCustom("($words)", 0, 0);

    // 6. Footer Notes
    await _safePrintCustom("** PRICES ARE INCLUSIVE OF GST **", 0, 1);
    await _safePrintCustom("** THANKS FOR YOUR KIND VISIT **", 0, 1);
    await _safePrintCustom("** FREE HOME DELIVERY **", 0, 1);
    await _safePrintCustom("** NO REFUND/NO REPLACEMENT **", 0, 1);

    if (settings != null && settings.invoiceFooterNote.trim().isNotEmpty) {
      await _safePrintCustom(settings.invoiceFooterNote.trim(), 0, 1);
    }

    // 7. Large Order ID at bottom
    await _safePrintNewLine();
    await _safePrintCustom(order.orderId, 1, 1);

    // 8. Feed paper safely (safe for all 58mm and 80mm printers)
    await _safePrintNewLine();
    await _safePrintNewLine();
    await _safePrintNewLine();
    if (settings?.receiptSize == '80mm') {
      try {
        await bluetooth.paperCut();
      } catch (_) {}
    }
  }

  /// Helper to wrap text for 58mm printer (usually 32 chars per line)
  List<String> _wrapText(String text, int maxChars) {
    List<String> lines = [];
    final words = text.split(' ');
    String current = '';
    for (final w in words) {
      if (current.isEmpty) {
        current = w;
      } else if (current.length + w.length + 1 <= maxChars) {
        current += ' $w';
      } else {
        lines.add(current);
        current = w;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines;
  }

  /// Helper to convert amount to Indian Rupee Words (e.g., "Rupees sixty Only")
  String _numberToWords(int number) {
    if (number == 0) return "Rupees Zero Only";

    final units = [
      "", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine",
      "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen",
      "Seventeen", "Eighteen", "Nineteen"
    ];

    final tens = [
      "", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"
    ];

    String convertLessThanThousand(int n) {
      if (n == 0) return "";
      if (n < 20) return units[n];
      if (n < 100) {
        final rem = n % 10;
        return "${tens[n ~/ 10]}${rem > 0 ? " ${units[rem]}" : ""}";
      }
      final rem = n % 100;
      return "${units[n ~/ 100]} Hundred${rem > 0 ? " and ${convertLessThanThousand(rem)}" : ""}";
    }

    int n = number;
    String result = "";

    if (n >= 10000000) {
      final crore = n ~/ 10000000;
      result += "${convertLessThanThousand(crore)} Crore ";
      n %= 10000000;
    }

    if (n >= 100000) {
      final lakh = n ~/ 100000;
      result += "${convertLessThanThousand(lakh)} Lakh ";
      n %= 100000;
    }

    if (n >= 1000) {
      final thousand = n ~/ 1000;
      result += "${convertLessThanThousand(thousand)} Thousand ";
      n %= 1000;
    }

    if (n > 0) {
      result += convertLessThanThousand(n);
    }

    return "Rupees ${result.trim()} Only";
  }
}
