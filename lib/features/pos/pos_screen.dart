import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/app_state.dart';
import '../../core/models/product.dart';
import '../../core/services/currency_service.dart';
import '../scanner/barcode_scanner_screen.dart';
import '../products/product_form_screen.dart';
import 'product_quantity_dialog.dart';
import '../sales/bill_qr_dialog.dart';
import '../sales/receipt_service.dart';
import '../../core/services/product_lookup_service.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode == null || !mounted) return;
    final state = context.read<AppState>();
    final product = await state.database.productByBarcode(barcode);
    if (product != null) {
      await _confirmScannedQuantity(state, product);
      return;
    }
    ProductLookupResult? lookup;
    if (state.settings['online_lookup'] != 'false') {
      lookup = await OpenFoodFactsLookupService().lookup(barcode);
    }
    if (!mounted) return;
    final add = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              lookup == null ? 'Product not found' : 'Product found online',
            ),
            content: Text(
              lookup == null
                  ? 'Barcode $barcode is not saved on this device. Add it now?'
                  : '${lookup.name}${lookup.brand == null ? '' : '\n${lookup.brand}'}\n\nEnter your local selling price and opening stock.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add product'),
              ),
            ],
          ),
    );
    if (add == true && mounted) {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder:
              (_) => ProductFormScreen(
                initialBarcode: barcode,
                initialName: lookup?.name,
                initialBrand: lookup?.brand,
              ),
        ),
      );
      if (saved == true && mounted) {
        final newProduct = await state.database.productByBarcode(barcode);
        if (newProduct != null && mounted) {
          await _confirmScannedQuantity(state, newProduct);
        }
      }
    }
  }

  Future<void> _confirmScannedQuantity(
    AppState state,
    Product product,
  ) async {
    final quantity = await showProductQuantityDialog(context, product);
    if (quantity == null || !mounted) return;
    final inCart = state.cart
        .where((item) => item.product.id == product.id)
        .fold<double>(0, (sum, item) => sum + item.quantity);
    final allowNegative = state.settings['allow_negative_stock'] == 'true';
    if (!allowNegative && inCart + quantity > product.stockQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only ${product.stockQuantity.toStringAsFixed(3)} '
            '${product.unitType} of ${product.name} is available.',
          ),
        ),
      );
      return;
    }
    state.addToCart(product, quantity: quantity);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final query = _search.text.toLowerCase();
    final products =
        state.products
            .where(
              (p) =>
                  p.name.toLowerCase().contains(query) ||
                  (p.barcode?.contains(query) ?? false),
            )
            .toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('New sale'),
        actions: [
          Badge(
            label: Text('${state.cart.length}'),
            isLabelVisible: state.cart.isNotEmpty,
            child: IconButton(
              onPressed: state.cart.isEmpty ? null : () => _showCart(state),
              icon: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search products',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  tooltip: 'Scan barcode',
                  onPressed: _scan,
                  icon: const Icon(Icons.qr_code_scanner),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                products.isEmpty
                    ? const Center(child: Text('No matching products.'))
                    : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 110),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.08,
                          ),
                      itemCount: products.length,
                      itemBuilder: (_, index) {
                        final product = products[index];
                        return _ProductTile(
                          product: product,
                          currency: state.currencyCode,
                          enabled:
                              state.settings['allow_negative_stock'] == 'true' ||
                              product.stockQuantity > 0,
                          onTap: () => _confirmScannedQuantity(state, product),
                        );
                      },
                    ),
          ),
        ],
      ),
      bottomSheet:
          state.cart.isEmpty
              ? null
              : SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 18),
                    ],
                  ),
                  child: FilledButton(
                    onPressed: () => _showCart(state),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${state.cart.length} items'),
                          Text(
                            CurrencyService.format(
                              state.subtotal + state.tax,
                              code: state.currencyCode,
                            ),
                          ),
                          const Text('View cart'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
    );
  }

  Future<void> _showCart(AppState state) async {
    final sale = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (_) =>
              const FractionallySizedBox(heightFactor: .9, child: _CartSheet()),
    );
    if (sale != null && mounted) {
      await _showCompletedSale(state, sale);
    }
  }

  Future<void> _showCompletedSale(
    AppState state,
    Map<String, Object?> sale,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 48,
            ),
            title: const Text('Sale completed'),
            content: Text(
              '${sale['bill_number']}\n'
              '${CurrencyService.format(sale['total'] as num, code: state.currencyCode)}',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 'done'),
                child: const Text('Done'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(dialogContext, 'qr'),
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Show QR'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, 'share'),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share bill'),
              ),
            ],
          ),
    );
    if (!mounted) return;
    if (action == 'qr') {
      await showBillQrDialog(context, state: state, sale: sale);
    } else if (action == 'share') {
      await ReceiptService.shareReceipt(
        sale: sale,
        business: state.business,
        settings: state.settings,
      );
    }
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.currency,
    required this.enabled,
    required this.onTap,
  });
  final Product product;
  final String currency;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final out = product.stockQuantity <= 0;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: enabled ? onTap : null,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.shopping_bag_outlined),
              ),
              const Spacer(),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                CurrencyService.format(product.sellingPrice, code: currency),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                out
                    ? 'Out of stock'
                    : '${product.stockQuantity.toStringAsFixed(3)} ${product.unitType}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartSheet extends StatefulWidget {
  const _CartSheet();

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  final _discount = TextEditingController(text: '0');
  final _paid = TextEditingController();
  final _customer = TextEditingController();
  final _phone = TextEditingController();
  String _method = 'cash';
  bool _processing = false;

  @override
  void dispose() {
    for (final c in [_discount, _paid, _customer, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final discount = double.tryParse(_discount.text) ?? 0;
    final total =
        (state.subtotal + state.tax - discount)
            .clamp(0, double.infinity)
            .toDouble();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Shopping cart'),
        actions: [
          TextButton(onPressed: state.clearCart, child: const Text('Clear')),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [
          ...state.cart.map(
            (item) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            CurrencyService.format(
                              item.total,
                              code: state.currencyCode,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => state.changeQuantity(item, -1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      item.quantity.toStringAsFixed(0),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () {
                        if (!state.changeQuantity(item, 1)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Only ${item.product.stockQuantity.toStringAsFixed(3)} '
                                '${item.product.unitType} available.',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    IconButton(
                      onPressed: () => state.removeFromCart(item),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customer,
                  decoration: const InputDecoration(
                    labelText: 'Customer (optional)',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _discount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Discount'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Payment method'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'card', child: Text('Card')),
              DropdownMenuItem(
                value: 'bank_transfer',
                child: Text('Bank transfer'),
              ),
              DropdownMenuItem(
                value: 'mobile_payment',
                child: Text('Mobile payment'),
              ),
              DropdownMenuItem(value: 'credit', child: Text('Credit')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (value) => setState(() => _method = value ?? 'cash'),
          ),
          if (_method == 'cash' || _method == 'credit') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _paid,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText:
                    _method == 'cash' ? 'Amount received' : 'Initial payment',
              ),
            ),
          ],
          const SizedBox(height: 18),
          _amountRow('Subtotal', state.subtotal, state),
          _amountRow('Tax', state.tax, state),
          _amountRow('Discount', -discount, state),
          const Divider(height: 24),
          _amountRow('Total', total, state, prominent: true),
          if (_method == 'cash' && (double.tryParse(_paid.text) ?? 0) >= total)
            _amountRow(
              'Balance',
              (double.tryParse(_paid.text) ?? 0) - total,
              state,
            ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed:
                _processing || state.cart.isEmpty
                    ? null
                    : () => _checkout(state, total),
            icon:
                _processing
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.check_circle_outline),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Text('Complete sale'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(
    String label,
    double amount,
    AppState state, {
    bool prominent = false,
  }) {
    final style =
        prominent
            ? Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)
            : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            CurrencyService.format(amount, code: state.currencyCode),
            style: style,
          ),
        ],
      ),
    );
  }

  Future<void> _checkout(AppState state, double total) async {
    setState(() => _processing = true);
    try {
      final amount =
          _method == 'cash'
              ? double.tryParse(_paid.text) ?? 0
              : _method == 'credit'
              ? double.tryParse(_paid.text) ?? 0
              : total;
      final sale = await state.checkout(
        discount: double.tryParse(_discount.text) ?? 0,
        paymentMethod: _method,
        amountPaid: amount,
        customerName: _customer.text,
        customerPhone: _phone.text,
      );
      final fullSale = await state.database.getSale(sale['id'] as int);
      if (!mounted) return;
      Navigator.pop(context, fullSale ?? sale);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

}
