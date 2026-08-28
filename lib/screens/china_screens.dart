import 'dart:async';
import 'dart:io' show File;

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
      autoRefreshInterval: const Duration(seconds: 8),
      filterLabelFor: transferStatusFilterLabel,
      filters: const ['open', 'processing', 'rmb_sent', 'completed', 'all'],
      searchHint: 'Search reference or buyer',
      listHeader: (meta) => meta == null ? null : _TransferRmbStatsBar(meta: meta),
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
      autoRefreshInterval: const Duration(seconds: 8),
      filterLabelFor: transferStatusFilterLabel,
      filters: const ['open', 'submitted', 'payout_processing', 'paid', 'completed', 'all'],
      searchHint: 'Search reference or buyer',
      listHeader: (meta) => meta == null ? null : _TransferRmbStatsBar(meta: meta),
      itemBuilder: (item, _) => _TransferTile(
        item: item,
        onTap: () => context.push('/sell-rmb/${item['id']}'),
      ),
    );
  }
}

class _TransferRmbStatsBar extends StatelessWidget {
  const _TransferRmbStatsBar({required this.meta});

  final Map<String, dynamic> meta;

  @override
  Widget build(BuildContext context) {
    final processing = meta['processing'];
    final completed = meta['completed'];
    final today = meta['today'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _TransferStatChip(
              label: 'In progress',
              value: '$processing',
              color: const Color(0xFFDBEAFE),
              textColor: const Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TransferStatChip(
              label: 'Completed',
              value: '$completed',
              color: const Color(0xFFD1FAE5),
              textColor: AppColors.emerald,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TransferStatChip(
              label: 'Today',
              value: '$today',
              color: AppColors.ringOrange,
              textColor: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferStatChip extends StatelessWidget {
  const _TransferStatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
  });

  final String label;
  final String value;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textColor)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor)),
        ],
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
    final reference = str(item['reference'], '#${item['id']}');
    final buyer = str(user['name'], 'Buyer');
    final status = str(item['status_label'], str(item['status']));
    final isSell = str(item['flow']) == 'sell_rmb';
    final amount = quote.isEmpty
        ? ''
        : isSell
            ? '¥${asDouble(quote['rmb_amount']).toStringAsFixed(0)}'
            : str(asMap(quote['breakdown'])['total'], money.format(asDouble(quote['total_payable_ghs'])));

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reference,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$buyer · $status',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (amount.isNotEmpty)
                Text(
                  amount,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textPrimary),
                ),
            ],
          ),
        ),
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
      actionsBuilder: _buyRmbActions,
      actions: const [],
    );
  }
}

List<(String, String, bool)> _buyRmbActions(Map<String, dynamic> item) {
  final status = str(item['status']);
  if (['completed', 'cancelled', 'payment_rejected', 'transfer_failed'].contains(status)) {
    return [];
  }
  if (status == 'rmb_sent') {
    return [
      ('complete', 'Complete', false),
      ('fail', 'Fail', false),
    ];
  }
  if (item['can_upload_proof_and_complete'] == true ||
      ['processing', 'payment_submitted', 'payment_verification'].contains(status)) {
    return [
      ('reject', 'Reject', false),
      ('fail', 'Fail', false),
      if (item['can_cancel'] == true) ('cancel', 'Cancel', false),
    ];
  }
  if (status == 'pending_payment') {
    return [
      if (item['can_cancel'] == true) ('cancel', 'Cancel', false),
    ];
  }
  return [
    ('reject', 'Reject', false),
    ('fail', 'Fail', false),
  ];
}

List<(String, String, bool)> _sellRmbActions(Map<String, dynamic> item) {
  final status = str(item['status']);
  if (['completed', 'cancelled', 'rejected', 'failed'].contains(status)) {
    return [];
  }
  if (status == 'paid') {
    return [
      ('complete', 'Complete', false),
      ('fail', 'Fail', false),
    ];
  }
  if (item['can_mark_paid'] == true) {
    return [
      ('reject', 'Reject', false),
      ('fail', 'Fail', false),
      if (item['can_cancel'] == true) ('cancel', 'Cancel', false),
    ];
  }
  if (status == 'submitted') {
    return [
      ('verify', 'Start verification', false),
      ('reject', 'Reject', false),
      if (item['can_cancel'] == true) ('cancel', 'Cancel', false),
    ];
  }
  if (status == 'rmb_verification') {
    return [
      ('received', 'RMB received', false),
      ('reject', 'Reject', false),
      ('fail', 'Fail', false),
    ];
  }
  if (status == 'rmb_received') {
    return [
      ('process', 'Start payout', false),
      ('fail', 'Fail', false),
    ];
  }
  return [
    ('reject', 'Reject', false),
    ('fail', 'Fail', false),
    if (item['can_cancel'] == true) ('cancel', 'Cancel', false),
  ];
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
      actionsBuilder: _sellRmbActions,
      actions: const [],
    );
  }
}

bool _adminTransferIsTerminal(String? status) {
  return [
    'completed',
    'cancelled',
    'payment_rejected',
    'transfer_failed',
    'refunded',
    'rejected',
    'failed',
  ].contains(status);
}

String _formatProofFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

class _TransferDetail extends StatefulWidget {
  const _TransferDetail({
    required this.id,
    required this.loadPath,
    required this.title,
    required this.actions,
    this.actionsBuilder,
  });

  final int id;
  final String loadPath;
  final String title;
  final List<(String, String, bool)> actions;
  final List<(String, String, bool)> Function(Map<String, dynamic> item)? actionsBuilder;

  @override
  State<_TransferDetail> createState() => _TransferDetailState();
}

class _TransferDetailState extends State<_TransferDetail> {
  bool loading = true;
  String? error;
  Map<String, dynamic> item = {};
  bool downloadingQr = false;
  String? pendingProofPath;
  String? pendingProofName;
  int? pendingProofBytes;
  bool submittingProof = false;
  bool savingPendingProof = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    final status = str(item['status']);
    if (_adminTransferIsTerminal(status)) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _load(silent: true));
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final data = await context.read<AdminStore>().getJson(widget.loadPath);
      if (!mounted) return;
      setState(() {
        item = asMap(data['data']);
        loading = false;
        error = null;
      });
      _schedulePoll();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _pickProofForComplete() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;
    final bytes = await File(file.path).length();
    setState(() {
      pendingProofPath = file.path;
      pendingProofName = file.name;
      pendingProofBytes = bytes;
    });
  }

  void _clearPendingProof() {
    setState(() {
      pendingProofPath = null;
      pendingProofName = null;
      pendingProofBytes = null;
    });
  }

  void _openLocalProof(String path) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
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

  Future<void> _savePendingProofToPhotos() async {
    final path = pendingProofPath;
    if (path == null || savingPendingProof) return;
    setState(() => savingPendingProof = true);
    try {
      if (!await Gal.hasAccess(toAlbum: true) && !await Gal.requestAccess(toAlbum: true)) {
        if (mounted) showSnack(context, 'Allow photo access to save the proof.', error: true);
        return;
      }
      await Gal.putImage(path, album: 'CityShop Admin');
      if (mounted) showSnack(context, 'Proof saved to Photos');
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save proof: $e', error: true);
    } finally {
      if (mounted) setState(() => savingPendingProof = false);
    }
  }

  Future<void> _submitProofAndComplete() async {
    final path = pendingProofPath;
    if (path == null) {
      showSnack(context, 'Add a proof screenshot first.', error: true);
      return;
    }
    if (submittingProof) return;

    final quote = asMap(item['quote']);
    final rmb = asDouble(quote['rmb_amount']);
    if (rmb <= 0) {
      showSnack(context, 'Missing RMB amount on this transfer.', error: true);
      return;
    }

    setState(() => submittingProof = true);
    try {
      final store = context.read<AdminStore>();
      final result = await store.postForm(
        '${widget.loadPath}/complete-with-proof',
        {'rmb_sent_amount': rmb.toStringAsFixed(2)},
        fileField: 'proof',
        filePath: path,
      );
      if (!mounted) return;
      showSnack(context, str(result['message'], 'Transfer completed.'));
      _clearPendingProof();
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => submittingProof = false);
    }
  }

  Future<void> _submitPayoutProof() async {
    final path = pendingProofPath;
    if (path == null) {
      showSnack(context, 'Add a payout proof screenshot first.', error: true);
      return;
    }
    if (submittingProof) return;

    final quote = asMap(item['quote']);
    var payout = asDouble(quote['payout_amount']);
    if (payout <= 0) payout = asDouble(quote['ghs_payout']);
    if (payout <= 0) payout = asDouble(quote['usd_payout']);
    if (payout <= 0) {
      showSnack(context, 'Missing payout amount on this transfer.', error: true);
      return;
    }

    setState(() => submittingProof = true);
    try {
      final store = context.read<AdminStore>();
      final result = await store.postForm(
        '${widget.loadPath}/paid',
        {'payout_amount': payout.toStringAsFixed(2)},
        fileField: 'proof',
        filePath: path,
      );
      if (!mounted) return;
      showSnack(context, str(result['message'], 'Payout marked as paid.'));
      _clearPendingProof();
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => submittingProof = false);
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
        final quote = asMap(item['quote']);
        final String amountStr;
        if (action == 'sent' || action == 'complete-with-proof') {
          final rmb = asDouble(quote['rmb_amount']);
          if (rmb <= 0) {
            showSnack(context, 'Missing RMB amount on this transfer.', error: true);
            return;
          }
          amountStr = rmb.toStringAsFixed(2);
        } else {
          var payout = asDouble(quote['payout_amount']);
          if (payout <= 0) payout = asDouble(quote['ghs_payout']);
          if (payout <= 0) payout = asDouble(quote['usd_payout']);
          if (payout <= 0) {
            showSnack(context, 'Missing payout amount on this transfer.', error: true);
            return;
          }
          amountStr = payout.toStringAsFixed(2);
        }
        final endpoint = action == 'complete-with-proof' ? '$base/complete-with-proof' : '$base/$action';
        result = await store.postForm(
          endpoint,
          {
            if (action == 'sent' || action == 'complete-with-proof')
              'rmb_sent_amount': amountStr
            else
              'payout_amount': amountStr,
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
    final canUploadProofAndComplete = item['can_upload_proof_and_complete'] == true;
    final canMarkPayoutProof = item['can_mark_paid'] == true;
    final isSell = str(item['flow']) == 'sell_rmb';
    final receiveMethod = asMap(item['receive_method']);
    final receiveQr = str(receiveMethod['qr_url']);
    final actions = widget.actionsBuilder?.call(item) ?? widget.actions;
    final status = str(item['status']);
    final terminal = _adminTransferIsTerminal(status);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(str(item['reference'], widget.title)),
        actions: [
          if (!loading && error == null && !terminal)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 6),
                      Text('Auto refresh', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _load(),
          ),
        ],
      ),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
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
                          if (isSell) ...[
                            const Text(
                              'RMB received from buyer',
                              style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              str(breakdown['rmb'], '¥${asDouble(quote['rmb_amount']).toStringAsFixed(2)}'),
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Payout: ${str(breakdown['ghs_payout'], money.format(asDouble(quote['ghs_payout'])))}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                            ),
                            if (str(breakdown['rate']).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                str(breakdown['rate']),
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                          ] else if (str(item['funding_source_label']).isNotEmpty)
                            Text(
                              str(item['funding_source_label']),
                              style: const TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w800),
                            ),
                          if (!isSell) ...[
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
                        ],
                      ),
                    ),
                    if (isSell && receiveQr.isNotEmpty)
                      _TransferCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.qr_code_2_rounded, color: AppColors.emerald),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    str(receiveMethod['name'], 'CityShop Alipay'),
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Buyer sends RMB to this Alipay QR.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => _openTransferImage(context, receiveQr),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  color: const Color(0xFFF8FAFC),
                                  padding: const EdgeInsets.all(16),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: CachedNetworkImage(
                                      imageUrl: ApiConfig.resolveMediaUrl(receiveQr),
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
                            Text(isSell ? 'Payout proof' : 'RMB sent proof', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
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
                    if (canUploadProofAndComplete)
                      _TransferCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.emerald.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.upload_file_rounded, color: AppColors.emerald),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Upload proof & complete', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                      SizedBox(height: 4),
                                      Text(
                                        'Add your Alipay screenshot, review it, then tap Complete.',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (pendingProofPath == null)
                              OutlinedButton.icon(
                                onPressed: _pickProofForComplete,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: Color(0xFF6EE7B7)),
                                ),
                                icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.emerald),
                                label: const Text(
                                  'Add proof screenshot',
                                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.emerald),
                                ),
                              )
                            else ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF6EE7B7)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: AppColors.emerald, size: 20),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'Proof ready for review',
                                            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    GestureDetector(
                                      onTap: () => _openLocalProof(pendingProofPath!),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          color: Colors.white,
                                          padding: const EdgeInsets.all(8),
                                          child: AspectRatio(
                                            aspectRatio: 3 / 4,
                                            child: Image.file(
                                              File(pendingProofPath!),
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, _, _) => const Center(
                                                child: Icon(Icons.broken_image_outlined, size: 48),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      pendingProofName ?? 'proof.jpg',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (pendingProofBytes != null)
                                      Text(
                                        _formatProofFileSize(pendingProofBytes!),
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: _pickProofForComplete,
                                            icon: const Icon(Icons.edit_outlined, size: 18),
                                            label: const Text('Change'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: _clearPendingProof,
                                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                                            icon: const Icon(Icons.close, size: 18),
                                            label: const Text('Remove'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton.icon(
                                            onPressed: () => _openLocalProof(pendingProofPath!),
                                            icon: const Icon(Icons.open_in_full, size: 18),
                                            label: const Text('View full size'),
                                          ),
                                        ),
                                        Expanded(
                                          child: TextButton.icon(
                                            onPressed: savingPendingProof ? null : _savePendingProofToPhotos,
                                            icon: savingPendingProof
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                  )
                                                : const Icon(Icons.download_rounded, size: 18),
                                            label: Text(savingPendingProof ? 'Saving…' : 'Save to Photos'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Check this is the correct Alipay screenshot before completing.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: submittingProof ? null : _submitProofAndComplete,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.emerald,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                icon: submittingProof
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.check_circle_outline),
                                label: Text(submittingProof ? 'Completing…' : 'Complete transfer'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (canMarkPayoutProof)
                      _TransferCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.emerald.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.upload_file_rounded, color: AppColors.emerald),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Upload payout proof', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                      SizedBox(height: 4),
                                      Text(
                                        'Add MoMo/GHS payout screenshot, review it, then mark paid.',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (pendingProofPath == null)
                              OutlinedButton.icon(
                                onPressed: _pickProofForComplete,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: Color(0xFF6EE7B7)),
                                ),
                                icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.emerald),
                                label: const Text(
                                  'Add payout proof',
                                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.emerald),
                                ),
                              )
                            else ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF6EE7B7)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _openLocalProof(pendingProofPath!),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          color: Colors.white,
                                          padding: const EdgeInsets.all(8),
                                          child: AspectRatio(
                                            aspectRatio: 3 / 4,
                                            child: Image.file(
                                              File(pendingProofPath!),
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    FilledButton.icon(
                                      onPressed: submittingProof ? null : _submitPayoutProof,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.emerald,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      icon: submittingProof
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Icon(Icons.payments_outlined),
                                      label: Text(submittingProof ? 'Uploading…' : 'Mark paid'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (str(item['status']) == 'rmb_sent' || (isSell && str(item['status']) == 'paid'))
                      _TransferCard(
                        child: FilledButton(
                          onPressed: () => _run('complete', false),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.emerald,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Complete'),
                        ),
                      ),
                    if (actions.isNotEmpty)
                      _TransferCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Other actions', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            const SizedBox(height: 10),
                            ...actions.map((action) {
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
  bool publishing = false;
  String? error;
  Map<String, dynamic> data = {};
  final _rmbPerGhsController = TextEditingController();
  final _ghsPerRmbController = TextEditingController();
  bool _syncingRates = false;

  @override
  void initState() {
    super.initState();
    _rmbPerGhsController.addListener(_onRmbPerGhsChanged);
    _ghsPerRmbController.addListener(_onGhsPerRmbChanged);
    _load();
  }

  @override
  void dispose() {
    _rmbPerGhsController.removeListener(_onRmbPerGhsChanged);
    _ghsPerRmbController.removeListener(_onGhsPerRmbChanged);
    _rmbPerGhsController.dispose();
    _ghsPerRmbController.dispose();
    super.dispose();
  }

  String _formatRate(double value) {
    if (value <= 0) return '';
    return value.toStringAsFixed(3);
  }

  void _applyRatesFromPayload(Map<String, dynamic> rate) {
    _syncingRates = true;
    final rmbPerGhs = asDouble(rate['rmb_per_ghs']);
    final ghsPerRmb = asDouble(rate['ghs_per_rmb']);
    if (rmbPerGhs > 0) {
      _rmbPerGhsController.text = _formatRate(rmbPerGhs);
      _ghsPerRmbController.text = ghsPerRmb > 0 ? _formatRate(ghsPerRmb) : _formatRate(1 / rmbPerGhs);
    } else if (ghsPerRmb > 0) {
      _ghsPerRmbController.text = _formatRate(ghsPerRmb);
      _rmbPerGhsController.text = _formatRate(1 / ghsPerRmb);
    } else {
      _rmbPerGhsController.text = '0.559';
      _ghsPerRmbController.text = '1.789';
    }
    _syncingRates = false;
  }

  void _onRmbPerGhsChanged() {
    if (_syncingRates) return;
    final cleaned = _rmbPerGhsController.text.replaceAll(RegExp(r'[^\d.]'), '');
    if (cleaned != _rmbPerGhsController.text) {
      _syncingRates = true;
      _rmbPerGhsController.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
      _syncingRates = false;
    }
    final value = double.tryParse(cleaned);
    if (value == null || value <= 0) return;
    _syncingRates = true;
    _ghsPerRmbController.text = _formatRate(1 / value);
    _syncingRates = false;
  }

  void _onGhsPerRmbChanged() {
    if (_syncingRates) return;
    final cleaned = _ghsPerRmbController.text.replaceAll(RegExp(r'[^\d.]'), '');
    if (cleaned != _ghsPerRmbController.text) {
      _syncingRates = true;
      _ghsPerRmbController.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
      _syncingRates = false;
    }
    final value = double.tryParse(cleaned);
    if (value == null || value <= 0) return;
    _syncingRates = true;
    _rmbPerGhsController.text = _formatRate(1 / value);
    _syncingRates = false;
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await context.read<AdminStore>().getJson('/admin/china-transfers/settings');
      if (!mounted) return;
      setState(() {
        data = result;
        loading = false;
      });
      _applyRatesFromPayload(asMap(result['current_rate']));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _publishRate() async {
    final rmb = _rmbPerGhsController.text.trim();
    final parsed = double.tryParse(rmb);
    if (parsed == null || parsed <= 0) {
      showSnack(context, 'Enter a valid GHS to RMB rate (e.g. 0.558).', error: true);
      return;
    }
    setState(() => publishing = true);
    try {
      final rate = asMap(data['current_rate']);
      await context.read<AdminStore>().postJson('/admin/china-transfers/rates', data: {
        'rmb_per_ghs': rmb,
        'fee_mode': rate['fee_mode'] ?? 'percent',
        'fee_value': rate['fee_value'] ?? 0,
        'min_ghs': rate['min_ghs'] ?? 50,
        'max_ghs': rate['max_ghs'] ?? 50000,
        if (rate['daily_max_ghs'] != null) 'daily_max_ghs': rate['daily_max_ghs'],
        if (rate['monthly_max_ghs'] != null) 'monthly_max_ghs': rate['monthly_max_ghs'],
        if (rate['max_per_day'] != null) 'max_per_day': rate['max_per_day'],
        if (rate['approval_above_ghs'] != null) 'approval_above_ghs': rate['approval_above_ghs'],
      });
      if (!mounted) return;
      showSnack(context, 'Rate published.');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => publishing = false);
    }
  }

  Widget _rateField({
    required String label,
    required String unitLeft,
    required String unitRight,
    required TextEditingController controller,
    required String helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text('1', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(width: 8),
            Text(unitLeft, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            const Text('=', style: TextStyle(color: Colors.black54, fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(unitRight, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        Text(helper, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = asMap(data['settings']);
    final rate = asMap(data['current_rate']);
    final enabled = settings['enabled'] == true;
    final liveRmb = asDouble(rate['rmb_per_ghs']);
    final liveGhs = asDouble(rate['ghs_per_rmb']);
    return Scaffold(
      appBar: AppBar(title: const Text('System Settings')),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
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
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text('⇄', style: TextStyle(fontSize: 22, color: Colors.indigo.shade600)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Conversion Rates', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                                      Text('GHS ⇄ RMB', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w700)),
                                      if (liveRmb > 0) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Live: 1 GHS = ${_formatRate(liveRmb)} RMB · 1 RMB = ${_formatRate(liveGhs)} GHS',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _rateField(
                              label: 'GHS to RMB Rate',
                              unitLeft: 'GHS',
                              unitRight: 'RMB',
                              controller: _rmbPerGhsController,
                              helper: 'Shown to buyers with 3 decimals (e.g., 0.558, 0.565, 0.580)',
                            ),
                            const SizedBox(height: 20),
                            _rateField(
                              label: 'RMB to GHS Rate',
                              unitLeft: 'RMB',
                              unitRight: 'GHS',
                              controller: _ghsPerRmbController,
                              helper: 'Synced from RMB rate — 3 decimals (e.g., 1.789, 1.770, 2.300)',
                            ),
                            const SizedBox(height: 16),
                            PrimaryButton(
                              label: publishing ? 'Publishing…' : 'Publish rate',
                              loading: publishing,
                              onPressed: publishing ? null : _publishRate,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
  bool publishing = false;
  bool savingMethod = false;
  bool replacingQr = false;
  String? error;
  Map<String, dynamic> data = {};
  final _ghsPerRmbController = TextEditingController();
  final _minRmbController = TextEditingController(text: '20');
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _receiveInstructionsController = TextEditingController();
  String? _qrPath;
  int? _editingMethodId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ghsPerRmbController.dispose();
    _minRmbController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _instructionsController.dispose();
    _receiveInstructionsController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get readiness => asMap(data['readiness']);

  Map<String, dynamic>? get activeAlipayMethod {
    for (final method in asMaps(data['methods'])) {
      if (method['active'] == true && (method['type'] == 'alipay' || method['type'] == 'wechat')) {
        return method;
      }
    }
    return null;
  }

  void _applyFromPayload() {
    final rate = asMap(data['current_rate']);
    final ghs = asDouble(rate['ghs_per_rmb']);
    if (ghs > 0) {
      _ghsPerRmbController.text = ghs.toStringAsFixed(4);
    }
    final minRmb = asDouble(rate['min_rmb']);
    if (minRmb > 0) {
      _minRmbController.text = minRmb.toStringAsFixed(0);
    }

    final settings = asMap(data['settings']);
    _instructionsController.text = str(settings['instructions']);
    _receiveInstructionsController.text = str(settings['receive_instructions']);

    final method = activeAlipayMethod;
    if (method != null) {
      _editingMethodId = (method['id'] as num?)?.toInt();
      _accountNameController.text = str(method['account_name']);
      _accountNumberController.text = str(method['account_number']);
    } else {
      _editingMethodId = null;
      _accountNameController.text = 'RMB Wallet';
    }
    _qrPath = null;
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await context.read<AdminStore>().getJson('/admin/sell-rmb/settings');
      if (!mounted) return;
      setState(() {
        data = result;
        loading = false;
      });
      _applyFromPayload();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _pickQr() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file == null || !mounted) return;
    setState(() => _qrPath = file.path);
  }

  Future<void> _publishRate() async {
    final ghs = double.tryParse(_ghsPerRmbController.text.trim());
    final minRmb = double.tryParse(_minRmbController.text.trim()) ?? 20;
    if (ghs == null || ghs <= 0) {
      showSnack(context, 'Enter a valid GHS per 1 RMB rate.', error: true);
      return;
    }
    setState(() => publishing = true);
    try {
      await context.read<AdminStore>().postJson('/admin/sell-rmb/rates', data: {
        'ghs_per_rmb': ghs,
        'fee_mode': 'percent',
        'fee_value': 0,
        'min_rmb': minRmb,
        'max_rmb': 50000,
      });
      if (!mounted) return;
      showSnack(context, 'Buying rate published.');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => publishing = false);
    }
  }

  Future<void> _replaceQrOnly() async {
    if (_editingMethodId == null) {
      showSnack(context, 'Save the Alipay method first, then you can replace the QR anytime.', error: true);
      return;
    }
    if (_qrPath == null) {
      showSnack(context, 'Choose the new QR image from your gallery.', error: true);
      return;
    }
    setState(() => replacingQr = true);
    try {
      await context.read<AdminStore>().postForm(
        '/admin/sell-rmb/methods/$_editingMethodId/qr',
        const <String, dynamic>{},
        fileField: 'qr',
        filePath: _qrPath!,
      );
      if (!mounted) return;
      showSnack(context, 'New Alipay QR published. Buyers see it on refresh.');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => replacingQr = false);
    }
  }

  Future<void> _saveAlipayMethod() async {
    final accountName = _accountNameController.text.trim();
    if (accountName.isEmpty) {
      showSnack(context, 'Enter the Alipay account name buyers will see.', error: true);
      return;
    }
    if (_editingMethodId == null && _qrPath == null) {
      showSnack(context, 'Upload your Alipay QR code.', error: true);
      return;
    }
    setState(() => savingMethod = true);
    try {
      final store = context.read<AdminStore>();
      final fields = <String, dynamic>{
        'name': 'Alipay',
        'type': 'alipay',
        'account_name': accountName,
        if (_accountNumberController.text.trim().isNotEmpty) 'account_number': _accountNumberController.text.trim(),
        'proof_required': true,
        'active': true,
      };
      if (_editingMethodId != null) {
        await store.postForm(
          '/admin/sell-rmb/methods/$_editingMethodId',
          fields,
          fileField: _qrPath == null ? null : 'qr',
          filePath: _qrPath,
        );
      } else {
        await store.postForm(
          '/admin/sell-rmb/methods',
          fields,
          fileField: 'qr',
          filePath: _qrPath!,
        );
      }
      if (!mounted) return;
      showSnack(context, 'Alipay receive method saved.');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => savingMethod = false);
    }
  }

  Future<void> _saveInstructions() async {
    final settings = asMap(data['settings']);
    try {
      await context.read<AdminStore>().postJson('/admin/sell-rmb/settings', data: {
        'enabled': settings['enabled'] == true,
        'instructions': _instructionsController.text.trim(),
        'receive_instructions': _receiveInstructionsController.text.trim(),
      });
      if (!mounted) return;
      showSnack(context, 'Instructions saved.');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    }
  }

  String _formatQrUpdated(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Not set yet';
    try {
      return DateTime.parse(raw).toLocal().toString().substring(0, 16);
    } catch (_) {
      return raw;
    }
  }

  Widget _checklistRow(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, color: ok ? Colors.green : Colors.grey, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontWeight: ok ? FontWeight.w700 : FontWeight.w500))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = asMap(data['settings']);
    final enabled = settings['enabled'] == true;
    final open = data['open'] == true;
    final rate = asMap(data['current_rate']);
    final method = activeAlipayMethod;
    final qrUrl = _qrPath != null
        ? null
        : (method?['qr_url'] as String?)?.trim();
    final liveGhs = asDouble(rate['ghs_per_rmb']);

    return Scaffold(
      appBar: AppBar(title: const Text('Sell RMB settings')),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: open ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: open ? const Color(0xFF6EE7B7) : const Color(0xFFFDBA74)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            open ? 'Live for buyers' : 'Not live yet',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: open ? const Color(0xFF047857) : const Color(0xFFC2410C),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            open
                                ? 'Buyers can sell RMB for GHS on the app and website.'
                                : 'Complete all steps below. Buyers see “Paused” until everything is ready.',
                            style: const TextStyle(fontSize: 13, height: 1.35),
                          ),
                          const SizedBox(height: 12),
                          _checklistRow('Live toggle on', readiness['live_toggle'] == true),
                          _checklistRow('Buying rate published', readiness['rate_published'] == true),
                          _checklistRow('Alipay QR uploaded', readiness['alipay_qr'] == true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Live for buyers'),
                      subtitle: const Text('Turn on when rate and Alipay QR are ready'),
                      value: enabled,
                      onChanged: (value) async {
                        try {
                          await context.read<AdminStore>().postJson('/admin/sell-rmb/settings', data: {
                            'enabled': value,
                            'instructions': _instructionsController.text.trim(),
                            'receive_instructions': _receiveInstructionsController.text.trim(),
                          });
                          await _load();
                        } on ApiException catch (e) {
                          if (!context.mounted) return;
                          showSnack(context, e.message, error: true);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Buying rate', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                            if (liveGhs > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, bottom: 12),
                                child: Text(
                                  'Live: 1 RMB = ${liveGhs.toStringAsFixed(4)} GHS',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ),
                            Row(
                              children: [
                                const Text('1 RMB =', style: TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _ghsPerRmbController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      suffixText: 'GHS',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _minRmbController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Minimum RMB amount',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            PrimaryButton(
                              label: publishing ? 'Publishing…' : 'Publish buying rate',
                              loading: publishing,
                              onPressed: publishing ? null : _publishRate,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Alipay QR code', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFDBA74)),
                              ),
                              child: const Text(
                                'Alipay QR codes expire or hit limits. Replace anytime — buyers always get the latest code on refresh.',
                                style: TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF9A3412)),
                              ),
                            ),
                            if (method != null && (method['qr_updated_at'] != null || qrUrl != null)) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Current QR last updated: ${_formatQrUpdated(method['qr_updated_at'] as String?)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                            const SizedBox(height: 12),
                            TextField(
                              controller: _accountNameController,
                              decoration: const InputDecoration(
                                labelText: 'Paid to name',
                                hintText: 'RMB Wallet',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _accountNumberController,
                              decoration: const InputDecoration(
                                labelText: 'Alipay ID / phone (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text('QR preview', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            if (_qrPath != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(File(_qrPath!), height: 200, fit: BoxFit.contain),
                              )
                            else if (qrUrl != null && qrUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(imageUrl: qrUrl, height: 200, fit: BoxFit.contain),
                              )
                            else
                              Container(
                                height: 120,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('No QR uploaded yet', style: TextStyle(color: Colors.black54)),
                              ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _pickQr,
                              icon: const Icon(Icons.upload_file),
                              label: Text(_qrPath != null ? 'Pick new QR image' : (qrUrl != null ? 'Choose replacement QR' : 'Upload QR image')),
                            ),
                            if (_editingMethodId != null && _qrPath != null) ...[
                              const SizedBox(height: 10),
                              PrimaryButton(
                                label: replacingQr ? 'Publishing QR…' : 'Publish new QR now',
                                loading: replacingQr,
                                onPressed: replacingQr ? null : _replaceQrOnly,
                              ),
                            ],
                            const SizedBox(height: 12),
                            PrimaryButton(
                              label: savingMethod ? 'Saving…' : (_editingMethodId == null ? 'Save Alipay method' : 'Save account details'),
                              loading: savingMethod,
                              onPressed: savingMethod ? null : _saveAlipayMethod,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Instructions for buyers', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _instructionsController,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Main instructions',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _receiveInstructionsController,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'On payment step',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            PrimaryButton(label: 'Save instructions', onPressed: _saveInstructions),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => context.push('/sell-rmb'),
                      child: const Text('View pending sell requests'),
                    ),
                  ],
                ),
    );
  }
}
