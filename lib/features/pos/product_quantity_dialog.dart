import 'package:flutter/material.dart';
import '../../core/models/product.dart';

Future<double?> showProductQuantityDialog(
  BuildContext context,
  Product product,
) {
  return showDialog<double>(
    context: context,
    builder: (_) => _ProductQuantityDialog(product: product),
  );
}

class _ProductQuantityDialog extends StatefulWidget {
  const _ProductQuantityDialog({required this.product});

  final Product product;

  @override
  State<_ProductQuantityDialog> createState() => _ProductQuantityDialogState();
}

class _ProductQuantityDialogState extends State<_ProductQuantityDialog> {
  final _controller = TextEditingController(text: '1');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(_controller.text);
    if (value == null || value <= 0) {
      setState(() => _error = 'Enter a quantity greater than 0');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product.name),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Quantity',
          helperText:
              'Available: ${widget.product.stockQuantity.toStringAsFixed(3)} ${widget.product.unitType}',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add to cart')),
      ],
    );
  }
}
