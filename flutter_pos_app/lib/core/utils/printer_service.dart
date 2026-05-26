import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:retail_verse_pos/data/models/order_model.dart';

class PrinterService {
  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  Future<List<BluetoothDevice>> getDevices() async {
    try {
      return await bluetooth.getBondedDevices();
    } on PlatformException {
      return [];
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    bool? isConnected = await bluetooth.isConnected;
    if (isConnected == true) {
      return true; // Already connected
    }
    
    try {
      await bluetooth.connect(device);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    await bluetooth.disconnect();
  }

  Future<void> printReceipt(Order order) async {
    bool? isConnected = await bluetooth.isConnected;
    if (isConnected != true) {
      throw Exception('Printer not connected');
    }

    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(order.dateTime);

    // Using blue_thermal_printer's built in print methods which map directly to ESC/POS

    // Header
    bluetooth.printCustom("RETAIL VERSE STORE", 2, 1); // Size 2, Align Center (1)
    bluetooth.printCustom("Receipt / Tax Invoice", 1, 1);
    bluetooth.printNewLine();

    // Order Info
    bluetooth.printCustom("Order ID: \${order.orderId}", 0, 0);
    bluetooth.printCustom("Date: \$formattedDate", 0, 0);
    bluetooth.printCustom("Payment: \${order.paymentMethod.toUpperCase()}", 0, 0);
    if (order.customerName != null && order.customerName!.isNotEmpty) {
      bluetooth.printCustom("Customer: \${order.customerName}", 0, 0);
    }
    bluetooth.printNewLine();
    
    bluetooth.printCustom("--------------------------------", 0, 1);

    // Items Header
    bluetooth.printLeftRight("Item", "Total", 0);
    bluetooth.printCustom("--------------------------------", 0, 1);

    // Items
    for (var item in order.items) {
      bluetooth.printCustom(item.product.name, 0, 0);
      bluetooth.printLeftRight("\${item.quantity} x Rs.\${item.price.toStringAsFixed(2)}", "Rs.\${item.total.toStringAsFixed(2)}", 0);
    }

    bluetooth.printCustom("--------------------------------", 0, 1);

    // Totals
    bluetooth.printLeftRight("Subtotal", "Rs.\${order.subtotal.toStringAsFixed(2)}", 0);
    if (order.discount > 0) {
      bluetooth.printLeftRight("Discount", "-Rs.\${order.discount.toStringAsFixed(2)}", 0);
    }
    if (order.tax > 0) {
      bluetooth.printLeftRight("GST/Tax", "Rs.\${order.tax.toStringAsFixed(2)}", 0);
    }
    
    bluetooth.printCustom("--------------------------------", 0, 1);
    bluetooth.printLeftRight("GRAND TOTAL", "Rs.\${order.total.toStringAsFixed(2)}", 1); // Size 1 for total
    
    bluetooth.printNewLine();
    bluetooth.printCustom("Thank you for shopping!", 1, 1);
    bluetooth.printCustom("Visit Again", 0, 1);
    
    // Add extra lines to feed the paper and cut
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut();
  }
}
