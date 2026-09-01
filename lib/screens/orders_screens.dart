import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../store/admin_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, this.initialTab = 'all'});

  final String initialTab;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> items = [];
  int unprocessedCount = 0;

  static int _tabIndex(String tab) => switch (tab) {
        'unprocessed' => 1,
        'awaiting' || 'awaiting-confirmation' => 2,
        'direct' || 'awaiting-direct' => 3,
        'cancelled' || 'cancellations' => 4,
        _ => 0,
      };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this, initialIndex: _tabIndex(widget.initialTab));
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _load();
    });
    _load();
  }

  @override
  void didUpdateWidget(OrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab == widget.initialTab) return;
    final index = _tabIndex(widget.initialTab);
    if (_tabs.index != index) _tabs.animateTo(index);
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
        if (_tabs.index == 1) {
          unprocessedCount = asInt(data['count']);
          if (unprocessedCount <= 0) {
            unprocessedCount = asInt(asMap(data['meta'])['total']);
          }
        }
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
    final reason = await promptText(
      context,
      title: 'Cancel unprocessed order',
      label: 'Reason',
      initial: 'Admin cancelled: order does not look like it will go through.',
    );
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

  String _formatWait(dynamic hoursRaw) {
    final hours = asInt(hoursRaw);
    if (hours <= 0) return '—';
    if (hours < 48) return '${hours}h';
    final days = hours ~/ 24;
    final rem = hours % 24;
    return rem > 0 ? '${days}d ${rem}h' : '${days}d';
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
                      ? ListView(
                          children: [
                            if (_tabs.index == 1) const _UnprocessedBanner(count: 0),
                            const SizedBox(height: 80),
                            const EmptyState('No orders here.'),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                          itemCount: items.length + (_tabs.index == 1 ? 1 : 0) + (_tabs.index == 2 ? 1 : 0),
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            var offset = 0;
                            if (_tabs.index == 1 && index == 0) {
                              return _UnprocessedBanner(count: unprocessedCount);
                            }
                            if (_tabs.index == 1) offset = 1;
                            if (_tabs.index == 2 && index == 0) {
                              return const _AwaitingBanner();
                            }
                            if (_tabs.index == 2) {
                              offset = 1;
                            }
                            final item = items[index - offset];
                            final isOrder = item.containsKey('order_number') && item.containsKey('total');
                            final orderId = isOrder ? asInt(item['id']) : asInt(item['order_id']);
                            final itemId = asInt(item['id']);

                            if (_tabs.index == 2 && !isOrder) {
                              return AdminAwaitingOrderCard(
                                productName: str(item['product_name'], 'Item'),
                                orderNumber: str(item['order_number'], 'Order'),
                                statusLabel: str(item['status'], 'awaiting confirmation'),
                                subtitle: '${str(item['buyer_name'])} → ${str(item['seller_name'])}',
                                onTap: orderId > 0 ? () => context.push('/orders/$orderId') : null,
                                onConfirm: () => _confirm(itemId),
                              );
                            }

                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: orderId > 0 ? () => context.push('/orders/$orderId') : null,
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE5E7EB)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              isOrder
                                                  ? str(item['order_number'], 'Order')
                                                  : str(item['product_name'], 'Item'),
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
                                        if (asDouble(item['line_total']) > 0) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Qty ${asInt(item['quantity'])} · ${money.format(asDouble(item['line_total']))}',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Text(
                                          'Waiting ${_formatWait(item['hours_waiting'])}',
                                          style: const TextStyle(
                                            color: Color(0xFFDC2626),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(0xFFDC2626),
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () => _cancel(itemId),
                                            child: const Text('Cancel & refund'),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

class _AwaitingBanner extends StatelessWidget {
  const _AwaitingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Waiting for buyer confirmation',
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF9A3412)),
          ),
          SizedBox(height: 4),
          Text(
            'Seller marked delivered. Tap Confirm delivery when the buyer received the item.',
            style: TextStyle(fontSize: 12, color: Color(0xFFB45309), height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _UnprocessedBanner extends StatelessWidget {
  const _UnprocessedBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paid orders not yet out for delivery',
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Cancel anytime and refund the buyer’s CityShop wallet. Waiting time is shown on each card.',
            style: TextStyle(fontSize: 12, color: Color(0xFFB45309), height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(
            '$count waiting',
            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
          ),
        ],
      ),
    );
  }
}

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> order = {};

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
      final data = await context.read<AdminStore>().getJson('/admin/orders/${widget.id}');
      if (!mounted) return;
      setState(() {
        order = asMap(data['data']);
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

  Future<void> _call(String number) async {
    final phone = number.replaceAll(RegExp(r'\s+'), '');
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    final ok = await launchUrl(uri);
    if (!ok && mounted) showSnack(context, 'Could not open the phone app.', error: true);
  }

  Future<void> _confirmItem(int itemId) async {
    final ok = await confirmAction(
      context,
      title: 'Confirm delivery',
      body: 'Mark this item delivered. Funds stay pending until you release them.',
    );
    if (!ok || !mounted) return;
    try {
      final data = await context.read<AdminStore>().postJson('/admin/orders/items/$itemId/confirm-delivery');
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
    final buyer = asMap(order['buyer']);
    final items = asMaps(order['items']);
    final receiver = str(order['receiver_name'], str(buyer['name']));
    final phone = str(order['receiver_phone'], str(buyer['mobile']));
    final address = [
      str(order['city']),
      str(order['region']),
    ].where((e) => e.isNotEmpty).join(', ');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(str(order['order_number'], 'Order'))),
      body: loading
          ? const FullPageLoader(label: 'Loading order…')
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      ...items.map((item) => _AdminProductCard(item: item)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(receiver.isEmpty ? 'Buyer' : receiver, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            const SizedBox(height: 8),
                            if (str(buyer['name']).isNotEmpty) Text(str(buyer['name'])),
                            if (phone.isNotEmpty) Text(phone),
                            if (address.isNotEmpty) Text(address),
                            if (str(order['digital_address']).isNotEmpty) Text(str(order['digital_address'])),
                            if (str(order['delivery_notes']).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Note: ${str(order['delivery_notes'])}', style: const TextStyle(color: AppColors.textSecondary)),
                              ),
                            if (phone.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              InkWell(
                                onTap: () => _call(phone),
                                child: const Row(
                                  children: [
                                    Icon(Icons.phone, color: AppColors.accent, size: 18),
                                    SizedBox(width: 6),
                                    Text('Call buyer', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Payment · ${str(order['payment_channel'], '—')} · ${str(order['payment_status'])}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Method: ${str(order['payment_method'], '—')}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      ...items.map(
                        (item) => _SellerProvidedCard(
                          item: item,
                          onCallDriver: str(item['driver_phone']).isEmpty ? null : () => _call(str(item['driver_phone'])),
                          onConfirm: str(item['status']) == 'awaiting_confirmation'
                              ? () => _confirmItem(asInt(item['id']))
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _AdminProductCard extends StatelessWidget {
  const _AdminProductCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NetworkThumb(item['product_image'] as String?, size: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(str(item['product_name'], 'Item'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  'Qty ${asInt(item['quantity'])} · ${money.format(asDouble(item['unit_price']))}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                Text(
                  str(item['status']).replaceAll('_', ' '),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            money.format(asDouble(item['unit_price']) * asInt(item['quantity'])),
            style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _SellerProvidedCard extends StatelessWidget {
  const _SellerProvidedCard({
    required this.item,
    this.onCallDriver,
    this.onConfirm,
  });

  final Map<String, dynamic> item;
  final VoidCallback? onCallDriver;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final status = str(item['status']);
    final vehicle = str(item['vehicle_number']);
    final driver = str(item['driver_phone']);
    final package = str(item['package_image_url']);
    final courier = str(item['courier_name']);
    final tracking = str(item['tracking_number']);
    final hasDetails = vehicle.isNotEmpty || driver.isNotEmpty || package.isNotEmpty || courier.isNotEmpty || tracking.isNotEmpty;
    final steps = [
      ('Start processing', _stepDone(status, const ['processing', 'call_confirmed', 'packed', 'shipped', 'awaiting_confirmation', 'delivered'])),
      ('Mark as packing', _stepDone(status, const ['packed', 'shipped', 'awaiting_confirmation', 'delivered'])),
      ('Out for delivery', _stepDone(status, const ['shipped', 'awaiting_confirmation', 'delivered'])),
      ('Mark as delivered', _stepDone(status, const ['awaiting_confirmation', 'delivered'])),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(str(item['product_name'], 'Item'), style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(
              'Seller: ${str(item['seller_name'], '—')}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            const Text('Fulfillment', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(
              'Current: ${status.replaceAll('_', ' ')}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            for (final step in steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      step.$2 ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 20,
                      color: step.$2 ? AppColors.emerald : const Color(0xFFD1D5DB),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      step.$1,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: step.$2 ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            const Text('Seller provided', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 4),
            const Text(
              'Vehicle, driver phone, and package photo the seller added for this delivery.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 10),
            if (!hasDetails)
              const Text('Seller has not added delivery details yet.', style: TextStyle(color: AppColors.textMuted))
            else ...[
              if (vehicle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Vehicle / car number', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                            Text(vehicle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy',
                        onPressed: () => copyText(context, vehicle, label: 'Vehicle number copied.'),
                        icon: const Icon(Icons.copy, size: 16),
                      ),
                    ],
                  ),
                ),
              if (driver.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Driver phone', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                            InkWell(
                              onTap: onCallDriver,
                              child: Text(driver, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.blue, fontSize: 16)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy',
                        onPressed: () => copyText(context, driver, label: 'Driver number copied.'),
                        icon: const Icon(Icons.copy, size: 16),
                      ),
                    ],
                  ),
                ),
              _DetailLine(label: 'Courier', value: courier),
              _DetailLine(label: 'Tracking', value: tracking),
              if (package.isNotEmpty) ...[
                const Text('Package photo', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                NetworkThumb(package, size: 120),
              ],
            ],
            if (onConfirm != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onConfirm,
                  child: const Text('Confirm delivery'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _stepDone(String status, List<String> done) => done.contains(status);
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
