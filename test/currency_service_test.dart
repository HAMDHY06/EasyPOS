import 'package:flutter_test/flutter_test.dart';
import 'package:easypos/core/services/currency_service.dart';

void main() {
  test('formats Sri Lankan Rupees with two decimals and separators', () {
    expect(CurrencyService.format(100), 'Rs. 100.00');
    expect(CurrencyService.format(1250), 'Rs. 1,250.00');
    expect(CurrencyService.format(25000), 'Rs. 25,000.00');
  });
}
