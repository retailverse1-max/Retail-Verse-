import re

file_path = '/Users/sumitgupta/retail_verse/flutter_pos_app/lib/features/orders/presentation/widgets/invoice_details_modal.dart'

with open(file_path, 'r') as f:
    content = f.read()

if "import 'package:printing/printing.dart';" not in content:
    content = content.replace("import 'package:path_provider/path_provider.dart';", "import 'package:path_provider/path_provider.dart';\nimport 'package:printing/printing.dart';")

pattern_download = re.compile(r'  Future<void> _downloadPdf\(BuildContext context, Order order\) async \{.*?\n  \}', re.DOTALL)

replacement_pdf = """  Future<pw.Document> _generatePdf(Order order) async {
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();
    
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
        italic: fontItalic,
      ),
    );

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(isQuote ? 'Quote #${order.orderId}' : 'Invoice #${order.orderId}', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('Customer: ${order.customerName ?? 'Walk-In'}'),
            if (order.customerEmail != null && order.customerEmail!.isNotEmpty) pw.Text('Email: ${order.customerEmail}'),
            if (order.customerPhone != null && order.customerPhone!.isNotEmpty) pw.Text('Phone: ${order.customerPhone}'),
            pw.Text('Date: ${AppFormatters.formatDateTime(order.dateTime)}'),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Item', 'Qty', 'Price', 'Total'],
              data: order.items.map((item) => [
                item.product.name,
                item.quantity.toString(),
                AppFormatters.formatCurrency(item.price).replaceAll('₹', 'Rs.'),
                AppFormatters.formatCurrency(item.total).replaceAll('₹', 'Rs.'),
              ]).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Subtotal: ${AppFormatters.formatCurrency(order.subtotal).replaceAll('₹', 'Rs.')}'),
                    pw.Text('Tax: ${AppFormatters.formatCurrency(order.tax).replaceAll('₹', 'Rs.')}'),
                    if (order.discount > 0) pw.Text('Discount: -${AppFormatters.formatCurrency(order.discount).replaceAll('₹', 'Rs.')}'),
                    if (order.extraCharges > 0) pw.Text('Extra Charges: +${AppFormatters.formatCurrency(order.extraCharges).replaceAll('₹', 'Rs.')}'),
                    pw.Divider(),
                    pw.Text('Total: ${AppFormatters.formatCurrency(order.total).replaceAll('₹', 'Rs.')}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                  ]
                )
              ]
            ),
            pw.SizedBox(height: 40),
            pw.Text('Thank you for your business!', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
          ],
        ),
      ),
    );

    return pdf;
  }

  Future<void> _downloadPdf(BuildContext context, Order order) async {
    try {
      final pdf = await _generatePdf(order);
      final bytes = await pdf.save();

      Directory? directory;
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          directory = downloadDir;
        } else {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        final prefix = isQuote ? 'Quote' : 'Invoice';
        File file = File('${directory.path}/${prefix}_${order.orderId}.pdf');
        
        try {
          await file.writeAsBytes(bytes);
        } catch (e) {
          if (Platform.isAndroid) {
            final fallbackDir = await getExternalStorageDirectory();
            if (fallbackDir != null) {
              file = File('${fallbackDir.path}/${prefix}_${order.orderId}.pdf');
              await file.writeAsBytes(bytes);
            } else {
              throw e;
            }
          } else {
            throw e;
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF Downloaded to ${file.path}'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        throw Exception("Could not access storage directory");
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _printPdf(BuildContext context, Order order) async {
    try {
      final pdf = await _generatePdf(order);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: isQuote ? 'Quote_${order.orderId}' : 'Invoice_${order.orderId}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }"""

content = pattern_download.sub(replacement_pdf, content)

email_find = """              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop(); // Pop loading dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email sent successfully!'),
                    backgroundColor: AppColors.success,
                  ),
                );
                Navigator.of(context).pop(); // Close the InvoiceDetailsModal
              }"""
email_replace = """              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop(); // Pop loading dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email sent successfully!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }"""
content = content.replace(email_find, email_replace)

download_find = """            if (context.mounted) {
              Navigator.of(context, rootNavigator: true).pop(); // pop loading
              Navigator.of(context).pop(); // pop modal
            }"""
download_replace = """            if (context.mounted) {
              Navigator.of(context, rootNavigator: true).pop(); // pop loading
            }"""
content = content.replace(download_find, download_replace)

print_find = """            await Future.delayed(const Duration(seconds: 1));
            if (context.mounted) {
              Navigator.of(context, rootNavigator: true).pop(); // pop loading
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Receipt Printed')),
              );
              Navigator.of(context).pop(); // pop modal
            }"""
print_replace = """            await _printPdf(context, order);
            if (context.mounted) {
              Navigator.of(context, rootNavigator: true).pop(); // pop loading
            }"""
content = content.replace(print_find, print_replace)

with open(file_path, 'w') as f:
    f.write(content)

print("Updated invoice_details_modal.dart successfully!")
