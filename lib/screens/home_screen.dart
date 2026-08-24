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
  bool refreshing = false;
  String? error;
  Map<String, dynamic> stats = {};
  List<Map<String, dynamic>> pendingSellers = [];
  List<Map<String, dynamic>> pendingWithdrawals = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool fromRefresh = false}) async {
    if (fromRefresh) {
      setState(() {
        refreshing = true;
        error = null;
      });
    } else {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final data = await context.read<AdminStore>().getJson('/admin/dashboard');
      if (!mounted) return;
      final queues = asMap(data['queues']);
      setState(() {
        stats = asMap(data['stats']);
        pendingSellers = asMaps(queues['sellers']);
        pendingWithdrawals = asMaps(queues['withdrawals']);
        loading = false;
        refreshing = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        loading = false;
        refreshing = false;
      });
    }
  }

  Future<void> _refresh() => _load(fromRefresh: true);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AdminStore>().user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin home'),
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: refreshing ? null : _refresh,
            icon: refreshing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const FullPageLoader(label: 'Loading dashboard…')
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      if (refreshing) const LinearProgressIndicator(minHeight: 2),
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
                      Row(
                        children: [
                          Expanded(
                            child: _QuickAction(
                              label: 'Deposit',
                              count: stats['pending_topups'],
                              icon: Icons.add_card_outlined,
                              onTap: () => context.go('/money?tab=deposits'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _QuickAction(
                              label: 'Withdrawal',
                              count: stats['pending_withdrawals'],
                              icon: Icons.outbond_outlined,
                              onTap: () => context.go('/money'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _QuickAction(
                              label: 'Transfer RMB',
                              count: stats['pending_rmb'],
                              icon: Icons.currency_exchange,
                              onTap: () => context.push('/china-transfers'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickAction(
                              label: 'Unprocessed',
                              count: stats['unprocessed_orders'],
                              icon: Icons.schedule_outlined,
                              onTap: () => context.go('/orders?tab=unprocessed'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _QuickAction(
                              label: 'Awaiting confirm',
                              count: stats['awaiting_confirmation'],
                              icon: Icons.local_shipping_outlined,
                              onTap: () => context.go('/orders?tab=awaiting'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          leading: const Icon(Icons.badge_outlined, color: AppColors.accent),
                          title: const Text('Ghana Card KYC', style: TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text('${stats['pending_kyc'] ?? 0} waiting for approve / reject / improve.'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/kyc'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          leading: const Icon(Icons.account_balance, color: AppColors.accent),
                          title: const Text('Seller bank withdrawal fees', style: TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: const Text('Fee sellers see when they cash out to a Ghana bank.'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/settings/withdrawal'),
                        ),
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
                          _StatTile('Deposits', stats['pending_topups'], '/money?tab=deposits'),
                          _StatTile('Open refunds', stats['open_disputes'], '/disputes'),
                          _StatTile('Transfer RMB', stats['pending_rmb'], '/china-transfers'),
                          _StatTile('Pending funds', stats['pending_funds'], '/pending-funds'),
                          _StatTile('Unprocessed', stats['unprocessed_orders'], '/orders?tab=unprocessed'),
                          _StatTile('Awaiting confirm', stats['awaiting_confirmation'], '/orders?tab=awaiting'),
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
                          final number = str(item['momo_number']);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(money.format(asDouble(item['amount']))),
                            subtitle: Text(
                              '${str(userMap['name'])} · ${str(item['network'])} $number',
                            ),
                            trailing: IconButton(
                              tooltip: 'Copy number',
                              onPressed: () => copyText(context, number, label: 'Account number copied.'),
                              icon: const Icon(Icons.copy, size: 18),
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
        onTap: route == null
            ? null
            : () {
                final path = route!;
                if (path.startsWith('/money') ||
                    path == '/sellers' ||
                    path == '/orders' ||
                    path.startsWith('/orders?')) {
                  context.go(path);
                } else {
                  context.push(path);
                }
              },
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

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.count,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final dynamic count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: AppColors.accent),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                '${count ?? 0}',
                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
