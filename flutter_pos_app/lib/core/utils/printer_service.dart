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

  Future<bool> autoPrintReceipt(Order order, {String? storeName}) async {
    try {
      bool? isConnected = await bluetooth.isConnected;
      if (isConnected == true) {
        await printReceipt(order, storeName: storeName);
        return true;
      }
      final devices = await getDevices();
      if (devices.isNotEmpty) {
        final connected = await connect(devices.first);
        if (connected) {
          await printReceipt(order, storeName: storeName);
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> printReceipt(Order order, {String? storeName}) async {
    bool? isConnected = await bluetooth.isConnected;
    if (isConnected != true) {
      throw Exception('Printer not connected');
    }

    final formattedDate = DateFormat('dd/MM/yyyy, hh:mm a').format(order.dateTime);
    final totalQty = order.items.fold<int>(0, (sum, it) => sum + it.quantity);
    final store = (storeName != null && storeName.trim().isNotEmpty) ? storeName.trim().toUpperCase() : "RETAIL VERSE SUPERMARKET";

    // Header (DMart Supermarket Style)
    bluetooth.printCustom(store, 2, 1); // Size 2, Align Center (1)
    bluetooth.printCustom("*** TAX INVOICE / CASH MEMO ***", 1, 1);
    bluetooth.printNewLine();

    // Order Info
    bluetooth.printCustom("Bill No: #${order.orderId}", 0, 0);
    bluetooth.printCustom("Date: $formattedDate", 0, 0);
    bluetooth.printCustom("Cashier: ${order.cashierName ?? 'Staff 01'} | POS: 01", 0, 0);
    if (order.customerName != null && order.customerName!.isNotEmpty) {
      bluetooth.printCustom("Customer: ${order.customerName} (${order.customerPhone ?? ''})", 0, 0);
    }
    bluetooth.printNewLine();
    
    bluetooth.printCustom("--------------------------------", 0, 1);

    // Items Header
    bluetooth.printLeftRight("ITEM", "AMOUNT", 0);
    bluetooth.printCustom("--------------------------------", 0, 1);

    // Items
    for (var item in order.items) {
      bluetooth.printCustom(item.product.name.toUpperCase(), 0, 0);
      bluetooth.printLeftRight("  ${item.quantity} PCS x Rs.${item.price.toStringAsFixed(2)}", "Rs.${item.total.toStringAsFixed(2)}", 0);
    }

    bluetooth.printCustom("--------------------------------", 0, 1);

    // Supermarket Item Count & Totals
    bluetooth.printLeftRight("Total Items: ${order.items.length}", "Total Qty: $totalQty", 0);
    bluetooth.printLeftRight("Subtotal", "Rs.${order.subtotal.toStringAsFixed(2)}", 0);
    if (order.discount > 0) {
      bluetooth.printLeftRight("Store Savings/Discount", "-Rs.${order.discount.toStringAsFixed(2)}", 0);
    }
    if (order.tax > 0) {
      bluetooth.printLeftRight("GST/Tax (Incl.)", "Rs.${order.tax.toStringAsFixed(2)}", 0);
    }
    
    bluetooth.printCustom("================================", 0, 1);
    bluetooth.printLeftRight("NET PAYABLE", "Rs.${order.total.toStringAsFixed(2)}", 1); // Size 1 for total
    bluetooth.printCustom("Payment Mode: ${order.paymentMethod.toUpperCase()}", 0, 0);
    bluetooth.printCustom("================================", 0, 1);
    
    if (order.discount > 0) {
      bluetooth.printCustom("*** YOU SAVED: Rs.${order.discount.toStringAsFixed(2)} ***", 1, 1);
      bluetooth.printCustom("--------------------------------", 0, 1);
    }

    final hasRewardCoupon = (order.rewardCouponCode != null && order.rewardCouponCode!.isNotEmpty) ||
        order.subtotal >= 3000 ||
        order.total >= 3000;
    if (hasRewardCoupon) {
      final rewardCode = (order.rewardCouponCode != null && order.rewardCouponCode!.isNotEmpty)
          ? order.rewardCouponCode!
          : 'SAVE300-${order.orderId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').substring(0, 4).toUpperCase()}';

      bluetooth.printNewLine();
      bluetooth.printCustom("--- REWARD COUPON UNLOCKED ---", 1, 1);
      bluetooth.printCustom("CODE: $rewardCode", 2, 1);
      bluetooth.printCustom("Flat Rs.300 OFF on Next Shopping", 0, 1);
      bluetooth.printCustom("Min Order: Rs.3,000 (30 Days)", 0, 1);
      bluetooth.printCustom("--------------------------------", 0, 1);
    }

    bluetooth.printNewLine();
    bluetooth.printCustom("Goods exchange within 7 days with bill", 0, 1);
    bluetooth.printCustom("Thank you for shopping with us!", 1, 1);
    bluetooth.printCustom("Please Visit Again", 0, 1);
    
    // Add extra lines to feed the paper and cut
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut();
  }
}
