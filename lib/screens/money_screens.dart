import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
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
  String withdrawalRole = 'all';
  String topUpStatus = 'pending';
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> items = [];
  Map<String, dynamic> counts = {};

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
            query: {
              'status': _withdrawals ? withdrawalStatus : topUpStatus,
              if (_withdrawals) 'role': withdrawalRole,
            },
          );
      if (!mounted) return;
      setState(() {
        items = asMaps(data['data']);
        counts = asMap(data['counts']);
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

  Future<void> _markComplete(int id) async {
    final result = await showDialog<_CompleteResult>(
      context: context,
      builder: (ctx) => const _MarkCompleteDialog(),
    );
    if (result == null || !mounted) return;
    try {
      final fields = <String, dynamic>{};
      if (result.notes.trim().isNotEmpty) {
        fields['admin_notes'] = result.notes.trim();
      }
      final response = await context.read<AdminStore>().postForm(
            '/admin/withdrawals/$id/approve',
            fields,
            fileField: result.proofPath == null ? null : 'proof',
            filePath: result.proofPath,
          );
      if (!mounted) return;
      showSnack(context, str(response['message'], 'Payout marked complete.'));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingSellers = asInt(counts['pending_sellers']);
    final pendingBuyers = asInt(counts['pending_buyers']);
    final processingCount = asInt(counts['processing']);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Money'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _withdrawals ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _withdrawals ? const Color(0xFF6EE7B7) : const Color(0xFFFDBA74)),
              ),
              child: Text(
                _withdrawals
                    ? 'Workflow: Start → send MoMo → Complete. Copy number from the card, then mark paid.'
                    : 'Workflow: Check proof → edit amount if needed → Approve. Reject if payment is wrong.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: _withdrawals ? const Color(0xFF047857) : const Color(0xFFC2410C),
                ),
              ),
            ),
          ),
          if (_withdrawals) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  for (final tab in [
                    ('all', 'everyone'),
                    ('seller', 'sellers ($pendingSellers)'),
                    ('buyer', 'buyers ($pendingBuyers)'),
                  ]) ...[
                    ChoiceChip(
                      label: Text(tab.$2),
                      selected: withdrawalRole == tab.$1,
                      selectedColor: AppColors.ringOrange,
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: withdrawalRole == tab.$1 ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      side: BorderSide(
                        color: withdrawalRole == tab.$1 ? AppColors.accent : const Color(0xFFE5E7EB),
                      ),
                      onSelected: (_) {
                        withdrawalRole = tab.$1;
                        _load();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            FilterBar(
              options: const ['pending', 'processing', 'paid', 'rejected', 'all'],
              value: withdrawalStatus,
              onChanged: (value) {
                withdrawalStatus = value;
                _load();
              },
            ),
            if (processingCount > 0 && withdrawalStatus == 'pending')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: const Color(0xFFDBEAFE),
                  child: Text(
                    'Send MoMo now ($processingCount) — switch to processing',
                    style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ] else
            FilterBar(
              options: const ['pending', 'approved', 'rejected', 'all'],
              value: topUpStatus,
              onChanged: (value) {
                topUpStatus = value;
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
                                separatorBuilder: (_, _) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return _withdrawals
                                      ? _WithdrawalCard(item, onAct: _act, onMarkComplete: _markComplete)
                                      : _TopUpCard(item, onAct: _act, onReload: _load);
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _CompleteResult {
  const _CompleteResult({required this.notes, this.proofPath});

  final String notes;
  final String? proofPath;
}

class _MarkCompleteDialog extends StatefulWidget {
  const _MarkCompleteDialog();

  @override
  State<_MarkCompleteDialog> createState() => _MarkCompleteDialogState();
}

class _MarkCompleteDialogState extends State<_MarkCompleteDialog> {
  final _notes = TextEditingController();
  String? _proofPath;
  String? _proofName;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2000);
    if (file == null) return;
    setState(() {
      _proofPath = file.path;
      _proofName = file.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mark payout complete'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Seller will see Paid. Attach a MoMo / bank receipt if you have one.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Note to seller (optional)',
                hintText: 'e.g. Sent via MTN MoMo',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickProof,
              icon: const Icon(Icons.image_outlined),
              label: Text(_proofName == null ? 'Add proof image (optional)' : _proofName!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _CompleteResult(notes: _notes.text, proofPath: _proofPath)),
          style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
          child: const Text('Confirm paid'),
        ),
      ],
    );
  }
}

class _WithdrawalCard extends StatelessWidget {
  const _WithdrawalCard(this.item, {required this.onAct, required this.onMarkComplete});

  final Map<String, dynamic> item;
  final Future<void> Function(String path, {Object? data}) onAct;
  final Future<void> Function(int id) onMarkComplete;

  Color _statusBg(String status) {
    switch (status) {
      case 'processing':
        return const Color(0xFFDBEAFE);
      case 'paid':
        return const Color(0xFFD1FAE5);
      case 'rejected':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFFFEDD5);
    }
  }

  Color _statusFg(String status) {
    switch (status) {
      case 'processing':
        return const Color(0xFF1D4ED8);
      case 'paid':
        return const Color(0xFF047857);
      case 'rejected':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFFC2410C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = asMap(item['user']);
    final seller = asMap(item['seller']);
    final status = str(item['status']);
    final role = str(user['role']);
    final id = asInt(item['id']);
    final number = str(item['momo_number']);
    final network = str(item['network_label'], str(item['network']));
    final accountName = str(item['account_name']);
    final displayName = str(seller['business_name'], str(user['name']));
    final fee = asDouble(item['fee']);
    final reference = str(item['reference'], '$id');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetails(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: status == 'processing' ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#$reference',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _statusBg(status), borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      status,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _statusFg(status)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (role.isNotEmpty)
                Text(role, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          const Text('Pay out', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          Text(
                            money.format(asDouble(item['amount'])),
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFC2410C)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: fee > 0 ? const Color(0xFFEDE9FE) : const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(fee > 0 ? 'Fee' : 'Role', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          Text(
                            fee > 0 ? money.format(fee) : (role.isEmpty ? 'user' : role),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: fee > 0 ? const Color(0xFF6D28D9) : AppColors.emerald,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
                    const Text('MoMo payout', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF047857))),
                    if (network.isNotEmpty)
                      Text(network, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            number.isEmpty ? '—' : number,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: number.isEmpty
                              ? null
                              : () => copyText(context, number, label: 'Account number copied.'),
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
                    if (accountName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(accountName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openDetails(context),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('View'),
                    ),
                  ),
                  if (status == 'pending') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => onAct('/admin/withdrawals/$id/start'),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Start'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                      onPressed: () async {
                        final reason = await promptText(context, title: 'Reject withdrawal', label: 'Reason');
                        if (reason == null) return;
                        await onAct('/admin/withdrawals/$id/reject', data: {'rejection_reason': reason});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                  if (status == 'processing') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => onMarkComplete(id),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Complete'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                      onPressed: () async {
                        final reason = await promptText(context, title: 'Reject & refund', label: 'Reason');
                        if (reason == null) return;
                        await onAct('/admin/withdrawals/$id/reject', data: {'rejection_reason': reason});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDetails(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _WithdrawalDetailsSheet(
        item: item,
        onAct: onAct,
        onMarkComplete: onMarkComplete,
      ),
    );
  }
}

class _PayToBox extends StatelessWidget {
  const _PayToBox({required this.item, required this.onCopy});

  final Map<String, dynamic> item;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final number = str(item['momo_number']);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PAY TO',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            str(item['pay_to_label'], 'Mobile money'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            str(item['network_label'], str(item['network'])),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  number.isEmpty ? '—' : number,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.4, fontFamily: 'monospace'),
                ),
              ),
              FilledButton(
                onPressed: number.isEmpty ? null : onCopy,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(72, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text('COPY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ],
          ),
          if (str(item['account_name']).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                str(item['account_name']).toUpperCase(),
                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4),
              ),
            ),
        ],
      ),
    );
  }
}

class _WithdrawalDetailsSheet extends StatefulWidget {
  const _WithdrawalDetailsSheet({
    required this.item,
    required this.onAct,
    required this.onMarkComplete,
  });

  final Map<String, dynamic> item;
  final Future<void> Function(String path, {Object? data}) onAct;
  final Future<void> Function(int id) onMarkComplete;

  @override
  State<_WithdrawalDetailsSheet> createState() => _WithdrawalDetailsSheetState();
}

class _WithdrawalDetailsSheetState extends State<_WithdrawalDetailsSheet> {
  bool acting = false;

  Map<String, dynamic> get item => widget.item;

  String _formatDate(dynamic value) {
    final raw = str(value);
    if (raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('d MMM yyyy, hh:mm a').format(dt.toLocal());
  }

  Future<void> _reject({required bool refund}) async {
    final reason = await promptText(
      context,
      title: refund ? 'Reject & refund' : 'Reject withdrawal',
      label: 'Reason',
    );
    if (reason == null || !mounted) return;
    setState(() => acting = true);
    try {
      await widget.onAct(
        '/admin/withdrawals/${asInt(item['id'])}/reject',
        data: {'rejection_reason': reason},
      );
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  Future<void> _start() async {
    setState(() => acting = true);
    try {
      await widget.onAct('/admin/withdrawals/${asInt(item['id'])}/start');
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  Future<void> _complete() async {
    setState(() => acting = true);
    try {
      await widget.onMarkComplete(asInt(item['id']));
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = asMap(item['user']);
    final seller = asMap(item['seller']);
    final wallet = asMap(item['wallet']);
    final number = str(item['momo_number']);
    final status = str(item['status']);
    final pending = status == 'pending';
    final processing = status == 'processing';
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final displayName = str(seller['business_name'], str(user['name']));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Withdrawal details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  StatusChip(status),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text('#${asInt(item['id'])}', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              Text(
                money.format(asDouble(item['amount'])),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.emerald),
              ),
              if (asDouble(item['fee']) > 0)
                Text(
                  'Fee ${money.format(asDouble(item['fee']))} · Debited ${money.format(asDouble(item['total_debited']))}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              const SizedBox(height: 16),
              _DetailRow('Name', displayName.isEmpty ? '—' : displayName),
              _DetailRow('Email', str(user['email'], '—')),
              _DetailRow('Phone', str(user['mobile'], '—')),
              _DetailRow('Role', str(user['role'], 'user')),
              _DetailRow('Method', str(item['pay_to_label'], 'Mobile money')),
              _DetailRow('Network', str(item['network_label'], str(item['network'], '—')).toUpperCase()),
              _DetailRow('Account', number.isEmpty ? '—' : number),
              if (str(item['account_name']).isNotEmpty)
                _DetailRow('Account name', str(item['account_name'])),
              _DetailRow('Status', status),
              _DetailRow('Created', _formatDate(item['created_at'])),
              if (str(item['processed_at']).isNotEmpty)
                _DetailRow('Processed', _formatDate(item['processed_at'])),
              if (str(item['rejection_reason']).isNotEmpty)
                _DetailRow('Reject reason', str(item['rejection_reason'])),
              if (str(item['admin_notes']).isNotEmpty)
                _DetailRow('Admin notes', str(item['admin_notes'])),
              if (wallet.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CURRENT AVAILABLE BALANCE',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
                      ),
                      Text(
                        money.format(asDouble(wallet['available_balance'])),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
                      ),
                      Text(
                        'Pending ${money.format(asDouble(wallet['pending_balance']))} · Withdrawn ${money.format(asDouble(wallet['withdrawn_amount']))}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF047857)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _PayToBox(
                item: item,
                onCopy: () => copyText(context, number, label: 'Account number copied.'),
              ),
              const SizedBox(height: 14),
              const Text('Transaction timeline', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _TimelineDot(label: 'Withdrawal created', when: _formatDate(item['created_at'])),
              if (str(item['processed_at']).isNotEmpty)
                _TimelineDot(label: 'Processed', when: _formatDate(item['processed_at'])),
              if (pending || processing) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (pending)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: acting ? null : _start,
                          style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: Text(acting ? '…' : 'Start'),
                        ),
                      ),
                    if (processing)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: acting ? null : _complete,
                          style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(acting ? '…' : 'Complete'),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: acting ? null : () => _reject(refund: processing),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: Color(0xFFFECACA)),
                        ),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineDot extends StatelessWidget {
  const _TimelineDot({required this.label, required this.when});

  final String label;
  final String when;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label: $when',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopUpCard extends StatelessWidget {
  const _TopUpCard(this.item, {required this.onAct, required this.onReload});

  final Map<String, dynamic> item;
  final Future<void> Function(String path, {Object? data}) onAct;
  final Future<void> Function() onReload;

  Color _statusBg(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFFD1FAE5);
      case 'rejected':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFFFEDD5);
    }
  }

  Color _statusFg(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF047857);
      case 'rejected':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFFC2410C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = asMap(item['user']);
    final status = str(item['status']);
    final proof = str(item['proof_url']);
    final pending = status == 'pending';
    final network = str(item['network']);
    final reference = str(item['payment_reference']);
    final senderName = str(item['sender_name']);
    final senderNumber = str(item['sender_number']);
    final id = asInt(item['id']);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetails(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: pending ? const Color(0xFFFFF7ED) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#$id',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _statusBg(status), borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      status,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _statusFg(status)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(str(user['name'], 'Buyer'), style: const TextStyle(fontWeight: FontWeight.w700)),
              if (network.isNotEmpty)
                Text(network.toUpperCase(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          const Text('Deposit', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          Text(
                            money.format(asDouble(item['amount'])),
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFC2410C)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          const Text('Network', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          Text(
                            network.isEmpty ? '—' : network.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.emerald),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
                    const Text('Payment details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF047857))),
                    Text(
                      'Ref ${reference.isEmpty ? '—' : reference}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (senderName.isNotEmpty || senderNumber.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        [if (senderName.isNotEmpty) senderName, if (senderNumber.isNotEmpty) senderNumber].join(' · '),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                    if (senderNumber.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              senderNumber,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                            ),
                          ),
                          FilledButton(
                            onPressed: () => copyText(context, senderNumber, label: 'Sender number copied.'),
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
                  ],
                ),
              ),
              if (proof.isNotEmpty) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _openDetails(context),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: CachedNetworkImage(
                        imageUrl: ApiConfig.resolveMediaUrl(proof),
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: const Color(0xFFFFF7ED), alignment: Alignment.center, child: const CircularProgressIndicator(strokeWidth: 2)),
                        errorWidget: (_, _, _) => Container(
                          color: const Color(0xFFFFF7ED),
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_outlined, color: AppColors.accent, size: 40),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: pending
                        ? OutlinedButton.icon(
                            onPressed: () => _openDetails(context),
                            icon: const Icon(Icons.rate_review_outlined, size: 18),
                            label: const Text('Review'),
                          )
                        : OutlinedButton.icon(
                            onPressed: () => _openDetails(context),
                            icon: const Icon(Icons.visibility_outlined, size: 18),
                            label: const Text('View'),
                          ),
                  ),
                  if (pending) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => onAct('/admin/top-ups/$id/approve'),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                      onPressed: () async {
                        final notes = await promptText(context, title: 'Reject deposit', label: 'Admin notes');
                        if (notes == null) return;
                        await onAct('/admin/top-ups/$id/reject', data: {'admin_notes': notes});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDetails(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _TopUpDetailsSheet(
        item: item,
        onAct: onAct,
        onReload: onReload,
      ),
    );
  }
}

class _TopUpDetailsSheet extends StatefulWidget {
  const _TopUpDetailsSheet({
    required this.item,
    required this.onAct,
    required this.onReload,
  });

  final Map<String, dynamic> item;
  final Future<void> Function(String path, {Object? data}) onAct;
  final Future<void> Function() onReload;

  @override
  State<_TopUpDetailsSheet> createState() => _TopUpDetailsSheetState();
}

class _TopUpDetailsSheetState extends State<_TopUpDetailsSheet> {
  late final TextEditingController _amount;
  late final double _originalAmount;
  bool saving = false;
  bool acting = false;

  @override
  void initState() {
    super.initState();
    _originalAmount = asDouble(widget.item['amount']);
    _amount = TextEditingController(text: _originalAmount.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String _formatDate(dynamic value) {
    final raw = str(value);
    if (raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('d MMM yyyy, hh:mm a').format(dt.toLocal());
  }

  Future<void> _saveAmount() async {
    final parsed = double.tryParse(_amount.text.trim());
    if (parsed == null || parsed < 1) {
      showSnack(context, 'Enter a valid amount (min GH₵1).', error: true);
      return;
    }
    setState(() => saving = true);
    try {
      // POST (not PATCH) — matches web admin; some proxies reject PATCH.
      final result = await context.read<AdminStore>().postJson(
            '/admin/top-ups/${asInt(widget.item['id'])}/amount',
            data: {'amount': parsed},
          );
      if (!mounted) return;
      widget.item['amount'] = parsed;
      showSnack(context, str(result['message'], 'Amount updated.'));
      await widget.onReload();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _approve() async {
    final parsed = double.tryParse(_amount.text.trim());
    if (parsed == null || parsed < 1) {
      showSnack(context, 'Enter a valid amount (min GH₵1).', error: true);
      return;
    }
    if ((parsed - _originalAmount).abs() > 0.001) {
      final ok = await confirmAction(
        context,
        title: 'Approve different amount?',
        body: 'User submitted ${money.format(_originalAmount)} but you will credit ${money.format(parsed)}.',
        action: 'Approve',
      );
      if (!ok || !mounted) return;
    }
    setState(() => acting = true);
    try {
      await widget.onAct(
        '/admin/top-ups/${asInt(widget.item['id'])}/approve',
        data: {'amount': parsed},
      );
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  Future<void> _reject() async {
    final notes = await promptText(context, title: 'Reject deposit', label: 'Admin notes');
    if (notes == null || !mounted) return;
    setState(() => acting = true);
    try {
      await widget.onAct(
        '/admin/top-ups/${asInt(widget.item['id'])}/reject',
        data: {'admin_notes': notes},
      );
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = asMap(widget.item['user']);
    final status = str(widget.item['status']);
    final proof = str(widget.item['proof_url']);
    final pending = status == 'pending';
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Review deposit',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  StatusChip(status),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text('#${asInt(widget.item['id'])}', style: const TextStyle(color: AppColors.textSecondary)),
              if (pending) ...[
                const SizedBox(height: 6),
                const Text(
                  'Check the payment proof below. Change the amount if the user entered the wrong value.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35),
                ),
              ],
              const SizedBox(height: 14),
              if (proof.isNotEmpty) ...[
                const Text('Payment proof', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _openProof(context, proof),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: CachedNetworkImage(
                        imageUrl: ApiConfig.resolveMediaUrl(proof),
                        fit: BoxFit.contain,
                        placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _openProof(context, proof),
                  child: const Text('Open full size'),
                ),
                const SizedBox(height: 8),
              ],
              if (pending) ...[
                const Text('Amount to credit', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          prefixText: 'GH₵ ',
                          hintText: '0.00',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: saving || acting ? null : _saveAmount,
                      icon: saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined, size: 16),
                      label: Text(saving ? 'Saving…' : 'Save'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Match this to the proof screenshot, then Save or Approve.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Text(
                  money.format(asDouble(widget.item['amount'])),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.emerald),
                ),
                const SizedBox(height: 16),
              ],
              _DetailRow('Name', str(user['name'], '—')),
              _DetailRow('Email', str(user['email'], '—')),
              _DetailRow('Phone', str(user['mobile'], '—')),
              _DetailRow('Network', str(widget.item['network'], '—').toUpperCase()),
              _DetailRow('Reference', str(widget.item['payment_reference'], '—')),
              _DetailRow('Sender', '${str(widget.item['sender_name'], '—')} ${str(widget.item['sender_number'])}'.trim()),
              _DetailRow('Created', _formatDate(widget.item['created_at'])),
              if (str(widget.item['reviewed_at']).isNotEmpty)
                _DetailRow('Reviewed', _formatDate(widget.item['reviewed_at'])),
              if (str(widget.item['user_note']).isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('User note', style: TextStyle(fontWeight: FontWeight.w800)),
                Text(str(widget.item['user_note']), style: const TextStyle(color: AppColors.textSecondary)),
              ],
              if (str(widget.item['admin_notes']).isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Admin notes', style: TextStyle(fontWeight: FontWeight.w800)),
                Text(str(widget.item['admin_notes']), style: const TextStyle(color: AppColors.textSecondary)),
              ],
              if (pending) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: acting || saving ? null : _approve,
                        style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(acting ? '…' : 'Approve'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: acting || saving ? null : _reject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: Color(0xFFFECACA)),
                        ),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}

void _openProof(BuildContext context, String url) {
  final resolved = ApiConfig.resolveMediaUrl(url);
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: resolved,
              fit: BoxFit.contain,
              errorWidget: (_, _, _) => const Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.white, size: 48),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}
