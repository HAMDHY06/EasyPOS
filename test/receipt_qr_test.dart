import 'package:barcode_widget/barcode_widget.dart';
import 'package:easypos/app/app_state.dart';
import 'package:easypos/features/sales/bill_qr_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easypos/features/sales/receipt_service.dart';

void main() {
  test('bill QR payload stays compact and contains the bill reference', () {
    final payload = ReceiptService.billQrData(
      sale: {
        'bill_number': 'EP-2026-000123',
        'created_at': '2026-07-28T13:30:00.000',
        'total': 1250.0,
        'payment_method': 'cash',
        'payment_status': 'paid',
        'items': <Map<String, Object?>>[
          {
            'product_name': '7UP 500ml',
            'quantity': 2.0,
            'total': 500.0,
          },
        ],
      },
      business: {'name': 'Test Shop'},
      settings: {'currency_code': 'LKR'},
    );

    expect(payload, contains('EP-2026-000123'));
    expect(payload, contains('Rs. 1,250.00'));
    expect(payload, contains('EasyPOS 1.4'));
    expect(payload.length, lessThan(300));
  });

  testWidgets('bill QR dialog renders and closes without an exception', (
    tester,
  ) async {
    final state = AppState()
      ..business = {'name': 'Test Shop'}
      ..settings = {'currency_code': 'LKR'};
    final sale = <String, Object?>{
      'bill_number': 'EP-2026-000123',
      'created_at': '2026-07-28T13:30:00.000',
      'total': 1250.0,
      'payment_method': 'cash',
      'payment_status': 'paid',
      'items': <Map<String, Object?>>[],
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: FilledButton(
                  onPressed:
                      () => showBillQrDialog(
                        context,
                        state: state,
                        sale: sale,
                      ),
                  child: const Text('Show QR'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Show QR'));
    await tester.pumpAndSettle();
    expect(find.byType(BarcodeWidget), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(BarcodeWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
