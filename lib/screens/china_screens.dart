import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import '../store/admin_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'extra_screens.dart';

class ChinaTransfersScreen extends StatelessWidget {
  const ChinaTransfersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminResourceList(
      title: 'Transfer RMB',
      path: '/admin/china-transfers',
      filters: const ['open', 'all', 'payment_submitted', 'processing', 'rmb_sent', 'completed'],
      searchHint: 'Search reference or buyer',
      itemBuilder: (item, _) => _TransferTile(
        item: item,
        onTap: () => context.push('/china-transfers/${item['id']}'),
      ),
    );
  }
}

class SellRmbScreen extends StatelessWidget {
  const SellRmbScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminResourceList(
      title: 'Sell RMB (China → GHS)',
      path: '/admin/sell-rmb',
      filters: const ['open', 'all', 'submitted', 'rmb_verification', 'payout_processing', 'completed'],
      searchHint: 'Search reference or buyer',
      itemBuilder: (item, _) => _TransferTile(
        item: item,
        onTap: () => context.push('/sell-rmb/${item['id']}'),
      ),
    );
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = asMap(item['user']);
    final quote = asMap(item['quote']);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        title: Text(str(item['reference'], '#${item['id']}')),
        subtitle: Text('${str(user['name'])} · ${str(item['status_label'], str(item['status']))}'),
        trailing: Text(
          quote.isEmpty ? '' : str(asMap(quote['breakdown'])['total'], money.format(asDouble(quote['total_payable_ghs']))),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        onTap: onTap,
      ),
    );
  }
}

class ChinaTransferDetailScreen extends StatelessWidget {
  const ChinaTransferDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context) {
    return _TransferDetail(
      id: id,
      loadPath: '/admin/china-transfers/$id',
      title: 'Buy RMB',
      actions: const [
        ('verify', 'Verify payment', false),
        ('process', 'Start processing', false),
        ('sent', 'Mark RMB sent', true),
        ('complete', 'Complete', false),
        ('reject', 'Reject', false),
        ('fail', 'Fail', false),
        ('cancel', 'Cancel', false),
      ],
    );
  }
}

class SellRmbDetailScreen extends StatelessWidget {
  const SellRmbDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context) {
    return _TransferDetail(
      id: id,
      loadPath: '/admin/sell-rmb/$id',
      title: 'Sell RMB',
      actions: const [
        ('verify', 'Start verification', false),
        ('received', 'RMB received', false),
        ('process', 'Start payout', false),
        ('paid', 'Mark paid', true),
        ('complete', 'Complete', false),
        ('reject', 'Reject', false),
        ('fail', 'Fail', false),
        ('cancel', 'Cancel', false),
      ],
    );
  }
}

class _TransferDetail extends StatefulWidget {
  const _TransferDetail({
    required this.id,
    required this.loadPath,
    required this.title,
    required this.actions,
  });

  final int id;
  final String loadPath;
  final String title;
  final List<(String, String, bool)> actions;

  @override
  State<_TransferDetail> createState() => _TransferDetailState();
}

class _TransferDetailState extends State<_TransferDetail> {
  bool loading = true;
  String? error;
  Map<String, dynamic> item = {};
  bool downloadingQr = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AdminStore>().getJson(widget.loadPath);
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

  Future<void> _run(String action, bool needsProof) async {
    final store = context.read<AdminStore>();
    final base = widget.loadPath;
    try {
      Map<String, dynamic> result;
      if (needsProof) {
        final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
        if (file == null || !mounted) return;
        final amount = await promptText(
          context,
          title: action == 'sent' ? 'RMB sent' : 'Payout amount',
          label: 'Amount',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        );
        if (amount == null || !mounted) return;
        result = await store.postForm(
          '$base/$action',
          {
            if (action == 'sent') 'rmb_sent_amount': amount else 'payout_amount': amount,
          },
          fileField: 'proof',
          filePath: file.path,
        );
      } else if (action == 'reject' || action == 'fail') {
        final reason = await promptText(context, title: 'Reason');
        if (reason == null || !mounted) return;
        result = await store.postJson('$base/$action', data: {'reason': reason});
      } else if (action == 'cancel') {
        result = await store.postJson('$base/$action');
      } else {
        result = await store.postJson('$base/$action');
      }
      if (!mounted) return;
      showSnack(context, str(result['message'], 'Updated.'));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    }
  }

  Future<void> _downloadQr(String url, String reference) async {
    if (downloadingQr) return;
    setState(() => downloadingQr = true);
    try {
      if (!await Gal.hasAccess(toAlbum: true) && !await Gal.requestAccess(toAlbum: true)) {
        if (mounted) showSnack(context, 'Allow photo access to save the QR code.', error: true);
        return;
      }

      final resolved = ApiConfig.resolveMediaUrl(url);
      final dir = await getTemporaryDirectory();
      final safeRef = reference.replaceAll(RegExp(r'[^\w\-]+'), '_');
      final ext = resolved.toLowerCase().contains('.png') ? 'png' : 'jpg';
      final path = '${dir.path}/alipay_qr_$safeRef.$ext';

      await Dio().download(resolved, path);
      await Gal.putImage(path, album: 'CityShop Admin');

      if (!mounted) return;
      showSnack(context, 'QR saved to Photos');
    } catch (e) {
      if (mounted) showSnack(context, 'Could not download QR: $e', error: true);
    } finally {
      if (mounted) setState(() => downloadingQr = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = asMap(item['user']);
    final quote = asMap(item['quote']);
    final breakdown = asMap(quote['breakdown']);
    final fields = asMaps(item['fields']);
    final qrFields = fields.where(_isTransferQrField).toList();
    final textFields = fields.where((f) {
      if (_isTransferQrField(f)) return false;
      final group = str(f['group']).toLowerCase();
      return !['payment', 'payment_proof', 'proof'].contains(group);
    }).toList();
    final funding = str(item['funding_source']);
    final paymentProof = str(item['payment_proof_url']);
    final proofs = asMaps(item['proofs']);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(str(item['reference'], widget.title))),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    _TransferCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            str(user['name'], 'Buyer'),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                          ),
                          if (str(user['mobile']).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(str(user['mobile']), style: const TextStyle(color: AppColors.textSecondary)),
                            ),
                          const SizedBox(height: 10),
                          StatusChip(str(item['status_label'], str(item['status']))),
                        ],
                      ),
                    ),
                    _TransferCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (str(item['funding_source_label']).isNotEmpty)
                            Text(
                              str(item['funding_source_label']),
                              style: const TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w800),
                            ),
                          const SizedBox(height: 8),
                          if (funding == 'rmb_wallet')
                            Text(
                              str(breakdown['rmb'], '¥${asDouble(quote['rmb_amount']).toStringAsFixed(2)}'),
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                            )
                          else ...[
                            Text(
                              str(breakdown['total'], money.format(asDouble(quote['total_payable_ghs']))),
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              str(breakdown['rmb'], '¥${asDouble(quote['rmb_amount']).toStringAsFixed(2)}'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                            ),
                          ],
                          if (str(breakdown['rate_ghs']).isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              str(breakdown['rate_ghs']),
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (qrFields.isNotEmpty)
                      ...qrFields.map((field) {
                        final url = str(field['file_url']);
                        final label = str(field['label'], 'Alipay QR code');
                        return _TransferCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Scan or save this QR when sending RMB on Alipay.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () => _openTransferImage(context, url),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    color: const Color(0xFFF8FAFC),
                                    padding: const EdgeInsets.all(16),
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: CachedNetworkImage(
                                        imageUrl: ApiConfig.resolveMediaUrl(url),
                                        fit: BoxFit.contain,
                                        placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
                                        errorWidget: (_, _, _) => const Center(
                                          child: Icon(Icons.broken_image_outlined, size: 48),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: downloadingQr
                                    ? null
                                    : () => _downloadQr(url, str(item['reference'], 'transfer')),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                icon: downloadingQr
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.download_rounded),
                                label: Text(downloadingQr ? 'Saving…' : 'Download QR'),
                              ),
                              TextButton(
                                onPressed: () => _openTransferImage(context, url),
                                child: const Text('View full size'),
                              ),
                            ],
                          ),
                        );
                      }),
                    if (textFields.isNotEmpty)
                      _TransferCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Recipient details', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            const SizedBox(height: 10),
                            ...textFields.map(
                              (field) => _TransferDetailRow(
                                str(field['label'], str(field['name'], 'Field')),
                                str(field['value'], '—'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (paymentProof.isNotEmpty)
                      _TransferCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Payment proof', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () => _openTransferImage(context, paymentProof),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: AspectRatio(
                                  aspectRatio: 3 / 4,
                                  child: CachedNetworkImage(
                                    imageUrl: ApiConfig.resolveMediaUrl(paymentProof),
                                    fit: BoxFit.contain,
                                    placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
                                    errorWidget: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined)),
                                  ),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _openTransferImage(context, paymentProof),
                              child: const Text('Open full size'),
                            ),
                          ],
                        ),
                      ),
                    if (proofs.isNotEmpty)
                      _TransferCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('RMB sent proof', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            const SizedBox(height: 8),
                            ...proofs.map((proof) {
                              final url = str(proof['url']);
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.receipt_long_outlined, color: AppColors.emerald),
                                title: Text(str(proof['original_name'], 'View proof')),
                                trailing: url.isEmpty
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.open_in_new),
                                        onPressed: () => _openTransferImage(context, url),
                                      ),
                                onTap: url.isEmpty ? null : () => _openTransferImage(context, url),
                              );
                            }),
                          ],
                        ),
                      ),
                    _TransferCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Actions', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          const SizedBox(height: 10),
                          ...widget.actions.map((action) {
                            final destructive = action.$1 == 'reject' || action.$1 == 'fail' || action.$1 == 'cancel';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: OutlinedButton(
                                onPressed: () => _run(action.$1, action.$3),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: destructive ? AppColors.danger : AppColors.textPrimary,
                                  side: BorderSide(color: destructive ? const Color(0xFFFECACA) : const Color(0xFFE5E7EB)),
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(action.$2),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

bool _isTransferQrField(Map<String, dynamic> field) {
  if (str(field['file_url']).isEmpty) return false;
  final type = str(field['type']).toLowerCase();
  final blob = '${field['name'] ?? ''} ${field['label'] ?? ''}'.toLowerCase();
  return ['image', 'document', 'files'].contains(type) || blob.contains('qr');
}

void _openTransferImage(BuildContext context, String url) {
  final resolved = ApiConfig.resolveMediaUrl(url);
  if (resolved.isEmpty) return;
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: resolved,
              fit: BoxFit.contain,
              errorWidget: (_, _, _) => const Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.white, size: 48),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}

class _TransferDetailRow extends StatelessWidget {
  const _TransferDetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}

class ChinaSettingsScreen extends StatefulWidget {
  const ChinaSettingsScreen({super.key});

  @override
  State<ChinaSettingsScreen> createState() => _ChinaSettingsScreenState();
}

class _ChinaSettingsScreenState extends State<ChinaSettingsScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await context.read<AdminStore>().getJson('/admin/china-transfers/settings');
      if (!mounted) return;
      setState(() {
        data = result;
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
    final settings = asMap(data['settings']);
    final rate = asMap(data['current_rate']);
    final enabled = settings['enabled'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Buy RMB settings')),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SwitchListTile(
                      title: const Text('Live for buyers'),
                      subtitle: const Text('Alipay only in China'),
                      value: enabled,
                      onChanged: (value) async {
                        try {
                          await context.read<AdminStore>().postJson('/admin/china-transfers/settings', data: {
                            'enabled': value,
                            'instructions': settings['instructions'],
                          });
                          await _load();
                        } on ApiException catch (e) {
                          if (!context.mounted) return;
                          showSnack(context, e.message, error: true);
                        }
                      },
                    ),
                    Text(() {
                      final rmb = rate['rmb_per_ghs'];
                      final ghs = double.tryParse('${rate['ghs_per_rmb'] ?? ''}');
                      final rmbPerGhs = rmb is num
                          ? rmb.toDouble()
                          : (ghs != null && ghs > 0 ? 1 / ghs : null);
                      if (rmbPerGhs == null || rmbPerGhs <= 0) {
                        return 'Current rate: not set';
                      }
                      final example = (100 * rmbPerGhs).toStringAsFixed(2);
                      return 'Buyers see: 1 GHS = ${rmbPerGhs.toStringAsFixed(4)} RMB\nExample: GH₵100 → ¥$example';
                    }()),
                    Text(
                      'Hours: ${settings['transfer_open_time'] ?? '04:30'} – ${settings['transfer_close_time'] ?? '17:00'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    PrimaryButton(
                      label: 'Edit transfer hours',
                      onPressed: () async {
                        final open = await promptText(
                          context,
                          title: 'Open time',
                          label: 'HH:MM (24h)',
                          initial: '${settings['transfer_open_time'] ?? '04:30'}',
                          keyboardType: TextInputType.text,
                        );
                        if (open == null || !context.mounted) return;
                        final close = await promptText(
                          context,
                          title: 'Close time',
                          label: 'HH:MM (24h)',
                          initial: '${settings['transfer_close_time'] ?? '17:00'}',
                          keyboardType: TextInputType.text,
                        );
                        if (close == null || !context.mounted) return;
                        try {
                          await context.read<AdminStore>().postJson('/admin/china-transfers/settings', data: {
                            'enabled': enabled,
                            'instructions': settings['instructions'],
                            'transfer_open_time': open,
                            'transfer_close_time': close,
                          });
                          if (!context.mounted) return;
                          showSnack(context, 'Transfer hours saved.');
                          await _load();
                        } on ApiException catch (e) {
                          if (!context.mounted) return;
                          showSnack(context, e.message, error: true);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Publish new rate',
                      onPressed: () async {
                        final rmb = await promptText(
                          context,
                          title: 'GHS to RMB Rate',
                          label: '1 GHS = ? RMB (e.g. 0.559)',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        );
                        if (rmb == null || !context.mounted) return;
                        try {
                          await context.read<AdminStore>().postJson('/admin/china-transfers/rates', data: {
                            'rmb_per_ghs': rmb,
                            'fee_mode': 'percent',
                            'fee_value': 0,
                            'min_ghs': 50,
                            'max_ghs': 50000,
                          });
                          if (!context.mounted) return;
                          showSnack(context, 'Rate published.');
                          await _load();
                        } on ApiException catch (e) {
                          if (!context.mounted) return;
                          showSnack(context, e.message, error: true);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Payment methods', style: TextStyle(fontWeight: FontWeight.w800)),
                    ...asMaps(data['methods']).map((method) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(str(method['name'])),
                          trailing: StatusChip(method['active'] == true ? 'active' : 'off'),
                        )),
                  ],
                ),
    );
  }
}

class SellRmbSettingsScreen extends StatefulWidget {
  const SellRmbSettingsScreen({super.key});

  @override
  State<SellRmbSettingsScreen> createState() => _SellRmbSettingsScreenState();
}

class _SellRmbSettingsScreenState extends State<SellRmbSettingsScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await context.read<AdminStore>().getJson('/admin/sell-rmb/settings');
      if (!mounted) return;
      setState(() {
        data = result;
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
    final settings = asMap(data['settings']);
    final rate = asMap(data['current_rate']);
    final enabled = settings['enabled'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Sell RMB settings')),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SwitchListTile(
                      title: const Text('Live for buyers'),
                      value: enabled,
                      onChanged: (value) async {
                        try {
                          await context.read<AdminStore>().postJson('/admin/sell-rmb/settings', data: {
                            'enabled': value,
                            'instructions': settings['instructions'],
                            'receive_instructions': settings['receive_instructions'],
                          });
                          await _load();
                        } on ApiException catch (e) {
                          if (!context.mounted) return;
                          showSnack(context, e.message, error: true);
                        }
                      },
                    ),
                    Text('Buying rate: ${str(rate['ghs_per_rmb'], 'not set')} GHS per RMB'),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Publish buying rate',
                      onPressed: () async {
                        final ghs = await promptText(context, title: 'GHS per 1 RMB', label: 'Rate', keyboardType: const TextInputType.numberWithOptions(decimal: true));
                        if (ghs == null || !context.mounted) return;
                        try {
                          await context.read<AdminStore>().postJson('/admin/sell-rmb/rates', data: {
                            'ghs_per_rmb': ghs,
                            'fee_mode': 'percent',
                            'fee_value': 0,
                            'min_rmb': 50,
                            'max_rmb': 50000,
                          });
                          if (!context.mounted) return;
                          showSnack(context, 'Rate published.');
                          await _load();
                        } on ApiException catch (e) {
                          if (!context.mounted) return;
                          showSnack(context, e.message, error: true);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Receive methods', style: TextStyle(fontWeight: FontWeight.w800)),
                    ...asMaps(data['methods']).map((method) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(str(method['name'])),
                          trailing: StatusChip(method['active'] == true ? 'active' : 'off'),
                        )),
                  ],
                ),
    );
  }
}
