import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/app_state.dart';
import '../../core/services/currency_service.dart';
import 'bill_qr_dialog.dart';
import 'receipt_service.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _search = TextEditingController();
  late Future<List<Map<String, Object?>>> _sales;
  int _loadedRevision = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _sales = context.read<AppState>().database.getSales(query: _search.text);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (_loadedRevision != state.salesRevision) {
      _loadedRevision = state.salesRevision;
      _load();
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Sales history'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: TextField(
              controller: _search,
              onSubmitted: (_) => setState(_load),
              decoration: InputDecoration(
                hintText: 'Bill number or customer',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: () => setState(_load),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: _sales,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data!;
                if (rows.isEmpty) {
                  return const Center(child: Text('No sales found.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => setState(_load),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final sale = rows[index];
                      final cancelled = sale['status'] == 'cancelled';
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              cancelled
                                  ? Icons.cancel_outlined
                                  : Icons.receipt_long,
                            ),
                          ),
                          title: Text(
                            sale['bill_number'].toString(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${_date(sale['created_at'])} • ${sale['payment_method']}\n'
                            '${sale['payment_status']}${cancelled ? ' • cancelled' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: Text(
                            CurrencyService.format(
                              sale['total'] as num,
                              code: state.currencyCode,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () => _openSale(sale['id'] as int),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSale(int id) async {
    final state = context.read<AppState>();
    final sale = await state.database.getSale(id);
    if (!mounted || sale == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (context) => FractionallySizedBox(
            heightFactor: .86,
            child: Scaffold(
              appBar: AppBar(
                title: Text(sale['bill_number'].toString()),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  ...((sale['items'] as List).cast<Map<String, Object?>>()).map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item['product_name'].toString()),
                      subtitle: Text(
                        '${item['quantity']} × ${CurrencyService.format(item['unit_price'] as num, code: state.currencyCode)}',
                      ),
                      trailing: Text(
                        CurrencyService.format(
                          item['total'] as num,
                          code: state.currencyCode,
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  _line('Subtotal', sale['subtotal'] as num, state),
                  _line('Discount', sale['discount'] as num, state),
                  _line('Tax', sale['tax'] as num, state),
                  _line('Total', sale['total'] as num, state, bold: true),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed:
                        () => ReceiptService.shareReceipt(
                          sale: sale,
                          business: state.business,
                          settings: state.settings,
                        ),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Download or share e-bill'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed:
                        () => showBillQrDialog(
                          context,
                          state: state,
                          sale: sale,
                        ),
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Show bill QR'),
                  ),
                  if ((sale['balance'] as num).toDouble() > 0 &&
                      sale['status'] == 'completed') ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _recordPayment(state, sale),
                      icon: const Icon(Icons.payments_outlined),
                      label: Text(
                        'Record credit payment • ${CurrencyService.format(sale['balance'] as num, code: state.currencyCode)} due',
                      ),
                    ),
                  ],
                  if (sale['status'] == 'completed') ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Cancel this sale?'),
                                content: const Text(
                                  'Sold quantities will be returned to stock.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, false),
                                    child: const Text('Keep sale'),
                                  ),
                                  FilledButton(
                                    onPressed:
                                        () => Navigator.pop(context, true),
                                    child: const Text('Cancel sale'),
                                  ),
                                ],
                              ),
                        );
                        if (confirm == true) {
                          await state.database.cancelSale(id);
                          await state.refreshProducts();
                          state.markSalesChanged();
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.undo),
                      label: const Text('Cancel and return stock'),
                    ),
                  ],
                ],
              ),
            ),
          ),
    );
    setState(_load);
  }

  Widget _line(String label, num amount, AppState state, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
            ),
            Text(
              CurrencyService.format(amount, code: state.currencyCode),
              style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
            ),
          ],
        ),
      );

  String _date(Object? value) {
    final date = DateTime.tryParse(value.toString()) ?? DateTime.now();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _recordPayment(AppState state, Map<String, Object?> sale) async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Record payment'),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount received'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = double.tryParse(controller.text);
                  if (value != null && value > 0) Navigator.pop(context, value);
                },
                child: const Text('Save payment'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (amount == null) return;
    try {
      await state.database.addCreditPayment(
        saleId: sale['id'] as int,
        amount: amount,
      );
      state.markSalesChanged();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

}
