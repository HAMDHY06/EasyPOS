import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/app_state.dart';
import '../../core/models/product.dart';
import '../scanner/barcode_scanner_screen.dart';
import '../../core/services/interaction_feedback_service.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({
    super.key,
    this.product,
    this.initialBarcode,
    this.initialName,
    this.initialBrand,
    this.initialPrice,
  });
  final Product? product;
  final String? initialBarcode;
  final String? initialName;
  final String? initialBrand;
  final double? initialPrice;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _brand;
  late final TextEditingController _cost;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _lowStock;
  late final TextEditingController _tax;
  late final TextEditingController _notes;
  String _unit = 'pcs';
  int? _categoryId;
  String? _imagePath;
  DateTime? _expiryDate;
  List<Map<String, Object?>> _categories = [];
  bool _favourite = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: widget.initialName ?? p?.name);
    _barcode = TextEditingController(text: widget.initialBarcode ?? p?.barcode);
    _brand = TextEditingController(text: widget.initialBrand ?? p?.brand);
    _cost = TextEditingController(text: p?.costPrice.toStringAsFixed(2));
    _price = TextEditingController(
      text:
          widget.initialPrice?.toStringAsFixed(2) ??
          p?.sellingPrice.toStringAsFixed(2),
    );
    _stock = TextEditingController(text: p?.stockQuantity.toString());
    _lowStock = TextEditingController(text: p?.lowStockLevel.toString() ?? '5');
    _tax = TextEditingController(text: p?.taxPercentage.toString() ?? '0');
    _notes = TextEditingController(text: p?.notes);
    _unit = p?.unitType ?? 'pcs';
    _categoryId = p?.categoryId;
    _imagePath = p?.imagePath;
    _expiryDate = p?.expiryDate;
    _favourite = p?.isFavourite ?? false;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final rows = await context.read<AppState>().database.getCategories();
    if (mounted) setState(() => _categories = rows);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _barcode,
      _brand,
      _cost,
      _price,
      _stock,
      _lowStock,
      _tax,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _scan() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (value != null) _barcode.text = value;
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    final product = Product(
      id: widget.product?.id,
      name: _name.text,
      barcode: _barcode.text,
      brand: _brand.text,
      categoryId: _categoryId,
      costPrice: double.tryParse(_cost.text) ?? 0,
      sellingPrice: double.parse(_price.text),
      stockQuantity: double.tryParse(_stock.text) ?? 0,
      lowStockLevel: double.tryParse(_lowStock.text) ?? 5,
      unitType: _unit,
      taxPercentage: double.tryParse(_tax.text) ?? 0,
      notes: _notes.text,
      imagePath: _imagePath,
      expiryDate: _expiryDate,
      isFavourite: _favourite,
      createdAt: widget.product?.createdAt,
    );
    final state = context.read<AppState>();
    try {
      await state.database.saveProduct(product);
      await state.refreshProducts();
      await InteractionFeedbackService.productAdded();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      final update = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Barcode already exists'),
              content: const Text(
                'Update the existing product with these details instead?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Update'),
                ),
              ],
            ),
      );
      if (update == true) {
        if (!mounted) return;
        final state = context.read<AppState>();
        await state.database.saveProduct(product, updateDuplicate: true);
        await state.refreshProducts();
        await InteractionFeedbackService.productAdded();
        if (mounted) Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add product' : 'Edit product'),
      ),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _field(_name, 'Product name', required: true),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcode,
              decoration: InputDecoration(
                labelText: 'Barcode',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Generate internal Code 128 number',
                      onPressed:
                          () =>
                              _barcode.text =
                                  'EP${DateTime.now().millisecondsSinceEpoch}',
                      icon: const Icon(Icons.auto_awesome),
                    ),
                    IconButton(
                      tooltip: 'Scan barcode',
                      onPressed: _scan,
                      icon: const Icon(Icons.qr_code_scanner),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _field(_brand, 'Brand'),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Uncategorised'),
                ),
                ..._categories.map(
                  (row) => DropdownMenuItem<int?>(
                    value: row['id'] as int,
                    child: Text(row['name'].toString()),
                  ),
                ),
              ],
              onChanged: (value) => _categoryId = value,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _cost,
                    'Cost price',
                    number: true,
                    nonNegative: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _price,
                    'Selling price',
                    number: true,
                    nonNegative: true,
                    required: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _stock,
                    'Opening stock',
                    number: true,
                    nonNegative: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _lowStock,
                    'Low-stock level',
                    number: true,
                    nonNegative: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: const [
                      DropdownMenuItem(value: 'pcs', child: Text('Pieces')),
                      DropdownMenuItem(value: 'kg', child: Text('Kilograms')),
                      DropdownMenuItem(value: 'g', child: Text('Grams')),
                      DropdownMenuItem(value: 'l', child: Text('Litres')),
                      DropdownMenuItem(value: 'ml', child: Text('Millilitres')),
                    ],
                    onChanged: (value) => _unit = value ?? 'pcs',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(_tax, 'Tax %', number: true, nonNegative: true),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _field(_notes, 'Notes', lines: 3),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading:
                    _imagePath == null
                        ? const Icon(Icons.add_a_photo_outlined)
                        : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_imagePath!),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                title: const Text('Product image'),
                subtitle: Text(
                  _imagePath == null ? 'Capture with camera' : 'Image selected',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final image = await ImagePicker().pickImage(
                    source: ImageSource.camera,
                  );
                  if (image != null && mounted) {
                    setState(() => _imagePath = image.path);
                  }
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_outlined),
                title: const Text('Expiry date'),
                subtitle: Text(
                  _expiryDate == null
                      ? 'Optional'
                      : '${_expiryDate!.year}-${_expiryDate!.month.toString().padLeft(2, '0')}-${_expiryDate!.day.toString().padLeft(2, '0')}',
                ),
                trailing:
                    _expiryDate == null
                        ? const Icon(Icons.chevron_right)
                        : IconButton(
                          onPressed: () => setState(() => _expiryDate = null),
                          icon: const Icon(Icons.clear),
                        ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    initialDate: _expiryDate ?? DateTime.now(),
                  );
                  if (date != null && mounted) {
                    setState(() => _expiryDate = date);
                  }
                },
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Quick Sale favourite'),
              value: _favourite,
              onChanged: (value) => setState(() => _favourite = value),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon:
                  _saving
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.save_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Save product'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextFormField _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool number = false,
    bool nonNegative = false,
    int lines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: lines,
      keyboardType:
          number ? const TextInputType.numberWithOptions(decimal: true) : null,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return 'Required';
        }
        if (number && value != null && value.isNotEmpty) {
          final parsed = double.tryParse(value);
          if (parsed == null) return 'Invalid number';
          if (nonNegative && parsed < 0) return 'Must be 0 or more';
        }
        return null;
      },
    );
  }
}
