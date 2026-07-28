import 'package:barcode_widget/barcode_widget.dart' as widget;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../app/app_state.dart';
import '../../core/models/product.dart';
import '../../core/services/currency_service.dart';
import '../products/product_form_screen.dart';

class BarcodeSelection {
  BarcodeSelection({required this.product, this.quantity = 1});
  final Product product;
  int quantity;
}

class BarcodeScreen extends StatefulWidget {
  const BarcodeScreen({super.key});

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  final List<BarcodeSelection> _selected = [];
  String _layout = 'three';

  Future<void> _add() async {
    final state = context.read<AppState>();
    final product = await showModalBottomSheet<Product>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Select product',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              ...state.products.map(
                (product) => ListTile(
                  leading: const Icon(Icons.qr_code_2),
                  title: Text(product.name),
                  subtitle: Text(product.barcode ?? 'No barcode'),
                  onTap:
                      product.barcode == null
                          ? null
                          : () => Navigator.pop(context, product),
                ),
              ),
            ],
          ),
    );
    if (product == null) return;
    setState(() {
      final existing =
          _selected
              .where((entry) => entry.product.id == product.id)
              .firstOrNull;
      if (existing == null) {
        _selected.add(BarcodeSelection(product: product));
      } else {
        existing.quantity++;
      }
    });
  }

  Future<void> _createProductBarcode() async {
    final name = TextEditingController();
    final price = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final details = await showDialog<(String, double)>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Create product barcode'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Product name',
                    ),
                    validator:
                        (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Required'
                                : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Selling price',
                      prefixText: 'Rs. ',
                    ),
                    validator: (value) {
                      final amount = double.tryParse(value ?? '');
                      return amount == null || amount < 0
                          ? 'Enter a valid price'
                          : null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(
                      context,
                      (name.text.trim(), double.parse(price.text)),
                    );
                  }
                },
                child: const Text('Generate'),
              ),
            ],
          ),
    );
    name.dispose();
    price.dispose();
    if (details == null || !mounted) return;

    final barcode = 'EP${DateTime.now().millisecondsSinceEpoch}';
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) => ProductFormScreen(
              initialName: details.$1,
              initialPrice: details.$2,
              initialBarcode: barcode,
            ),
      ),
    );
    if (saved != true || !mounted) return;
    final state = context.read<AppState>();
    final product = await state.database.productByBarcode(barcode);
    if (product != null && mounted) {
      setState(() => _selected.add(BarcodeSelection(product: product)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Barcode creator')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Create a new product barcode'),
              subtitle: const Text(
                'Enter a product name and price, generate the barcode, then add the remaining details.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _createProductBarcode,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _layout,
                  decoration: const InputDecoration(labelText: 'PDF layout'),
                  items: const [
                    DropdownMenuItem(
                      value: 'one',
                      child: Text('One large label'),
                    ),
                    DropdownMenuItem(value: 'two', child: Text('Two columns')),
                    DropdownMenuItem(
                      value: 'three',
                      child: Text('Three columns'),
                    ),
                  ],
                  onChanged:
                      (value) => setState(() => _layout = value ?? 'three'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(onPressed: _add, icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 18),
          if (_selected.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.qr_code_2, size: 48),
                    SizedBox(height: 10),
                    Text(
                      'Add products to create printable labels.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ..._selected.map(
            (entry) => Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      height: 45,
                      child: widget.BarcodeWidget(
                        data: entry.product.barcode!,
                        barcode: widget.Barcode.code128(),
                        drawText: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.product.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            CurrencyService.format(
                              entry.product.sellingPrice,
                              code: state.currencyCode,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed:
                          () => setState(
                            () =>
                                entry.quantity = (entry.quantity - 1).clamp(
                                  1,
                                  99,
                                ),
                          ),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('${entry.quantity}'),
                    IconButton(
                      onPressed: () => setState(() => entry.quantity++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _selected.remove(entry)),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _selected.isEmpty ? null : _generate,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Generate and share PDF'),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'EasyPOS uses Code 128 for internal labels. It does not create registered UPC or EAN numbers.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createProductBarcode,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Create barcode'),
      ),
    );
  }

  Future<void> _generate() async {
    final state = context.read<AppState>();
    final document = pw.Document();
    final copies = <Product>[
      for (final entry in _selected)
        for (var i = 0; i < entry.quantity; i++) entry.product,
    ];
    final columns =
        _layout == 'one'
            ? 1
            : _layout == 'two'
            ? 2
            : 3;
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build:
            (_) => [
              pw.Text(
                state.business?['name']?.toString() ?? 'EasyPOS',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.GridView(
                crossAxisCount: columns,
                childAspectRatio: columns == 1 ? 3.2 : 1.6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children:
                    copies
                        .map(
                          (product) => pw.Container(
                            padding: const pw.EdgeInsets.all(6),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey500),
                            ),
                            child: pw.Column(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.Text(
                                  product.name,
                                  maxLines: 1,
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  CurrencyService.format(
                                    product.sellingPrice,
                                    code: state.currencyCode,
                                  ),
                                ),
                                pw.SizedBox(height: 3),
                                pw.BarcodeWidget(
                                  data: product.barcode!,
                                  barcode: pw.Barcode.code128(),
                                  height: 34,
                                ),
                                pw.Text(
                                  product.barcode!,
                                  style: const pw.TextStyle(fontSize: 7),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
              ),
            ],
      ),
    );
    final bytes = await document.save();
    await state.database.saveBarcodeBatch(
      title: 'Product labels',
      layout: _layout,
      labelCount: copies.length,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'EasyPOS_barcodes_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
