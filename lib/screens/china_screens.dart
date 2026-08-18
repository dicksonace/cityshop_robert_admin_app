import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../store/admin_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'extra_screens.dart';

class ChinaTransfersScreen extends StatelessWidget {
  const ChinaTransfersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminResourceList(
      title: 'Transfer RMB',
      path: '/admin/china-transfers',
      filters: const ['open', 'all', 'payment_submitted', 'processing', 'rmb_sent', 'completed'],
      searchHint: 'Search reference or buyer',
      itemBuilder: (item, _) => _TransferTile(
        item: item,
        onTap: () => context.push('/china-transfers/${item['id']}'),
      ),
    );
  }
}

class SellRmbScreen extends StatelessWidget {
  const SellRmbScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminResourceList(
      title: 'Sell RMB (China → GHS)',
      path: '/admin/sell-rmb',
      filters: const ['open', 'all', 'submitted', 'rmb_verification', 'payout_processing', 'completed'],
      searchHint: 'Search reference or buyer',
      itemBuilder: (item, _) => _TransferTile(
        item: item,
        onTap: () => context.push('/sell-rmb/${item['id']}'),
      ),
    );
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = asMap(item['user']);
    final quote = asMap(item['quote']);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        title: Text(str(item['reference'], '#${item['id']}')),
        subtitle: Text('${str(user['name'])} · ${str(item['status_label'], str(item['status']))}'),
        trailing: Text(
          quote.isEmpty ? '' : str(asMap(quote['breakdown'])['total'], money.format(asDouble(quote['total_payable_ghs']))),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        onTap: onTap,
      ),
    );
  }
}

class ChinaTransferDetailScreen extends StatelessWidget {
  const ChinaTransferDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context) {
    return _TransferDetail(
      id: id,
      loadPath: '/admin/china-transfers/$id',
      title: 'Buy RMB',
      actions: const [
        ('verify', 'Verify payment', false),
        ('process', 'Start processing', false),
        ('sent', 'Mark RMB sent', true),
        ('complete', 'Complete', false),
        ('reject', 'Reject', false),
        ('fail', 'Fail', false),
        ('cancel', 'Cancel', false),
      ],
    );
  }
}

class SellRmbDetailScreen extends StatelessWidget {
  const SellRmbDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context) {
    return _TransferDetail(
      id: id,
      loadPath: '/admin/sell-rmb/$id',
      title: 'Sell RMB',
      actions: const [
        ('verify', 'Start verification', false),
        ('received', 'RMB received', false),
        ('process', 'Start payout', false),
        ('paid', 'Mark paid', true),
        ('complete', 'Complete', false),
        ('reject', 'Reject', false),
        ('fail', 'Fail', false),
        ('cancel', 'Cancel', false),
      ],
    );
  }
}

class _TransferDetail extends StatefulWidget {
  const _TransferDetail({
    required this.id,
    required this.loadPath,
    required this.title,
    required this.actions,
  });

  final int id;
  final String loadPath;
  final String title;
  final List<(String, String, bool)> actions;

  @override
  State<_TransferDetail> createState() => _TransferDetailState();
}

class _TransferDetailState extends State<_TransferDetail> {
  bool loading = true;
  String? error;
  Map<String, dynamic> item = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AdminStore>().getJson(widget.loadPath);
      if (!mounted) return;
      setState(() {
        item = asMap(data['data']);
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

  Future<void> _run(String action, bool needsProof) async {
    final store = context.read<AdminStore>();
    final base = widget.loadPath;
    try {
      Map<String, dynamic> result;
      if (needsProof) {
        final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
        if (file == null || !mounted) return;
        final amount = await promptText(
          context,
          title: action == 'sent' ? 'RMB sent' : 'Payout amount',
          label: 'Amount',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        );
        if (amount == null || !mounted) return;
        result = await store.postForm(
          '$base/$action',
          {
            if (action == 'sent') 'rmb_sent_amount': amount else 'payout_amount': amount,
          },
          fileField: 'proof',
          filePath: file.path,
        );
      } else if (action == 'reject' || action == 'fail') {
        final reason = await promptText(context, title: 'Reason');
        if (reason == null || !mounted) return;
        result = await store.postJson('$base/$action', data: {'reason': reason});
      } else if (action == 'cancel') {
        result = await store.postJson('$base/$action');
      } else {
        result = await store.postJson('$base/$action');
      }
      if (!mounted) return;
      showSnack(context, str(result['message'], 'Updated.'));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = asMap(item['user']);
    final quote = asMap(item['quote']);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(str(item['reference'], widget.title))),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(str(user['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    Text(str(user['mobile'])),
                    const SizedBox(height: 8),
                    StatusChip(str(item['status_label'], str(item['status']))),
                    const SizedBox(height: 12),
                    Text(str(asMap(quote['breakdown'])['total'])),
                    Text(str(asMap(quote['breakdown'])['rmb'])),
                    const SizedBox(height: 16),
                    ...widget.actions.map(
                      (action) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton(
                          onPressed: () => _run(action.$1, action.$3),
                          child: Text(action.$2),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class ChinaSettingsScreen extends StatefulWidget {
  const ChinaSettingsScreen({super.key});

  @override
  State<ChinaSettingsScreen> createState() => _ChinaSettingsScreenState();
}

class _ChinaSettingsScreenState extends State<ChinaSettingsScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await context.read<AdminStore>().getJson('/admin/china-transfers/settings');
      if (!mounted) return;
      setState(() {
        data = result;
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
    final settings = asMap(data['settings']);
    final rate = asMap(data['current_rate']);
    final enabled = settings['enabled'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Buy RMB settings')),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SwitchListTile(
                      title: const Text('Live for buyers'),
                      subtitle: const Text('Alipay only in China'),
                      value: enabled,
                      onChanged: (value) async {
                        try {
                          await context.read<AdminStore>().postJson('/admin/china-transfers/settings', data: {
                            'enabled': value,
                            'instructions': settings['instructions'],
                          });
                          await _load();
                        } on ApiException catch (e) {
                          if (!context.mounted) return;
                          showSnack(context, e.message, error: true);
                        }
                      },
                    ),
                    Text('Current rate: ${str(rate['ghs_per_rmb'], 'not set')} GHS per RMB'),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Publish new rate',
                      onPressed: () async {
                        final ghs = await promptText(context, title: 'GHS per 1 RMB', label: 'Rate', keyboardType: const TextInputType.numberWithOptions(decimal: true));
                        if (ghs == null || !context.mounted) return;
                        try {
                          await context.read<AdminStore>().postJson('/admin/china-transfers/rates', data: {
                            'ghs_per_rmb': ghs,
                            'fee_mode': 'percent',
                            'fee_value': 0,
                            'min_ghs': 50,
                            'max_ghs': 50000,
                          });
                          if (!context.mounted) return;
                          showSnack(context, 'Rate published.');
                          await _load();
                        } on ApiException catch (e) {
                          if (!context.mounted) return;
                          showSnack(context, e.message, error: true);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Payment methods', style: TextStyle(fontWeight: FontWeight.w800)),
                    ...asMaps(data['methods']).map((method) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(str(method['name'])),
                          trailing: StatusChip(method['active'] == true ? 'active' : 'off'),
                        )),
                  ],
                ),
    );
  }
}

class SellRmbSettingsScreen extends StatefulWidget {
  const SellRmbSettingsScreen({super.key});

  @override
  State<SellRmbSettingsScreen> createState() => _SellRmbSettingsScreenState();
}

class _SellRmbSettingsScreenState extends State<SellRmbSettingsScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await context.read<AdminStore>().getJson('/admin/sell-rmb/settings');
      if (!mounted) return;
      setState(() {
        data = result;
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
    final settings = asMap(data['settings']);
    final rate = asMap(data['current_rate']);
    final enabled = settings['enabled'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Sell RMB settings')),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SwitchListTile(
                      title: const Text('Live for buyers'),
                      value: enabled,
                      onChanged: (value) async {
                        try {
                          await context.read<AdminStore>().postJson('/admin/sell-rmb/settings', data: {
                            'enabled': value,
                            'instructions': settings['instructions'],
                            'receive_instructions': settings['receive_instructions'],
                          });
                          await _load();
                        } on ApiException catch (e) {
                          if (!context.mounted) return;
                          showSnack(context, e.message, error: true);
                        }
                      },
                    ),
                    Text('Buying rate: ${str(rate['ghs_per_rmb'], 'not set')} GHS per RMB'),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Publish buying rate',
                      onPressed: () async {
                        final ghs = await promptText(context, title: 'GHS per 1 RMB', label: 'Rate', keyboardType: const TextInputType.numberWithOptions(decimal: true));
                        if (ghs == null || !context.mounted) return;
                        try {
                          await context.read<AdminStore>().postJson('/admin/sell-rmb/rates', data: {
                            'ghs_per_rmb': ghs,
                            'fee_mode': 'percent',
                            'fee_value': 0,
                            'min_rmb': 50,
                            'max_rmb': 50000,
                          });
                          if (!context.mounted) return;
                          showSnack(context, 'Rate published.');
                          await _load();
                        } on ApiException catch (e) {
                          if (!context.mounted) return;
                          showSnack(context, e.message, error: true);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Receive methods', style: TextStyle(fontWeight: FontWeight.w800)),
                    ...asMaps(data['methods']).map((method) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(str(method['name'])),
                          trailing: StatusChip(method['active'] == true ? 'active' : 'off'),
                        )),
                  ],
                ),
    );
  }
}
