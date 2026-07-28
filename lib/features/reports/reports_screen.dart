import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../app/app_state.dart';
import '../../core/services/currency_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<_ReportData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_ReportData> _load() async {
    final database = context.read<AppState>().database;
    final values = await Future.wait([
      database.reportSalesByDay(days: 30),
      database.bestSellers(),
      database.dashboardStats(),
      database.reportOverview(),
    ]);
    return _ReportData(
      daily: values[0] as List<Map<String, Object?>>,
      best: values[1] as List<Map<String, Object?>>,
      stats: values[2] as Map<String, num>,
      overview: values[3] as Map<String, Object?>,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            onPressed: () async => _export(await _data),
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: FutureBuilder<_ReportData>(
        future: _data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final revenue30 = data.daily.fold<num>(
            0,
            (sum, row) => sum + (row['revenue'] as num),
          );
          final methods =
              (data.overview['methods'] as List).cast<Map<String, Object?>>();
          return RefreshIndicator(
            onRefresh: () async => setState(() => _data = _load()),
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Summary(
                        label: 'Today',
                        value: CurrencyService.format(
                          data.stats['revenue'] ?? 0,
                          code: state.currencyCode,
                        ),
                        icon: Icons.today,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Summary(
                        label: 'Last 30 days',
                        value: CurrencyService.format(
                          revenue30,
                          code: state.currencyCode,
                        ),
                        icon: Icons.calendar_month,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _Summary(
                  label: 'Estimated gross profit',
                  value: CurrencyService.format(
                    data.overview['profit'] as num,
                    code: state.currencyCode,
                  ),
                  icon: Icons.savings_outlined,
                ),
                const SizedBox(height: 22),
                Text(
                  'Daily sales',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (data.daily.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('No completed sales yet.'),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children:
                          data.daily
                              .map(
                                (row) => ListTile(
                                  title: Text(row['day'].toString()),
                                  subtitle: Text('${row['bills']} bills'),
                                  trailing: Text(
                                    CurrencyService.format(
                                      row['revenue'] as num,
                                      code: state.currencyCode,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                const SizedBox(height: 22),
                Text(
                  'Best-selling products',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child:
                      data.best.isEmpty
                          ? const Padding(
                            padding: EdgeInsets.all(18),
                            child: Text('Sales will appear here.'),
                          )
                          : Column(
                            children:
                                data.best
                                    .map(
                                      (row) => ListTile(
                                        leading: const Icon(
                                          Icons.emoji_events_outlined,
                                        ),
                                        title: Text(
                                          row['product_name'].toString(),
                                        ),
                                        subtitle: Text(
                                          '${row['quantity']} sold',
                                        ),
                                        trailing: Text(
                                          CurrencyService.format(
                                            row['revenue'] as num,
                                            code: state.currencyCode,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Sales by payment method',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child:
                      methods.isEmpty
                          ? const Padding(
                            padding: EdgeInsets.all(18),
                            child: Text('No payment data yet.'),
                          )
                          : Column(
                            children:
                                methods
                                    .map(
                                      (row) => ListTile(
                                        title: Text(
                                          row['payment_method'].toString(),
                                        ),
                                        subtitle: Text('${row['bills']} bills'),
                                        trailing: Text(
                                          CurrencyService.format(
                                            row['total'] as num,
                                            code: state.currencyCode,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Inventory alerts',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.warning_amber,
                      color: Colors.orange,
                    ),
                    title: const Text('Low or out-of-stock products'),
                    trailing: Text(
                      '${data.stats['lowStock']?.toInt() ?? 0}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _export(_ReportData data) async {
    final rows = <List<Object?>>[
      ['Date', 'Bills', 'Revenue'],
      ...data.daily.map((row) => [row['day'], row['bills'], row['revenue']]),
      [],
      ['Best-selling product', 'Quantity', 'Revenue'],
      ...data.best.map(
        (row) => [row['product_name'], row['quantity'], row['revenue']],
      ),
    ];
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/EasyPOS_report_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(const ListToCsvConverter().convert(rows));
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'EasyPOS sales report'),
    );
  }
}

class _ReportData {
  const _ReportData({
    required this.daily,
    required this.best,
    required this.stats,
    required this.overview,
  });
  final List<Map<String, Object?>> daily;
  final List<Map<String, Object?>> best;
  final Map<String, num> stats;
  final Map<String, Object?> overview;
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}
