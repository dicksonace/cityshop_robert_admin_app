import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../store/admin_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'extra_screens.dart';

class GsmToolsScreen extends StatelessWidget {
  const GsmToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminResourceList(
      title: 'GSM Tools',
      path: '/admin/gsm-tools',
      autoRefreshInterval: const Duration(seconds: 8),
      filters: const ['pending', 'processing', 'completed', 'failed', 'cancelled', 'all'],
      filterLabelFor: (option) => option[0].toUpperCase() + option.substring(1),
      itemBuilder: (item, _) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          str(item['service_name'], 'GSM service'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${str(item['reference'])} · ${str(asMap(item['user'])['name'], 'Buyer')}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money.format(asDouble(item['price_ghs'])),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              str(item['status_label'], str(item['status'])),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
        onTap: () => context.push('/gsm-tools/${item['id']}'),
      ),
    );
  }
}

class GsmToolDetailScreen extends StatefulWidget {
  const GsmToolDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<GsmToolDetailScreen> createState() => _GsmToolDetailScreenState();
}

class _GsmToolDetailScreenState extends State<GsmToolDetailScreen> {
  bool loading = true;
  bool busy = false;
  String? error;
  Map<String, dynamic> order = {};
  final resultNote = TextEditingController();
  final failReason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    resultNote.dispose();
    failReason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await context.read<AdminStore>().getJson('/admin/gsm-tools/${widget.id}');
      if (!mounted) return;
      setState(() {
        order = asMap(data['order']);
        if (resultNote.text.isEmpty) {
          resultNote.text = str(order['admin_result_note']);
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

  Future<void> _post(String action, {Map<String, dynamic>? data}) async {
    setState(() => busy = true);
    try {
      final result = await context.read<AdminStore>().postJson(
        '/admin/gsm-tools/${widget.id}/$action',
        data: data,
      );
      if (!mounted) return;
      setState(() {
        order = asMap(result['order']).isEmpty ? order : asMap(result['order']);
        busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${action[0].toUpperCase()}${action.substring(1)} saved.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = str(order['status']);
    final open = status == 'pending' || status == 'processing';
    final user = asMap(order['user']);
    final fields = asMaps(order['fields']);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(str(order['reference'], 'GSM order')),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(error!, style: const TextStyle(color: Colors.red)),
                  ),
                Text(
                  str(order['service_name'], 'GSM service'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  str(order['status_label'], status),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
                Text(
                  '${money.format(asDouble(order['price_ghs']))} · ${str(user['name'], 'Buyer')}',
                ),
                Text(
                  '${str(user['mobile'])} · ${str(user['email'])}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ...fields.map(
                  (field) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          str(field['label'], str(field['name'])).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SelectableText(
                          str(field['value'], '—'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                if (str(order['admin_result_note']).isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(str(order['admin_result_note'])),
                  ),
                if (str(order['failure_reason']).isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(str(order['failure_reason'])),
                  ),
                if (open) ...[
                  if (status == 'pending')
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final ok = await confirmAction(
                                context,
                                title: 'Start processing?',
                                body: 'Mark this GSM order as processing.',
                                action: 'Process',
                              );
                              if (ok && mounted) await _post('process');
                            },
                      child: const Text('Start processing'),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: resultNote,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Result note',
                      hintText: 'What should the buyer see?',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final ok = await confirmAction(
                              context,
                              title: 'Complete order?',
                              body: 'Mark this GSM request as completed.',
                              action: 'Complete',
                            );
                            if (ok && mounted) {
                              await _post('complete', data: {'result_note': resultNote.text.trim()});
                            }
                          },
                    style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
                    child: const Text('Complete'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: failReason,
                    decoration: const InputDecoration(
                      labelText: 'Fail reason',
                      hintText: 'Shown to the buyer',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final ok = await confirmAction(
                              context,
                              title: 'Fail & refund?',
                              body: 'The buyer wallet will be credited.',
                              action: 'Fail',
                            );
                            if (ok && mounted) {
                              await _post('fail', data: {'reason': failReason.text.trim()});
                            }
                          },
                    child: const Text('Fail & refund'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final ok = await confirmAction(
                              context,
                              title: 'Cancel & refund?',
                              body: 'The buyer wallet will be credited.',
                              action: 'Cancel',
                            );
                            if (ok && mounted) await _post('cancel');
                          },
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Cancel & refund'),
                  ),
                ],
              ],
            ),
    );
  }
}
