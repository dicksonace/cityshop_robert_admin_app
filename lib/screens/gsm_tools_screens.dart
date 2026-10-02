import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
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
      filters: const ['processing', 'pending', 'completed', 'failed', 'cancelled', 'all'],
      filterLabelFor: (option) => option[0].toUpperCase() + option.substring(1),
      itemBuilder: (item, _) => _GsmOrderCard(
        item: item,
        onTap: () => context.push('/gsm-tools/${item['id']}'),
      ),
    );
  }
}

int _gsmReplyWordCount(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
}

bool _gsmReplyTooLong(String text) => _gsmReplyWordCount(text) > 20;

class _GsmWordCount extends StatelessWidget {
  const _GsmWordCount({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final count = _gsmReplyWordCount(text);
    final over = count > 20;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$count/20 words',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: over ? const Color(0xFFB91C1C) : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _GsmOrderCard extends StatelessWidget {
  const _GsmOrderCard({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = str(item['status']);
    final colors = _gsmStatusColors(status);
    final qty = asInt(item['quantity']);
    final buyer = str(asMap(item['user'])['name'], 'Buyer');
    final when = _gsmWhen(str(item['created_at']));
    final eta = str(item['eta_label']).trim();

    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: const Color(0x140F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GsmAdminLogo(url: str(item['image_url']), size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          str(item['service_name'], 'GSM service'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, height: 1.25),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _SolidChip(
                              label: money.format(asDouble(item['price_ghs'])),
                              background: const Color(0xFFECFDF5),
                              foreground: const Color(0xFF065F46),
                            ),
                            _SolidChip(
                              label: str(item['status_label'], status.isEmpty ? 'Processing' : status).toUpperCase(),
                              background: colors.$1,
                              foreground: colors.$2,
                            ),
                            if (eta.isNotEmpty)
                              _SolidChip(
                                label: eta.toUpperCase(),
                                background: const Color(0xFFEFF6FF),
                                foreground: const Color(0xFF1D4ED8),
                              ),
                            if (qty > 1)
                              _SolidChip(
                                label: 'QTY $qty',
                                background: const Color(0xFFF3F4F6),
                                foreground: const Color(0xFF374151),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tag_rounded, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        str(item['reference'], '—'),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        buyer,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      ),
                    ),
                    if (when.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        when,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

(Color, Color) _gsmStatusColors(String status) {
  switch (status) {
    case 'completed':
      return (const Color(0xFFECFDF5), const Color(0xFF065F46));
    case 'failed':
      return (const Color(0xFFFEF2F2), const Color(0xFFB91C1C));
    case 'cancelled':
      return (const Color(0xFFF3F4F6), const Color(0xFF4B5563));
    case 'pending':
      return (const Color(0xFFFEF3C7), const Color(0xFF92400E));
    default:
      return (const Color(0xFFFFF7ED), const Color(0xFFC2410C));
  }
}

String _gsmWhen(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return '';
  final local = dt.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.isNegative) return DateFormat('d MMM, h:mm a').format(local);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return DateFormat('d MMM, h:mm a').format(local);
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
    final statusColors = _gsmStatusColors(status);
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
                Material(
                  color: Colors.white,
                  elevation: 1,
                  shadowColor: const Color(0x140F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GsmAdminLogo(url: str(order['image_url']), size: 56),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    str(order['service_name'], 'GSM service'),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, height: 1.2),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _SolidChip(
                                        label: money.format(asDouble(order['price_ghs'])),
                                        background: const Color(0xFFECFDF5),
                                        foreground: const Color(0xFF065F46),
                                      ),
                                      _SolidChip(
                                        label: str(order['status_label'], status).toUpperCase(),
                                        background: statusColors.$1,
                                        foreground: statusColors.$2,
                                      ),
                                      if (str(order['eta_label']).trim().isNotEmpty)
                                        _SolidChip(
                                          label: str(order['eta_label']).toUpperCase(),
                                          background: const Color(0xFFEFF6FF),
                                          foreground: const Color(0xFF1D4ED8),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${str(order['reference'])} · ${str(user['name'], 'Buyer')}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                        ),
                        if (user['id'] != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.only(top: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => context.push('/buyers/${user['id']}'),
                              child: const Text('View buyer profile'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
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
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(str(field['value']), height: 180, fit: BoxFit.cover),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Copy',
                                  onPressed: () => copyText(context, str(field['value']), label: '${str(field['label'])} copied'),
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                ),
                              ],
                            ),
                          )
                        else
                          _CopyRow(label: '', value: str(field['value'], '—'), hideEmptyLabel: true),
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
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Reply message',
                      hintText: 'SUCCESS — device unlocked. Paste the code or next steps.',
                    ),
                  ),
                  _GsmWordCount(text: replyMessage.text),
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
                            if (_gsmReplyTooLong(text)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Reply must be 20 words or fewer so the SMS can be delivered.')),
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
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Complete reply',
                      hintText: 'Optional if you already sent a reply. 20 words or fewer.',
                    ),
                  ),
                  _GsmWordCount(text: resultNote.text),
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
                              if (_gsmReplyTooLong(note)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Reply must be 20 words or fewer so the SMS can be delivered.')),
                                );
                                return;
                              }
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

const _gsmGroups = <String, String>{
  'imei': 'IMEI Service',
  'server': 'Server Service',
  'remote': 'Remote Service',
  'file': 'File Service',
};

class _BuyerFieldDraft {
  _BuyerFieldDraft({this.id, this.type = 'text', this.required = true, String label = '', String placeholder = ''}) {
    this.label.text = label;
    this.placeholder.text = placeholder;
  }

  final int? id;
  final label = TextEditingController();
  final placeholder = TextEditingController();
  String type;
  bool required;

  void dispose() {
    label.dispose();
    placeholder.dispose();
  }
}

class GsmServiceGroupScreen extends StatefulWidget {
  const GsmServiceGroupScreen({super.key, required this.type});

  final String type;

  @override
  State<GsmServiceGroupScreen> createState() => _GsmServiceGroupScreenState();
}

class _GsmServiceGroupScreenState extends State<GsmServiceGroupScreen> {
  bool loading = true;
  bool saving = false;
  String? error;
  List<Map<String, dynamic>> services = [];
  List<Map<String, dynamic>> groups = [];
  final name = TextEditingController();
  final serviceQuery = TextEditingController();
  final categoryName = TextEditingController();
  final description = TextEditingController();
  final eta = TextEditingController(text: 'INSTANT');
  final price = TextEditingController(text: '50');
  final minQty = TextEditingController(text: '1');
  final maxQty = TextEditingController(text: '10');
  String? groupId;
  bool allowQuantity = false;
  int? editingId;
  String? logoPath;
  String existingLogoUrl = '';
  String? categoryLogoPath;
  final fields = <_BuyerFieldDraft>[_BuyerFieldDraft()];

  String get title => _gsmGroups[widget.type] ?? 'GSM Service';

  List<Map<String, dynamic>> get _visibleServices {
    final query = serviceQuery.text.trim().toLowerCase();
    if (query.isEmpty) return services;
    return services.where((service) {
      final text = '${service['name'] ?? ''} ${service['description'] ?? ''} ${service['group_name'] ?? ''}'.toLowerCase();
      return text.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    name.dispose();
    serviceQuery.dispose();
    categoryName.dispose();
    description.dispose();
    eta.dispose();
    price.dispose();
    minQty.dispose();
    maxQty.dispose();
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await context.read<AdminStore>().getJson(
            '/admin/gsm-tools/services',
            query: {'type': widget.type},
          );
      if (!mounted) return;
      setState(() {
        services = asMaps(data['services']);
        groups = asMaps(data['groups']);
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

  Future<void> _createCategory() async {
    if (categoryName.text.trim().isEmpty) {
      showSnack(context, 'Add a category name');
      return;
    }
    setState(() => saving = true);
    try {
      if (categoryLogoPath != null) {
        await context.read<AdminStore>().postForm(
          '/admin/gsm-tools/groups',
          {
            'name': categoryName.text.trim(),
            'service_type': widget.type,
            'active': true,
          },
          fileField: 'image',
          filePath: categoryLogoPath,
        );
      } else {
        await context.read<AdminStore>().postJson('/admin/gsm-tools/groups', data: {
          'name': categoryName.text.trim(),
          'service_type': widget.type,
          'active': true,
        });
      }
      categoryName.clear();
      categoryLogoPath = null;
      if (!mounted) return;
      showSnack(context, 'Category added');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> group) async {
    final ok = await confirmAction(
      context,
      title: 'Delete this category?',
      body: '“${group['name']}” will be removed. Services in it stay, with no category.',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    setState(() => saving = true);
    try {
      await context.read<AdminStore>().deleteJson('/admin/gsm-tools/groups/${group['id']}');
      if (!mounted) return;
      if (groupId == '${group['id']}') {
        setState(() => groupId = '');
      }
      showSnack(context, 'Category deleted');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Map<String, dynamic> _servicePayload() => {
        'name': name.text.trim(),
        'service_type': widget.type,
        'description': description.text.trim(),
        'eta_label': eta.text.trim().isEmpty ? 'INSTANT' : eta.text.trim(),
        'price_ghs': price.text.trim(),
        'allow_quantity': allowQuantity,
        'min_qty': int.tryParse(minQty.text.trim()) ?? 1,
        'max_qty': int.tryParse(maxQty.text.trim()) ?? 10,
        'active': true,
        if (groupId != null && groupId!.isNotEmpty) 'gsm_service_group_id': groupId,
        'fields': [
          for (final field in fields)
            if (field.label.text.trim().isNotEmpty)
              {
                if (field.id != null) 'id': field.id,
                'label': field.label.text.trim(),
                'placeholder': field.placeholder.text.trim(),
                'type': field.type,
                'required': field.required,
                'active': true,
              },
        ],
      };

  Map<String, dynamic> _flattenServicePayload(Map<String, dynamic> payload) {
    final fields = <String, dynamic>{};
    payload.forEach((key, value) {
      if (key == 'fields' && value is List) {
        for (var i = 0; i < value.length; i++) {
          final row = Map<String, dynamic>.from(value[i] as Map);
          row.forEach((k, v) {
            fields['fields[$i][$k]'] = v is bool ? (v ? '1' : '0') : v;
          });
        }
      } else if (value is bool) {
        fields[key] = value ? '1' : '0';
      } else if (value != null) {
        fields[key] = value;
      }
    });
    return fields;
  }

  void _resetForm() {
    editingId = null;
    name.clear();
    description.clear();
    eta.text = 'INSTANT';
    price.text = '50';
    minQty.text = '1';
    maxQty.text = '10';
    allowQuantity = false;
    groupId = null;
    logoPath = null;
    existingLogoUrl = '';
    for (final field in fields) {
      field.dispose();
    }
    fields
      ..clear()
      ..add(_BuyerFieldDraft());
  }

  void _startEdit(Map<String, dynamic> service) {
    for (final field in fields) {
      field.dispose();
    }
    final existing = ((service['fields'] as List?) ?? [])
        .whereType<Map>()
        .map((row) => _BuyerFieldDraft(
              id: row['id'] as int?,
              label: '${row['label'] ?? ''}',
              placeholder: '${row['placeholder'] ?? ''}',
              type: '${row['type'] ?? 'text'}',
              required: row['required'] == true,
            ))
        .toList();
    setState(() {
      editingId = service['id'] as int?;
      name.text = '${service['name'] ?? ''}';
      description.text = '${service['description'] ?? ''}';
      eta.text = '${service['eta_label'] ?? 'INSTANT'}';
      price.text = '${service['price_ghs'] ?? ''}';
      allowQuantity = service['allow_quantity'] == true;
      minQty.text = '${service['min_qty'] ?? 1}';
      maxQty.text = '${service['max_qty'] ?? 10}';
      groupId = service['group_id'] == null ? '' : '${service['group_id']}';
      existingLogoUrl = '${service['image_url'] ?? ''}';
      logoPath = null;
      fields
        ..clear()
        ..addAll(existing.isEmpty ? [_BuyerFieldDraft()] : existing);
    });
  }

  Future<void> _create() async {
    if (name.text.trim().isEmpty) {
      showSnack(context, 'Add a service name');
      return;
    }
    setState(() => saving = true);
    try {
      final payload = _servicePayload();
      final path = editingId != null ? '/admin/gsm-tools/services/$editingId' : '/admin/gsm-tools/services';
      await context.read<AdminStore>().postForm(
            path,
            _flattenServicePayload(payload),
            fileField: logoPath != null ? 'image' : null,
            filePath: logoPath,
          );
      if (!mounted) return;
      final savedEdit = editingId != null;
      setState(_resetForm);
      showSnack(context, savedEdit ? '$title updated' : '$title created');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> service) async {
    final ok = await confirmAction(
      context,
      title: 'Delete this service?',
      body: 'Buyers will no longer see “${service['name']}”. Existing orders stay in history.',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    setState(() => saving = true);
    try {
      await context.read<AdminStore>().deleteJson('/admin/gsm-tools/services/${service['id']}');
      if (!mounted) return;
      if (editingId == service['id']) {
        setState(_resetForm);
      }
      showSnack(context, 'Service deleted');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => context.push('/gsm-tools/orders'),
            child: const Text('Orders'),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
                const Text('GSM Tools', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.accent)),
                const SizedBox(height: 4),
                Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                TextField(controller: categoryName, decoration: const InputDecoration(labelText: 'Category (e.g. Galaxy Multi Tool)')),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
                    if (file != null) setState(() => categoryLogoPath = file.path);
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: Text(categoryLogoPath == null ? 'Category logo' : 'Category logo selected'),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: 'Add category',
                  loading: saving,
                  onPressed: saving ? null : _createCategory,
                ),
                if (groups.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Categories', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  for (final group in groups)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        child: ListTile(
                          leading: GsmAdminLogo(url: '${group['image_url'] ?? ''}', size: 40),
                          title: Text('${group['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          trailing: IconButton(
                            tooltip: 'Delete category',
                            onPressed: saving ? null : () => _deleteCategory(group),
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFB91C1C)),
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Service name')),
                const SizedBox(height: 8),
                if (existingLogoUrl.isNotEmpty || logoPath != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GsmAdminLogo(url: existingLogoUrl, size: 64),
                  ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
                    if (file != null) setState(() => logoPath = file.path);
                  },
                  icon: const Icon(Icons.shield_outlined),
                  label: Text(logoPath == null ? 'Service logo (web + app)' : 'Service logo selected'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Service description'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: eta,
                  decoration: const InputDecoration(labelText: 'Delivery time', hintText: 'INSTANT, 1-24 hours…'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: groupId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('No category')),
                    ...groups.map((group) => DropdownMenuItem(value: '${group['id']}', child: Text('${group['name']}'))),
                  ],
                  onChanged: (value) => setState(() => groupId = value),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price (GHS)'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('This service uses quantity'),
                  subtitle: const Text('Off unless the buyer should order more than one.'),
                  value: allowQuantity,
                  onChanged: (value) => setState(() => allowQuantity = value),
                ),
                if (allowQuantity) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minQty,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Minimum quantity'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: maxQty,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Maximum quantity'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 12),
                const Text('What should the buyer submit?', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'Each service has its own form. Add Username, Password, Mobile, Email — whatever this tool needs.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final preset in [
                      ('Username', 'text', true),
                      ('Password', 'password', false),
                      ('Mobile', 'phone', true),
                      ('Email', 'email', true),
                      ('IMEI', 'text', true),
                      ('Serial', 'text', true),
                    ])
                      ActionChip(
                        label: Text('+ ${preset.$1}'),
                        onPressed: () => setState(() {
                          fields.add(_BuyerFieldDraft(label: preset.$1, placeholder: preset.$1, type: preset.$2, required: preset.$3));
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < fields.length; i++) ...[
                  TextField(
                    controller: fields[i].label,
                    decoration: const InputDecoration(labelText: 'Name of field'),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: fields[i].placeholder,
                    decoration: const InputDecoration(labelText: 'Placeholder shown to buyer'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: fields[i].type,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: const [
                            DropdownMenuItem(value: 'text', child: Text('Text')),
                            DropdownMenuItem(value: 'password', child: Text('Password')),
                            DropdownMenuItem(value: 'phone', child: Text('Mobile')),
                            DropdownMenuItem(value: 'email', child: Text('Email')),
                            DropdownMenuItem(value: 'number', child: Text('Number')),
                            DropdownMenuItem(value: 'textarea', child: Text('Long text')),
                            DropdownMenuItem(value: 'image', child: Text('Photo')),
                          ],
                          onChanged: (value) => setState(() => fields[i].type = value ?? 'text'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          const Text('Required', style: TextStyle(fontSize: 12)),
                          Switch(
                            value: fields[i].required,
                            onChanged: (value) => setState(() => fields[i].required = value),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => setState(() {
                          fields[i].dispose();
                          fields.removeAt(i);
                        }),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                TextButton.icon(
                  onPressed: () => setState(() => fields.add(_BuyerFieldDraft())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add another Field'),
                ),
                const SizedBox(height: 8),
                if (editingId != null)
                  TextButton(
                    onPressed: () => setState(_resetForm),
                    child: const Text('Cancel edit'),
                  ),
                PrimaryButton(
                  label: editingId == null ? 'Create $title' : 'Save $title',
                  loading: saving,
                  onPressed: saving ? null : _create,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: serviceQuery,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search services',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: serviceQuery.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            onPressed: () {
                              serviceQuery.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                if (services.isEmpty)
                  Text(
                    'No $title yet. Add the first one. You can send more details later.',
                    style: const TextStyle(color: AppColors.textSecondary),
                  )
                else if (_visibleServices.isEmpty)
                  const Text(
                    'No services match that search.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                for (final service in _visibleServices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GsmAdminLogo(url: '${service['image_url'] ?? ''}', size: 52),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${service['name']}',
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.25, color: Color(0xFF111827)),
                                        ),
                                      ),
                                      _GsmIconAction(
                                        tooltip: 'Edit',
                                        color: const Color(0xFFEA580C),
                                        icon: Icons.edit_outlined,
                                        onPressed: () => _startEdit(service),
                                      ),
                                      _GsmIconAction(
                                        tooltip: 'Delete',
                                        color: const Color(0xFFB91C1C),
                                        icon: Icons.delete_outline,
                                        onPressed: () => _delete(service),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _buyerPriceChip(asDouble(service['price_ghs'])),
                                      _buyerMetaChip(
                                        _shortGsmType('${service['service_type'] ?? widget.type}'),
                                        const Color(0xFFFFF7ED),
                                        const Color(0xFFF97316),
                                      ),
                                      _buyerMetaChip(
                                        '${service['eta_label'] ?? 'INSTANT'}'.trim().toUpperCase(),
                                        const Color(0xFFEFF6FF),
                                        const Color(0xFF1D4ED8),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

String _shortGsmType(String raw) {
  final type = raw.trim().toLowerCase();
  if (type.isEmpty) return 'GSM';
  return type.toUpperCase();
}

Widget _buyerPriceChip(double price) {
  final whole = price.truncateToDouble() == price;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
    child: Text(
      'GH₵${price.toStringAsFixed(whole ? 0 : 2)}',
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
    ),
  );
}

Widget _buyerMetaChip(String label, Color background, Color foreground) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(4)),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: foreground),
    ),
  );
}

class _GsmIconAction extends StatelessWidget {
  const _GsmIconAction({required this.tooltip, required this.color, required this.icon, required this.onPressed});

  final String tooltip;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(28, 28),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, color: color, size: 18),
    );
  }
}

class _SolidChip extends StatelessWidget {
  const _SolidChip({required this.label, required this.background, required this.foreground});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: foreground, letterSpacing: 0.2),
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value, this.hideEmptyLabel = false});

  final String label;
  final String value;
  final bool hideEmptyLabel;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty || value == '—') {
      if (hideEmptyLabel) {
        return const SelectableText('—', style: TextStyle(fontWeight: FontWeight.w600));
      }
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label.isNotEmpty)
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                SelectableText(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => copyText(context, value, label: '${label.isEmpty ? 'Value' : label} copied'),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }
}

class GsmAdminLogo extends StatelessWidget {
  const GsmAdminLogo({required this.url, this.size = 44});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolved = ApiConfig.resolveMediaUrl(url);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      clipBehavior: Clip.antiAlias,
      child: resolved.isEmpty
          ? const Center(child: Icon(Icons.phonelink_setup, color: Colors.white54, size: 20))
          : CachedNetworkImage(imageUrl: resolved, fit: BoxFit.contain),
    );
  }
}
