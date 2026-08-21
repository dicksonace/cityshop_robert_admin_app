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
  static const _ghanaRegions = [
    'Ahafo',
    'Ashanti',
    'Bono',
    'Bono East',
    'Central',
    'Eastern',
    'Greater Accra',
    'North East',
    'Northern',
    'Oti',
    'Savannah',
    'Upper East',
    'Upper West',
    'Volta',
    'Western',
    'Western North',
  ];

  bool loading = true;
  bool busy = false;
  String? error;
  Map<String, dynamic> seller = {};

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _ghanaCard = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _storeName = TextEditingController();
  final _businessName = TextEditingController();
  final _businessReg = TextEditingController();
  String _region = '';
  bool _businessRegistered = false;
  bool _acceptMarketplace = true;
  bool _acceptDirect = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    _ghanaCard.dispose();
    _city.dispose();
    _address.dispose();
    _storeName.dispose();
    _businessName.dispose();
    _businessReg.dispose();
    super.dispose();
  }

  void _fillForm(Map<String, dynamic> data) {
    final user = asMap(data['user']);
    _name.text = str(user['name']);
    _email.text = str(user['email']);
    _mobile.text = str(user['mobile']);
    _ghanaCard.text = str(user['ghana_card_number']);
    _city.text = str(user['city']);
    _address.text = str(user['residential_address']);
    _storeName.text = str(data['store_name_raw'], str(data['store_name']));
    _businessName.text = str(data['business_name']);
    _businessReg.text = str(data['business_registration_number']);
    _region = str(user['region']);
    _businessRegistered = data['is_business_registered'] == true;
    _acceptMarketplace = data['accept_marketplace_payments'] != false;
    _acceptDirect = data['accept_direct_payments'] == true;
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await context.read<AdminStore>().getJson('/admin/sellers/${widget.id}');
      if (!mounted) return;
      final payload = asMap(data['data']);
      _fillForm(payload);
      setState(() {
        seller = payload;
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
        if (data['data'] is Map) {
          seller = asMap(data['data']);
          _fillForm(seller);
        }
        busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      showSnack(context, e.message, error: true);
    }
  }

  Future<void> _saveProfile() async {
    if (!_acceptMarketplace && !_acceptDirect) {
      showSnack(context, 'Choose at least one buyer payment mode.', error: true);
      return;
    }
    await _run(
      () => context.read<AdminStore>().patchJson(
            '/admin/sellers/${widget.id}/profile',
            data: {
              'name': _name.text.trim(),
              'email': _email.text.trim(),
              'mobile': _mobile.text.trim(),
              'ghana_card_number': _ghanaCard.text.trim(),
              'region': _region,
              'city': _city.text.trim(),
              'residential_address': _address.text.trim(),
              'store_name': _storeName.text.trim(),
              'is_business_registered': _businessRegistered,
              'business_name': _businessName.text.trim(),
              'business_registration_number': _businessReg.text.trim(),
              'accept_marketplace_payments': _acceptMarketplace,
              'accept_direct_payments': _acceptDirect,
            },
          ),
    );
  }

  Widget _field(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = asMap(seller['user']);
    final activation = asMap(seller['activation']);
    final status = str(seller['status']);
    final regions = _region.isNotEmpty && !_ghanaRegions.contains(_region)
        ? [_region, ..._ghanaRegions]
        : _ghanaRegions;

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
                    const Text('Seller information', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text(
                      'Admin can update personal and business details.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    _field('Name', _name),
                    _field('Email', _email, keyboardType: TextInputType.emailAddress),
                    _field('Phone number', _mobile, keyboardType: TextInputType.phone),
                    _field('Ghana Card', _ghanaCard),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DropdownButtonFormField<String>(
                        value: _region.isEmpty ? null : _region,
                        decoration: const InputDecoration(labelText: 'Region'),
                        items: regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (value) => setState(() => _region = value ?? ''),
                      ),
                    ),
                    _field('City', _city),
                    _field('Address', _address),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Business is registered'),
                      value: _businessRegistered,
                      onChanged: (value) => setState(() => _businessRegistered = value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    _field('Store name', _storeName),
                    if (_businessRegistered) ...[
                      _field('Registered business name', _businessName),
                      _field('Registration number', _businessReg),
                    ],
                    const SizedBox(height: 4),
                    const Text('Buyer payment modes', style: TextStyle(fontWeight: FontWeight.w600)),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Marketplace'),
                      value: _acceptMarketplace,
                      onChanged: (value) => setState(() => _acceptMarketplace = value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Direct to seller'),
                      value: _acceptDirect,
                      onChanged: (value) => setState(() => _acceptDirect = value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    PrimaryButton(
                      label: 'Save seller information',
                      loading: busy,
                      onPressed: busy ? null : _saveProfile,
                    ),
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
                    // Pending applications: approve/reject only — no resend/delete cleanup tools.
                    if (status != 'pending') ...[
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
                  ],
                ),
    );
  }
}
