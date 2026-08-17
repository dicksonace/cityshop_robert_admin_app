import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../store/admin_store.dart';
import '../widgets/common_widgets.dart';

class SmsSettingsScreen extends StatefulWidget {
  const SmsSettingsScreen({super.key});

  @override
  State<SmsSettingsScreen> createState() => _SmsSettingsScreenState();
}

class _SmsSettingsScreenState extends State<SmsSettingsScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> settings = {};
  final _alert1 = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _alert1.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AdminStore>().getJson('/admin/settings/sms');
      if (!mounted) return;
      settings = asMap(data['settings']);
      _alert1.text = str(settings['alert_mobile_1']);
      setState(() => loading = false);
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
      appBar: AppBar(title: const Text('SMS settings')),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: str(settings['driver'], 'formula_dc'),
                      items: const [
                        DropdownMenuItem(value: 'formula_dc', child: Text('Formula DC')),
                        DropdownMenuItem(value: 'txtconnect', child: Text('TxtConnect')),
                      ],
                      onChanged: (value) => settings['driver'] = value,
                      decoration: const InputDecoration(labelText: 'Provider'),
                    ),
                    SwitchListTile(
                      title: const Text('Failover'),
                      value: settings['failover'] == true,
                      onChanged: (value) => setState(() => settings['failover'] = value),
                    ),
                    TextField(controller: _alert1, decoration: const InputDecoration(labelText: 'Alert mobile 1')),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Save',
                      onPressed: () async {
                        try {
                          final result = await context.read<AdminStore>().postJson('/admin/settings/sms', data: {
                            'driver': settings['driver'] ?? 'formula_dc',
                            'failover': settings['failover'] == true,
                            'alert_mobile_1': _alert1.text.trim(),
                            'alert_mobile_2': settings['alert_mobile_2'] ?? '',
                            'alert_mobile_3': settings['alert_mobile_3'] ?? '',
                            'alert_mobile_4': settings['alert_mobile_4'] ?? '',
                          });
                          if (!context.mounted) return;
                          showSnack(context, str(result['message'], 'Saved.'));
                        } on ApiException catch (e) {
                          if (!context.mounted) return;
                          showSnack(context, e.message, error: true);
                        }
                      },
                    ),
                  ],
                ),
    );
  }
}

class PaystackSettingsScreen extends StatefulWidget {
  const PaystackSettingsScreen({super.key});

  @override
  State<PaystackSettingsScreen> createState() => _PaystackSettingsScreenState();
}

class _PaystackSettingsScreenState extends State<PaystackSettingsScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> settings = {};
  bool locked = false;
  final _percent = TextEditingController();
  final _flat = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _percent.dispose();
    _flat.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AdminStore>().getJson('/admin/settings/paystack');
      if (!mounted) return;
      settings = asMap(data['settings']);
      locked = data['payments_locked'] == true;
      _percent.text = str(settings['percent'], '0');
      _flat.text = str(settings['flat'], '0');
      setState(() => loading = false);
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
      appBar: AppBar(title: const Text('Paystack')),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SwitchListTile(
                      title: const Text('Disable Paystack checkout'),
                      value: locked,
                      onChanged: (value) async {
                        try {
                          await context.read<AdminStore>().postJson('/admin/settings/paystack/lock', data: {'locked': value});
                          await _load();
                        } on ApiException catch (e) {
                          if (!context.mounted) return;
                          showSnack(context, e.message, error: true);
                        }
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Fee enabled'),
                      value: settings['enabled'] == true,
                      onChanged: (value) => setState(() => settings['enabled'] = value),
                    ),
                    TextField(controller: _percent, decoration: const InputDecoration(labelText: 'Percent'), keyboardType: TextInputType.number),
                    const SizedBox(height: 8),
                    TextField(controller: _flat, decoration: const InputDecoration(labelText: 'Flat GHS'), keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Save fees',
                      onPressed: () async {
                        try {
                          final result = await context.read<AdminStore>().postJson('/admin/settings/paystack', data: {
                            'enabled': settings['enabled'] == true,
                            'mode': settings['mode'] ?? 'percent',
                            'percent': _percent.text,
                            'flat': _flat.text,
                          });
                          if (!context.mounted) return;
                          showSnack(context, str(result['message'], 'Saved.'));
                        } on ApiException catch (e) {
                          if (!context.mounted) return;
                          showSnack(context, e.message, error: true);
                        }
                      },
                    ),
                  ],
                ),
    );
  }
}

class WithdrawalSettingsScreen extends StatefulWidget {
  const WithdrawalSettingsScreen({super.key});

  @override
  State<WithdrawalSettingsScreen> createState() => _WithdrawalSettingsScreenState();
}

class _WithdrawalSettingsScreenState extends State<WithdrawalSettingsScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> settings = {};
  Map<String, dynamic> auto = {};
  final _amount = TextEditingController();
  final _momo = TextEditingController();
  final _autoPercent = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _momo.dispose();
    _autoPercent.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AdminStore>().getJson('/admin/settings/withdrawal');
      if (!mounted) return;
      settings = asMap(data['settings']);
      auto = asMap(data['auto_paystack']);
      _amount.text = str(settings['amount'], '0');
      _momo.text = str(settings['momo_amount'], '0');
      _autoPercent.text = str(auto['fee_percent'], '0');
      setState(() => loading = false);
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
      appBar: AppBar(title: const Text('Withdrawal fees')),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SwitchListTile(
                      title: const Text('Fees enabled'),
                      value: settings['enabled'] == true,
                      onChanged: (value) => setState(() => settings['enabled'] = value),
                    ),
                    TextField(controller: _amount, decoration: const InputDecoration(labelText: 'Bank fee GHS')),
                    const SizedBox(height: 8),
                    TextField(controller: _momo, decoration: const InputDecoration(labelText: 'MoMo fee GHS')),
                    SwitchListTile(
                      title: const Text('Auto Paystack payouts'),
                      value: auto['enabled'] == true,
                      onChanged: (value) => setState(() => auto['enabled'] = value),
                    ),
                    TextField(controller: _autoPercent, decoration: const InputDecoration(labelText: 'Auto Paystack fee %')),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Save',
                      onPressed: () async {
                        try {
                          final result = await context.read<AdminStore>().postJson('/admin/settings/withdrawal', data: {
                            'enabled': settings['enabled'] == true,
                            'amount': _amount.text,
                            'momo_amount': _momo.text,
                            'applies_to': settings['applies_to'] ?? 'all',
                            'auto_paystack_enabled': auto['enabled'] == true,
                            'auto_paystack_fee_percent': _autoPercent.text,
                          });
                          if (!context.mounted) return;
                          showSnack(context, str(result['message'], 'Saved.'));
                        } on ApiException catch (e) {
                          if (!context.mounted) return;
                          showSnack(context, e.message, error: true);
                        }
                      },
                    ),
                  ],
                ),
    );
  }
}

class ManualFundingSettingsScreen extends StatefulWidget {
  const ManualFundingSettingsScreen({super.key});

  @override
  State<ManualFundingSettingsScreen> createState() => _ManualFundingSettingsScreenState();
}

class _ManualFundingSettingsScreenState extends State<ManualFundingSettingsScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> settings = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AdminStore>().getJson('/admin/settings/manual-funding');
      if (!mounted) return;
      settings = asMap(data['settings']);
      setState(() => loading = false);
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
    final accounts = asMaps(settings['accounts']);
    return Scaffold(
      appBar: AppBar(title: const Text('Manual funding')),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SwitchListTile(
                      title: const Text('Show manual accounts'),
                      value: settings['enabled'] == true,
                      onChanged: (value) => setState(() => settings['enabled'] = value),
                    ),
                    Text(str(settings['instructions'])),
                    const SizedBox(height: 12),
                    ...accounts.map((account) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(str(account['label'])),
                          subtitle: Text('${str(account['account_name'])} · ${str(account['account_number'])}'),
                        )),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Save',
                      onPressed: () async {
                        try {
                          final result = await context.read<AdminStore>().postJson('/admin/settings/manual-funding', data: {
                            'enabled': settings['enabled'] == true,
                            'instructions': settings['instructions'],
                            'accounts': accounts,
                          });
                          if (!context.mounted) return;
                          showSnack(context, str(result['message'], 'Saved.'));
                        } on ApiException catch (e) {
                          if (!context.mounted) return;
                          showSnack(context, e.message, error: true);
                        }
                      },
                    ),
                  ],
                ),
    );
  }
}
