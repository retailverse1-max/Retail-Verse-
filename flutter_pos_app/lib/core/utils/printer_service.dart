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
import '../branding/app_branding.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  String? _connectedEngine; // 'blue' or 'thermal'
  String? _connectedAddress;
  String? _connectedName;

  /// Reactive notifier for real-time printer connection state
  final ValueNotifier<bool> connectionStatusNotifier = ValueNotifier<bool>(false);

  String? get connectedAddress => _connectedAddress;
  String? get connectedName => _connectedName;

  static const String _prefKeyPrinterAddress = 'saved_thermal_printer_address';
  static const String _prefKeyPrinterName = 'saved_thermal_printer_name';
  static const String _prefKeyReceiptPrinterAddress = 'saved_receipt_printer_address';
  static const String _prefKeyReceiptPrinterName = 'saved_receipt_printer_name';
  static const String _prefKeyLabelPrinterAddress = 'saved_label_printer_address';
  static const String _prefKeyLabelPrinterName = 'saved_label_printer_name';

  static const String defaultBillplusMac = '02:2D:36:C9:4E:A9';
  static const String defaultBillplusName = 'billplus 617';

  /// Helper to identify non-printer audio, car, or phone devices
  static bool isAudioOrPhoneDevice(String? name) {
    if (name == null) return false;
    final n = name.toLowerCase();
    return n.contains('buds') ||
        n.contains('airbass') ||
        n.contains('earphone') ||
        n.contains('headphone') ||
        n.contains('headset') ||
        n.contains('audio') ||
        n.contains('jbl') ||
        n.contains('boat') ||
        n.contains('boult') ||
        n.contains('enco') ||
        n.contains('redmi') ||
        n.contains('realme') ||
        n.contains('vivo') ||
        n.contains('oppo') ||
        n.contains('samsung') ||
        n.contains('phone') ||
        n.contains('kia') ||
        n.contains('hyundai') ||
        n.contains('car');
  }

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
        const Duration(milliseconds: 600),
        onTimeout: () => false,
      );
      if (status == true) {
        _connectedEngine = 'blue';
        if (!connectionStatusNotifier.value) {
          connectionStatusNotifier.value = true;
        }
        return true;
      }
    } catch (_) {}

    try {
      final thermalStatus = await PrintBluetoothThermal.connectionStatus;
      if (thermalStatus == true) {
        _connectedEngine = 'thermal';
        if (!connectionStatusNotifier.value) {
          connectionStatusNotifier.value = true;
        }
        return true;
      }
    } catch (_) {}

    _connectedEngine = null;
    if (connectionStatusNotifier.value) {
      connectionStatusNotifier.value = false;
    }
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

  /// Save printer to SharedPreferences
  Future<void> savePrinter(BluetoothDevice device) async {
    if (isAudioOrPhoneDevice(device.name)) {
      debugPrint('Refusing to save non-printer audio device: ${device.name}');
      return;
    }
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

  /// Get designated receipt printer MAC address
  Future<String?> getReceiptPrinterAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rName = prefs.getString(_prefKeyReceiptPrinterName);
      if (rName != null && isAudioOrPhoneDevice(rName)) {
        await prefs.remove(_prefKeyReceiptPrinterName);
        await prefs.remove(_prefKeyReceiptPrinterAddress);
      }
      final pName = prefs.getString(_prefKeyPrinterName);
      if (pName != null && isAudioOrPhoneDevice(pName)) {
        await prefs.remove(_prefKeyPrinterName);
        await prefs.remove(_prefKeyPrinterAddress);
      }
      return prefs.getString(_prefKeyReceiptPrinterAddress) ?? prefs.getString(_prefKeyPrinterAddress) ?? defaultBillplusMac;
    } catch (_) {
      return defaultBillplusMac;
    }
  }

  /// Get designated receipt printer name
  Future<String?> getReceiptPrinterName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rName = prefs.getString(_prefKeyReceiptPrinterName);
      if (rName != null) {
        if (isAudioOrPhoneDevice(rName)) {
          await prefs.remove(_prefKeyReceiptPrinterName);
          await prefs.remove(_prefKeyReceiptPrinterAddress);
        } else if (rName.isNotEmpty) {
          return rName;
        }
      }

      final pName = prefs.getString(_prefKeyPrinterName);
      if (pName != null) {
        if (isAudioOrPhoneDevice(pName)) {
          await prefs.remove(_prefKeyPrinterName);
          await prefs.remove(_prefKeyPrinterAddress);
        } else if (pName.isNotEmpty) {
          return pName;
        }
      }

      if (_connectedName != null && !isAudioOrPhoneDevice(_connectedName)) {
        return _connectedName;
      }

      return defaultBillplusName;
    } catch (_) {
      return defaultBillplusName;
    }
  }

  /// Designate a printer as the Receipt/Bill printer
  Future<void> saveReceiptPrinter(BluetoothDevice device) async {
    if (isAudioOrPhoneDevice(device.name)) {
      debugPrint('Refusing to save non-printer audio device: ${device.name}');
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (device.address != null) {
        await prefs.setString(_prefKeyReceiptPrinterAddress, device.address!);
        await prefs.setString(_prefKeyPrinterAddress, device.address!);
      }
      if (device.name != null) {
        await prefs.setString(_prefKeyReceiptPrinterName, device.name!);
        await prefs.setString(_prefKeyPrinterName, device.name!);
      }
    } catch (e) {
      debugPrint('Error saving receipt printer: $e');
    }
  }

  /// Get designated barcode label printer MAC address
  Future<String?> getLabelPrinterAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefKeyLabelPrinterAddress);
    } catch (_) {
      return null;
    }
  }

  /// Get designated barcode label printer name
  Future<String?> getLabelPrinterName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefKeyLabelPrinterName);
    } catch (_) {
      return null;
    }
  }

  /// Designate a printer as the Barcode Sticker/Label printer
  Future<void> saveLabelPrinter(BluetoothDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (device.address != null) {
        await prefs.setString(_prefKeyLabelPrinterAddress, device.address!);
      }
      if (device.name != null) {
        await prefs.setString(_prefKeyLabelPrinterName, device.name!);
      }
    } catch (e) {
      debugPrint('Error saving label printer: $e');
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
        _connectedAddress = device.address;
        _connectedName = device.name;
        await savePrinter(device);
        connectionStatusNotifier.value = true;
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
          _connectedAddress = device.address;
          _connectedName = device.name;
          await savePrinter(device);
          connectionStatusNotifier.value = true;
          debugPrint('Connected via PrintBluetoothThermal!');
          return true;
        }
      } catch (e) {
        debugPrint('Error connecting via PrintBluetoothThermal: $e');
      }
    }

    return false;
  }

  /// Automatically connect to the designated Receipt Printer (e.g. Billplus 617)
  Future<bool> autoConnectForReceipt() async {
    final receiptMac = await getReceiptPrinterAddress();
    final receiptName = await getReceiptPrinterName();

    if (await isConnected()) {
      if (_connectedAddress != null && receiptMac != null && _connectedAddress!.toLowerCase() == receiptMac.toLowerCase()) {
        return true;
      }
    }

    // Only try receiptMac directly if it's not an earphone / car / phone
    if (receiptMac != null && receiptMac.isNotEmpty && !isAudioOrPhoneDevice(receiptName)) {
      final success = await connect(BluetoothDevice(receiptName ?? defaultBillplusName, receiptMac));
      if (success) return true;
    }

    return await autoConnect();
  }

  /// Automatically connect to the designated Barcode Label Printer (e.g. TVS / TSC / Xprinter)
  /// If no dedicated label printer is configured, falls back to currently connected / receipt printer
  Future<bool> autoConnectForLabel() async {
    final labelMac = await getLabelPrinterAddress();
    final labelName = await getLabelPrinterName();

    if (labelMac != null && labelMac.isNotEmpty && !isAudioOrPhoneDevice(labelName)) {
      if (await isConnected()) {
        if (_connectedAddress != null && _connectedAddress!.toLowerCase() == labelMac.toLowerCase()) {
          return true;
        }
      }
      final success = await connect(BluetoothDevice(labelName ?? 'Label Printer', labelMac));
      if (success) return true;
    }

    // Fallback: If already connected to any printer (e.g. Billplus), continue with it
    if (await isConnected()) return true;
    return await autoConnect();
  }

  /// Auto-connect to saved printer, or any paired thermal printer
  Future<bool> autoConnect() async {
    try {
      if (await isConnected()) {
        return true;
      }

      final devices = await getDevices();
      if (devices.isEmpty) return false;

      // Filter out non-printers (earphones, cars, phones) from automatic candidate pool
      final printerCandidates = devices.where((d) => !isAudioOrPhoneDevice(d.name)).toList();

      // 1. Smart auto-detect: find any paired device matching known thermal printer keywords FIRST
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
      final candidate = printerCandidates.where((d) {
        final name = (d.name ?? '').toLowerCase();
        return printerKeywords.any((kw) => name.contains(kw));
      }).firstOrNull;

      if (candidate != null) {
        final connected = await connect(candidate);
        if (connected) return true;
      }

      // 2. Check saved printer MAC address if it's NOT an audio/phone device
      final savedAddress = await getSavedPrinterAddress();
      final savedName = await getSavedPrinterName();
      if (savedAddress != null && savedAddress.isNotEmpty && !isAudioOrPhoneDevice(savedName)) {
        final match = printerCandidates.where((d) => d.address?.toLowerCase() == savedAddress.toLowerCase()).firstOrNull;
        if (match != null) {
          final connected = await connect(match);
          if (connected) return true;
        }
      }

      // 3. Specifically try default Billplus 617 if found
      final defaultBillplus = printerCandidates.where((d) => d.address?.toLowerCase() == defaultBillplusMac.toLowerCase()).firstOrNull;
      if (defaultBillplus != null) {
        final connected = await connect(defaultBillplus);
        if (connected) return true;
      }

      // 4. Fallback: Try remaining printer candidates
      for (final dev in printerCandidates) {
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
    _connectedAddress = null;
    _connectedName = null;
    connectionStatusNotifier.value = false;
  }

  /// Print a simple test slip to verify printer connection
  Future<bool> printTestReceipt() async {
    if (!await isConnected()) {
      final connected = await autoConnect();
      if (!connected) return false;
    }
    try {
      // 1. Generate a crisp 58mm test bitmap (384 dot width)
      final testImg = img.Image(width: 384, height: 180);
      img.fill(testImg, color: img.ColorRgb8(255, 255, 255));
      img.drawString(testImg, '================================', font: img.arial14, x: 10, y: 10, color: img.ColorRgb8(0, 0, 0));
      img.drawString(testImg, '${AppBranding.getStoreName().toUpperCase()} POS', font: img.arial24, x: 75, y: 35, color: img.ColorRgb8(0, 0, 0));
      final savedName = await getSavedPrinterName() ?? 'billplus 617';
      img.drawString(testImg, '$savedName: ONLINE', font: img.arial14, x: 90, y: 75, color: img.ColorRgb8(0, 0, 0));
      img.drawString(testImg, 'PRINTER TEST SUCCESSFUL', font: img.arial14, x: 80, y: 105, color: img.ColorRgb8(0, 0, 0));
      img.drawString(testImg, '================================', font: img.arial14, x: 10, y: 140, color: img.ColorRgb8(0, 0, 0));
      final testPng = Uint8List.fromList(img.encodePng(testImg));

      await printImageBytes(testPng);
      await _safePrintNewLine();
      await _safePrintNewLine();
      return true;
    } catch (e) {
      debugPrint('Error printing test receipt: $e');
      return false;
    }
  }

  /// Print image bytes directly to thermal printer (auto-scales to 384 dots for 58mm printers)
  Future<bool> printImageBytes(Uint8List bytes) async {
    if (!await isConnected()) {
      final connected = await autoConnect();
      if (!connected) return false;
    }

    Uint8List finalBytes = bytes;
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        img.Image processed = decoded;
        // 58mm print head is strictly 384 dots max. Anything larger overflows printer buffer!
        if (processed.width > 384) {
          processed = img.copyResize(processed, width: 384);
        }

        // CRITICAL FIX: Flatten any transparency onto pure opaque white (255, 255, 255).
        // Transparent pixels (alpha=0, rgb=0) otherwise get converted to solid black by
        // thermal printer drivers, which caused the unwanted black border/margins!
        final solidWhite = img.Image(
          width: processed.width,
          height: processed.height,
          numChannels: 3,
        );
        img.fill(solidWhite, color: img.ColorRgb8(255, 255, 255));
        for (int y = 0; y < processed.height; y++) {
          for (int x = 0; x < processed.width; x++) {
            final p = processed.getPixel(x, y);
            if (p.a >= 128) {
              solidWhite.setPixelRgb(x, y, p.r, p.g, p.b);
            }
          }
        }
        processed = solidWhite;

        finalBytes = Uint8List.fromList(img.encodePng(processed));

        if (_connectedEngine == 'thermal' || await PrintBluetoothThermal.connectionStatus) {
          try {
            final profile = await _getProfile();
            final generator = Generator(PaperSize.mm58, profile);
            final escBytes = generator.imageRaster(processed);
            await PrintBluetoothThermal.writeBytes(escBytes);
            return true;
          } catch (e) {
            debugPrint('Thermal printImageBytes error: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error processing image bytes: $e');
    }

    try {
      await bluetooth.printImageBytes(finalBytes);
      return true;
    } catch (e) {
      debugPrint('Error printing image bytes: $e');
      return false;
    }
  }

  bool _isPrintingCancelled = false;

  /// Immediately cancels any active loop printing (barcode stickers, multiple copies)
  void cancelPrinting() {
    _isPrintingCancelled = true;
    try {
      // Send ESC/POS CAN (Cancel = 0x18) to clear printer receive buffer
      _sendRawBytes(Uint8List.fromList([0x18]));
    } catch (_) {}
  }

  bool get isPrintingCancelled => _isPrintingCancelled;

  /// Prints barcode sticker directly to the thermal printer
  /// Sends 0x0C (Form Feed) after each label so the hardware gap sensor
  /// automatically locks the paper at the next sticker boundary (zero-drift).
  Future<bool> printBarcodeStickerDirect({
    required Uint8List pngBytes,
    int count = 1,
    void Function(int current, int total)? onProgress,
  }) async {
    _isPrintingCancelled = false;
    final connected = await autoConnectForLabel();
    if (!connected) return false;

    try {
      for (int i = 0; i < count; i++) {
        if (_isPrintingCancelled) {
          debugPrint('[PrinterService] Print cancelled before sticker ${i + 1}/$count');
          break;
        }

        onProgress?.call(i + 1, count);
        await printImageBytes(pngBytes);
        // 0x1D 0x0C (GS FF): Single Top of Form feed command to align to the next gap
        await _sendRawBytes(Uint8List.fromList([0x1D, 0x0C]));

        if (_isPrintingCancelled) {
          debugPrint('[PrinterService] Print cancelled after sending sticker ${i + 1}/$count');
          break;
        }

        // Allow physical stepper motor to finish feeding across the gap before sending the next sticker
        await Future.delayed(const Duration(milliseconds: 600));

        if (_isPrintingCancelled) {
          debugPrint('[PrinterService] Print cancelled after delay at sticker ${i + 1}/$count');
          break;
        }
      }

      return !_isPrintingCancelled;
    } catch (e) {
      debugPrint('Error printing barcode sticker: $e');
      return false;
    }
  }

  /// Prints barcode labels natively using TSPL (TSC / TVS / Xprinter / Zebra Label Printers)
  /// Uses hardware optical gap sensor and native vector barcode formatting for zero-drift 100+ copies
  Future<bool> printBarcodeStickerTspl({
    required String storeName,
    required String productName,
    required String barcode,
    int count = 1,
    double widthMm = 50.0,
    double heightMm = 25.0,
    double gapMm = 3.0,
  }) async {
    final connected = await autoConnectForLabel();
    if (!connected) return false;

    try {
      final tsplCommand = StringBuffer();
      tsplCommand.writeln('SIZE ${widthMm.toStringAsFixed(1)} mm, ${heightMm.toStringAsFixed(1)} mm');
      tsplCommand.writeln('GAP ${gapMm.toStringAsFixed(1)} mm, 0 mm');
      tsplCommand.writeln('DIRECTION 1');
      tsplCommand.writeln('REFERENCE 0,0');
      tsplCommand.writeln('CLS');
      // Store Name Header (Font "3", x=24, y=16)
      tsplCommand.writeln('TEXT 24,16,"3",0,1,1,"$storeName"');
      // Product Name (Font "2", x=24, y=48)
      tsplCommand.writeln('TEXT 24,48,"2",0,1,1,"$productName"');
      // Code 128 Barcode (x=24, y=80, height=54 dots, print text below)
      tsplCommand.writeln('BARCODE 24,80,"128",54,1,0,2,2,"$barcode"');
      // Print N copies
      tsplCommand.writeln('PRINT $count,1');

      final rawBytes = Uint8List.fromList(tsplCommand.toString().codeUnits);
      return await _sendRawBytes(rawBytes);
    } catch (e) {
      debugPrint('TSPL barcode print error: $e');
      return false;
    }
  }


  /// Print receipt as a high-resolution monochrome raster bitmap image.
  /// Works with 100% of Bluetooth thermal printers without code-page or unicode issues.
  Future<bool> printReceiptRaster({
    required Order order,
    PosSettings? settings,
  }) async {
    final connected = await autoConnectForReceipt();
    if (!connected) return false;

    try {
      // Force 58mm roll (384 dots width) for Billplus & 58mm thermal printers
      final effectiveSettings = settings?.copyWith(receiptSize: '58mm');

      final pdfBytes = await ReceiptGenerator.generateReceiptPdf(
        order,
        settings: effectiveSettings,
      );
      try {
        final rasterPages = Printing.raster(pdfBytes, pages: [0], dpi: 203);
        final firstPage = await rasterPages.first;
        final pngBytes = await firstPage.toPng();

        await printImageBytes(pngBytes);
        await _safePrintNewLine();
        await _safePrintNewLine();
        await _safePrintNewLine();
        return true;
      } catch (e) {
        debugPrint('Printing.raster failed: $e. Falling back to ESC/POS print...');
        await printReceipt(order, settings: effectiveSettings);
        return true;
      }
    } catch (e) {
      debugPrint('Error printing raster receipt: $e');
      await printReceipt(order, settings: settings);
      return true;
    }
  }

  CapabilityProfile? _cachedProfile;
  Future<CapabilityProfile> _getProfile() async {
    if (_cachedProfile != null) return _cachedProfile!;
    try {
      _cachedProfile = await CapabilityProfile.load();
      return _cachedProfile!;
    } catch (e) {
      debugPrint('Error loading CapabilityProfile: $e');
      rethrow;
    }
  }

  /// Sends raw ESC/POS bytes to whichever engine is connected
  Future<bool> _sendRawBytes(Uint8List bytes) async {
    bool ok = false;
    // 1. Try PrintBluetoothThermal
    if (_connectedEngine == 'thermal' || await PrintBluetoothThermal.connectionStatus) {
      try {
        final res = await PrintBluetoothThermal.writeBytes(bytes);
        if (res) return true;
      } catch (e) {
        debugPrint('PrintBluetoothThermal writeBytes error: $e');
      }
    }

    // 2. Try blue_thermal_printer
    try {
      if (await bluetooth.isConnected == true) {
        await bluetooth.writeBytes(bytes);
        return true;
      }
    } catch (e) {
      debugPrint('BlueThermal writeBytes error: $e');
    }

    // 3. Last fallback try PrintBluetoothThermal anyway
    try {
      final res = await PrintBluetoothThermal.writeBytes(bytes);
      if (res) return true;
    } catch (_) {}

    return ok;
  }

  Future<void> _safePrintCustom(String message, int size, int align) async {
    final sanitized = message.replaceAll('₹', 'Rs.');
    if (_connectedEngine == 'thermal' || await PrintBluetoothThermal.connectionStatus) {
      try {
        final profile = await _getProfile();
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
      await Future.delayed(const Duration(milliseconds: 15));
    } catch (e) {
      debugPrint('SafePrintCustom error: $e');
    }
  }

  Future<void> _safePrintLeftRight(String left, String right, int size) async {
    final sanitizedLeft = left.replaceAll('₹', 'Rs.');
    final sanitizedRight = right.replaceAll('₹', 'Rs.');

    if (_connectedEngine == 'thermal' || await PrintBluetoothThermal.connectionStatus) {
      try {
        final profile = await _getProfile();
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
      await Future.delayed(const Duration(milliseconds: 15));
    } catch (e) {
      debugPrint('SafePrintLeftRight error: $e');
    }
  }

  Future<void> _safePrintNewLine() async {
    if (_connectedEngine == 'thermal' || await PrintBluetoothThermal.connectionStatus) {
      try {
        final profile = await _getProfile();
        final generator = Generator(PaperSize.mm58, profile);
        await PrintBluetoothThermal.writeBytes(generator.emptyLines(1));
        return;
      } catch (_) {}
    }

    try {
      await bluetooth.printNewLine();
      await Future.delayed(const Duration(milliseconds: 15));
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
    final connected = await autoConnectForReceipt();
    if (!connected) {
      throw Exception('Receipt printer not connected. Please pair and select printer.');
    }

    // Resolve store header info
    String finalStoreName = (storeName != null && storeName.trim().isNotEmpty)
        ? storeName.trim().toUpperCase()
        : (settings?.storeName.trim().isNotEmpty ?? false)
            ? settings!.storeName.trim().toUpperCase()
            : (authUser?['businessName']?.toString().trim().toUpperCase() ??
               authUser?['storeName']?.toString().trim().toUpperCase() ??
               authUser?['name']?.toString().trim().toUpperCase() ??
               '${AppBranding.getStoreName().toUpperCase()} STORE');

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

    // ── ATTEMPT 1: Single ESC/POS binary packet (Instant, 100% formatted & reliable) ──
    final paperSize = (settings?.receiptSize == '80mm') ? PaperSize.mm80 : PaperSize.mm58;
    final int colWidth = (paperSize == PaperSize.mm80) ? 48 : 32;
    final String doubleDivider = "=" * colWidth;
    final String singleDivider = "-" * colWidth;

    try {
      final profile = await _getProfile();
      final generator = Generator(paperSize, profile);
      List<int> bytes = [];

      // 1. Store Header (Centered, matching Image 3)
      if (settings != null &&
          settings.showShopLogoOnInvoice &&
          settings.businessLogoPath.isNotEmpty) {
        try {
          final logoFile = File(settings.businessLogoPath);
          if (logoFile.existsSync()) {
            final logoBytes = await logoFile.readAsBytes();
            final decodedImg = img.decodeImage(logoBytes);
            if (decodedImg != null) {
              final resized = img.copyResize(decodedImg, width: (colWidth == 48 ? 160 : 120));
              bytes += generator.imageRaster(resized, align: PosAlign.center);
              bytes += generator.emptyLines(1);
            }
          }
        } catch (_) {}
      }

      bytes += generator.text(
        finalStoreName,
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );

      final bool showTax = settings?.showTaxOnBill ?? true;
      bytes += generator.text(
        showTax ? "TAX INVOICE" : "RETAIL INVOICE",
        styles: const PosStyles(align: PosAlign.center),
      );

      if (storeAddress != null && storeAddress.isNotEmpty) {
        for (final line in _wrapText(storeAddress, colWidth)) {
          bytes += generator.text(line, styles: const PosStyles(align: PosAlign.center));
        }
      }

      if (storePhone != null && storePhone.isNotEmpty) {
        bytes += generator.text("Ph: $storePhone", styles: const PosStyles(align: PosAlign.center));
      }

      if (showTax && gstNumber != null && gstNumber.isNotEmpty) {
        bytes += generator.text("GSTIN: $gstNumber", styles: const PosStyles(align: PosAlign.center));
      }

      final fssai = authUser?['fssai']?.toString().trim() ?? authUser?['fssaiNumber']?.toString().trim();
      if (fssai != null && fssai.isNotEmpty) {
        bytes += generator.text("FSSAI: $fssai", styles: const PosStyles(align: PosAlign.center));
      }

      // 2. Double Divider
      bytes += generator.text(doubleDivider);

      // 3. Bill Meta (Matching Image 3)
      final billNo = order.orderId;
      final shortBill = billNo.contains('-') ? billNo.split('-').last : billNo;
      final billDisplay = (("BILL: $billNo".length + "DATE: $formattedDate".length + 2) <= colWidth)
          ? "BILL: $billNo"
          : "BILL: #$shortBill";

      bytes += generator.text(_padTwoColumns(billDisplay, "DATE: $formattedDate", colWidth));
      bytes += generator.text(_padTwoColumns("TIME: $formattedTime", "OP: ${order.cashierName ?? 'POS Admin'}", colWidth));
      bytes += generator.text("PAY MODE: ${paymentMethod.isEmpty ? 'CASH' : paymentMethod}");
      if (order.customerName != null && order.customerName!.trim().isNotEmpty) {
        final phonePart = (order.customerPhone != null && order.customerPhone!.trim().isNotEmpty) ? " (${order.customerPhone})" : "";
        final custLine = "CUST: ${order.customerName}$phonePart";
        for (final line in _wrapText(custLine, colWidth)) {
          bytes += generator.text(line);
        }
      }

      // 4. Single Divider
      bytes += generator.text(singleDivider);

      // 5. Items Table Header
      bytes += generator.text(_padTwoColumns("ITEM (QTY x RATE)", "TOTAL", colWidth));

      // 6. Single Divider
      bytes += generator.text(singleDivider);

      // 7. Item Rows (Clean 2-line layout per item - never glitches or wraps awkwardly)
      for (var item in order.items) {
        final name = item.product.name.trim();
        final displayName = name.length > colWidth ? name.substring(0, colWidth) : name;
        bytes += generator.text(displayName);

        final qtyStr = item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2);
        final priceStr = item.price.toStringAsFixed(2);
        final totalStr = item.total.toStringAsFixed(2);

        final leftDetails = "  $qtyStr x Rs.$priceStr";
        final rightTotal = "Rs.$totalStr";
        bytes += generator.text(_padTwoColumns(leftDetails, rightTotal, colWidth));
      }

      // 8. Single Divider
      bytes += generator.text(singleDivider);

      // 9. Totals Section
      bytes += generator.text(_padTwoColumns("SUBTOTAL:", "Rs.${order.subtotal.toStringAsFixed(2)}", colWidth));

      if (order.discount > 0) {
        final discLabel = order.couponCode != null && order.couponCode!.trim().isNotEmpty
            ? "DISCOUNT (${order.couponCode}):"
            : "DISCOUNT:";
        bytes += generator.text(_padTwoColumns(discLabel, "-Rs.${order.discount.toStringAsFixed(2)}", colWidth));
      }

      if (showTax && order.tax > 0) {
        bytes += generator.text(_padTwoColumns("TOTAL GST:", "Rs.${order.tax.toStringAsFixed(2)}", colWidth));
      }

      if (order.extraCharges > 0) {
        bytes += generator.text(_padTwoColumns("EXTRA CHARGES:", "Rs.${order.extraCharges.toStringAsFixed(2)}", colWidth));
      }

      // 10. Double Divider
      bytes += generator.text(doubleDivider);

      // 11. Grand Total (Bold, high contrast)
      bytes += generator.text(
        _padTwoColumns("GRAND TOTAL:", "Rs.${order.total.toStringAsFixed(2)}", colWidth),
        styles: const PosStyles(bold: true, height: PosTextSize.size1, width: PosTextSize.size1),
      );

      // 12. Double Divider
      bytes += generator.text(doubleDivider);

      // 13. Footer Note (Clean, matching Image 3)
      final footerMsg = (settings != null &&
              settings.invoiceFooterNote.trim().isNotEmpty &&
              settings.invoiceFooterNote.trim() != 'Thank you for your business.')
          ? settings.invoiceFooterNote.trim()
          : "THANKS FOR YOUR VISIT! GOODS ONCE SOLD CANNOT BE RETURNED";

      for (final line in _wrapText(footerMsg, colWidth)) {
        bytes += generator.text(line, styles: const PosStyles(align: PosAlign.center));
      }

      bytes += generator.emptyLines(3);

      if (settings?.receiptSize == '80mm') {
        bytes += generator.cut();
      }

      // 14. Reward Coupon Slip (Prints immediately after main bill for orders >= Rs.3,000)
      final hasCoupon = (order.rewardCouponCode != null && order.rewardCouponCode!.isNotEmpty) ||
          order.subtotal >= 3000 ||
          order.total >= 3000;
      if (hasCoupon) {
        final cleanId = order.orderId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
        final suffix = cleanId.length >= 4 ? cleanId.substring(0, 4).toUpperCase() : cleanId.toUpperCase().padRight(4, '0');
        final couponCode = (order.rewardCouponCode != null && order.rewardCouponCode!.isNotEmpty)
            ? order.rewardCouponCode!
            : 'SAVE300-$suffix';

        final divider = (paperSize == PaperSize.mm80)
            ? "================================================"
            : "================================";

        bytes += generator.text(divider, styles: const PosStyles(align: PosAlign.center));
        bytes += generator.text(
          "NEXT VISIT REWARD COUPON",
          styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1),
        );
        bytes += generator.text(finalStoreName, styles: const PosStyles(align: PosAlign.center));
        bytes += generator.emptyLines(1);
        bytes += generator.text("COUPON CODE:", styles: const PosStyles(align: PosAlign.center));
        bytes += generator.text(
          couponCode,
          styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
        );
        bytes += generator.emptyLines(1);
        bytes += generator.text(
          "Flat Rs.300 OFF on your next order of Rs.3,000+",
          styles: const PosStyles(align: PosAlign.center),
        );
        bytes += generator.text(
          "Valid for 30 Days. Present slip at billing.",
          styles: const PosStyles(align: PosAlign.center),
        );
        bytes += generator.text(divider, styles: const PosStyles(align: PosAlign.center));
        bytes += generator.emptyLines(3);
        if (settings?.receiptSize == '80mm') {
          bytes += generator.cut();
        }
      }

      final sent = await _sendRawBytes(Uint8List.fromList(bytes));
      if (sent) {
        debugPrint('Receipt sent successfully as ESC/POS raw bytes package!');
        return;
      }
    } catch (e) {
      debugPrint('ESC/POS generator error: $e. Falling back to line-by-line printing...');
    }

    // ── ATTEMPT 2: Fallback Line-by-Line Native Bluetooth Print ──
    const int fbWidth = 32;
    const String fbDoubleDivider = "================================";
    const String fbSingleDivider = "--------------------------------";

    // 1. Store Header
    await _safePrintCustom(finalStoreName, 1, 1);
    await _safePrintCustom("TAX INVOICE", 0, 1);
    if (storeAddress != null && storeAddress.isNotEmpty) {
      for (final line in _wrapText(storeAddress, fbWidth)) {
        await _safePrintCustom(line, 0, 1);
      }
    }
    if (storePhone != null && storePhone.isNotEmpty) {
      await _safePrintCustom("Ph: $storePhone", 0, 1);
    }
    if (gstNumber != null && gstNumber.isNotEmpty) {
      await _safePrintCustom("GSTIN: $gstNumber", 0, 1);
    }

    // 2. Double Divider
    await _safePrintCustom(fbDoubleDivider, 0, 1);

    // 3. Bill Meta
    final fbBillNo = order.orderId;
    final fbShortBill = fbBillNo.contains('-') ? fbBillNo.split('-').last : fbBillNo;
    final fbBillDisplay = (("BILL: $fbBillNo".length + "DATE: $formattedDate".length + 2) <= fbWidth)
        ? "BILL: $fbBillNo"
        : "BILL: #$fbShortBill";

    await _safePrintCustom(_padTwoColumns(fbBillDisplay, "DATE: $formattedDate", fbWidth), 0, 0);
    await _safePrintCustom(_padTwoColumns("TIME: $formattedTime", "OP: ${order.cashierName ?? 'POS Admin'}", fbWidth), 0, 0);
    await _safePrintCustom("PAY MODE: ${paymentMethod.isEmpty ? 'CASH' : paymentMethod}", 0, 0);
    if (order.customerName != null && order.customerName!.trim().isNotEmpty) {
      final phonePart = (order.customerPhone != null && order.customerPhone!.trim().isNotEmpty) ? " (${order.customerPhone})" : "";
      final custLine = "CUST: ${order.customerName}$phonePart";
      for (final line in _wrapText(custLine, fbWidth)) {
        await _safePrintCustom(line, 0, 0);
      }
    }

    // 4. Single Divider
    await _safePrintCustom(fbSingleDivider, 0, 1);

    // 5. Items Header
    await _safePrintCustom(_padTwoColumns("ITEM (QTY x RATE)", "TOTAL", fbWidth), 0, 0);
    await _safePrintCustom(fbSingleDivider, 0, 1);

    // 6. Item Rows
    for (var item in order.items) {
      final name = item.product.name.trim();
      final displayName = name.length > fbWidth ? name.substring(0, fbWidth) : name;
      await _safePrintCustom(displayName, 0, 0);

      final qtyStr = item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2);
      final priceStr = item.price.toStringAsFixed(2);
      final totalStr = item.total.toStringAsFixed(2);
      final leftDetails = "  $qtyStr x Rs.$priceStr";
      final rightTotal = "Rs.$totalStr";
      await _safePrintCustom(_padTwoColumns(leftDetails, rightTotal, fbWidth), 0, 0);
    }

    // 7. Single Divider
    await _safePrintCustom(fbSingleDivider, 0, 1);

    // 8. Totals
    await _safePrintCustom(_padTwoColumns("SUBTOTAL:", "Rs.${order.subtotal.toStringAsFixed(2)}", fbWidth), 0, 0);
    if (order.discount > 0) {
      final discLabel = order.couponCode != null && order.couponCode!.trim().isNotEmpty
          ? "DISCOUNT (${order.couponCode}):"
          : "DISCOUNT:";
      await _safePrintCustom(_padTwoColumns(discLabel, "-Rs.${order.discount.toStringAsFixed(2)}", fbWidth), 0, 0);
    }
    if (order.tax > 0) {
      await _safePrintCustom(_padTwoColumns("TOTAL GST:", "Rs.${order.tax.toStringAsFixed(2)}", fbWidth), 0, 0);
    }
    if (order.extraCharges > 0) {
      await _safePrintCustom(_padTwoColumns("EXTRA CHARGES:", "Rs.${order.extraCharges.toStringAsFixed(2)}", fbWidth), 0, 0);
    }

    // 9. Double Divider
    await _safePrintCustom(fbDoubleDivider, 0, 1);

    // 10. Grand Total
    await _safePrintCustom(_padTwoColumns("GRAND TOTAL:", "Rs.${order.total.toStringAsFixed(2)}", fbWidth), 1, 0);

    // 11. Double Divider
    await _safePrintCustom(fbDoubleDivider, 0, 1);

    // 12. Footer
    final fallbackFooter = (settings != null &&
            settings.invoiceFooterNote.trim().isNotEmpty &&
            settings.invoiceFooterNote.trim() != 'Thank you for your business.')
        ? settings.invoiceFooterNote.trim()
        : "THANKS FOR YOUR VISIT! GOODS ONCE SOLD CANNOT BE RETURNED";

    for (final line in _wrapText(fallbackFooter, fbWidth)) {
      await _safePrintCustom(line, 0, 1);
    }

    await _safePrintNewLine();
    await _safePrintNewLine();
    await _safePrintNewLine();
    if (settings?.receiptSize == '80mm') {
      try {
        await bluetooth.paperCut();
      } catch (_) {}
    }

    // 9. Reward Coupon Fallback Slip
    final hasCouponFallback = (order.rewardCouponCode != null && order.rewardCouponCode!.isNotEmpty) ||
        order.subtotal >= 3000 ||
        order.total >= 3000;
    if (hasCouponFallback) {
      final cleanId = order.orderId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      final suffix = cleanId.length >= 4 ? cleanId.substring(0, 4).toUpperCase() : cleanId.toUpperCase().padRight(4, '0');
      final couponCode = (order.rewardCouponCode != null && order.rewardCouponCode!.isNotEmpty)
          ? order.rewardCouponCode!
          : 'SAVE300-$suffix';

      await _safePrintCustom("================================", 0, 1);
      await _safePrintCustom("NEXT VISIT REWARD COUPON", 1, 1);
      await _safePrintCustom(finalStoreName, 0, 1);
      await _safePrintNewLine();
      await _safePrintCustom("COUPON CODE:", 0, 1);
      await _safePrintCustom(couponCode, 2, 1);
      await _safePrintNewLine();
      await _safePrintCustom("Flat Rs.300 OFF on next order of Rs.3,000+", 0, 1);
      await _safePrintCustom("Valid for 30 Days. Present slip at billing.", 0, 1);
      await _safePrintCustom("================================", 0, 1);
      await _safePrintNewLine();
      await _safePrintNewLine();
      await _safePrintNewLine();
      if (settings?.receiptSize == '80mm') {
        try {
          await bluetooth.paperCut();
        } catch (_) {}
      }
    }
  }

  /// Print a standalone reward coupon slip
  Future<bool> printCouponSlip({
    required String couponCode,
    String? storeName,
    String description = 'Flat Rs.300 OFF on your next order of Rs.3,000+',
    String validity = 'Valid for 30 Days. Present slip at billing.',
    String? paperSizeStr,
  }) async {
    if (!await isConnected()) {
      final connected = await autoConnect();
      if (!connected) return false;
    }

    final finalStoreName = (storeName != null && storeName.trim().isNotEmpty)
        ? storeName.trim().toUpperCase()
        : '${AppBranding.getStoreName().toUpperCase()} STORE';

    try {
      final profile = await _getProfile();
      final paperSize = (paperSizeStr == '80mm') ? PaperSize.mm80 : PaperSize.mm58;
      final generator = Generator(paperSize, profile);
      List<int> bytes = [];

      final divider = (paperSize == PaperSize.mm80)
          ? "================================================"
          : "================================";

      bytes += generator.text(divider, styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text(
        "NEXT VISIT REWARD COUPON",
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1),
      );
      bytes += generator.text(finalStoreName, styles: const PosStyles(align: PosAlign.center));
      bytes += generator.emptyLines(1);
      bytes += generator.text("COUPON CODE:", styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text(
        couponCode,
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
      );
      bytes += generator.emptyLines(1);
      bytes += generator.text(description, styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text(validity, styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text(divider, styles: const PosStyles(align: PosAlign.center));
      bytes += generator.emptyLines(3);
      if (paperSize == PaperSize.mm80) {
        bytes += generator.cut();
      }

      final sent = await _sendRawBytes(Uint8List.fromList(bytes));
      if (sent) return true;
    } catch (e) {
      debugPrint('Error printing coupon via ESC/POS: $e');
    }

    try {
      await _safePrintCustom("================================", 0, 1);
      await _safePrintCustom("NEXT VISIT REWARD COUPON", 1, 1);
      await _safePrintCustom(finalStoreName, 0, 1);
      await _safePrintNewLine();
      await _safePrintCustom("COUPON CODE:", 0, 1);
      await _safePrintCustom(couponCode, 2, 1);
      await _safePrintNewLine();
      await _safePrintCustom(description, 0, 1);
      await _safePrintCustom(validity, 0, 1);
      await _safePrintCustom("================================", 0, 1);
      await _safePrintNewLine();
      await _safePrintNewLine();
      await _safePrintNewLine();
      return true;
    } catch (e) {
      debugPrint('Error fallback printing coupon: $e');
      return false;
    }
  }

  /// Helper to pad two columns with exact width for thermal printing (e.g. left "SUBTOTAL:", right "Rs.80.00")
  String _padTwoColumns(String left, String right, int width) {
    if (left.length + right.length >= width) {
      final maxLeft = width - right.length - 1;
      if (maxLeft > 0 && left.length > maxLeft) {
        left = left.substring(0, maxLeft);
      }
    }
    final spaces = width - left.length - right.length;
    return left + (" " * (spaces > 0 ? spaces : 1)) + right;
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
