import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../store/admin_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AdminStore>().user;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(user?.name ?? 'Admin'),
            subtitle: Text(user?.email ?? ''),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 4),
            child: Text('Operations', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
          ),
          _tile(context, Icons.inventory_2_outlined, 'Products', '/products'),
          _tile(context, Icons.category_outlined, 'Categories', '/categories'),
          _tile(context, Icons.store_mall_directory_outlined, 'Store oversight', '/stores'),
          _tile(context, Icons.report_gmailerrorred_outlined, 'Refunds & disputes', '/disputes'),
          _tile(context, Icons.flag_outlined, 'Seller reports', '/reports'),
          _tile(context, Icons.hourglass_bottom, 'Pending seller funds', '/pending-funds'),
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 4),
            child: Text('People', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
          ),
          _tile(context, Icons.people_outline, 'Buyers', '/buyers'),
          _tile(context, Icons.badge_outlined, 'Ghana Card KYC', '/kyc'),
          _tile(context, Icons.link, 'Seller invites', '/invites'),
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 4),
            child: Text('Money', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
          ),
          _tile(context, Icons.add_card_outlined, 'Deposits', '/money?tab=deposits'),
          _tile(context, Icons.outbond_outlined, 'Withdrawals', '/money'),
          _tile(context, Icons.payments_outlined, 'Wallet funding', '/wallet-funding'),
          _tile(context, Icons.receipt_long_outlined, 'Transactions', '/transactions'),
          _tile(context, Icons.currency_exchange, 'Transfer RMB', '/china-transfers'),
          _tile(context, Icons.currency_yen, 'Sell RMB queues', '/sell-rmb'),
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 4),
            child: Text('Messages', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
          ),
          _tile(context, Icons.chat_outlined, 'Chats', '/chats'),
          _tile(context, Icons.mail_outline, 'Contact messages', '/contact'),
          _tile(context, Icons.campaign_outlined, 'Seller announcements', '/announcements'),
          _tile(context, Icons.campaign, 'Buyer announcements', '/buyer-announcements'),
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 4),
            child: Text('Settings', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
          ),
          _tile(context, Icons.sms_outlined, 'SMS', '/settings/sms'),
          _tile(context, Icons.credit_card, 'Paystack', '/settings/paystack'),
          _tile(context, Icons.account_balance, 'Seller bank withdrawal fees', '/settings/withdrawal'),
          _tile(context, Icons.account_balance_wallet_outlined, 'Manual funding', '/settings/manual-funding'),
          _tile(context, Icons.tune, 'Buy RMB settings', '/china-settings'),
          _tile(context, Icons.tune_outlined, 'Sell RMB settings', '/sell-rmb-settings'),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () async {
              await context.read<AdminStore>().logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, String route) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accent),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
  }
}

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String status = 'pending';
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> products = [];

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
      final data = await context.read<AdminStore>().getJson('/admin/products', query: {'status': status});
      if (!mounted) return;
      setState(() {
        products = asMaps(data['data']);
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
      appBar: AppBar(title: const Text('Products')),
      body: Column(
        children: [
          FilterBar(
            options: const ['pending', 'approved', 'rejected', 'draft', 'all'],
            value: status,
            onChanged: (value) {
              status = value;
              _load();
            },
          ),
          Expanded(
            child: loading
                ? const FullPageLoader(label: 'Loading products…')
                : error != null
                    ? ErrorRetry(message: error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: products.isEmpty
                            ? ListView(children: const [SizedBox(height: 80), EmptyState('No products.')])
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                                itemCount: products.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final product = products[index];
                                  final id = asInt(product['id']);
                                  return Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    child: ListTile(
                                      leading: NetworkThumb(product['image'] as String?),
                                      title: Text(str(product['name'])),
                                      subtitle: Text(
                                        '${money.format(asDouble(product['price']))} · ${str(product['seller_name'])}',
                                      ),
                                      trailing: StatusChip(str(product['status'])),
                                      onTap: () async {
                                        final choice = await showModalBottomSheet<String>(
                                          context: context,
                                          builder: (ctx) => SafeArea(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ListTile(
                                                  title: const Text('Approve'),
                                                  onTap: () => Navigator.pop(ctx, 'approve'),
                                                ),
                                                ListTile(
                                                  title: const Text('Reject'),
                                                  onTap: () => Navigator.pop(ctx, 'reject'),
                                                ),
                                                ListTile(
                                                  title: const Text('Hide'),
                                                  onTap: () => Navigator.pop(ctx, 'hide'),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                        if (!context.mounted) return;
                                        if (choice == 'approve') {
                                          await _act('/admin/products/$id/approve');
                                        } else if (choice == 'hide') {
                                          await _act('/admin/products/$id/hide');
                                        } else if (choice == 'reject') {
                                          final reason = await promptText(context, title: 'Reject product');
                                          if (reason == null || !context.mounted) return;
                                          await _act(
                                            '/admin/products/$id/reject',
                                            data: {'rejection_reason': reason},
                                          );
                                        }
                                      },
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

class DisputesScreen extends StatefulWidget {
  const DisputesScreen({super.key});

  @override
  State<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends State<DisputesScreen> {
  String status = 'open';
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> disputes = [];

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
      final data = await context.read<AdminStore>().getJson('/admin/disputes', query: {'status': status});
      if (!mounted) return;
      setState(() {
        disputes = asMaps(data['data']);
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

  Future<void> _resolve(int id) async {
    final notes = await promptText(context, title: 'Resolution notes', label: 'Notes');
    if (notes == null || !mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Refund buyer'),
              onTap: () => Navigator.pop(ctx, 'resolved_buyer'),
            ),
            ListTile(
              title: const Text('Pay seller'),
              onTap: () => Navigator.pop(ctx, 'resolved_seller'),
            ),
            ListTile(
              title: const Text('Close without payout'),
              onTap: () => Navigator.pop(ctx, 'closed'),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    try {
      final result = await context.read<AdminStore>().postJson(
            '/admin/disputes/$id/resolve',
            data: {'resolution': picked, 'resolution_notes': notes},
          );
      if (!mounted) return;
      showSnack(context, str(result['message'], 'Resolved.'));
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
      appBar: AppBar(title: const Text('Refunds')),
      body: Column(
        children: [
          FilterBar(
            options: const ['open', 'under_review', 'resolved_buyer', 'resolved_seller', 'closed', 'all'],
            value: status,
            onChanged: (value) {
              status = value;
              _load();
            },
          ),
          Expanded(
            child: loading
                ? const FullPageLoader()
                : error != null
                    ? ErrorRetry(message: error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: disputes.isEmpty
                            ? ListView(children: const [SizedBox(height: 80), EmptyState('No refunds.')])
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                                itemCount: disputes.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final dispute = disputes[index];
                                  final id = asInt(dispute['id']);
                                  return Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    child: ListTile(
                                      title: Text(str(dispute['product_name'], str(dispute['order_number']))),
                                      subtitle: Text(
                                        '${str(dispute['buyer_name'])} vs ${str(dispute['seller_name'])}\n${str(dispute['reason'])}',
                                      ),
                                      isThreeLine: true,
                                      trailing: StatusChip(str(dispute['status'])),
                                      onTap: () async {
                                        final store = context.read<AdminStore>();
                                        final choice = await showModalBottomSheet<String>(
                                          context: context,
                                          builder: (ctx) => SafeArea(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ListTile(
                                                  title: const Text('Mark under review'),
                                                  onTap: () => Navigator.pop(ctx, 'review'),
                                                ),
                                                ListTile(
                                                  title: const Text('Resolve'),
                                                  onTap: () => Navigator.pop(ctx, 'resolve'),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                        if (!context.mounted) return;
                                        if (choice == 'review') {
                                          try {
                                            final result = await store.postJson(
                                                  '/admin/disputes/$id/review',
                                                );
                                            if (!context.mounted) return;
                                            showSnack(context, str(result['message'], 'Updated.'));
                                            await _load();
                                          } on ApiException catch (e) {
                                            if (!context.mounted) return;
                                            showSnack(context, e.message, error: true);
                                          }
                                        } else if (choice == 'resolve') {
                                          await _resolve(id);
                                        }
                                      },
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

class PendingFundsScreen extends StatefulWidget {
  const PendingFundsScreen({super.key});

  @override
  State<PendingFundsScreen> createState() => _PendingFundsScreenState();
}

class _PendingFundsScreenState extends State<PendingFundsScreen> {
  String status = 'pending';
  bool loading = true;
  String? error;
  int? busyId;
  List<Map<String, dynamic>> items = [];
  Map<String, dynamic> counts = {};

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
      final data = await context.read<AdminStore>().getJson(
        '/admin/pending-funds',
        query: {'status': status, 'per_page': 50},
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

  String _formatDate(dynamic value) {
    final raw = str(value);
    if (raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('d MMM yyyy, hh:mm a').format(dt.toLocal());
  }

  Future<void> _approve(Map<String, dynamic> item) async {
    final id = asInt(item['id']);
    if (id <= 0) return;
    final shipping = asDouble(asMap(item['order'])['shipping_cost']);
    final goods = asDouble(item['seller_amount']);
    final releaseTotal = goods + (shipping > 0 ? shipping : 0);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Release funds now?'),
        content: Text(
          'Move ${money.format(releaseTotal)} to this seller’s Available balance right away.\n\n'
          'You can do this anytime — no 24-hour wait and no need for buyer confirm first.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
            child: const Text('Release now'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busyId = id);
    try {
      final result = await context.read<AdminStore>().postJson('/admin/pending-funds/$id/release');
      if (!mounted) return;
      showSnack(context, str(result['message'], 'Funds released to Available.'));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> _reject(Map<String, dynamic> item) async {
    final id = asInt(item['id']);
    if (id <= 0) return;
    final notes = await promptText(
      context,
      title: 'Reject — hold & dispute',
      label: 'Why are you holding these funds?',
      hint: 'At least 5 characters',
    );
    if (notes == null || !mounted) return;
    if (notes.trim().length < 5) {
      showSnack(context, 'Notes must be at least 5 characters.', error: true);
      return;
    }
    setState(() => busyId = id);
    try {
      final result = await context.read<AdminStore>().postJson(
        '/admin/pending-funds/$id/hold',
        data: {'admin_notes': notes.trim()},
      );
      if (!mounted) return;
      showSnack(context, str(result['message'], 'Funds held. A dispute was opened.'));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ('pending', 'Pending (${counts['pending'] ?? 0})'),
      ('held', 'Held (${counts['held'] ?? 0})'),
      ('released', 'Released (${counts['released'] ?? 0})'),
      ('all', 'All'),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pending funds')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pending fund releases', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                SizedBox(height: 6),
                Text(
                  'Once a CityShop-secured order is processing, you can Release to the seller’s Available balance anytime — even under 24 hours, and without waiting for the buyer to confirm delivery.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                for (final tab in tabs) ...[
                  ChoiceChip(
                    label: Text(tab.$2),
                    selected: status == tab.$1,
                    selectedColor: AppColors.blue,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: status == tab.$1 ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) {
                      status = tab.$1;
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const FullPageLoader()
                : error != null
                    ? ErrorRetry(message: error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: items.isEmpty
                            ? ListView(children: const [SizedBox(height: 80), EmptyState('No items in this view.')])
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                                itemCount: items.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 10),
                                itemBuilder: (context, index) => _PendingFundCard(
                                  item: items[index],
                                  busy: busyId == asInt(items[index]['id']),
                                  formatDate: _formatDate,
                                  onApprove: () => _approve(items[index]),
                                  onReject: () => _reject(items[index]),
                                ),
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _PendingFundCard extends StatelessWidget {
  const _PendingFundCard({
    required this.item,
    required this.busy,
    required this.formatDate,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> item;
  final bool busy;
  final String Function(dynamic value) formatDate;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final order = asMap(item['order']);
    final buyer = asMap(order['buyer']);
    final seller = asMap(item['seller']);
    final fundsStatus = str(item['funds_release_status'], 'pending');
    final shipping = asDouble(order['shipping_cost']);
    final goods = asDouble(item['seller_amount']);
    final releaseTotal = goods + (shipping > 0 ? shipping : 0);
    final canApprove = item['can_approve'] == true || fundsStatus == 'pending' || fundsStatus == 'held';
    final canReject = item['can_reject'] == true || fundsStatus == 'pending';
    final qty = asInt(item['quantity']);
    final orderNumber = str(order['order_number'], str(item['order_number']));
    final buyerName = str(buyer['name'], str(item['buyer_name'], '—'));
    final buyerMobile = str(buyer['mobile']);
    final sellerName = str(seller['name'], str(item['seller_name'], '—'));
    final sellerMobile = str(seller['mobile']);
    final stage = str(item['status_label'], str(item['status']).replaceAll('_', ' '));

    Color badgeBg;
    Color badgeFg;
    switch (fundsStatus) {
      case 'held':
        badgeBg = const Color(0xFFFEE2E2);
        badgeFg = const Color(0xFFB91C1C);
      case 'released':
        badgeBg = const Color(0xFFD1FAE5);
        badgeFg = const Color(0xFF047857);
      default:
        badgeBg = const Color(0xFFFEF3C7);
        badgeFg = const Color(0xFF92400E);
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    str(item['product_name'], 'Item'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    fundsStatus,
                    style: TextStyle(color: badgeFg, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Qty $qty · ${money.format(goods)}${shipping > 0 ? ' · Delivery ${money.format(shipping)}' : ''}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (shipping > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Release total ${money.format(releaseTotal)} (goods + delivery fee)',
                  style: const TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w800),
                ),
              ),
            const SizedBox(height: 6),
            Text('Order stage: $stage', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            if (orderNumber.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Order $orderNumber · Updated ${formatDate(item['updated_at'])}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              'Buyer: $buyerName${buyerMobile.isEmpty ? '' : ' · $buyerMobile'}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              'Seller: $sellerName${sellerMobile.isEmpty ? '' : ' · $sellerMobile'}',
              style: const TextStyle(fontSize: 13),
            ),
            if (str(item['funds_release_notes']).isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
                child: Text('Notes: ${str(item['funds_release_notes'])}'),
              ),
            if (fundsStatus == 'held')
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Funds are held (often after a dispute). You can still Release anytime to Available.',
                  style: TextStyle(color: Color(0xFF92400E), fontSize: 13),
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: asInt(order['id']) <= 0 ? null : () => context.push('/orders/${asInt(order['id'])}'),
                child: const Text('View complete order'),
              ),
            ),
            if (canApprove) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: busy ? null : onApprove,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald),
                  child: busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Release now — ${money.format(releaseTotal)} to Available'),
                ),
              ),
              if (canReject) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: busy ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: Color(0xFFFECACA)),
                    ),
                    child: const Text('Hold & open dispute'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class WalletFundingScreen extends StatefulWidget {
  const WalletFundingScreen({super.key});

  @override
  State<WalletFundingScreen> createState() => _WalletFundingScreenState();
}

class _WalletFundingScreenState extends State<WalletFundingScreen> {
  final _search = TextEditingController();
  bool loading = false;
  String? error;
  List<Map<String, dynamic>> users = [];

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
      final data = await context.read<AdminStore>().getJson(
            '/admin/wallet-funding/users',
            query: {'search': _search.text.trim()},
          );
      if (!mounted) return;
      setState(() {
        users = asMaps(data['data']);
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

  Future<void> _fund(Map<String, dynamic> user, String action) async {
    final amount = await promptText(
      context,
      title: action == 'credit' ? 'Add GHS' : 'Remove GHS',
      label: 'Amount',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
    if (amount == null || !mounted) return;
    try {
      final result = await context.read<AdminStore>().postJson(
            '/admin/wallet-funding',
            data: {
              'user_id': user['id'],
              'action': action,
              'amount': amount,
            },
          );
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Wallet funding')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search name, email, or mobile',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.arrow_forward)),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(
            child: loading
                ? const FullPageLoader()
                : error != null
                    ? ErrorRetry(message: error!, onRetry: _load)
                    : users.isEmpty
                        ? const EmptyState('Search a buyer or seller to credit or debit GHS.')
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            itemCount: users.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final user = users[index];
                              return Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                child: ListTile(
                                  title: Text(str(user['name'])),
                                  subtitle: Text(
                                    '${str(user['role'])} · ${str(user['mobile'])}\n${money.format(asDouble(user['available_balance']))}',
                                  ),
                                  isThreeLine: true,
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) => _fund(user, value),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'credit', child: Text('Add money')),
                                      PopupMenuItem(value: 'debit', child: Text('Remove money')),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
