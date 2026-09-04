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
  final _alert2 = TextEditingController();
  final _alert3 = TextEditingController();
  final _alert4 = TextEditingController();
  final _testMobile = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _alert1.dispose();
    _alert2.dispose();
    _alert3.dispose();
    _alert4.dispose();
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
      _alert2.text = str(settings['alert_mobile_2']);
      _alert3.text = str(settings['alert_mobile_3']);
      _alert4.text = str(settings['alert_mobile_4']);
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
        'alert_mobile_2': _alert2.text.trim(),
        'alert_mobile_3': _alert3.text.trim(),
        'alert_mobile_4': _alert4.text.trim(),
      });
      if (!mounted) return;
      final saved = asMap(result['settings']);
      if (saved.isNotEmpty) {
        settings = {...settings, ...saved};
        _alert1.text = str(settings['alert_mobile_1']);
        _alert2.text = str(settings['alert_mobile_2']);
        _alert3.text = str(settings['alert_mobile_3']);
        _alert4.text = str(settings['alert_mobile_4']);
      }
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
                      'PIN and password reset codes always use the provider you pick here — they never silently fall back to the other one.\n\n'
                      'If failover is ON, other SMS (orders, alerts) can still use Formula DC when TxtConnect fails. Turn failover OFF to test TxtConnect alone.',
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
                    const SizedBox(height: 8),
                    const Text('Admin alert numbers', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text(
                      'These numbers get SMS when a buyer submits a withdrawal, a pending manual deposit, or a Transfer to China.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _alert1,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Alert number 1', hintText: '0XX XXX XXXX'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _alert2,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Alert number 2', hintText: '0XX XXX XXXX'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _alert3,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Alert number 3', hintText: '0XX XXX XXXX'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _alert4,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Alert number 4', hintText: '0XX XXX XXXX'),
                    ),
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
  final _autoFlat = TextEditingController();
  String autoFeeMode = 'flat';
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
    _autoFlat.dispose();
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
      autoFeeMode = str(auto['fee_mode'], (asDouble(auto['fee_percent']) > 0) ? 'percent' : 'flat');
      if (autoFeeMode != 'percent') autoFeeMode = 'flat';
      _autoPercent.text = str(auto['fee_percent'], '0');
      _autoFlat.text = str(auto['fee_flat'], '1');
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
                      subtitle: const Text(
                        'Pay out via Paystack without the admin queue. Fee below is separate from recharge fees.',
                      ),
                      value: auto['enabled'] == true,
                      onChanged: (value) => setState(() => auto['enabled'] = value),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: autoFeeMode,
                      decoration: const InputDecoration(
                        labelText: 'Paystack withdrawal fee type',
                        helperText: 'Flat fee works like bank fees (recommended).',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'flat', child: Text('Flat fee (GH₵)')),
                        DropdownMenuItem(value: 'percent', child: Text('Percent of amount')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => autoFeeMode = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    if (autoFeeMode == 'flat')
                      TextField(
                        controller: _autoFlat,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Flat Paystack withdrawal fee (GHS)',
                          helperText: 'Example: GH₵1 — same amount every payout.',
                        ),
                      )
                    else
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
                            'auto_paystack_fee_mode': autoFeeMode,
                            'auto_paystack_fee_flat': _autoFlat.text,
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
  bool saving = false;
  String? error;
  Map<String, dynamic> settings = {};
  final _instructions = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _accounts =>
      asMaps(settings['accounts']).map((a) => Map<String, dynamic>.from(a)).toList();

  set _accounts(List<Map<String, dynamic>> value) {
    settings['accounts'] = value;
  }

  Map<String, dynamic> _normalizeAccount(Map<String, dynamic> raw) {
    final type = str(raw['type'], 'momo') == 'bank' ? 'bank' : 'momo';
    final network = str(raw['network'], 'mtn').toLowerCase();
    return {
      'type': type,
      'label': str(raw['label'], type == 'bank' ? 'Bank transfer' : 'Mobile Money'),
      'account_name': str(raw['account_name']),
      'account_number': str(raw['account_number']),
      'network': type == 'momo'
          ? (['mtn', 'telecel', 'airteltigo'].contains(network) ? network : 'mtn')
          : null,
      'bank_name': type == 'bank' ? str(raw['bank_name']) : null,
    };
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await context.read<AdminStore>().getJson('/admin/settings/manual-funding');
      if (!mounted) return;
      settings = asMap(data['settings']);
      final accounts = asMaps(settings['accounts']);
      settings['accounts'] = accounts.isEmpty
          ? [_defaultAccount()]
          : accounts.map((a) => _normalizeAccount(a)).toList();
      _instructions.text = str(settings['instructions']);
      setState(() => loading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Map<String, dynamic> _defaultAccount({String network = 'mtn'}) {
    final label = switch (network) {
      'telecel' => 'Telecel Cash',
      'airteltigo' => 'AirtelTigo Cash',
      _ => 'MTN Mobile Money',
    };
    return {
      'type': 'momo',
      'label': label,
      'account_name': 'City Unlock Ventures / Robert Asare',
      'account_number': '',
      'network': network,
      'bank_name': null,
    };
  }

  void _updateAccount(int index, Map<String, dynamic> patch) {
    final next = [..._accounts];
    next[index] = _normalizeAccount({...next[index], ...patch});
    setState(() => _accounts = next);
  }

  Future<void> _deleteAccount(int index) async {
    final ok = await confirmAction(
      context,
      title: 'Remove account?',
      body: 'Buyers will no longer see ${_accounts[index]['label']}. You can add it again later.',
      action: 'Remove',
    );
    if (!ok || !mounted) return;
    setState(() {
      final next = [..._accounts]..removeAt(index);
      _accounts = next;
    });
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      final payloadAccounts = _accounts
          .map((a) => _normalizeAccount(a))
          .where((a) => str(a['account_number']).isNotEmpty)
          .toList();
      final result = await context.read<AdminStore>().postJson('/admin/settings/manual-funding', data: {
        'enabled': settings['enabled'] == true,
        'instructions': _instructions.text.trim(),
        'accounts': payloadAccounts,
      });
      if (!mounted) return;
      showSnack(context, str(result['message'], 'Saved.'));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _accounts;
    return Scaffold(
      appBar: AppBar(title: const Text('Manual funding')),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show manual accounts'),
                      subtitle: const Text('Let buyers and sellers top up by MoMo or bank transfer'),
                      value: settings['enabled'] == true,
                      onChanged: (value) => setState(() => settings['enabled'] = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _instructions,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Instructions for users',
                        hintText: 'Send payment to one of the accounts below…',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Receive accounts',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: accounts.length >= 10
                              ? null
                              : () => setState(() => _accounts = [...accounts, _defaultAccount()]),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < accounts.length; i++)
                      _ManualFundingAccountCard(
                        key: ValueKey('mf-$i-${accounts[i]['type']}-${accounts[i]['network']}-${accounts[i]['account_number']}'),
                        index: i,
                        account: accounts[i],
                        onChanged: (patch) => _updateAccount(i, patch),
                        onDelete: () => _deleteAccount(i),
                      ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: saving ? 'Saving…' : 'Save',
                      loading: saving,
                      onPressed: saving ? null : _save,
                    ),
                  ],
                ),
    );
  }
}

class _ManualFundingAccountCard extends StatelessWidget {
  const _ManualFundingAccountCard({
    super.key,
    required this.index,
    required this.account,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final Map<String, dynamic> account;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final type = str(account['type'], 'momo') == 'bank' ? 'bank' : 'momo';
    final network = str(account['network'], 'mtn');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Account ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                tooltip: 'Remove account',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'momo', child: Text('Mobile Money')),
              DropdownMenuItem(value: 'bank', child: Text('Bank')),
            ],
            onChanged: (value) {
              if (value == null) return;
              onChanged({
                'type': value,
                if (value == 'momo') 'network': network.isEmpty ? 'mtn' : network,
              });
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: str(account['label']),
            decoration: const InputDecoration(labelText: 'Label'),
            onChanged: (value) => onChanged({'label': value}),
          ),
          if (type == 'momo') ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: ['mtn', 'telecel', 'airteltigo'].contains(network) ? network : 'mtn',
              decoration: const InputDecoration(labelText: 'Network'),
              items: const [
                DropdownMenuItem(value: 'mtn', child: Text('MTN Mobile Money')),
                DropdownMenuItem(value: 'telecel', child: Text('Telecel Cash')),
                DropdownMenuItem(value: 'airteltigo', child: Text('AirtelTigo Cash')),
              ],
              onChanged: (value) {
                if (value == null) return;
                final label = switch (value) {
                  'telecel' => 'Telecel Cash',
                  'airteltigo' => 'AirtelTigo Cash',
                  _ => 'MTN Mobile Money',
                };
                onChanged({'network': value, 'label': label});
              },
            ),
          ],
          if (type == 'bank') ...[
            const SizedBox(height: 10),
            TextFormField(
              initialValue: str(account['bank_name']),
              decoration: const InputDecoration(labelText: 'Bank name'),
              onChanged: (value) => onChanged({'bank_name': value}),
            ),
          ],
          const SizedBox(height: 10),
          TextFormField(
            initialValue: str(account['account_name']),
            decoration: const InputDecoration(labelText: 'Account name'),
            onChanged: (value) => onChanged({'account_name': value}),
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: str(account['account_number']),
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: type == 'bank' ? 'Account number' : 'MoMo number',
            ),
            onChanged: (value) => onChanged({'account_number': value}),
          ),
        ],
      ),
    );
  }
}
