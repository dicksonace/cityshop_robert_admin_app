import 'dart:async';

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
  static const _refreshInterval = Duration(seconds: 8);

  bool loading = true;
  bool refreshing = false;
  String? error;
  Map<String, dynamic> stats = {};
  List<Map<String, dynamic>> pendingSellers = [];
  List<Map<String, dynamic>> pendingWithdrawals = [];
  List<Map<String, dynamic>> pendingRmbTransfers = [];
  List<Map<String, dynamic>> pendingSellRmbTransfers = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(_refreshInterval, (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool fromRefresh = false, bool silent = false}) async {
    if (fromRefresh) {
      setState(() {
        refreshing = true;
        error = null;
      });
    } else if (!silent) {
      setState(() {
        loading = true;
        error = null;
      });
    } else {
      setState(() => refreshing = true);
    }
    try {
      final store = context.read<AdminStore>();
      final results = await Future.wait([
        store.getJson('/admin/dashboard'),
        store.getJson('/admin/china-transfers', query: {'status': 'open'}),
        store.getJson('/admin/sell-rmb', query: {'status': 'open'}),
      ]);
      if (!mounted) return;
      final data = results[0];
      final rmb = results[1];
      final sellRmb = results[2];
      final queues = asMap(data['queues']);
      setState(() {
        stats = asMap(data['stats']);
        pendingSellers = asMaps(queues['sellers']);
        pendingWithdrawals = asMaps(queues['withdrawals']);
        pendingRmbTransfers = asMaps(rmb['data']).take(5).toList();
        pendingSellRmbTransfers = asMaps(sellRmb['data']).take(5).toList();
        loading = false;
        refreshing = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) error = e.message;
        loading = false;
        refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) error = e.toString();
        loading = false;
        refreshing = false;
      });
    }
  }

  Future<void> _refresh() => _load(fromRefresh: true);

  void _go(String path) {
    if (path.startsWith('/money') || path == '/sellers' || path == '/orders' || path.startsWith('/orders?')) {
      context.go(path);
    } else {
      context.push(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AdminStore>().user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin dashboard'),
        actions: [
          if (!loading && error == null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: refreshing
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : const DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(0xFF3B82F6),
                                  shape: BoxShape.circle,
                                ),
                              ),
                      ),
                      const SizedBox(width: 6),
                      const Text('Auto refresh', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
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
                      Text(
                        'Hi ${user?.name ?? 'Admin'}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Queues that need a decision today.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Text(
                          'Workflow: Clear deposits & withdrawals → process Transfer RMB / Sell RMB → keep orders moving.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8), height: 1.35),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _DashStat(
                              label: 'Deposits',
                              value: '${stats['pending_topups'] ?? 0}',
                              bg: const Color(0xFFFFF7ED),
                              fg: const Color(0xFFC2410C),
                              onTap: () => _go('/money?tab=deposits'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DashStat(
                              label: 'Withdrawals',
                              value: '${stats['pending_withdrawals'] ?? 0}',
                              bg: const Color(0xFFDBEAFE),
                              fg: const Color(0xFF1D4ED8),
                              onTap: () => _go('/money'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _DashStat(
                              label: 'Transfer RMB',
                              value: '${stats['pending_rmb'] ?? 0}',
                              bg: const Color(0xFFFEE2E2),
                              fg: const Color(0xFFB91C1C),
                              onTap: () => _go('/china-transfers'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DashStat(
                              label: 'Sell RMB',
                              value: '${stats['pending_sell_rmb'] ?? 0}',
                              bg: const Color(0xFFD1FAE5),
                              fg: AppColors.emerald,
                              onTap: () => _go('/sell-rmb'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _DashStat(
                              label: 'Unprocessed',
                              value: '${stats['unprocessed_orders'] ?? 0}',
                              bg: const Color(0xFFFEF9C3),
                              fg: const Color(0xFF854D0E),
                              onTap: () => _go('/orders?tab=unprocessed'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DashStat(
                              label: 'Awaiting confirm',
                              value: '${stats['awaiting_confirmation'] ?? 0}',
                              bg: const Color(0xFFE0E7FF),
                              fg: const Color(0xFF4338CA),
                              onTap: () => _go('/orders?tab=awaiting'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _SectionBar(
                        title: 'Transfer RMB queue (${pendingRmbTransfers.length})',
                        bg: const Color(0xFFDBEAFE),
                        fg: const Color(0xFF1D4ED8),
                        action: 'View all',
                        onAction: () => context.push('/china-transfers'),
                      ),
                      const SizedBox(height: 10),
                      if (pendingRmbTransfers.isEmpty)
                        const _EmptyQueue('No open RMB transfers.')
                      else
                        ...pendingRmbTransfers.map((item) {
                          final userMap = asMap(item['user']);
                          final quote = asMap(item['quote']);
                          final ghsPaid = asDouble(quote['total_payable_ghs']);
                          final ghs = money.format(ghsPaid > 0 ? ghsPaid : asDouble(quote['ghs_amount']));
                          final rmb = '¥${asDouble(quote['rmb_amount']).toStringAsFixed(2)}';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _QueueCard(
                              idLabel: str(item['reference'], '#${item['id']}'),
                              name: str(userMap['name'], 'Buyer'),
                              status: str(item['status_label'], str(item['status'])),
                              statusBg: const Color(0xFFDBEAFE),
                              statusFg: const Color(0xFF1D4ED8),
                              leftLabel: 'GHS paid',
                              leftValue: ghs,
                              leftBg: const Color(0xFFFFF7ED),
                              leftFg: const Color(0xFFC2410C),
                              rightLabel: 'RMB to send',
                              rightValue: rmb,
                              rightBg: const Color(0xFFFEE2E2),
                              rightFg: const Color(0xFFB91C1C),
                              tint: const Color(0xFFEFF6FF),
                              onOpen: () => context.push('/china-transfers/${item['id']}'),
                            ),
                          );
                        }),
                      const SizedBox(height: 8),
                      _SectionBar(
                        title: 'Sell RMB queue (${pendingSellRmbTransfers.length})',
                        bg: const Color(0xFFD1FAE5),
                        fg: const Color(0xFF047857),
                        action: 'View all',
                        onAction: () => context.push('/sell-rmb'),
                      ),
                      const SizedBox(height: 10),
                      if (pendingSellRmbTransfers.isEmpty)
                        const _EmptyQueue('No open Sell RMB transfers.')
                      else
                        ...pendingSellRmbTransfers.map((item) {
                          final userMap = asMap(item['user']);
                          final quote = asMap(item['quote']);
                          final payout = asMap(item['payout_account']);
                          final rmb = '¥${asDouble(quote['rmb_amount']).toStringAsFixed(2)}';
                          final ghs = money.format(asDouble(quote['ghs_payout']));
                          final momo = str(payout['number']);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _QueueCard(
                              idLabel: '#${item['id']}',
                              name: str(userMap['name'], 'Buyer'),
                              status: str(item['status_label'], str(item['status'])),
                              statusBg: const Color(0xFFDBEAFE),
                              statusFg: const Color(0xFF1D4ED8),
                              leftLabel: 'RMB',
                              leftValue: rmb,
                              leftBg: const Color(0xFFFEE2E2),
                              leftFg: const Color(0xFFB91C1C),
                              rightLabel: 'GHS Payout',
                              rightValue: ghs,
                              rightBg: const Color(0xFFD1FAE5),
                              rightFg: AppColors.emerald,
                              tint: const Color(0xFFECFDF5),
                              copyValue: momo.isEmpty ? null : momo,
                              copyHint: str(payout['network'], 'MoMo payout'),
                              onOpen: () => context.push('/sell-rmb/${item['id']}'),
                            ),
                          );
                        }),
                      const SizedBox(height: 8),
                      _SectionBar(
                        title: 'Withdrawal queue (${pendingWithdrawals.length})',
                        bg: const Color(0xFFFFEDD5),
                        fg: const Color(0xFFC2410C),
                        action: 'View all',
                        onAction: () => context.go('/money'),
                      ),
                      const SizedBox(height: 10),
                      if (pendingWithdrawals.isEmpty)
                        const _EmptyQueue('No pending withdrawals.')
                      else
                        ...pendingWithdrawals.take(5).map((item) {
                          final userMap = asMap(item['user']);
                          final number = str(item['momo_number']);
                          final network = str(item['network_label'], str(item['network']));
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _QueueCard(
                              idLabel: '#${str(item['reference'], item['id'])}',
                              name: str(userMap['name'], 'User'),
                              status: str(item['status_label'], str(item['status'], 'pending')),
                              statusBg: str(item['status']) == 'processing'
                                  ? const Color(0xFFDBEAFE)
                                  : const Color(0xFFFFEDD5),
                              statusFg: str(item['status']) == 'processing'
                                  ? const Color(0xFF1D4ED8)
                                  : const Color(0xFFC2410C),
                              leftLabel: 'Pay out',
                              leftValue: money.format(asDouble(item['amount'])),
                              leftBg: const Color(0xFFFFF7ED),
                              leftFg: const Color(0xFFC2410C),
                              rightLabel: 'Role',
                              rightValue: str(userMap['role'], 'user'),
                              rightBg: const Color(0xFFDBEAFE),
                              rightFg: const Color(0xFF1D4ED8),
                              tint: Colors.white,
                              copyValue: number.isEmpty ? null : number,
                              copyHint: network.isEmpty ? 'MoMo payout' : network,
                              onOpen: () => context.go('/money'),
                            ),
                          );
                        }),
                      const SizedBox(height: 8),
                      _SectionBar(
                        title: 'Seller applications (${pendingSellers.length})',
                        bg: const Color(0xFFF3F4F6),
                        fg: const Color(0xFF374151),
                        action: 'View all',
                        onAction: () => context.go('/sellers'),
                      ),
                      const SizedBox(height: 10),
                      if (pendingSellers.isEmpty)
                        const _EmptyQueue('No pending sellers.')
                      else
                        ...pendingSellers.take(5).map((seller) {
                          final userMap = asMap(seller['user']);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => context.push('/sellers/${seller['id']}'),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE5E7EB)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              str(seller['store_name'], 'Store'),
                                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              str(userMap['name'], str(userMap['mobile'], '—')),
                                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                      FilledButton(
                                        onPressed: () => context.push('/sellers/${seller['id']}'),
                                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                                        child: const Text('Review'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 14),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          leading: const Icon(Icons.account_balance, color: AppColors.accent),
                          title: const Text('Seller bank withdrawal fees', style: TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: const Text('Fee sellers see when they cash out to a Ghana bank.'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/settings/withdrawal'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('More stats', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _DashStat(
                              label: 'Pending sellers',
                              value: '${stats['pending_sellers'] ?? 0}',
                              bg: Colors.white,
                              fg: AppColors.textPrimary,
                              onTap: () => _go('/sellers'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DashStat(
                              label: 'Open refunds',
                              value: '${stats['open_disputes'] ?? 0}',
                              bg: Colors.white,
                              fg: AppColors.textPrimary,
                              onTap: () => _go('/disputes'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _DashStat(
                              label: 'Pending funds',
                              value: '${stats['pending_funds'] ?? 0}',
                              bg: Colors.white,
                              fg: AppColors.textPrimary,
                              onTap: () => _go('/pending-funds'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DashStat(
                              label: 'Paid revenue',
                              value: money.format(asDouble(stats['paid_revenue'])),
                              bg: const Color(0xFFD1FAE5),
                              fg: AppColors.emerald,
                              onTap: null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _DashStat extends StatelessWidget {
  const _DashStat({
    required this.label,
    required this.value,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color bg;
  final Color fg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg.withValues(alpha: 0.85))),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionBar extends StatelessWidget {
  const _SectionBar({
    required this.title,
    required this.bg,
    required this.fg,
    this.action,
    this.onAction,
  });

  final String title;
  final Color bg;
  final Color fg;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: fg))),
          if (action != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: fg,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(action!, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.textSecondary)),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.idLabel,
    required this.name,
    required this.status,
    required this.statusBg,
    required this.statusFg,
    required this.leftLabel,
    required this.leftValue,
    required this.leftBg,
    required this.leftFg,
    required this.rightLabel,
    required this.rightValue,
    required this.rightBg,
    required this.rightFg,
    required this.tint,
    required this.onOpen,
    this.copyValue,
    this.copyHint,
  });

  final String idLabel;
  final String name;
  final String status;
  final Color statusBg;
  final Color statusFg;
  final String leftLabel;
  final String leftValue;
  final Color leftBg;
  final Color leftFg;
  final String rightLabel;
  final String rightValue;
  final Color rightBg;
  final Color rightFg;
  final Color tint;
  final VoidCallback onOpen;
  final String? copyValue;
  final String? copyHint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(idLabel, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(999)),
                child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusFg)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: leftBg, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      Text(leftLabel, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      Text(leftValue, style: TextStyle(fontWeight: FontWeight.w900, color: leftFg)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: rightBg, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      Text(rightLabel, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      Text(rightValue, style: TextStyle(fontWeight: FontWeight.w900, color: rightFg)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if ((copyValue ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6EE7B7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copyHint ?? 'MoMo payout',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          copyValue!,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                        ),
                      ),
                      FilledButton(
                        onPressed: () => copyText(context, copyValue!, label: 'Number copied.'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(72, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: const Text('COPY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
