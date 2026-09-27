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
  final replyMessage = TextEditingController();
  final failReason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    resultNote.dispose();
    replyMessage.dispose();
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
    final replies = asMaps(order['replies']);

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
                        if (str(field['type']) == 'image' && str(field['value']).startsWith('http'))
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(str(field['value']), height: 180, fit: BoxFit.cover),
                            ),
                          )
                        else
                          SelectableText(
                            str(field['value'], '—'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ),
                ),
                const Text('Admin reply', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                if (replies.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(str(order['admin_result_note'], 'No reply yet.')),
                  )
                else
                  ...replies.map(
                    (reply) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(str(reply['body'])),
                          const SizedBox(height: 4),
                          Text(
                            str(reply['admin'], 'Admin'),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                          ),
                        ],
                      ),
                    ),
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
                                title: 'Processing?',
                                body: 'Mark this GSM order as Processing.',
                                action: 'Processing',
                              );
                              if (ok && mounted) await _post('process');
                            },
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                      child: const Text('Processing'),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Currently Processing', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8))),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: replyMessage,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Reply message',
                      hintText: 'SUCCESS — device unlocked. Paste the code or next steps.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final text = replyMessage.text.trim();
                            if (text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Type a reply first.')),
                              );
                              return;
                            }
                            await _post('reply', data: {'message': text});
                            if (mounted) replyMessage.clear();
                          },
                    child: const Text('Send reply'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: resultNote,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Complete reply',
                      hintText: 'Optional if you already sent a reply',
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
                              body: 'Mark this GSM request as Completed. Buyer will see your reply.',
                              action: 'Complete',
                            );
                            if (ok && mounted) {
                              final note = resultNote.text.trim().isNotEmpty
                                  ? resultNote.text.trim()
                                  : replyMessage.text.trim();
                              await _post('complete', data: {'result_note': note});
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
