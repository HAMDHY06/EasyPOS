import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/app_state.dart';
import '../../core/services/currency_service.dart';
import '../barcodes/barcode_screen.dart';
import '../reports/reports_screen.dart';
import '../stock/stock_screen.dart';
import '../../core/services/admin_guard.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, num>> _stats;
  int _loadedRevision = -1;

  @override
  void initState() {
    super.initState();
    _stats = context.read<AppState>().database.dashboardStats();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _stats = context.read<AppState>().database.dashboardStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (_loadedRevision != state.dataRevision) {
      _loadedRevision = state.dataRevision;
      _stats = state.database.dashboardStats();
    }
    final name = state.business?['name']?.toString() ?? 'EasyPOS';
    return RefreshIndicator(
      onRefresh: () async {
        await state.refreshProducts();
        _refresh();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Text('Good business starts with a clear view.'),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'product') widget.onNavigate(2);
                  if (value == 'stock') _open(const StockScreen());
                  if (value == 'barcode') _open(const BarcodeScreen());
                  if (value == 'settings') {
                    AdminGuard.authorize(context, action: 'open settings').then(
                      (ok) {
                        if (ok && mounted) widget.onNavigate(4);
                      },
                    );
                  }
                },
                itemBuilder:
                    (_) => const [
                      PopupMenuItem(
                        value: 'product',
                        child: Text('Add product'),
                      ),
                      PopupMenuItem(
                        value: 'barcode',
                        child: Text('Create barcodes'),
                      ),
                      PopupMenuItem(value: 'stock', child: Text('Check stock')),
                      PopupMenuItem(value: 'settings', child: Text('Settings')),
                    ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          FutureBuilder<Map<String, num>>(
            future: _stats,
            builder: (context, snapshot) {
              final stats = snapshot.data;
              if (stats == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  _StatCard(
                    label: "Today's sales",
                    value: CurrencyService.format(
                      stats['revenue'] ?? 0,
                      code: state.currencyCode,
                    ),
                    icon: Icons.trending_up,
                    color: Colors.green,
                  ),
                  _StatCard(
                    label: 'Bills today',
                    value: '${stats['bills']?.toInt() ?? 0}',
                    icon: Icons.receipt_long,
                    color: Colors.blue,
                  ),
                  _StatCard(
                    label: 'Low stock',
                    value: '${stats['lowStock']?.toInt() ?? 0}',
                    icon: Icons.warning_amber,
                    color: Colors.orange,
                  ),
                  _StatCard(
                    label: 'Products',
                    value: '${stats['products']?.toInt() ?? 0}',
                    icon: Icons.inventory_2,
                    color: Colors.purple,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Quick actions',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _Action(
                'New sale',
                Icons.add_shopping_cart,
                () => widget.onNavigate(1),
              ),
              _Action(
                'Products',
                Icons.inventory_2_outlined,
                () => widget.onNavigate(2),
              ),
              _Action(
                'Stock',
                Icons.warehouse_outlined,
                () => _open(const StockScreen()),
              ),
              _Action('History', Icons.history, () => widget.onNavigate(3)),
              _Action(
                'Barcodes',
                Icons.qr_code_2,
                () => _open(const BarcodeScreen()),
              ),
              _Action('Reports', Icons.bar_chart, () async {
                if (await AdminGuard.authorize(
                  context,
                  action: 'view sales reports',
                )) {
                  _open(const ReportsScreen());
                }
              }),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.cloud_off)),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Offline ready',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Sales continue without an internet connection.'),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _open(Widget screen) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => screen)).then((_) {
      if (mounted) _refresh();
    });
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 30,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
