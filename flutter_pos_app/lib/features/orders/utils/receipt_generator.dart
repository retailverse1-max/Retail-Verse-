import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:retail_verse_pos/data/models/order_model.dart';
import 'package:retail_verse_pos/features/settings/domain/models/pos_settings.dart';
import '../../../core/branding/app_branding.dart';

/// Enterprise Grade Supermarket (DMart Style) 80mm Thermal Receipt Generator
class ReceiptGenerator {
  static Future<Uint8List> generateReceiptPdf(
    Order order, {
    PosSettings? settings,
  }) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);

    pw.MemoryImage? logoImage;
    if (settings != null &&
        settings.showShopLogoOnInvoice &&
        settings.businessLogoPath.isNotEmpty) {
      try {
        final logoFile = File(settings.businessLogoPath);
        if (logoFile.existsSync()) {
          final bytes = await logoFile.readAsBytes();
          logoImage = pw.MemoryImage(bytes);
        }
      } catch (_) {}
    }

    final storeTitle = (settings?.storeName.isNotEmpty ?? false)
        ? settings!.storeName.trim()
        : '${AppBranding.getStoreName().toUpperCase()} SUPERMARKET';

    final bool showTax = settings?.showTaxOnBill ?? true;

    final footerText = (settings?.invoiceFooterNote.isNotEmpty ?? false)
        ? settings!.invoiceFooterNote.trim()
        : 'Thank you for shopping with us! Please visit again.';

    // Default to 80mm continuous thermal receipt roll (Supermarket / DMart standard)
    final pageFormat = settings?.receiptSize == '58mm'
        ? PdfPageFormat.roll57
        : PdfPageFormat.roll80;

    final formattedDate = DateFormat('dd/MM/yyyy  hh:mm a').format(order.dateTime);
    final totalQty = order.items.fold<int>(0, (sum, it) => sum + it.quantity);
    final totalItems = order.items.length;
    final totalSavings = order.discount;

    final hasRewardCoupon = (order.rewardCouponCode != null && order.rewardCouponCode!.isNotEmpty) ||
        order.subtotal >= 3000 ||
        order.total >= 3000;
    final rewardCode = (order.rewardCouponCode != null && order.rewardCouponCode!.isNotEmpty)
        ? order.rewardCouponCode!
        : 'SAVE300-${order.orderId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').substring(0, 4).toUpperCase()}';

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.symmetric(horizontal: 5 * PdfPageFormat.mm, vertical: 6 * PdfPageFormat.mm),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // Store Logo (if available)
              if (logoImage != null) ...[
                pw.Center(
                  child: pw.Image(
                    logoImage,
                    width: 50,
                    height: 50,
                    fit: pw.BoxFit.contain,
                  ),
                ),
                pw.SizedBox(height: 4),
              ],

              // Store Name Header (DMart Supermarket Style)
              pw.Center(
                child: pw.Text(
                  storeTitle.toUpperCase(),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (settings?.storeAddress.isNotEmpty ?? false) ...[
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    settings!.storeAddress,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 7.5),
                  ),
                ),
              ],
              if (showTax && (settings?.gstTaxId.isNotEmpty ?? false)) ...[
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    'GSTIN: ${settings!.gstTaxId}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.8),
                  ),
                  child: pw.Text(
                    showTax ? 'TAX INVOICE / CASH MEMO' : 'RETAIL INVOICE / CASH MEMO',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),

              pw.SizedBox(height: 8),
              pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.8),

              // Invoice & POS Metadata
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bill No: #${order.orderId}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Date: $formattedDate', style: const pw.TextStyle(fontSize: 7.5)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Cashier: ${order.cashierName ?? 'Staff 01'}', style: const pw.TextStyle(fontSize: 7.5)),
                  pw.Text('POS Counter: POS-01', style: const pw.TextStyle(fontSize: 7.5)),
                ],
              ),
              if (order.customerName != null && order.customerName!.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Cust: ${order.customerName}', style: const pw.TextStyle(fontSize: 7.5)),
                    if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                      pw.Text('Mob: ${order.customerPhone}', style: const pw.TextStyle(fontSize: 7.5)),
                  ],
                ),
              ],

              pw.SizedBox(height: 6),
              pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.8),

              // Items Table Header
              pw.Row(
                children: [
                  pw.Expanded(flex: 5, child: pw.Text('ITEM DESCRIPTION', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('QTY', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('RATE', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 3, child: pw.Text('AMOUNT', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.6),

              // Items List
              ...order.items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item.product.name.toUpperCase(),
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            flex: 5,
                            child: pw.Text(
                              item.product.barcode?.isNotEmpty == true ? 'SKU: ${item.product.barcode}' : '',
                              style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text('${item.quantity} PCS', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5)),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text('Rs.${item.price.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5)),
                          ),
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text('Rs.${item.total.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 6),
              pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.8),

              // Supermarket Item Count & Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Items: $totalItems  |  Total Qty: $totalQty', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Sub Total: Rs.${order.subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              if (order.discount > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Special Store Discount:', style: const pw.TextStyle(fontSize: 7.5)),
                    pw.Text('-Rs.${order.discount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
              if (showTax && order.tax > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('GST / Tax (Included):', style: const pw.TextStyle(fontSize: 7.5)),
                    pw.Text('Rs.${order.tax.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7.5)),
                  ],
                ),
              ],
              if (order.extraCharges > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Extra Charges:', style: const pw.TextStyle(fontSize: 7.5)),
                    pw.Text('Rs.${order.extraCharges.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7.5)),
                  ],
                ),
              ],

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1.2),
              // Grand Total (D-Mart Prominent Style)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'NET PAYABLE:',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Rs. ${order.total.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.Divider(thickness: 1.2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Payment Mode: ${order.paymentMethod.toUpperCase()}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Status: PAID', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),

              // D-Mart Signature Savings Banner
              if (totalSavings > 0) ...[
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1, style: pw.BorderStyle.dashed),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Center(
                        child: pw.Text(
                          '*** YOU SAVED ON THIS PURCHASE ***',
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Center(
                        child: pw.Text(
                          'TOTAL SAVINGS: Rs. ${totalSavings.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Next Visit Reward Coupon
              if (hasRewardCoupon) ...[
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Center(
                        child: pw.Text(
                          '--- NEXT VISIT REWARD COUPON ---',
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Center(
                        child: pw.Text(
                          'COUPON: $rewardCode',
                          style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, letterSpacing: 1),
                        ),
                      ),
                      pw.SizedBox(height: 1),
                      pw.Center(
                        child: pw.Text(
                          'Flat Rs.300 OFF on your next shopping of Rs.3,000+',
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                      ),
                      pw.Center(
                        child: pw.Text(
                          'Valid for 30 Days. Present original bill at checkout.',
                          style: const pw.TextStyle(fontSize: 6.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              pw.SizedBox(height: 8),

              // Supermarket Gate Exit Barcode (Code128)
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: order.orderId,
                      width: 140,
                      height: 30,
                      drawText: false,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '* ${order.orderId} *',
                      style: const pw.TextStyle(fontSize: 7.5, letterSpacing: 1),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 6),
              pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.6),

              // Footer Terms & Conditions
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      footerText,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Goods once sold can be exchanged within 7 days with original invoice.',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 6.5),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      'Visit Again! Have a wonderful day!',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 6.5),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
