import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../utils/printer_service.dart';
import '../theme/app_colors.dart';

/// Modal bottom sheet to let users view, connect, test, and manage Bluetooth thermal printers in-app
class PrinterManagerSheet extends StatefulWidget {
  const PrinterManagerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PrinterManagerSheet(),
    );
  }

  @override
  State<PrinterManagerSheet> createState() => _PrinterManagerSheetState();
}

class _PrinterManagerSheetState extends State<PrinterManagerSheet> {
  final PrinterService _printerService = PrinterService();
  bool _isLoading = true;
  bool _isConnected = false;
  String? _connectedDeviceName;
  String? _connectedDeviceAddress;
  String? _receiptPrinterName;
  String? _receiptPrinterAddress;
  String? _labelPrinterName;
  String? _labelPrinterAddress;
  List<BluetoothDevice> _devices = [];
  String? _connectingAddress;

  @override
  void initState() {
    super.initState();
    _loadPrinterStatus();
  }

  bool _isPrinterDevice(String? name) {
    if (name == null) return false;
    if (PrinterService.isAudioOrPhoneDevice(name)) return false;
    final lower = name.toLowerCase();
    return lower.contains('billplus') ||
        lower.contains('printer') ||
        lower.contains('pos') ||
        lower.contains('mpt') ||
        lower.contains('mtp') ||
        lower.contains('rpp') ||
        lower.contains('thermal') ||
        lower.contains('58') ||
        lower.contains('80') ||
        lower.contains('innerprinter');
  }

  Future<void> _loadPrinterStatus() async {
    setState(() => _isLoading = true);
    try {
      final isConn = await _printerService.isConnected();
      final savedName = await _printerService.getSavedPrinterName();
      final savedAddress = await _printerService.getSavedPrinterAddress();
      String? receiptName = await _printerService.getReceiptPrinterName();
      String? receiptAddress = await _printerService.getReceiptPrinterAddress();
      String? labelName = await _printerService.getLabelPrinterName();
      String? labelAddress = await _printerService.getLabelPrinterAddress();
      final devices = await _printerService.getDevices();

      // Guard: if audio or phone device was previously saved as receipt printer, reset to billplus default
      if (receiptName != null && PrinterService.isAudioOrPhoneDevice(receiptName)) {
        receiptName = PrinterService.defaultBillplusName;
        receiptAddress = PrinterService.defaultBillplusMac;
      }
      if (labelName != null && PrinterService.isAudioOrPhoneDevice(labelName)) {
        labelName = null;
        labelAddress = null;
      }

      // Ensure billplus 617 is always in the list
      if (!devices.any((d) => d.address?.toLowerCase() == PrinterService.defaultBillplusMac.toLowerCase())) {
        devices.insert(0, BluetoothDevice(PrinterService.defaultBillplusName, PrinterService.defaultBillplusMac));
      }

      // Sort devices: printers first, then other bluetooth devices
      devices.sort((a, b) {
        final aIsPrinter = _isPrinterDevice(a.name);
        final bIsPrinter = _isPrinterDevice(b.name);
        if (aIsPrinter && !bIsPrinter) return -1;
        if (!aIsPrinter && bIsPrinter) return 1;
        return (a.name ?? '').compareTo(b.name ?? '');
      });

      if (mounted) {
        setState(() {
          _isConnected = isConn;
          _connectedDeviceName = savedName ?? (_isConnected ? PrinterService.defaultBillplusName : null);
          _connectedDeviceAddress = savedAddress ?? PrinterService.defaultBillplusMac;
          _receiptPrinterName = receiptName ?? PrinterService.defaultBillplusName;
          _receiptPrinterAddress = receiptAddress ?? PrinterService.defaultBillplusMac;
          _labelPrinterName = labelName;
          _labelPrinterAddress = labelAddress;
          _devices = devices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setAsReceiptPrinter(BluetoothDevice device) async {
    await _printerService.saveReceiptPrinter(device);
    await _loadPrinterStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Set ${device.name ?? 'Printer'} as Bill / Receipt Printer'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _setAsLabelPrinter(BluetoothDevice device) async {
    await _printerService.saveLabelPrinter(device);
    await _loadPrinterStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Set ${device.name ?? 'Printer'} as Barcode Label Printer'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() => _connectingAddress = device.address);
    try {
      final success = await _printerService.connect(device);
      if (mounted) {
        setState(() => _connectingAddress = null);
        if (success) {
          setState(() {
            _isConnected = true;
            _connectedDeviceName = device.name;
            _connectedDeviceAddress = device.address;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Connected to ${device.name ?? 'Printer'}!')),
                ],
              ),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Connection Failed',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${device.name ?? 'Printer'} (${device.address}) is not responding.\n\nPlease check:',
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '1. Close "Billplus" official app from recent apps.\n2. Ensure thermal printer power switch is ON.\n3. Bluetooth of phone is turned ON.',
                    style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF475569)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _connectToDevice(device);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry Connect'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _connectingAddress = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    await _printerService.disconnect();
    if (mounted) {
      setState(() {
        _isConnected = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Printer disconnected'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _testPrint() async {
    if (!_isConnected) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Printing test receipt...'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
    final ok = await _printerService.printTestReceipt();
    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test print sent successfully!'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test print failed. Try reconnecting.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showManualConnectDialog() {
    final nameCtrl = TextEditingController(text: PrinterService.defaultBillplusName);
    final macCtrl = TextEditingController(text: PrinterService.defaultBillplusMac);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Connect by MAC Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Printer Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: macCtrl,
              decoration: const InputDecoration(
                labelText: 'Bluetooth MAC Address',
                hintText: '02:2D:36:C9:4E:A9',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final name = nameCtrl.text.trim();
              final mac = macCtrl.text.trim();
              if (mac.isNotEmpty) {
                _connectToDevice(BluetoothDevice(name.isEmpty ? 'Thermal Printer' : name, mac));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceIcon(String name, bool isConnected, bool isProbablePrinter) {
    final lower = name.toLowerCase();
    IconData icon = Icons.bluetooth_rounded;
    if (isProbablePrinter) {
      icon = Icons.print_rounded;
    } else if (lower.contains('buds') ||
        lower.contains('airbass') ||
        lower.contains('earphone') ||
        lower.contains('headphone') ||
        lower.contains('headset') ||
        lower.contains('audio') ||
        lower.contains('wave') ||
        lower.contains('boat') ||
        lower.contains('boult')) {
      icon = Icons.headphones_rounded;
    } else if (lower.contains('redmi') ||
        lower.contains('realme') ||
        lower.contains('vivo') ||
        lower.contains('oppo') ||
        lower.contains('samsung') ||
        lower.contains('phone')) {
      icon = Icons.smartphone_rounded;
    } else if (lower.contains('kia') || lower.contains('car') || lower.contains('hyundai')) {
      icon = Icons.directions_car_rounded;
    }

    Color bg;
    Color iconColor;
    if (isConnected) {
      bg = const Color(0xFFDCFCE7);
      iconColor = const Color(0xFF15803D);
    } else if (isProbablePrinter) {
      bg = const Color(0xFFEFF6FF);
      iconColor = const Color(0xFF2563EB);
    } else {
      bg = const Color(0xFFF1F5F9);
      iconColor = const Color(0xFF64748B);
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: iconColor, size: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.print_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thermal Printer Connection',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Billplus / 58mm / 80mm Bluetooth Printers',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF475569)),
                    tooltip: 'Refresh devices',
                    onPressed: _loadPrinterStatus,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Available Bluetooth Devices Header
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Bluetooth Devices',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                    ),
                  ),
                  InkWell(
                    onTap: _showManualConnectDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_link_rounded, size: 13, color: Color(0xFF475569)),
                          SizedBox(width: 4),
                          Text('Manual MAC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Devices List
              Flexible(
                child: _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : _devices.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.print_rounded, color: AppColors.primary, size: 32),
                                const SizedBox(height: 8),
                                const Text(
                                  'Billplus Printer Ready to Connect',
                                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'billplus 617 (02:2D:36:C9:4E:A9)',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () => _connectToDevice(
                                    BluetoothDevice(
                                      PrinterService.defaultBillplusName,
                                      PrinterService.defaultBillplusMac,
                                    ),
                                  ),
                                  icon: const Icon(Icons.link_rounded, size: 15),
                                  label: const Text('Connect Billplus Printer', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: _devices.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final dev = _devices[index];
                              final isThisConnecting = _connectingAddress == dev.address;
                              final isThisConnected = _isConnected && _connectedDeviceAddress == dev.address;
                              final name = dev.name ?? 'Bluetooth Device';
                              final isProbablePrinter = _isPrinterDevice(name);

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isThisConnected
                                      ? const Color(0xFFF0FDF4)
                                      : (isProbablePrinter ? const Color(0xFFF8FAFC) : Colors.white),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isThisConnected
                                        ? const Color(0xFF86EFAC)
                                        : (isProbablePrinter ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0)),
                                    width: isThisConnected || isProbablePrinter ? 1.2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _buildDeviceIcon(name, isThisConnected, isProbablePrinter),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  name,
                                                  style: TextStyle(
                                                    fontWeight: isProbablePrinter ? FontWeight.w500 : FontWeight.w400,
                                                    fontSize: 13,
                                                    color: const Color(0xFF0F172A),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isProbablePrinter) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFDBEAFE),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'PRINTER',
                                                    style: TextStyle(
                                                      fontSize: 8.5,
                                                      fontWeight: FontWeight.w500,
                                                      color: Color(0xFF1D4ED8),
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (dev.address != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                dev.address!,
                                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w400),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isThisConnecting)
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    else if (isThisConnected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_rounded, color: Color(0xFF15803D), size: 14),
                                            SizedBox(width: 3),
                                            Text(
                                              'Connected',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF15803D),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      ElevatedButton(
                                        onPressed: () => _connectToDevice(dev),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isProbablePrinter ? AppColors.primary : const Color(0xFF475569),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          elevation: 0,
                                        ),
                                        child: const Text('Connect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                      ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
                                      padding: EdgeInsets.zero,
                                      tooltip: 'Printer Roles',
                                      onSelected: (val) {
                                        if (val == 'receipt') {
                                          _setAsReceiptPrinter(dev);
                                        } else if (val == 'label') {
                                          _setAsLabelPrinter(dev);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'receipt',
                                          child: Row(
                                            children: [
                                              Icon(Icons.receipt_long_rounded, color: Color(0xFF15803D), size: 16),
                                              SizedBox(width: 8),
                                              Text('Set as Bill / Receipt Printer', style: TextStyle(fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'label',
                                          child: Row(
                                            children: [
                                              Icon(Icons.qr_code_2_rounded, color: Color(0xFFB45309), size: 16),
                                              SizedBox(width: 8),
                                              Text('Set as Barcode Sticker Printer', style: TextStyle(fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
