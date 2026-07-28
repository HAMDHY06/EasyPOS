import 'package:flutter/material.dart';
import '../../core/models/product.dart';

class StockAdjustment {
  const StockAdjustment({required this.change, required this.reason});

  final double change;
  final String reason;
}

Future<StockAdjustment?> showStockAdjustmentDialog(
  BuildContext context, {
  required Product product,
  required bool positive,
}) {
  return showDialog<StockAdjustment>(
    context: context,
    builder:
        (_) => _StockAdjustmentDialog(
          product: product,
          positive: positive,
        ),
  );
}

class _StockAdjustmentDialog extends StatefulWidget {
  const _StockAdjustmentDialog({
    required this.product,
    required this.positive,
  });

  final Product product;
  final bool positive;

  @override
  State<_StockAdjustmentDialog> createState() =>
      _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<_StockAdjustmentDialog> {
  final _quantity = TextEditingController();
  late String _reason;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reason =
        widget.positive ? 'New stock received' : 'Manual correction';
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(_quantity.text);
    if (value == null || value <= 0) {
      setState(() => _error = 'Enter a quantity greater than 0');
      return;
    }
    if (!widget.positive && value > widget.product.stockQuantity) {
      setState(
        () => _error =
            'Only ${widget.product.stockQuantity.toStringAsFixed(3)} '
            '${widget.product.unitType} is available',
      );
      return;
    }
    Navigator.pop(
      context,
      StockAdjustment(
        change: widget.positive ? value : -value,
        reason: _reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.positive ? 'Add' : 'Remove'} stock'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.product.name}\n'
            'Current: ${widget.product.stockQuantity.toStringAsFixed(3)} '
            '${widget.product.unitType}',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantity,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Quantity',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: const [
              DropdownMenuItem(
                value: 'New stock received',
                child: Text('New stock received'),
              ),
              DropdownMenuItem(value: 'Damaged', child: Text('Damaged')),
              DropdownMenuItem(value: 'Expired', child: Text('Expired')),
              DropdownMenuItem(value: 'Returned', child: Text('Returned')),
              DropdownMenuItem(
                value: 'Manual correction',
                child: Text('Manual correction'),
              ),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _reason = value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save stock')),
      ],
    );
  }
}
