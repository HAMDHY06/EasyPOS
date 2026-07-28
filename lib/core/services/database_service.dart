import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/product.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _database;
  Future<Database> get database async => _database ??= await _openDatabase();

  Future<Database> _openDatabase() async {
    final root = await getDatabasesPath();
    return openDatabase(
      p.join(root, 'easypos.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE business (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            name TEXT NOT NULL,
            owner_name TEXT NOT NULL,
            phone TEXT,
            address TEXT,
            logo_path TEXT,
            admin_pin_hash TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            description TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            barcode TEXT UNIQUE,
            category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
            brand TEXT,
            cost_price REAL NOT NULL DEFAULT 0 CHECK(cost_price >= 0),
            selling_price REAL NOT NULL CHECK(selling_price >= 0),
            stock_quantity REAL NOT NULL DEFAULT 0,
            low_stock_level REAL NOT NULL DEFAULT 5,
            unit_type TEXT NOT NULL DEFAULT 'pcs',
            tax_percentage REAL NOT NULL DEFAULT 0,
            image_path TEXT,
            expiry_date TEXT,
            notes TEXT,
            is_favourite INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT UNIQUE,
            balance REAL NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sales (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bill_number TEXT NOT NULL UNIQUE,
            customer_id INTEGER REFERENCES customers(id) ON DELETE SET NULL,
            customer_name TEXT,
            customer_phone TEXT,
            subtotal REAL NOT NULL,
            discount REAL NOT NULL DEFAULT 0,
            tax REAL NOT NULL DEFAULT 0,
            total REAL NOT NULL,
            payment_method TEXT NOT NULL,
            payment_status TEXT NOT NULL DEFAULT 'paid',
            amount_paid REAL NOT NULL,
            balance REAL NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'completed',
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sale_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sale_id INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
            product_id INTEGER NOT NULL REFERENCES products(id),
            product_name TEXT NOT NULL,
            quantity REAL NOT NULL,
            unit_price REAL NOT NULL,
            cost_price REAL NOT NULL,
            tax REAL NOT NULL DEFAULT 0,
            total REAL NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sale_id INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
            method TEXT NOT NULL,
            amount REAL NOT NULL,
            reference TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE stock_movements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER NOT NULL REFERENCES products(id),
            type TEXT NOT NULL,
            quantity REAL NOT NULL,
            previous_quantity REAL NOT NULL,
            new_quantity REAL NOT NULL,
            reason TEXT NOT NULL,
            reference TEXT,
            actor TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE barcode_batches (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            layout TEXT NOT NULL,
            file_path TEXT,
            label_count INTEGER NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_products_name ON products(name)');
        await db.execute('CREATE INDEX idx_sales_created ON sales(created_at)');
        await db.execute(
          'CREATE INDEX idx_stock_product ON stock_movements(product_id)',
        );
        await _seed(db);
      },
    );
  }

  Future<void> _seed(Database db) async {
    final settings = {
      'currency_code': 'LKR',
      'currency_symbol': 'Rs.',
      'theme_mode': 'system',
      'default_tax': '0',
      'bill_prefix': 'EP',
      'bill_footer': 'Thank you for shopping with us!',
      'allow_negative_stock': 'false',
      'online_lookup': 'true',
      'biometric_enabled': 'false',
      'next_bill_number': '1',
    };
    for (final entry in settings.entries) {
      await db.insert('app_settings', {'key': entry.key, 'value': entry.value});
    }
    final now = DateTime.now().toIso8601String();
    await db.insert('categories', {'name': 'Beverages'});
    await db.insert('categories', {'name': 'Groceries'});
    final samples = [
      {
        'name': '7UP 500ml',
        'barcode': '4791044000357',
        'category_id': 1,
        'brand': '7UP',
        'cost_price': 220.0,
        'selling_price': 250.0,
        'stock_quantity': 24.0,
        'low_stock_level': 5.0,
        'unit_type': 'pcs',
        'tax_percentage': 0.0,
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Milk 1L',
        'barcode': '2000000000015',
        'category_id': 2,
        'brand': 'Sample',
        'cost_price': 390.0,
        'selling_price': 450.0,
        'stock_quantity': 12.0,
        'low_stock_level': 4.0,
        'unit_type': 'pcs',
        'tax_percentage': 0.0,
        'created_at': now,
        'updated_at': now,
      },
    ];
    for (final sample in samples) {
      await db.insert('products', sample);
    }
  }

  Future<bool> hasBusiness() async {
    final db = await database;
    final rows = await db.query('business', limit: 1);
    return rows.isNotEmpty;
  }

  Future<Map<String, Object?>?> getBusiness() async {
    final db = await database;
    final rows = await db.query('business', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> saveBusiness(Map<String, Object?> values) async {
    final db = await database;
    await db.insert('business', {
      ...values,
      'id': 1,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>> getSettings() async {
    final db = await database;
    final rows = await db.query('app_settings');
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Product>> getProducts({String query = ''}) async {
    final db = await database;
    final rows = await db.query(
      'products',
      where: query.trim().isEmpty ? null : 'name LIKE ? OR barcode LIKE ?',
      whereArgs: query.trim().isEmpty ? null : ['%$query%', '%$query%'],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<List<Map<String, Object?>>> getCategories() async {
    final db = await database;
    return db.query('categories', orderBy: 'name COLLATE NOCASE');
  }

  Future<int> addCategory(String name) async {
    final db = await database;
    return db.insert('categories', {
      'name': name.trim(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<Product?> productByBarcode(String barcode) async {
    final db = await database;
    final rows = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  Future<int> saveProduct(
    Product product, {
    bool updateDuplicate = false,
  }) async {
    final db = await database;
    if (product.id != null) {
      await db.update(
        'products',
        product.toMap(),
        where: 'id = ?',
        whereArgs: [product.id],
      );
      return product.id!;
    }
    try {
      return await db.insert('products', product.toMap());
    } on DatabaseException {
      if (!updateDuplicate || product.barcode == null) rethrow;
      final existing = await productByBarcode(product.barcode!);
      if (existing == null) rethrow;
      await db.update(
        'products',
        product.toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return existing.id!;
    }
  }

  Future<void> archiveProduct(int id) async {
    final db = await database;
    final used =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM sale_items WHERE product_id = ?',
            [id],
          ),
        ) ??
        0;
    if (used > 0) {
      throw StateError('Products used in sales cannot be deleted.');
    }
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> adjustStock({
    required Product product,
    required double change,
    required String reason,
    String actor = 'Owner',
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [product.id],
      );
      if (rows.isEmpty) throw StateError('Product not found.');
      final current = (rows.first['stock_quantity'] as num).toDouble();
      final next = current + change;
      if (next < 0) throw StateError('Stock cannot be below zero.');
      await txn.update(
        'products',
        {
          'stock_quantity': next,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [product.id],
      );
      await txn.insert('stock_movements', {
        'product_id': product.id,
        'type': change >= 0 ? 'in' : 'out',
        'quantity': change.abs(),
        'previous_quantity': current,
        'new_quantity': next,
        'reason': reason,
        'actor': actor,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<Map<String, Object?>> completeSale({
    required List<CartItem> items,
    required double discount,
    required String paymentMethod,
    required double amountPaid,
    String? customerName,
    String? customerPhone,
  }) async {
    if (items.isEmpty) throw StateError('Cart is empty.');
    final db = await database;
    return db.transaction((txn) async {
      final settingsRows = await txn.query('app_settings');
      final settings = {
        for (final row in settingsRows)
          row['key'] as String: row['value'] as String,
      };
      final allowNegative = settings['allow_negative_stock'] == 'true';
      final number = int.parse(settings['next_bill_number'] ?? '1');
      final prefix = settings['bill_prefix'] ?? 'EP';
      final year = DateTime.now().year;
      final billNumber = '$prefix-$year-${number.toString().padLeft(6, '0')}';

      double subtotal = 0;
      double tax = 0;
      for (final item in items) {
        subtotal += item.total;
        tax += item.tax;
        final rows = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [item.product.id],
        );
        if (rows.isEmpty) throw StateError('${item.product.name} was removed.');
        final available = (rows.first['stock_quantity'] as num).toDouble();
        if (!allowNegative && item.quantity > available) {
          throw StateError(
            'Only ${available.toStringAsFixed(3)} ${item.product.name} available.',
          );
        }
      }
      final total = (subtotal - discount + tax).clamp(0, double.infinity);
      if (paymentMethod == 'cash' && amountPaid < total) {
        throw StateError('Amount received is less than the total.');
      }
      final isCredit = paymentMethod == 'credit';
      final paid = isCredit ? amountPaid.clamp(0, total) : total;
      final balance =
          isCredit
              ? total - paid
              : (amountPaid - total).clamp(0, double.infinity);
      final now = DateTime.now().toIso8601String();
      final saleId = await txn.insert('sales', {
        'bill_number': billNumber,
        'customer_name': customerName?.trim(),
        'customer_phone': customerPhone?.trim(),
        'subtotal': subtotal,
        'discount': discount,
        'tax': tax,
        'total': total,
        'payment_method': paymentMethod,
        'payment_status': isCredit && balance > 0 ? 'due' : 'paid',
        'amount_paid': paid,
        'balance': balance,
        'status': 'completed',
        'created_at': now,
      });
      for (final item in items) {
        final rows = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [item.product.id],
        );
        final previous = (rows.first['stock_quantity'] as num).toDouble();
        final next = previous - item.quantity;
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': item.product.id,
          'product_name': item.product.name,
          'quantity': item.quantity,
          'unit_price': item.product.sellingPrice,
          'cost_price': item.product.costPrice,
          'tax': item.tax,
          'total': item.total,
        });
        await txn.update(
          'products',
          {'stock_quantity': next, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [item.product.id],
        );
        await txn.insert('stock_movements', {
          'product_id': item.product.id,
          'type': 'sale',
          'quantity': item.quantity,
          'previous_quantity': previous,
          'new_quantity': next,
          'reason': 'Sale',
          'reference': billNumber,
          'actor': 'Owner',
          'created_at': now,
        });
      }
      if (paid > 0) {
        await txn.insert('payments', {
          'sale_id': saleId,
          'method': paymentMethod,
          'amount': paid,
          'created_at': now,
        });
      }
      await txn.update(
        'app_settings',
        {'value': (number + 1).toString()},
        where: 'key = ?',
        whereArgs: ['next_bill_number'],
      );
      return {
        'id': saleId,
        'bill_number': billNumber,
        'subtotal': subtotal,
        'discount': discount,
        'tax': tax,
        'total': total,
        'amount_paid': paid,
        'balance': balance,
        'payment_method': paymentMethod,
        'created_at': now,
      };
    });
  }

  Future<List<Map<String, Object?>>> getSales({String query = ''}) async {
    final db = await database;
    return db.query(
      'sales',
      where:
          query.trim().isEmpty
              ? null
              : 'bill_number LIKE ? OR customer_name LIKE ?',
      whereArgs: query.trim().isEmpty ? null : ['%$query%', '%$query%'],
      orderBy: 'created_at DESC',
    );
  }

  Future<Map<String, Object?>?> getSale(int id) async {
    final db = await database;
    final rows = await db.query('sales', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return {
      ...rows.first,
      'items': await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [id],
        orderBy: 'id',
      ),
    };
  }

  Future<void> cancelSale(int saleId, {String reason = 'Cancelled'}) async {
    final db = await database;
    await db.transaction((txn) async {
      final salesRows = await txn.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
      );
      if (salesRows.isEmpty || salesRows.first['status'] != 'completed') {
        throw StateError('Only completed sales can be cancelled.');
      }
      final items = await txn.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );
      final now = DateTime.now().toIso8601String();
      for (final item in items) {
        final productId = item['product_id'] as int;
        final quantity = (item['quantity'] as num).toDouble();
        final productsRows = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [productId],
        );
        final previous =
            (productsRows.first['stock_quantity'] as num).toDouble();
        final next = previous + quantity;
        await txn.update(
          'products',
          {'stock_quantity': next, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [productId],
        );
        await txn.insert('stock_movements', {
          'product_id': productId,
          'type': 'refund',
          'quantity': quantity,
          'previous_quantity': previous,
          'new_quantity': next,
          'reason': reason,
          'reference': salesRows.first['bill_number'],
          'actor': 'Owner',
          'created_at': now,
        });
      }
      await txn.update(
        'sales',
        {'status': 'cancelled'},
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });
  }

  Future<void> addCreditPayment({
    required int saleId,
    required double amount,
  }) async {
    if (amount <= 0) throw StateError('Payment must be greater than zero.');
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
      );
      if (rows.isEmpty || rows.first['status'] != 'completed') {
        throw StateError('Sale is not available.');
      }
      final currentBalance = (rows.first['balance'] as num).toDouble();
      if (currentBalance <= 0) throw StateError('This bill is already paid.');
      if (amount > currentBalance) {
        throw StateError('Payment exceeds the outstanding balance.');
      }
      final paid = (rows.first['amount_paid'] as num).toDouble() + amount;
      final balance = currentBalance - amount;
      final now = DateTime.now().toIso8601String();
      await txn.insert('payments', {
        'sale_id': saleId,
        'method': 'credit_payment',
        'amount': amount,
        'created_at': now,
      });
      await txn.update(
        'sales',
        {
          'amount_paid': paid,
          'balance': balance,
          'payment_status': balance <= 0 ? 'paid' : 'due',
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });
  }

  Future<Map<String, num>> dashboardStats() async {
    final db = await database;
    final today = DateTime.now();
    final start =
        DateTime(today.year, today.month, today.day).toIso8601String();
    final revenue = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) total, COUNT(*) count FROM sales WHERE status='completed' AND created_at >= ?",
      [start],
    );
    final productStats = await db.rawQuery('''
      SELECT COUNT(*) total,
      SUM(CASE WHEN stock_quantity <= low_stock_level THEN 1 ELSE 0 END) low
      FROM products
    ''');
    return {
      'revenue': (revenue.first['total'] as num?) ?? 0,
      'bills': (revenue.first['count'] as num?) ?? 0,
      'products': (productStats.first['total'] as num?) ?? 0,
      'lowStock': (productStats.first['low'] as num?) ?? 0,
    };
  }

  Future<List<Map<String, Object?>>> reportSalesByDay({int days = 30}) async {
    final db = await database;
    final since =
        DateTime.now().subtract(Duration(days: days)).toIso8601String();
    return db.rawQuery(
      '''
      SELECT substr(created_at, 1, 10) day, COUNT(*) bills,
      COALESCE(SUM(total), 0) revenue
      FROM sales
      WHERE status = 'completed' AND created_at >= ?
      GROUP BY substr(created_at, 1, 10)
      ORDER BY day DESC
    ''',
      [since],
    );
  }

  Future<List<Map<String, Object?>>> bestSellers() async {
    final db = await database;
    return db.rawQuery('''
      SELECT product_name, SUM(quantity) quantity, SUM(total) revenue
      FROM sale_items
      GROUP BY product_id, product_name
      ORDER BY quantity DESC LIMIT 10
    ''');
  }

  Future<Map<String, Object?>> reportOverview() async {
    final db = await database;
    final profit = await db.rawQuery('''
      SELECT COALESCE(SUM((si.unit_price - si.cost_price) * si.quantity
        - (s.discount * (si.total / NULLIF(s.subtotal, 0)))), 0) profit
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      WHERE s.status = 'completed'
    ''');
    final methods = await db.rawQuery('''
      SELECT payment_method, COUNT(*) bills, SUM(total) total
      FROM sales WHERE status = 'completed'
      GROUP BY payment_method ORDER BY total DESC
    ''');
    return {'profit': profit.first['profit'] ?? 0, 'methods': methods};
  }

  Future<void> saveBarcodeBatch({
    required String title,
    required String layout,
    required int labelCount,
    String? filePath,
  }) async {
    final db = await database;
    await db.insert('barcode_batches', {
      'title': title,
      'layout': layout,
      'file_path': filePath,
      'label_count': labelCount,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<File> backupDatabase() async {
    final db = await database;
    final output = await getApplicationDocumentsDirectory();
    final target = File(
      p.join(
        output.path,
        'EasyPOS_backup_${DateTime.now().millisecondsSinceEpoch}.db',
      ),
    );
    await File(db.path).copy(target.path);
    return target;
  }

  Future<void> restoreDatabase(File source) async {
    final candidate = await openDatabase(source.path, readOnly: true);
    try {
      final rows = await candidate.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final names = rows.map((row) => row['name']).toSet();
      const required = {'business', 'products', 'sales', 'app_settings'};
      if (!names.containsAll(required)) {
        throw const FormatException('This is not a valid EasyPOS backup.');
      }
    } finally {
      await candidate.close();
    }
    final current = await database;
    final targetPath = current.path;
    await current.close();
    _database = null;
    await source.copy(targetPath);
  }

  Future<void> resetDatabase() async {
    final current = await database;
    final path = current.path;
    await current.close();
    _database = null;
    await deleteDatabase(path);
    await database;
  }
}
