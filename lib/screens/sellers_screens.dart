import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../store/admin_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class SellersScreen extends StatefulWidget {
  const SellersScreen({super.key});

  @override
  State<SellersScreen> createState() => _SellersScreenState();
}

class _SellersScreenState extends State<SellersScreen> {
  String status = 'pending';
  String search = '';
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> sellers = [];
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await context.read<AdminStore>().getJson('/admin/sellers', query: {
        'status': status,
        if (search.isNotEmpty) 'search': search,
      });
      if (!mounted) return;
      setState(() {
        sellers = asMaps(data['data']);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Sellers')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search store, name, mobile',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    search = _search.text.trim();
                    _load();
                  },
                ),
              ),
              onSubmitted: (value) {
                search = value.trim();
                _load();
              },
            ),
          ),
          FilterBar(
            options: const ['pending', 'approved', 'rejected', 'suspended', 'all'],
            value: status,
            onChanged: (value) {
              status = value;
              _load();
            },
          ),
          Expanded(
            child: loading
                ? const FullPageLoader(label: 'Loading sellers…')
                : error != null
                    ? ErrorRetry(message: error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: sellers.isEmpty
                            ? ListView(children: const [SizedBox(height: 80), EmptyState('No sellers in this list.')])
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                                itemCount: sellers.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final seller = sellers[index];
                                  final user = asMap(seller['user']);
                                  return Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    child: ListTile(
                                      leading: NetworkThumb(seller['shop_photo'] as String?),
                                      title: Text(str(seller['store_name'], 'Store')),
                                      subtitle: Text('${str(user['name'])} · ${str(user['mobile'])}'),
                                      trailing: StatusChip(str(seller['status'], 'pending')),
                                      onTap: () => context.push('/sellers/${seller['id']}'),
                                    ),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class SellerDetailScreen extends StatefulWidget {
  const SellerDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<SellerDetailScreen> createState() => _SellerDetailScreenState();
}

class _SellerDetailScreenState extends State<SellerDetailScreen> {
  bool loading = true;
  bool busy = false;
  String? error;
  Map<String, dynamic> seller = {};

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
      final data = await context.read<AdminStore>().getJson('/admin/sellers/${widget.id}');
      if (!mounted) return;
      setState(() {
        seller = asMap(data['data']);
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

  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    setState(() => busy = true);
    try {
      final data = await action();
      if (!mounted) return;
      showSnack(context, str(data['message'], 'Done.'));
      setState(() {
        if (data['data'] is Map) seller = asMap(data['data']);
        busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = asMap(seller['user']);
    final activation = asMap(seller['activation']);
    final status = str(seller['status']);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(str(seller['store_name'], 'Seller'))),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    if (busy) const LinearProgressIndicator(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: NetworkThumb(seller['shop_photo'] as String?, size: 64),
                      title: Text(str(user['name'])),
                      subtitle: Text('${str(user['email'])}\n${str(user['mobile'])}'),
                      isThreeLine: true,
                      trailing: StatusChip(status),
                    ),
                    if (str(seller['rejection_reason']).isNotEmpty)
                      Text('Reason: ${seller['rejection_reason']}'),
                    if (activation.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Activation: ${str(activation['status'], 'n/a')}'),
                    ],
                    const SizedBox(height: 16),
                    if (status == 'pending') ...[
                      PrimaryButton(
                        label: 'Approve seller',
                        onPressed: () => _run(
                          () => context.read<AdminStore>().postJson('/admin/sellers/${widget.id}/approve'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () async {
                          final reason = await promptText(context, title: 'Reject application');
                          if (reason == null || !context.mounted) return;
                          await _run(
                            () => context.read<AdminStore>().postJson(
                                  '/admin/sellers/${widget.id}/reject',
                                  data: {'rejection_reason': reason},
                                ),
                          );
                        },
                        child: const Text('Reject'),
                      ),
                    ],
                    if (status == 'approved') ...[
                      OutlinedButton(
                        onPressed: () async {
                          final reason = await promptText(context, title: 'Block this seller');
                          if (reason == null || !context.mounted) return;
                          await _run(
                            () => context.read<AdminStore>().postJson(
                                  '/admin/sellers/${widget.id}/block',
                                  data: {'reason': reason},
                                ),
                          );
                        },
                        child: const Text('Block seller'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () async {
                          final amount = await promptText(
                            context,
                            title: 'Yearly activation fee',
                            label: 'Amount (GHS)',
                            keyboardType: TextInputType.number,
                            action: 'Prompt',
                          );
                          if (amount == null || !context.mounted) return;
                          await _run(
                            () => context.read<AdminStore>().postJson(
                                  '/admin/sellers/${widget.id}/activation/prompt',
                                  data: {'amount': amount},
                                ),
                          );
                        },
                        child: const Text('Prompt activation fee'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => _run(
                          () => context.read<AdminStore>().postJson(
                                '/admin/sellers/${widget.id}/activation/waive',
                              ),
                        ),
                        child: const Text('Waive fee for 1 year'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => _run(
                          () => context.read<AdminStore>().postJson(
                                '/admin/sellers/${widget.id}/activation/end',
                              ),
                        ),
                        child: const Text('End activation now'),
                      ),
                    ],
                    if (status == 'suspended')
                      PrimaryButton(
                        label: 'Unblock seller',
                        onPressed: () => _run(
                          () => context.read<AdminStore>().postJson('/admin/sellers/${widget.id}/unblock'),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Text('Account', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _run(
                        () => context.read<AdminStore>().postJson('/admin/sellers/${widget.id}/resend-invite'),
                      ),
                      child: const Text('Resend registration link'),
                    ),
                    const SizedBox(height: 8),
                    if (seller['payment_methods_locked'] == true)
                      OutlinedButton(
                        onPressed: () => _run(
                          () => context.read<AdminStore>().postJson('/admin/sellers/${widget.id}/payment-methods/unlock'),
                        ),
                        child: const Text('Unlock payment methods'),
                      ),
                    ...asMaps(seller['payment_methods']).map((method) {
                      final disabled = method['is_disabled'] == true;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(str(method['label'])),
                        subtitle: disabled ? Text(str(method['disabled_reason'])) : null,
                        trailing: TextButton(
                          onPressed: () async {
                            if (disabled) {
                              await _run(
                                () => context.read<AdminStore>().postJson(
                                      '/admin/sellers/${widget.id}/payment-methods/${method['id']}/enable',
                                    ),
                              );
                              return;
                            }
                            final reason = await promptText(context, title: 'Disable payment method');
                            if (reason == null || !context.mounted) return;
                            await _run(
                              () => context.read<AdminStore>().postJson(
                                    '/admin/sellers/${widget.id}/payment-methods/${method['id']}/disable',
                                    data: {'reason': reason},
                                  ),
                            );
                          },
                          child: Text(disabled ? 'Enable' : 'Disable'),
                        ),
                      );
                    }),
                    OutlinedButton(
                      onPressed: () async {
                        final reason = await promptText(context, title: 'Delete seller', label: 'Reason');
                        if (reason == null || !context.mounted) return;
                        final confirm = await promptText(context, title: 'Type the store name', label: 'Store name');
                        if (confirm == null || !context.mounted) return;
                        try {
                          final result = await context.read<AdminStore>().deleteJson(
                                '/admin/sellers/${widget.id}',
                                data: {'reason': reason, 'confirm_store_name': confirm},
                              );
                          if (!context.mounted) return;
                          showSnack(context, str(result['message'], 'Deleted.'));
                          context.pop();
                        } on ApiException catch (e) {
                          if (!context.mounted) return;
                          showSnack(context, e.message, error: true);
                        }
                      },
                      child: const Text('Delete seller', style: TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
    );
  }
}
