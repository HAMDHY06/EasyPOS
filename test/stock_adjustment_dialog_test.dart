import 'package:easypos/core/models/product.dart';
import 'package:easypos/features/stock/stock_adjustment_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final product = Product(
    id: 1,
    name: '7UP 500ml',
    costPrice: 200,
    sellingPrice: 250,
    stockQuantity: 10,
    lowStockLevel: 2,
  );

  testWidgets('stock dialog safely returns a positive adjustment', (
    tester,
  ) async {
    StockAdjustment? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: FilledButton(
                  onPressed: () async {
                    result = await showStockAdjustmentDialog(
                      context,
                      product: product,
                      positive: true,
                    );
                  },
                  child: const Text('Adjust'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Adjust'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.text('Save stock'));
    await tester.pumpAndSettle();

    expect(result?.change, 5);
    expect(result?.reason, 'New stock received');
    expect(tester.takeException(), isNull);
  });

  testWidgets('stock dialog prevents removing more than available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: FilledButton(
                  onPressed:
                      () => showStockAdjustmentDialog(
                        context,
                        product: product,
                        positive: false,
                      ),
                  child: const Text('Remove'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '11');
    await tester.tap(find.text('Save stock'));
    await tester.pump();

    expect(find.textContaining('Only 10.000 pcs is available'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
