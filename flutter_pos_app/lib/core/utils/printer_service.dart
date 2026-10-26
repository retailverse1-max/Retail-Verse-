import 'dart:io';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
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
  String? _connectedEngine; // 'blue' or 'thermal'

  static const String _prefKeyPrinterAddress = 'saved_thermal_printer_address';
  static const String _prefKeyPrinterName = 'saved_thermal_printer_name';
  static const String defaultBillplusMac = '02:2D:36:C9:4E:A9';
  static const String defaultBillplusName = 'billplus 617';

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
    final List<BluetoothDevice> devices = [];
    try {
      await requestBluetoothPermissions().timeout(
        const Duration(seconds: 4),
        onTimeout: () => false,
      );
    } catch (_) {}

    // 1. Get bonded devices from BlueThermalPrinter
    try {
      final bonded = await bluetooth.getBondedDevices().timeout(
        const Duration(seconds: 4),
        onTimeout: () => [],
      );
      for (final d in bonded) {
        if (d.address != null && !devices.any((x) => x.address?.toLowerCase() == d.address!.toLowerCase())) {
          devices.add(d);
        }
      }
    } on PlatformException catch (e) {
      debugPrint('PlatformException getting bonded devices: $e');
    } catch (e) {
      debugPrint('Error getting bonded devices: $e');
    }

    // 2. Query PrintBluetoothThermal paired list
    try {
      final thermalPaired = await PrintBluetoothThermal.pairedBluetooths;
      for (final p in thermalPaired) {
        if (!devices.any((x) => x.address?.toLowerCase() == p.macAdress.toLowerCase())) {
          devices.add(BluetoothDevice(p.name, p.macAdress));
        }
      }
    } catch (e) {
      debugPrint('Error getting PrintBluetoothThermal paired devices: $e');
    }

    // 3. Always include saved printer or Billplus 617 printer in the list
    final savedAddress = await getSavedPrinterAddress();
    final savedName = await getSavedPrinterName();

    if (savedAddress != null && savedAddress.isNotEmpty) {
      if (!devices.any((d) => d.address?.toLowerCase() == savedAddress.toLowerCase())) {
        devices.insert(0, BluetoothDevice(savedName ?? defaultBillplusName, savedAddress));
      }
    }

    // Always ensure Billplus 617 is present
    if (!devices.any((d) => d.address?.toLowerCase() == defaultBillplusMac.toLowerCase())) {
      devices.insert(0, BluetoothDevice(defaultBillplusName, defaultBillplusMac));
    }

    return devices;
  }

  /// Check if bluetooth is currently connected (checks both engines)
  Future<bool> isConnected() async {
    try {
      final status = await bluetooth.isConnected.timeout(
        const Duration(milliseconds: 400),
        onTimeout: () => false,
      );
      if (status == true) {
        _connectedEngine = 'blue';
        return true;
      }
    } catch (_) {}

    try {
      final thermalStatus = await PrintBluetoothThermal.connectionStatus;
      if (thermalStatus == true) {
        _connectedEngine = 'thermal';
        return true;
      }
    } catch (_) {}

    _connectedEngine = null;
    return false;
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

  /// Connect to a specific Bluetooth printer (with dual-engine fallback)
  Future<bool> connect(BluetoothDevice device) async {
    debugPrint('Connecting to printer: ${device.name} (${device.address})');
    await disconnect();

    // 1. Try primary blue_thermal_printer engine
    try {
      await bluetooth.connect(device).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('Bluetooth connect timeout for ${device.name}');
          return null;
        },
      );
      if (await bluetooth.isConnected == true) {
        _connectedEngine = 'blue';
        await savePrinter(device);
        debugPrint('Connected via BlueThermalPrinter!');
        return true;
      }
    } catch (e) {
      debugPrint('Error connecting via BlueThermalPrinter: $e');
    }

    // 2. Fallback to PrintBluetoothThermal (direct RFCOMM by MAC)
    if (device.address != null && device.address!.isNotEmpty) {
      try {
        final ok = await PrintBluetoothThermal.connect(macPrinterAddress: device.address!);
        if (ok) {
          _connectedEngine = 'thermal';
          await savePrinter(device);
          debugPrint('Connected via PrintBluetoothThermal!');
          return true;
        }
      } catch (e) {
        debugPrint('Error connecting via PrintBluetoothThermal: $e');
      }
    }

    return false;
  }

  /// Auto-connect to saved printer, or any paired thermal printer
  Future<bool> autoConnect() async {
    try {
      if (await isConnected()) {
        return true;
      }

      final devices = await getDevices();
      if (devices.isEmpty) return false;

      // 1. Check saved printer MAC address
      final savedAddress = await getSavedPrinterAddress();
      if (savedAddress != null && savedAddress.isNotEmpty) {
        final match = devices.where((d) => d.address == savedAddress).firstOrNull;
        if (match != null) {
          final connected = await connect(match);
          if (connected) return true;
        }
      }

      // 2. Smart auto-detect: find any paired device matching known thermal printer keywords
      const printerKeywords = [
        'billplus',
        'printer',
        'pos',
        'mpt',
        'mtp',
        'rpp',
        'thermal',
        '58',
        '80',
        'zj',
        'xp',
        'innerprinter',
        'bt-',
        'bluetooth printer'
      ];
      final candidate = devices.where((d) {
        final name = (d.name ?? '').toLowerCase();
        return printerKeywords.any((kw) => name.contains(kw));
      }).firstOrNull;

      if (candidate != null) {
        final connected = await connect(candidate);
        if (connected) return true;
      }

      // 3. Fallback: Try each paired device (so even unlisted names/MAC addresses connect)
      for (final dev in devices) {
        final connected = await connect(dev);
        if (connected) return true;
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
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}
    _connectedEngine = null;
  }

  /// Print a simple test slip to verify printer connection
  Future<bool> printTestReceipt() async {
    if (!await isConnected()) {
      final connected = await autoConnect();
      if (!connected) return false;
    }
    try {
      await _safePrintCustom('================================', 0, 1);
      await _safePrintCustom('RETAIL VERSE POS', 2, 1);
      await _safePrintCustom('PRINTER TEST SUCCESS', 1, 1);
      await _safePrintCustom('================================', 0, 1);
      await _safePrintLeftRight('Printer Status:', 'ONLINE', 0);
      final savedName = await getSavedPrinterName();
      if (savedName != null) {
        await _safePrintLeftRight('Device:', savedName, 0);
      }
      await _safePrintCustom('Ready for Bills & Stickers', 0, 1);
      await _safePrintCustom('================================', 0, 1);
      await _safePrintNewLine();
      await _safePrintNewLine();
      return true;
    } catch (e) {
      debugPrint('Error printing test receipt: $e');
      return false;
    }
  }

  /// Print image bytes directly to thermal printer
  Future<bool> printImageBytes(Uint8List bytes) async {
    if (!await isConnected()) {
      final connected = await autoConnect();
      if (!connected) return false;
    }

    if (_connectedEngine == 'thermal' || await PrintBluetoothThermal.connectionStatus) {
      try {
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final profile = await CapabilityProfile.load();
          final generator = Generator(PaperSize.mm58, profile);
          final escBytes = generator.imageRaster(decoded);
          await PrintBluetoothThermal.writeBytes(escBytes);
          return true;
        }
      } catch (e) {
        debugPrint('Thermal printImageBytes error: $e');
      }
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
        await printImageBytes(pngBytes);
        await Future.delayed(const Duration(milliseconds: 100));
        await _safePrintNewLine();
        await Future.delayed(const Duration(milliseconds: 100));
      }
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

      await printImageBytes(pngBytes);
      await _safePrintNewLine();
      await _safePrintNewLine();
      await _safePrintNewLine();
      if (settings?.receiptSize == '80mm') {
        try {
          if (_connectedEngine == 'thermal') {
            final profile = await CapabilityProfile.load();
            final generator = Generator(PaperSize.mm80, profile);
            await PrintBluetoothThermal.writeBytes(generator.cut());
          } else {
            await bluetooth.paperCut();
          }
        } catch (_) {}
      }
      return true;
    } catch (e) {
      debugPrint('Error printing raster receipt: $e');
      return false;
    }
  }

  Future<void> _safePrintCustom(String message, int size, int align) async {
    final sanitized = message.replaceAll('₹', 'Rs.');
    if (_connectedEngine == 'thermal' || await PrintBluetoothThermal.connectionStatus) {
      try {
        final profile = await CapabilityProfile.load();
        final generator = Generator(PaperSize.mm58, profile);
        PosAlign posAlign = PosAlign.left;
        if (align == 1) posAlign = PosAlign.center;
        if (align == 2) posAlign = PosAlign.right;
        PosTextSize textSize = PosTextSize.size1;
        if (size == 1) textSize = PosTextSize.size2;
        if (size >= 2) textSize = PosTextSize.size3;
        final bytes = generator.text(
          sanitized,
          styles: PosStyles(align: posAlign, height: textSize, width: textSize),
        );
        await PrintBluetoothThermal.writeBytes(bytes);
        return;
      } catch (e) {
        debugPrint('SafePrintCustom thermal error: $e');
      }
    }

    try {
      await bluetooth.printCustom(sanitized, size, align);
      await Future.delayed(const Duration(milliseconds: 25));
    } catch (e) {
      debugPrint('SafePrintCustom error: $e');
    }
  }

  Future<void> _safePrintLeftRight(String left, String right, int size) async {
    final sanitizedLeft = left.replaceAll('₹', 'Rs.');
    final sanitizedRight = right.replaceAll('₹', 'Rs.');

    if (_connectedEngine == 'thermal' || await PrintBluetoothThermal.connectionStatus) {
      try {
        final profile = await CapabilityProfile.load();
        final generator = Generator(PaperSize.mm58, profile);
        final bytes = generator.row([
          PosColumn(text: sanitizedLeft, width: 7, styles: const PosStyles(align: PosAlign.left)),
          PosColumn(text: sanitizedRight, width: 5, styles: const PosStyles(align: PosAlign.right)),
        ]);
        await PrintBluetoothThermal.writeBytes(bytes);
        return;
      } catch (e) {
        debugPrint('SafePrintLeftRight thermal error: $e');
      }
    }

    try {
      final maxChars = size == 1 ? 16 : 32;
      if (sanitizedLeft.length + sanitizedRight.length >= maxChars) {
        final availableForLeft = maxChars - sanitizedRight.length - 1;
        if (availableForLeft > 5) {
          final trimmedLeft = sanitizedLeft.substring(0, availableForLeft);
          await bluetooth.printLeftRight(trimmedLeft, sanitizedRight, size);
        } else {
          await _safePrintCustom(sanitizedLeft, size, 0);
          await _safePrintCustom(sanitizedRight, size, 2);
        }
      } else {
        await bluetooth.printLeftRight(sanitizedLeft, sanitizedRight, size);
      }
      await Future.delayed(const Duration(milliseconds: 25));
    } catch (e) {
      debugPrint('SafePrintLeftRight error: $e');
    }
  }

  Future<void> _safePrintNewLine() async {
    if (_connectedEngine == 'thermal' || await PrintBluetoothThermal.connectionStatus) {
      try {
        final profile = await CapabilityProfile.load();
        final generator = Generator(PaperSize.mm58, profile);
        await PrintBluetoothThermal.writeBytes(generator.emptyLines(1));
        return;
      } catch (_) {}
    }

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

    // 8. Feed paper safely (exact 2 lines to reach tear-off on 58mm printers, then HARD STOP)
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
