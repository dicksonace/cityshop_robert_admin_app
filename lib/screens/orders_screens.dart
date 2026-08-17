import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../store/admin_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _path => switch (_tabs.index) {
        1 => '/admin/orders/unprocessed',
        2 => '/admin/orders/awaiting-confirmation',
        3 => '/admin/orders/awaiting-direct',
        4 => '/admin/orders/cancellations',
        _ => '/admin/orders',
      };

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await context.read<AdminStore>().getJson(_path);
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

  Future<void> _cancel(int id) async {
    final reason = await promptText(context, title: 'Cancel unprocessed order', label: 'Reason');
    if (reason == null || !mounted) return;
    try {
      final data = await context.read<AdminStore>().postJson(
            '/admin/orders/items/$id/cancel-unprocessed',
            data: {'reason': reason},
          );
      if (!mounted) return;
      showSnack(context, str(data['message'], 'Cancelled.'));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    }
  }

  Future<void> _confirm(int id) async {
    final ok = await confirmAction(
      context,
      title: 'Confirm delivery',
      body: 'Mark this item delivered. Funds stay pending until you release them.',
    );
    if (!ok || !mounted) return;
    try {
      final data = await context.read<AdminStore>().postJson('/admin/orders/items/$id/confirm-delivery');
      if (!mounted) return;
      showSnack(context, str(data['message'], 'Confirmed.'));
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
        title: const Text('Orders'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Unprocessed'),
            Tab(text: 'Awaiting'),
            Tab(text: 'Direct pay'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: loading
          ? const FullPageLoader(label: 'Loading orders…')
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: items.isEmpty
                      ? ListView(children: const [SizedBox(height: 80), EmptyState('No orders here.')])
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final isOrder = item.containsKey('order_number') && item.containsKey('total');
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
                                            isOrder
                                                ? str(item['order_number'], 'Order')
                                                : str(item['product_name'], 'Item'),
                                            style: const TextStyle(fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                        StatusChip(str(item['status'])),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      isOrder
                                          ? '${str(asMap(item['buyer'])['name'], str(item['buyer_name']))} · ${money.format(asDouble(item['total']))}'
                                          : '${str(item['order_number'])} · ${str(item['buyer_name'])} → ${str(item['seller_name'])}',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                    ),
                                    if (_tabs.index == 1) ...[
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () => _cancel(asInt(item['id'])),
                                          child: const Text('Cancel & refund'),
                                        ),
                                      ),
                                    ],
                                    if (_tabs.index == 2) ...[
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () => _confirm(asInt(item['id'])),
                                          child: const Text('Confirm delivery'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
