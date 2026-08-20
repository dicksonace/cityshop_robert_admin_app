import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
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
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            leading: _KycThumb(url: item['front_url'] as String?),
            title: Text(str(user['name'], 'User'), style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              '${str(item['ghana_card_number'])}\n${str(item['status_label'], str(item['status']))}',
            ),
            isThreeLine: true,
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

  Color _statusColor(String status) {
    return switch (status) {
      'approved' => AppColors.emerald,
      'rejected' => AppColors.danger,
      'needs_improvement' => const Color(0xFFB45309),
      _ => AppColors.accent,
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = asMap(item['user']);
    final status = str(item['status']);
    final statusColor = _statusColor(status);
    final canDecide = status != 'approved';

    return Scaffold(
      backgroundColor: AppColors.background,
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  str(user['name'], 'User'),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                                ),
                              ),
                              StatusChip(str(item['status_label'], status), color: statusColor),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(str(user['email']), style: const TextStyle(color: AppColors.textSecondary)),
                          Text(str(user['mobile']), style: const TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 14),
                          _InfoRow(label: 'Ghana Card', value: str(item['ghana_card_number'], '—')),
                          _InfoRow(label: 'Name on card', value: str(item['full_name'], '—')),
                          if (str(item['admin_notes']).isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(str(item['admin_notes']), style: const TextStyle(color: AppColors.danger, height: 1.35)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('ID photos', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap a photo to zoom and check the card number.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    _IdPhotoCard(label: 'Front of Ghana Card', url: item['front_url'] as String?),
                    const SizedBox(height: 12),
                    _IdPhotoCard(label: 'Back of Ghana Card', url: item['back_url'] as String?),
                    if (str(item['selfie_url']).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _IdPhotoCard(label: 'Selfie with card', url: item['selfie_url'] as String?, portrait: true),
                    ],
                    if (canDecide) ...[
                      const SizedBox(height: 22),
                      PrimaryButton(
                        label: 'Approve — allow wallet transactions',
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _KycThumb extends StatelessWidget {
  const _KycThumb({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final resolved = ApiConfig.resolveMediaUrl(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 64,
        height: 42,
        color: AppColors.ringOrange,
        child: resolved.isEmpty
            ? const Icon(Icons.badge_outlined, color: AppColors.accent, size: 22)
            : CachedNetworkImage(
                imageUrl: resolved,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const Icon(Icons.badge_outlined, color: AppColors.accent),
              ),
      ),
    );
  }
}

class _IdPhotoCard extends StatelessWidget {
  const _IdPhotoCard({required this.label, this.url, this.portrait = false});

  final String label;
  final String? url;
  final bool portrait;

  @override
  Widget build(BuildContext context) {
    final resolved = ApiConfig.resolveMediaUrl(url);
    final heroTag = 'kyc-photo-$label-$resolved';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: resolved.isEmpty ? null : () => openKycPhotoLightbox(context, url: resolved, label: label, heroTag: heroTag),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: AspectRatio(
                aspectRatio: portrait ? 0.78 : 1.586,
                child: resolved.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFFF8FAFC),
                        child: Center(
                          child: Text('No photo', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Hero(
                            tag: heroTag,
                            child: CachedNetworkImage(
                              imageUrl: resolved,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => const ColoredBox(
                                color: Color(0xFFF8FAFC),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                              errorWidget: (_, _, _) => const ColoredBox(
                                color: Color(0xFFF8FAFC),
                                child: Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted)),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.72)],
                                ),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.fromLTRB(12, 28, 12, 10),
                                child: Row(
                                  children: [
                                    Icon(Icons.zoom_in, color: Colors.white, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Tap to enlarge',
                                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

void openKycPhotoLightbox(
  BuildContext context, {
  required String url,
  required String label,
  required String heroTag,
}) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: _KycPhotoLightbox(url: url, label: label, heroTag: heroTag),
        );
      },
    ),
  );
}

class _KycPhotoLightbox extends StatefulWidget {
  const _KycPhotoLightbox({
    required this.url,
    required this.label,
    required this.heroTag,
  });

  final String url;
  final String label;
  final String heroTag;

  @override
  State<_KycPhotoLightbox> createState() => _KycPhotoLightboxState();
}

class _KycPhotoLightboxState extends State<_KycPhotoLightbox> {
  final _transform = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition;
    if (position == null) return;
    final current = _transform.value.getMaxScaleOnAxis();
    if (current > 1.05) {
      _transform.value = Matrix4.identity();
      return;
    }
    final zoomed = Matrix4.identity()
      ..translateByDouble(-position.dx * 1.5, -position.dy * 1.5, 0, 1)
      ..scaleByDouble(2.5, 2.5, 1, 1);
    _transform.value = zoomed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                onDoubleTapDown: (details) => _doubleTapDetails = details,
                onDoubleTap: _handleDoubleTap,
                child: InteractiveViewer(
                  transformationController: _transform,
                  minScale: 0.8,
                  maxScale: 6,
                  child: Center(
                    child: Hero(
                      tag: widget.heroTag,
                      child: CachedNetworkImage(
                        imageUrl: widget.url,
                        fit: BoxFit.contain,
                        width: MediaQuery.sizeOf(context).width,
                        placeholder: (_, _) => const SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator(color: Colors.white)),
                        ),
                        errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white70, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white),
                    icon: const Icon(Icons.close),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Text(
                'Pinch or double-tap to zoom · Tap outside or ✕ to close',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
