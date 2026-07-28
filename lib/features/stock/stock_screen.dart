import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/app_state.dart';
import '../../core/models/product.dart';
import '../scanner/barcode_scanner_screen.dart';
import '../products/product_form_screen.dart';
import '../../core/services/admin_guard.dart';
import '../../core/services/product_lookup_service.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode == null || !mounted) return;
    final state = context.read<AppState>();
    final product = await state.database.productByBarcode(barcode);
    if (product == null) {
      ProductLookupResult? lookup;
      if (state.settings['online_lookup'] != 'false') {
        lookup = await OpenFoodFactsLookupService().lookup(barcode);
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => ProductFormScreen(
                initialBarcode: barcode,
                initialName: lookup?.name,
                initialBrand: lookup?.brand,
              ),
        ),
      );
    } else {
      await _adjust(product, positive: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final q = _search.text.toLowerCase();
    final products =
        state.products.where((p) => p.name.toLowerCase().contains(q)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Stock management')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search products',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final product = products[index];
                final status =
                    product.stockQuantity <= 0
                        ? ('Out of stock', Colors.red)
                        : product.stockQuantity <= product.lowStockLevel
                        ? ('Low stock', Colors.orange)
                        : ('In stock', Colors.green);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(product.barcode ?? 'No barcode'),
                                ],
                              ),
                            ),
                            Chip(
                              label: Text(status.$1),
                              backgroundColor: status.$2.withValues(alpha: .12),
                              labelStyle: TextStyle(color: status.$2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${product.stockQuantity.toStringAsFixed(3)} ${product.unitType}',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Decrease stock',
                              onPressed:
                                  () => _adjust(product, positive: false),
                              icon: const Icon(Icons.remove),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              tooltip: 'Increase stock',
                              onPressed: () => _adjust(product, positive: true),
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scan,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan stock'),
      ),
    );
  }

  Future<void> _adjust(Product product, {required bool positive}) async {
    if (!await AdminGuard.authorize(context, action: 'adjust stock')) return;
    if (!mounted) return;
    final quantity = TextEditingController();
    String reason = positive ? 'New stock received' : 'Manual correction';
    final result = await showDialog<double>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text('${positive ? 'Add' : 'Remove'} stock'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${product.name}\nCurrent: ${product.stockQuantity}',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: quantity,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: reason,
                        decoration: const InputDecoration(labelText: 'Reason'),
                        items: const [
                          DropdownMenuItem(
                            value: 'New stock received',
                            child: Text('New stock received'),
                          ),
                          DropdownMenuItem(
                            value: 'Damaged',
                            child: Text('Damaged'),
                          ),
                          DropdownMenuItem(
                            value: 'Expired',
                            child: Text('Expired'),
                          ),
                          DropdownMenuItem(
                            value: 'Returned',
                            child: Text('Returned'),
                          ),
                          DropdownMenuItem(
                            value: 'Manual correction',
                            child: Text('Manual correction'),
                          ),
                          DropdownMenuItem(
                            value: 'Other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged:
                            (value) =>
                                setDialogState(() => reason = value ?? reason),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final value = double.tryParse(quantity.text);
                        if (value != null && value > 0) {
                          Navigator.pop(context, positive ? value : -value);
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
    quantity.dispose();
    if (result == null || !mounted) return;
    try {
      final state = context.read<AppState>();
      await state.database.adjustStock(
        product: product,
        change: result,
        reason: reason,
      );
      await state.refreshProducts();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}
