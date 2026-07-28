import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import '../../app/app_state.dart';
import '../../core/services/currency_service.dart';
import 'receipt_service.dart';

Future<void> showBillQrDialog(
  BuildContext context, {
  required AppState state,
  required Map<String, Object?> sale,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder:
        (dialogContext) => AlertDialog(
          title: Text('Bill ${sale['bill_number']}'),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BarcodeWidget(
                  data: ReceiptService.billQrData(
                    sale: sale,
                    business: state.business,
                    settings: state.settings,
                  ),
                  barcode: Barcode.qrCode(
                    errorCorrectLevel: BarcodeQRCorrectionLevel.medium,
                  ),
                  width: 240,
                  height: 240,
                  backgroundColor: Colors.white,
                  color: Colors.black,
                  padding: const EdgeInsets.all(12),
                ),
                const SizedBox(height: 12),
                Text(
                  CurrencyService.format(
                    sale['total'] as num,
                    code: state.currencyCode,
                  ),
                  style: Theme.of(dialogContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Scan this QR code to read the bill reference and total.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
  );
}
