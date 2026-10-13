import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../store/admin_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'extra_screens.dart';

const _statusLabels = {
  'all': 'All',
  'success': 'Paid',
  'pending': 'Pending',
  'processing': 'Processing',
  'failed': 'Failed',
};

class KorapayPaymentsScreen extends StatelessWidget {
  const KorapayPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminResourceList(
      title: 'Korapay payments',
      path: '/admin/korapay-payments',
      query: const {'per_page': 50},
      searchHint: 'Search name, phone or reference',
      filters: _statusLabels.keys.toList(),
      filterLabelFor: (option) => _statusLabels[option] ?? option,
      listHeader: (meta) {
        if (meta == null) return null;
        final available = meta['korapay_available'] == true;
        final configured = meta['korapay_configured'] == true;
        final state = available
            ? (meta['korapay_is_test'] == true ? 'Korapay on (test keys)' : 'Korapay on')
            : (configured ? 'Korapay disabled' : 'No Korapay keys');
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Pill(
                '${asInt(meta['paid_count'])} paid · ${money.format(asDouble(meta['paid_total']))}',
                const Color(0xFFECFDF5),
                const Color(0xFF047857),
              ),
              _Pill(
                state,
                available ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                available ? const Color(0xFF047857) : AppColors.danger,
              ),
            ],
          ),
        );
      },
      itemBuilder: (item, reload) => _KorapayPaymentCard(item: item, reload: reload),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.background, this.foreground);

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: foreground)),
    );
  }
}

class _KorapayPaymentCard extends StatefulWidget {
  const _KorapayPaymentCard({required this.item, required this.reload});

  final Map<String, dynamic> item;
  final VoidCallback reload;

  @override
  State<_KorapayPaymentCard> createState() => _KorapayPaymentCardState();
}

class _KorapayPaymentCardState extends State<_KorapayPaymentCard> {
  bool checking = false;

  Future<void> _recheck() async {
    setState(() => checking = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await context
          .read<AdminStore>()
          .postJson('/admin/korapay-payments/${widget.item['id']}/recheck');
      messenger.showSnackBar(SnackBar(content: Text(str(data['message'], 'Checked with Korapay.'))));
      widget.reload();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final user = asMap(item['user']);
    final status = str(item['status'], 'pending');
    final (bg, fg) = switch (status) {
      'success' => (const Color(0xFFECFDF5), const Color(0xFF047857)),
      'failed' => (const Color(0xFFFEF2F2), AppColors.danger),
      'processing' => (const Color(0xFFFFFBEB), const Color(0xFF92400E)),
      _ => (const Color(0xFFF3F4F6), AppColors.textSecondary),
    };
    String when = '';
    final createdAt = str(item['created_at']);
    if (createdAt.isNotEmpty) {
      try {
        when = DateFormat('d MMM yyyy, h:mm a').format(DateTime.parse(createdAt).toLocal());
      } catch (_) {}
    }
    final details = [str(user['name']), str(item['checkout_number'])].where((s) => s.isNotEmpty).join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(str(item['purpose'], 'Payment'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        status == 'success' ? 'Paid' : (_statusLabels[status] ?? status),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
                      ),
                    ),
                  ],
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(details, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 4),
                GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: str(item['reference'])));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reference copied')));
                  },
                  child: Text(str(item['reference']),
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ),
                if (when.isNotEmpty || str(user['mobile']).isNotEmpty)
                  Text(
                    [when, str(user['mobile'])].where((s) => s.isNotEmpty).join(' · '),
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                if (user['id'] != null)
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    onPressed: () => context.push(
                      str(user['role']) == 'seller' ? '/sellers/${user['id']}' : '/buyers/${user['id']}',
                    ),
                    child: const Text('Open user'),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(money.format(asDouble(item['amount'])),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              if (status != 'success') ...[
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFECFDF5),
                    foregroundColor: const Color(0xFF047857),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  onPressed: checking ? null : _recheck,
                  icon: checking
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 16),
                  label: const Text('Check with Korapay'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
