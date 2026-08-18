import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../store/admin_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'extra_screens.dart';

class KycQueueScreen extends StatelessWidget {
  const KycQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminResourceList(
      title: 'Ghana Card KYC',
      path: '/admin/kyc',
      filters: const ['pending', 'needs_improvement', 'approved', 'rejected', 'all'],
      searchHint: 'Search name, mobile, card number',
      itemBuilder: (item, _) {
        final user = asMap(item['user']);
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            title: Text(str(user['name'], 'User')),
            subtitle: Text('${str(item['ghana_card_number'])} · ${str(item['status_label'], str(item['status']))}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/kyc/${item['id']}'),
          ),
        );
      },
    );
  }
}

class KycDetailScreen extends StatefulWidget {
  const KycDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<KycDetailScreen> createState() => _KycDetailScreenState();
}

class _KycDetailScreenState extends State<KycDetailScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> item = {};

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
      final data = await context.read<AdminStore>().getJson('/admin/kyc/${widget.id}');
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

  Future<void> _act(String action, {String? notes}) async {
    try {
      final result = await context.read<AdminStore>().postJson(
            '/admin/kyc/${widget.id}/$action',
            data: notes == null ? null : {'admin_notes': notes},
          );
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
    final user = asMap(item['user']);
    final status = str(item['status']);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/kyc');
            }
          },
        ),
        title: const Text('Ghana Card review'),
      ),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(str(user['name']), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                    Text('${str(user['email'])} · ${str(user['mobile'])}'),
                    const SizedBox(height: 8),
                    StatusChip(str(item['status_label'], status)),
                    const SizedBox(height: 8),
                    Text('Card ${str(item['ghana_card_number'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (str(item['full_name']).isNotEmpty) Text('Name on card: ${str(item['full_name'])}'),
                    if (str(item['admin_notes']).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(str(item['admin_notes']), style: const TextStyle(color: AppColors.danger)),
                    ],
                    const SizedBox(height: 16),
                    const Text('Front', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    NetworkThumb(item['front_url'] as String?, size: 220),
                    const SizedBox(height: 12),
                    const Text('Back', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    NetworkThumb(item['back_url'] as String?, size: 220),
                    if (str(item['selfie_url']).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Selfie', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      NetworkThumb(item['selfie_url'] as String?, size: 220),
                    ],
                    if (status != 'approved') ...[
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Approve — allow wallet recharge',
                        onPressed: () => _act('approve'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () async {
                          final notes = await promptText(context, title: 'Ask for better photos', label: 'What should they improve?');
                          if (notes == null) return;
                          await _act('request-changes', notes: notes);
                        },
                        child: const Text('Ask them to improve'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final notes = await promptText(context, title: 'Reject Ghana Card', label: 'Reason');
                          if (notes == null) return;
                          await _act('reject', notes: notes);
                        },
                        child: const Text('Reject', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
    );
  }
}
