import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../store/admin_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class SmsSettingsScreen extends StatefulWidget {
  const SmsSettingsScreen({super.key});

  @override
  State<SmsSettingsScreen> createState() => _SmsSettingsScreenState();
}

class _SmsSettingsScreenState extends State<SmsSettingsScreen> {
  bool loading = true;
  bool saving = false;
  bool testing = false;
  String? error;
  Map<String, dynamic> settings = {};
  List<Map<String, dynamic>> providers = [];
  final _alert1 = TextEditingController();
  final _testMobile = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _alert1.dispose();
    _testMobile.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await context.read<AdminStore>().getJson('/admin/settings/sms');
      if (!mounted) return;
      settings = asMap(data['settings']);
      providers = asMaps(data['providers']);
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

  String get _driver => str(settings['driver'], 'formula_dc');
  bool get _failover => settings['failover'] == true;

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      final result = await context.read<AdminStore>().postJson('/admin/settings/sms', data: {
        'driver': _driver,
        'failover': _failover,
        'alert_mobile_1': _alert1.text.trim(),
        'alert_mobile_2': settings['alert_mobile_2'] ?? '',
        'alert_mobile_3': settings['alert_mobile_3'] ?? '',
        'alert_mobile_4': settings['alert_mobile_4'] ?? '',
      });
      if (!mounted) return;
      final saved = asMap(result['settings']);
      if (saved.isNotEmpty) settings = {...settings, ...saved};
      showSnack(context, str(result['message'], 'Saved.'));
      setState(() => saving = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      showSnack(context, e.message, error: true);
    }
  }

  Future<void> _test() async {
    final mobile = _testMobile.text.trim();
    if (mobile.isEmpty) {
      showSnack(context, 'Enter a phone number to test.', error: true);
      return;
    }
    setState(() => testing = true);
    try {
      final result = await context.read<AdminStore>().postJson('/admin/settings/sms/test', data: {
        'mobile': mobile,
      });
      if (!mounted) return;
      setState(() => testing = false);
      showSnack(context, str(result['message'], 'Test sent.'));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => testing = false);
      showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeLabel = _driver == 'txtconnect' ? 'TxtConnect' : 'Formula DC';

    return Scaffold(
      appBar: AppBar(title: const Text('SMS settings')),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Active now: $activeLabel', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 6),
                    const Text(
                      'If failover is ON and TxtConnect fails (sender ID not approved yet), Formula DC still sends the SMS. Turn failover OFF to test TxtConnect alone.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _driver,
                      items: const [
                        DropdownMenuItem(value: 'formula_dc', child: Text('Formula DC')),
                        DropdownMenuItem(value: 'txtconnect', child: Text('TxtConnect')),
                      ],
                      onChanged: (value) => setState(() => settings['driver'] = value),
                      decoration: const InputDecoration(labelText: 'Provider'),
                    ),
                    if (providers.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...providers.map((p) {
                        final id = str(p['id']);
                        final configured = p['configured'] == true;
                        return Text(
                          '${str(p['label'], id)}: ${configured ? 'API key saved' : 'API key missing'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: configured ? AppColors.textSecondary : AppColors.danger,
                          ),
                        );
                      }),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Failover to the other provider'),
                      subtitle: const Text('When ON, Formula DC can still send if TxtConnect fails.'),
                      value: _failover,
                      onChanged: (value) => setState(() => settings['failover'] = value),
                    ),
                    TextField(controller: _alert1, decoration: const InputDecoration(labelText: 'Alert mobile 1')),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Save SMS platform',
                      loading: saving,
                      onPressed: saving ? null : _save,
                    ),
                    const SizedBox(height: 24),
                    const Text('Send test SMS', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text(
                      'This reports which provider actually delivered the text.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _testMobile,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Test phone (0XXXXXXXXX)'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: testing ? null : _test,
                      child: Text(testing ? 'Sending…' : 'Send test SMS'),
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
  String appliesTo = 'bank';
  final _amount = TextEditingController();
  final _momo = TextEditingController();
  final _autoPercent = TextEditingController();
  final List<_BankTierEditors> _tiers = [];

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
    for (final tier in _tiers) {
      tier.dispose();
    }
    super.dispose();
  }

  void _replaceTiers(List<Map<String, dynamic>> rows) {
    for (final tier in _tiers) {
      tier.dispose();
    }
    _tiers
      ..clear()
      ..addAll(rows.map(_BankTierEditors.fromMap));
    if (_tiers.isEmpty) {
      _tiers.addAll([
        _BankTierEditors(min: '10', max: '999.99', fee: '10'),
        _BankTierEditors(min: '1000', max: '25000', fee: '20'),
      ]);
    }
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AdminStore>().getJson('/admin/settings/withdrawal');
      if (!mounted) return;
      settings = asMap(data['settings']);
      auto = asMap(data['auto_paystack']);
      appliesTo = str(settings['applies_to'], 'bank');
      if (appliesTo == 'all') appliesTo = 'bank';
      _amount.text = str(settings['amount'], '10');
      _momo.text = str(settings['momo_amount'], '0');
      _autoPercent.text = str(auto['fee_percent'], '0');
      _replaceTiers(asMaps(settings['bank_tiers']));
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/more');
            }
          },
        ),
        title: const Text('Seller bank withdrawal fees'),
      ),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Sellers see these fees in the CityShop app when they cash out to a Ghana bank. MoMo stays free unless you add a MoMo fee below.',
                      style: TextStyle(color: AppColors.textSecondary, height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable Paystack auto withdrawal'),
                      subtitle: const Text('Pay out without the admin queue. Uses the percent fee instead of bank bands.'),
                      value: auto['enabled'] == true,
                      onChanged: (value) => setState(() => auto['enabled'] = value),
                    ),
                    TextField(
                      controller: _autoPercent,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Auto Paystack fee %'),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Charge bank withdrawal fees'),
                      subtitle: const Text(
                        'Must be ON for sellers to see GH₵10 / GH₵20 bank fees. Bands below are ignored while this is off.',
                      ),
                      value: settings['enabled'] == true,
                      onChanged: (value) => setState(() => settings['enabled'] = value),
                    ),
                    if (settings['enabled'] != true && appliesTo == 'bank')
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDBA74)),
                        ),
                        child: const Text(
                          'Bank fee bands are filled, but charging is OFF — sellers currently see “No fee”. Turn the switch on, then Save.',
                          style: TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.w600, height: 1.35),
                        ),
                      ),
                    TextField(
                      controller: _momo,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'MoMo withdrawal fee (GHS)',
                        helperText: 'Default GH₵0 — sellers are not charged for MoMo unless you set this.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: appliesTo,
                      decoration: const InputDecoration(
                        labelText: 'Apply bank fees to',
                        helperText: '“Charge bank fee bands” also turns charging on when you save.',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'bank', child: Text('Charge bank fee bands')),
                        DropdownMenuItem(value: 'momo', child: Text('Do not charge bank fees')),
                        DropdownMenuItem(value: 'none', child: Text('Disable all flat fees')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          appliesTo = value;
                          if (value == 'bank') {
                            settings['enabled'] = true;
                          } else if (value == 'none') {
                            settings['enabled'] = false;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Bank fee bands', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text(
                      'Example: below GH₵1,000 → GH₵10 · from GH₵1,000 → GH₵20. Sellers see this on Bank cash-out.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _tiers.length; i++) ...[
                      _BankTierCard(
                        tier: _tiers[i],
                        onRemove: _tiers.length <= 1
                            ? null
                            : () => setState(() {
                                  _tiers.removeAt(i).dispose();
                                }),
                      ),
                      const SizedBox(height: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: _tiers.length >= 10
                          ? null
                          : () => setState(() => _tiers.add(_BankTierEditors(min: '0', max: '', fee: '0'))),
                      icon: const Icon(Icons.add),
                      label: const Text('Add bank band'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Fallback bank fee (GHS)',
                        helperText: 'Used if an amount does not match a band.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Save seller bank fees',
                      onPressed: () async {
                        try {
                          final chargeBank = appliesTo == 'bank';
                          final result = await context.read<AdminStore>().postJson('/admin/settings/withdrawal', data: {
                            'enabled': chargeBank ? true : settings['enabled'] == true,
                            'amount': _amount.text,
                            'momo_amount': _momo.text,
                            'applies_to': appliesTo,
                            'bank_tiers': _tiers
                                .map(
                                  (tier) => {
                                    'min': tier.min.text,
                                    'max': tier.max.text.trim().isEmpty ? null : tier.max.text,
                                    'fee': tier.fee.text,
                                  },
                                )
                                .toList(),
                            'auto_paystack_enabled': auto['enabled'] == true,
                            'auto_paystack_fee_percent': _autoPercent.text,
                          });
                          if (!context.mounted) return;
                          if (chargeBank) {
                            setState(() => settings['enabled'] = true);
                          }
                          showSnack(context, str(result['message'], 'Saved. Sellers will see bank fees on the next withdraw refresh.'));
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

class _BankTierEditors {
  _BankTierEditors({required String min, required String max, required String fee})
      : min = TextEditingController(text: min),
        max = TextEditingController(text: max),
        fee = TextEditingController(text: fee);

  factory _BankTierEditors.fromMap(Map<String, dynamic> row) {
    final max = row['max'];
    return _BankTierEditors(
      min: str(row['min'], '0'),
      max: max == null ? '' : str(max),
      fee: str(row['fee'], '0'),
    );
  }

  final TextEditingController min;
  final TextEditingController max;
  final TextEditingController fee;

  void dispose() {
    min.dispose();
    max.dispose();
    fee.dispose();
  }
}

class _BankTierCard extends StatelessWidget {
  const _BankTierCard({required this.tier, this.onRemove});

  final _BankTierEditors tier;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.ringOrange,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: tier.min,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'From (GHS)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: tier.max,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'To (GHS)', hintText: 'blank = open'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: tier.fee,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Fee (GHS)'),
                ),
              ),
            ],
          ),
          if (onRemove != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onRemove,
                child: const Text('Remove band'),
              ),
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
