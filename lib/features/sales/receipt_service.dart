import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/services/currency_service.dart';

class ReceiptService {
  static Future<Uint8List> buildReceipt({
    required Map<String, Object?> sale,
    required Map<String, Object?>? business,
    required Map<String, String> settings,
  }) async {
    final document = pw.Document();
    final items = (sale['items'] as List).cast<Map<String, Object?>>();
    final currency = settings['currency_code'] ?? 'LKR';
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(16),
        build:
            (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'EasyPOS',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  business?['name']?.toString() ?? 'HamdhyTech',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if ((business?['address']?.toString() ?? '').isNotEmpty)
                  pw.Text(
                    business!['address'].toString(),
                    textAlign: pw.TextAlign.center,
                  ),
                if ((business?['phone']?.toString() ?? '').isNotEmpty)
                  pw.Text(
                    'Phone: ${business!['phone']}',
                    textAlign: pw.TextAlign.center,
                  ),
                pw.SizedBox(height: 8),
                pw.Divider(),
                pw.Text('Bill: ${sale['bill_number']}'),
                pw.Text('Date: ${_date(sale['created_at'])}'),
                if ((sale['customer_name']?.toString() ?? '').isNotEmpty)
                  pw.Text('Customer: ${sale['customer_name']}'),
                pw.Divider(),
                ...items.map(
                  (item) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 5),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Text(
                          item['product_name'].toString(),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              '${_number(item['quantity'])} × ${CurrencyService.format(item['unit_price'] as num, code: currency)}',
                            ),
                            pw.Text(
                              CurrencyService.format(
                                item['total'] as num,
                                code: currency,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                pw.Divider(),
                _row('Subtotal', sale['subtotal'] as num, currency),
                _row('Discount', sale['discount'] as num, currency),
                _row('Tax', sale['tax'] as num, currency),
                pw.SizedBox(height: 4),
                _row('TOTAL', sale['total'] as num, currency, bold: true),
                _row('Amount paid', sale['amount_paid'] as num, currency),
                _row('Balance', sale['balance'] as num, currency),
                pw.Text('Payment: ${sale['payment_method']}'),
                pw.SizedBox(height: 10),
                pw.BarcodeWidget(
                  data: billQrData(
                    sale: sale,
                    business: business,
                    settings: settings,
                  ),
                  barcode: pw.Barcode.qrCode(),
                  width: 70,
                  height: 70,
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  settings['bill_footer'] ?? 'Thank you for shopping with us!',
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  'Developed by HamdhyTech',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
      ),
    );
    return document.save();
  }

  static Future<void> shareReceipt({
    required Map<String, Object?> sale,
    required Map<String, Object?>? business,
    required Map<String, String> settings,
  }) async {
    final bytes = await buildReceipt(
      sale: sale,
      business: business,
      settings: settings,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'EasyPOS_${sale['bill_number']}.pdf',
    );
  }

  static String billQrData({
    required Map<String, Object?> sale,
    required Map<String, Object?>? business,
    required Map<String, String> settings,
  }) {
    final currency = settings['currency_code'] ?? 'LKR';
    return [
      'EasyPOS Bill',
      business?['name']?.toString() ?? 'HamdhyTech',
      'Bill: ${sale['bill_number']}',
      'Date: ${_date(sale['created_at'])}',
      'Total: ${CurrencyService.format(sale['total'] as num, code: currency)}',
      'Payment: ${sale['payment_method']}',
      'Status: ${sale['payment_status']}',
      'EasyPOS 1.3 by HamdhyTech',
    ].join('\n');
  }

  static pw.Widget _row(
    String label,
    num amount,
    String currency, {
    bool bold = false,
  }) {
    final style = bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null;
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(CurrencyService.format(amount, code: currency), style: style),
      ],
    );
  }

  static String _number(Object? value) =>
      (value as num).toStringAsFixed((value.toDouble() % 1 == 0) ? 0 : 3);

  static String _date(Object? value) {
    final date = DateTime.tryParse(value.toString()) ?? DateTime.now();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
