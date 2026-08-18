import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../store/admin_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key, this.initialTab = 'withdrawals'});

  final String initialTab;

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String withdrawalStatus = 'pending';
  String topUpStatus = 'pending';
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab == 'deposits' ? 1 : 0);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _load();
    });
    _load();
  }

  @override
  void didUpdateWidget(MoneyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab == widget.initialTab) return;
    final index = widget.initialTab == 'deposits' ? 1 : 0;
    if (_tabs.index != index) _tabs.animateTo(index);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool get _withdrawals => _tabs.index == 0;

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await context.read<AdminStore>().getJson(
            _withdrawals ? '/admin/withdrawals' : '/admin/top-ups',
            query: {'status': _withdrawals ? withdrawalStatus : topUpStatus},
          );
      if (!mounted) return;
      setState(() {
        items = asMaps(data['data']);
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

  Future<void> _act(String path, {Object? data}) async {
    try {
      final result = await context.read<AdminStore>().postJson(path, data: data);
      if (!mounted) return;
      showSnack(context, str(result['message'], 'Done.'));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Money'),
        actions: [
          IconButton(
            tooltip: 'Transfer RMB',
            onPressed: () => context.push('/china-transfers'),
            icon: const Icon(Icons.currency_exchange),
          ),
          IconButton(
            tooltip: 'Seller bank fees',
            onPressed: () => context.push('/settings/withdrawal'),
            icon: const Icon(Icons.account_balance),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Withdrawals'),
            Tab(text: 'Deposits'),
          ],
        ),
      ),
      body: Column(
        children: [
          FilterBar(
            options: _withdrawals
                ? const ['pending', 'processing', 'paid', 'rejected', 'all']
                : const ['pending', 'approved', 'rejected', 'all'],
            value: _withdrawals ? withdrawalStatus : topUpStatus,
            onChanged: (value) {
              if (_withdrawals) {
                withdrawalStatus = value;
              } else {
                topUpStatus = value;
              }
              _load();
            },
          ),
          Expanded(
            child: loading
                ? const FullPageLoader(label: 'Loading…')
                : error != null
                    ? ErrorRetry(message: error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: items.isEmpty
                            ? ListView(children: const [SizedBox(height: 80), EmptyState('Nothing in this queue.')])
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                                itemCount: items.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return _withdrawals ? _WithdrawalCard(item, onAct: _act) : _TopUpCard(item, onAct: _act);
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalCard extends StatelessWidget {
  const _WithdrawalCard(this.item, {required this.onAct});

  final Map<String, dynamic> item;
  final Future<void> Function(String path, {Object? data}) onAct;

  @override
  Widget build(BuildContext context) {
    final user = asMap(item['user']);
    final status = str(item['status']);
    final id = asInt(item['id']);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    money.format(asDouble(item['amount'])),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                StatusChip(status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${str(user['name'])} (${str(user['role'])})\n${str(item['network'])} ${str(item['momo_number'])} · ${str(item['account_name'])}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            if (status == 'pending' || status == 'processing') ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (status == 'pending')
                    TextButton(
                      onPressed: () => onAct('/admin/withdrawals/$id/start'),
                      child: const Text('Start'),
                    ),
                  TextButton(
                    onPressed: () => onAct('/admin/withdrawals/$id/approve'),
                    child: const Text('Mark paid'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final reason = await promptText(context, title: 'Reject withdrawal');
                      if (reason == null) return;
                      await onAct('/admin/withdrawals/$id/reject', data: {'rejection_reason': reason});
                    },
                    child: const Text('Reject'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopUpCard extends StatelessWidget {
  const _TopUpCard(this.item, {required this.onAct});

  final Map<String, dynamic> item;
  final Future<void> Function(String path, {Object? data}) onAct;

  @override
  Widget build(BuildContext context) {
    final user = asMap(item['user']);
    final status = str(item['status']);
    final id = asInt(item['id']);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    money.format(asDouble(item['amount'])),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                StatusChip(status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${str(user['name'])} · ${str(item['network'])}\nRef ${str(item['payment_reference'], '—')} · ${str(item['sender_name'])} ${str(item['sender_number'])}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            if (str(item['proof_url']).isNotEmpty) ...[
              const SizedBox(height: 8),
              NetworkThumb(item['proof_url'] as String?, size: 88),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => onAct('/admin/top-ups/$id/approve'),
                    child: const Text('Approve'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final notes = await promptText(context, title: 'Reject deposit', label: 'Admin notes');
                      if (notes == null) return;
                      await onAct('/admin/top-ups/$id/reject', data: {'admin_notes': notes});
                    },
                    child: const Text('Reject'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
