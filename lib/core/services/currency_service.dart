import 'package:intl/intl.dart';

class CurrencyService {
  static const Map<String, String> symbols = {
    'LKR': 'Rs.',
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
    'INR': '₹',
  };

  static String format(num amount, {String code = 'LKR'}) {
    final symbol = symbols[code] ?? code;
    return '$symbol ${NumberFormat('#,##0.00', 'en_US').format(amount)}';
  }
}
