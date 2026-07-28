import 'package:easypos/app/app_state.dart';
import 'package:easypos/features/products/products_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Products shows Scan Barcode below Add Product', (tester) async {
    final state = AppState()
      ..settings = {'currency_code': 'LKR'}
      ..products = [];

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: ProductsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final add = find.text('Add Product');
    final scan = find.text('Scan Barcode');
    expect(add, findsOneWidget);
    expect(scan, findsOneWidget);
    expect(tester.getCenter(scan).dy, greaterThan(tester.getCenter(add).dy));
    expect(tester.takeException(), isNull);
  });
}
