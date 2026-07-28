import 'package:flutter/material.dart';
import '../core/models/product.dart';
import '../core/services/database_service.dart';

class AppState extends ChangeNotifier {
  AppState({DatabaseService? database})
    : database = database ?? DatabaseService.instance;

  final DatabaseService database;
  bool initialized = false;
  bool setupComplete = false;
  Map<String, Object?>? business;
  Map<String, String> settings = {};
  List<Product> products = [];
  final List<CartItem> cart = [];
  int salesRevision = 0;
  int dataRevision = 0;

  String get currencyCode => settings['currency_code'] ?? 'LKR';
  ThemeMode get themeMode => switch (settings['theme_mode']) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> initialize() async {
    settings = await database.getSettings();
    setupComplete = await database.hasBusiness();
    business = await database.getBusiness();
    products = await database.getProducts();
    salesRevision++;
    dataRevision++;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (settings['last_auto_backup'] != today) {
      await database.backupDatabase();
      await database.setSetting('last_auto_backup', today);
      settings['last_auto_backup'] = today;
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> refreshProducts({String query = ''}) async {
    products = await database.getProducts(query: query);
    dataRevision++;
    notifyListeners();
  }

  Future<void> completeSetup(Map<String, Object?> values) async {
    await database.saveBusiness(values);
    setupComplete = true;
    business = await database.getBusiness();
    notifyListeners();
  }

  Future<void> saveBusiness(Map<String, Object?> values) async {
    await database.saveBusiness(values);
    business = await database.getBusiness();
    notifyListeners();
  }

  Future<void> setSetting(String key, String value) async {
    await database.setSetting(key, value);
    settings[key] = value;
    notifyListeners();
  }

  void addToCart(Product product, {double quantity = 1}) {
    if (quantity <= 0) return;
    final existing =
        cart.where((item) => item.product.id == product.id).firstOrNull;
    if (existing == null) {
      cart.add(CartItem(product: product, quantity: quantity));
    } else {
      existing.quantity += quantity;
    }
    notifyListeners();
  }

  void markSalesChanged() {
    salesRevision++;
    dataRevision++;
    notifyListeners();
  }

  bool changeQuantity(CartItem item, double delta) {
    if (delta > 0 &&
        settings['allow_negative_stock'] != 'true' &&
        item.quantity + delta > item.product.stockQuantity) {
      return false;
    }
    item.quantity += delta;
    if (item.quantity <= 0) cart.remove(item);
    notifyListeners();
    return true;
  }

  void removeFromCart(CartItem item) {
    cart.remove(item);
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  double get subtotal => cart.fold(0, (sum, item) => sum + item.total);
  double get tax => cart.fold(0, (sum, item) => sum + item.tax);

  Future<Map<String, Object?>> checkout({
    required double discount,
    required String paymentMethod,
    required double amountPaid,
    String? customerName,
    String? customerPhone,
  }) async {
    final sale = await database.completeSale(
      items: cart,
      discount: discount,
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
      customerName: customerName,
      customerPhone: customerPhone,
    );
    cart.clear();
    products = await database.getProducts();
    salesRevision++;
    dataRevision++;
    notifyListeners();
    return sale;
  }
}
