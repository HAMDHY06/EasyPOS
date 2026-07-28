import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/app_state.dart';
import '../../core/models/product.dart';
import '../../core/services/currency_service.dart';
import 'product_form_screen.dart';
import '../../core/services/admin_guard.dart';
import '../../core/services/product_lookup_service.dart';
import '../scanner/barcode_scanner_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final products =
        state.products.where((p) {
          final q = _search.text.toLowerCase();
          return p.name.toLowerCase().contains(q) ||
              (p.barcode?.contains(q) ?? false);
        }).toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Products'),
        actions: [
          IconButton(
            tooltip: 'Add product',
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search name or barcode',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child:
                products.isEmpty
                    ? const Center(child: Text('No products found.'))
                    : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                      itemCount: products.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder:
                          (context, index) => _ProductCard(
                            product: products[index],
                            onEdit: _openForm,
                          ),
                    ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 8, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 13),
                  child: Text('Add Product'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _scanProduct,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 13),
                  child: Text('Scan Barcode'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm([Product? product]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
  }

  Future<void> _scanProduct() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder:
            (_) => const BarcodeScannerScreen(
              title: 'Scan product barcode',
            ),
      ),
    );
    if (barcode == null || !mounted) return;

    final state = context.read<AppState>();
    final existing = await state.database.productByBarcode(barcode);
    if (existing != null) {
      if (!mounted ||
          !await AdminGuard.authorize(
            context,
            action: 'edit the scanned product',
          )) {
        return;
      }
      if (mounted) await _openForm(existing);
      return;
    }

    ProductLookupResult? lookup;
    if (state.settings['online_lookup'] != 'false') {
      lookup = await OpenFoodFactsLookupService().lookup(barcode);
    }
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) => ProductFormScreen(
              initialBarcode: barcode,
              initialName: lookup?.name,
              initialBrand: lookup?.brand,
            ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onEdit});
  final Product product;
  final ValueChanged<Product?> onEdit;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        leading: CircleAvatar(
          child: Icon(
            product.isFavourite ? Icons.star : Icons.inventory_2_outlined,
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${CurrencyService.format(product.sellingPrice, code: state.currencyCode)} • '
          '${product.stockQuantity.toStringAsFixed(3)} ${product.unitType}\n'
          '${product.barcode ?? 'No barcode'}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') {
              if (await AdminGuard.authorize(
                context,
                action: 'edit product prices',
              )) {
                if (!context.mounted) return;
                onEdit(product);
              }
              return;
            }
            if (value == 'delete') {
              if (!await AdminGuard.authorize(
                context,
                action: 'delete this product',
              )) {
                return;
              }
              if (!context.mounted) return;
              final confirm = await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Delete product?'),
                      content: Text(product.name),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
              );
              if (confirm != true || !context.mounted) return;
              try {
                await state.database.archiveProduct(product.id!);
                await state.refreshProducts();
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              }
            }
          },
          itemBuilder:
              (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
        ),
      ),
    );
  }
}
