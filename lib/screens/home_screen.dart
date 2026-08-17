import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../store/admin_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> stats = {};
  List<Map<String, dynamic>> pendingSellers = [];
  List<Map<String, dynamic>> pendingWithdrawals = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await context.read<AdminStore>().getJson('/admin/dashboard');
      if (!mounted) return;
      final queues = asMap(data['queues']);
      setState(() {
        stats = asMap(data['stats']);
        pendingSellers = asMaps(queues['sellers']);
        pendingWithdrawals = asMaps(queues['withdrawals']);
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AdminStore>().user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin home'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const FullPageLoader(label: 'Loading dashboard…')
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      Text(
                        'Hi ${user?.name ?? 'Admin'}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Queues that need a decision today.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.45,
                        children: [
                          _StatTile('Pending sellers', stats['pending_sellers'], '/sellers'),
                          _StatTile('Withdrawals', stats['pending_withdrawals'], '/money'),
                          _StatTile('Top-ups', stats['pending_topups'], '/money'),
                          _StatTile('Open refunds', stats['open_disputes'], '/disputes'),
                          _StatTile('Pending funds', stats['pending_funds'], '/pending-funds'),
                          _StatTile('Unprocessed', stats['unprocessed_orders'], '/orders'),
                          _StatTile('Awaiting confirm', stats['awaiting_confirmation'], '/orders'),
                          _StatTile('Paid revenue', money.format(asDouble(stats['paid_revenue'])), null),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text('Seller applications', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      if (pendingSellers.isEmpty)
                        const Text('No pending sellers.', style: TextStyle(color: AppColors.textSecondary))
                      else
                        ...pendingSellers.map((seller) {
                          final userMap = asMap(seller['user']);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(str(seller['store_name'], 'Store')),
                            subtitle: Text(str(userMap['name'], str(userMap['mobile']))),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/sellers/${seller['id']}'),
                          );
                        }),
                      const SizedBox(height: 16),
                      const Text('Withdrawal queue', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      if (pendingWithdrawals.isEmpty)
                        const Text('No pending withdrawals.', style: TextStyle(color: AppColors.textSecondary))
                      else
                        ...pendingWithdrawals.map((item) {
                          final userMap = asMap(item['user']);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(money.format(asDouble(item['amount']))),
                            subtitle: Text(
                              '${str(userMap['name'])} · ${str(item['network'])} ${str(item['momo_number'])}',
                            ),
                            onTap: () => context.go('/money'),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value, this.route);

  final String label;
  final dynamic value;
  final String? route;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: route == null ? null : () => context.go(route!),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value is String ? value : '${value ?? 0}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
