import 'package:easypos/app/app_state.dart';
import 'package:easypos/core/services/admin_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('admin PIN dialog unlocks and disposes safely', (tester) async {
    final state = AppState()
      ..business = {'admin_pin_hash': AdminGuard.hashPin('1234')}
      ..settings = {'biometric_enabled': 'false'};
    var allowed = false;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: FilledButton(
                    onPressed: () async {
                      allowed = await AdminGuard.authorize(
                        context,
                        action: 'open settings',
                      );
                    },
                    child: const Text('Settings'),
                  ),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Admin PIN required'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(allowed, isTrue);
    expect(find.text('Admin PIN required'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
