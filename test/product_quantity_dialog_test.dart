import 'package:easypos/core/models/product.dart';
import 'package:easypos/features/pos/product_quantity_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('quantity dialog defaults to one and returns it', (tester) async {
    double? result;
    final product = Product(
      id: 1,
      name: '7UP 500ml',
      costPrice: 200,
      sellingPrice: 250,
      stockQuantity: 10,
      lowStockLevel: 2,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: FilledButton(
                  onPressed: () async {
                    result = await showProductQuantityDialog(context, product);
                  },
                  child: const Text('Select product'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Select product'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '1'), findsOneWidget);

    await tester.tap(find.text('Add to cart'));
    await tester.pumpAndSettle();
    expect(result, 1);
  });
}
