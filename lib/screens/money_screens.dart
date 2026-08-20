import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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
          if (_withdrawals) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                '1) Start processing so the seller sees progress. 2) Send MoMo / bank yourself. 3) Mark complete with optional proof, or reject with a reason. Target: about 15 minutes.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.35),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  for (final tab in [
                    ('all', 'Everyone'),
                    ('seller', 'Sellers ($pendingSellers)'),
                    ('buyer', 'Buyers ($pendingBuyers)'),
                  ]) ...[
                    ChoiceChip(
                      label: Text(tab.$2),
                      selected: withdrawalRole == tab.$1,
                      selectedColor: AppColors.blue,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: withdrawalRole == tab.$1 ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  for (final tab in [
                    ('pending', 'Pending'),
                    ('processing', 'Processing ($processingCount)'),
                    ('paid', 'Paid'),
                    ('rejected', 'Rejected'),
                    ('all', 'All'),
                  ]) ...[
                    ChoiceChip(
                      label: Text(tab.$2),
                      selected: withdrawalStatus == tab.$1,
                      selectedColor: AppColors.blue,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: withdrawalStatus == tab.$1 ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                      onSelected: (_) {
                        withdrawalStatus = tab.$1;
                        _load();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
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
                                separatorBuilder: (_, _) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return _withdrawals
                                      ? _WithdrawalCard(item, onAct: _act, onMarkComplete: _markComplete)
                                      : _TopUpCard(item, onAct: _act);
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

  @override
  Widget build(BuildContext context) {
    final user = asMap(item['user']);
    final seller = asMap(item['seller']);
    final wallet = asMap(item['wallet']);
    final status = str(item['status']);
    final role = str(user['role']);
    final id = asInt(item['id']);
    final number = str(item['momo_number']);
    final fee = asDouble(item['fee']);
    final displayName = str(seller['business_name'], str(user['name']));
    final isSeller = role == 'seller';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        money.format(asDouble(item['amount'])),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                      if (fee > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Fee ${money.format(fee)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6D28D9)),
                          ),
                        ),
                      StatusChip(status),
                      StatusChip(role.isEmpty ? 'user' : role, color: isSeller ? AppColors.accent : AppColors.blue),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(
              [
                str(user['email']),
                str(user['mobile']),
              ].where((e) => e.isNotEmpty).join(' · '),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 10),
            _PayToBox(
              item: item,
              onCopy: () => copyText(context, number, label: 'Account number copied.'),
            ),
            if (isSeller && wallet.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.storefront, size: 16, color: Color(0xFF9A3412)),
                        SizedBox(width: 6),
                        Text('Seller details', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF9A3412))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _WalletLine('Store', displayName),
                    _WalletLine('Current available', money.format(asDouble(wallet['available_balance'])), valueColor: AppColors.emerald),
                    _WalletLine('Pending balance', money.format(asDouble(wallet['pending_balance']))),
                    _WalletLine('Lifetime withdrawn', money.format(asDouble(wallet['withdrawn_amount']))),
                    const SizedBox(height: 4),
                    const Text('Seller earnings withdrawal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFC2410C))),
                  ],
                ),
              ),
            ] else if (!isSeller && wallet.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Current available: ${money.format(asDouble(wallet['available_balance']))}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _openDetails(context),
                  child: const Text('Full details'),
                ),
                if (status == 'pending') ...[
                  FilledButton.icon(
                    onPressed: () => onAct('/admin/withdrawals/$id/start'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.blue),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Start processing'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final reason = await promptText(context, title: 'Reject withdrawal', label: 'Reason');
                      if (reason == null) return;
                      await onAct('/admin/withdrawals/$id/reject', data: {'rejection_reason': reason});
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: Color(0xFFFECACA))),
                    child: const Text('Reject'),
                  ),
                ],
                if (status == 'processing') ...[
                  FilledButton.icon(
                    onPressed: () => onMarkComplete(id),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Mark complete'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final reason = await promptText(context, title: 'Reject & refund', label: 'Reason');
                      if (reason == null) return;
                      await onAct('/admin/withdrawals/$id/reject', data: {'rejection_reason': reason});
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: Color(0xFFFECACA))),
                    child: const Text('Reject & refund'),
                  ),
                ],
              ],
            ),
          ],
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
      builder: (ctx) => _WithdrawalDetailsSheet(item: item),
    );
  }
}

class _WalletLine extends StatelessWidget {
  const _WalletLine(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9A3412)))),
          Text(
            value,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: valueColor ?? const Color(0xFF7C2D12)),
          ),
        ],
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

class _WithdrawalDetailsSheet extends StatelessWidget {
  const _WithdrawalDetailsSheet({required this.item});

  final Map<String, dynamic> item;

  String _formatDate(dynamic value) {
    final raw = str(value);
    if (raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('d MMM yyyy, hh:mm:ss a').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final user = asMap(item['user']);
    final seller = asMap(item['seller']);
    final wallet = asMap(item['wallet']);
    final number = str(item['momo_number']);
    final status = str(item['status']);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Withdrawal #${asInt(item['id'])}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  StatusChip(status),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Amount to send', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              Text(
                money.format(asDouble(item['amount'])),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.emerald),
              ),
              if (asDouble(item['fee']) > 0)
                Text(
                  'Fee ${money.format(asDouble(item['fee']))} · Debited ${money.format(asDouble(item['total_debited']))}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              const SizedBox(height: 14),
              Text(
                str(user['role']) == 'seller' ? 'Seller' : 'User',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(str(seller['business_name'], str(user['name']))),
              if (str(user['email']).isNotEmpty) Text(str(user['email']), style: const TextStyle(color: AppColors.textSecondary)),
              if (str(user['mobile']).isNotEmpty) Text(str(user['mobile']), style: const TextStyle(color: AppColors.textSecondary)),
              if (str(seller['slug']).isNotEmpty)
                Text('Store: /store/${str(seller['slug'])}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
                      const Text('CURRENT AVAILABLE BALANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF047857))),
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
              const Text('Timeline', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Requested: ${_formatDate(item['created_at'])}'),
              Text('Processed: ${_formatDate(item['processed_at'])}'),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
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
