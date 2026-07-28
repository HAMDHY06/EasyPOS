import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/app_state.dart';
import '../../core/models/product.dart';
import '../../core/services/currency_service.dart';
import 'product_form_screen.dart';
import '../../core/services/admin_guard.dart';

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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'products-add',
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Future<void> _openForm([Product? product]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
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
