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
  List<BluetoothDevice> _devices = [];
  String? _connectingAddress;

  @override
  void initState() {
    super.initState();
    _loadPrinterStatus();
  }

  Future<void> _loadPrinterStatus() async {
    setState(() => _isLoading = true);
    try {
      final isConn = await _printerService.isConnected();
      final savedName = await _printerService.getSavedPrinterName();
      final savedAddress = await _printerService.getSavedPrinterAddress();
      final devices = await _printerService.getDevices();

      // Ensure billplus 617 is always in the list even if Bluetooth discovery returned empty
      if (devices.isEmpty) {
        devices.add(BluetoothDevice(PrinterService.defaultBillplusName, PrinterService.defaultBillplusMac));
      }

      if (mounted) {
        setState(() {
          _isConnected = isConn;
          _connectedDeviceName = savedName ?? (_isConnected ? PrinterService.defaultBillplusName : null);
          _connectedDeviceAddress = savedAddress ?? PrinterService.defaultBillplusMac;
          _devices = devices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${device.name ?? 'Printer'} (${device.address}) se connect nahi ho paya.\n\nKripya ye 3 cheezein check karein:',
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '1. "Billplus" label app ko Recent Apps se SWIPE-AWAY / CLOSE karein.\n   (Bluetooth printer ek samay me sirf EK app se connect hota hai! Agar Billplus app me connected hai to yahan connect nahi hoga.)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '2. Printer ka Switch ON hai ya nahi.\n3. Phone ka Bluetooth ON hai.',
                    style: TextStyle(fontSize: 12),
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
        title: const Text('Connect by MAC Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.print_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thermal Printer Connection',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        Text(
                          'Billplus / 58mm / 80mm Bluetooth Printers',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh devices',
                    onPressed: _loadPrinterStatus,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Active Connection Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isConnected ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isConnected ? const Color(0xFF86EFAC) : Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isConnected ? const Color(0xFF16A34A) : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isConnected
                                    ? 'Connected: ${_connectedDeviceName ?? 'Printer'}'
                                    : 'No Printer Connected',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: _isConnected ? const Color(0xFF15803D) : Colors.grey.shade800,
                                ),
                              ),
                              if (_connectedDeviceAddress != null)
                                Text(
                                  _connectedDeviceAddress!,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                            ],
                          ),
                        ),
                        if (_isConnected)
                          OutlinedButton(
                            onPressed: _disconnect,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade200),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Disconnect', style: TextStyle(fontSize: 12)),
                          )
                        else if (_connectedDeviceAddress != null)
                          ElevatedButton.icon(
                            onPressed: _connectingAddress != null
                                ? null
                                : () => _connectToDevice(
                                      BluetoothDevice(
                                        _connectedDeviceName ?? PrinterService.defaultBillplusName,
                                        _connectedDeviceAddress!,
                                      ),
                                    ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: _connectingAddress == _connectedDeviceAddress
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.bolt_rounded, size: 16),
                            label: const Text('Connect Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    if (_isConnected) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _testPrint,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.receipt_long_rounded, size: 16),
                            label: const Text('Print Test Slip', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Paired Devices Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available Bluetooth Devices',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _showManualConnectDialog,
                        icon: const Icon(Icons.add_link_rounded, size: 16),
                        label: const Text('Manual MAC', style: TextStyle(fontSize: 12)),
                      ),
                      TextButton.icon(
                        onPressed: () => _printerService.bluetooth.openSettings,
                        icon: const Icon(Icons.settings_bluetooth_rounded, size: 16),
                        label: const Text('Settings', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Devices List
              Flexible(
                child: _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _devices.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.print_rounded, color: AppColors.primary, size: 36),
                                const SizedBox(height: 10),
                                const Text(
                                  'Billplus Printer Ready to Connect',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'billplus 617 (02:2D:36:C9:4E:A9)',
                                  style: TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () => _connectToDevice(
                                    BluetoothDevice(
                                      PrinterService.defaultBillplusName,
                                      PrinterService.defaultBillplusMac,
                                    ),
                                  ),
                                  icon: const Icon(Icons.link_rounded, size: 16),
                                  label: const Text('Connect Billplus Printer'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: _devices.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final dev = _devices[index];
                              final isThisConnecting = _connectingAddress == dev.address;
                              final isThisConnected = _isConnected && _connectedDeviceAddress == dev.address;
                              final name = dev.name ?? 'Bluetooth Device';
                              final isProbablePrinter = name.toLowerCase().contains('billplus') ||
                                  name.toLowerCase().contains('printer') ||
                                  name.toLowerCase().contains('pos') ||
                                  name.toLowerCase().contains('mpt') ||
                                  name.toLowerCase().contains('rpp') ||
                                  name.toLowerCase().contains('thermal');

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isThisConnected
                                      ? const Color(0xFFF0FDF4)
                                      : (isProbablePrinter ? const Color(0xFFEFF6FF) : Colors.grey.shade50),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isThisConnected
                                        ? const Color(0xFF86EFAC)
                                        : (isProbablePrinter ? const Color(0xFFBFDBFE) : Colors.grey.shade200),
                                    width: isProbablePrinter || isThisConnected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: isThisConnected
                                          ? const Color(0xFFDCFCE7)
                                          : (isProbablePrinter ? const Color(0xFFDBEAFE) : Colors.grey.shade200),
                                      child: Icon(
                                        Icons.print_rounded,
                                        color: isThisConnected
                                            ? const Color(0xFF15803D)
                                            : (isProbablePrinter ? const Color(0xFF1D4ED8) : Colors.grey.shade700),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isProbablePrinter) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFDBEAFE),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'PRINTER',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF1D4ED8),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (dev.address != null)
                                            Text(
                                              dev.address!,
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isThisConnecting)
                                      const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    else if (isThisConnected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_rounded, color: Color(0xFF15803D), size: 16),
                                            SizedBox(width: 4),
                                            Text(
                                              'Connected',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
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
                                          backgroundColor: isProbablePrinter ? AppColors.primary : Colors.grey.shade800,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Connect', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
