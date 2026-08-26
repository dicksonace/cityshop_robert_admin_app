import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../api/api_config.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

String _formatWhen(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final dt = DateTime.tryParse(raw)?.toLocal();
  if (dt == null) return '';
  return DateFormat('dd/MM/yyyy, h:mm:ss a').format(dt);
}

String _formatMoney(double? amount, {String currency = 'GHS'}) {
  if (amount == null) return '—';
  final prefix = currency == 'GHS' ? 'GH₵' : '$currency ';
  return '$prefix${amount.toStringAsFixed(2)}';
}

Future<void> openChatMedia(String? url) async {
  final resolved = ApiConfig.resolveMediaUrl(url);
  if (resolved.isEmpty) return;
  final uri = Uri.tryParse(resolved);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class AdminChatMessageBubble extends StatelessWidget {
  const AdminChatMessageBubble({
    super.key,
    required this.message,
    required this.buyerId,
  });

  final Map<String, dynamic> message;
  final int? buyerId;

  @override
  Widget build(BuildContext context) {
    final sender = asMap(message['sender']);
    final senderId = asInt(sender['id']);
    final isBuyer = buyerId != null && senderId == buyerId;
    final type = str(message['type'], 'text');
    final createdAt = _formatWhen(message['created_at'] as String?);
    final mediaBubble = {'image', 'video', 'product'}.contains(type) && message['is_deleted'] != true;

    return Align(
      alignment: isBuyer ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.88),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: mediaBubble
              ? const EdgeInsets.fromLTRB(6, 6, 6, 8)
              : const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: isBuyer ? const Color(0xFFFFF7ED) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: mediaBubble ? 6 : 0),
                child: Text(
                  [
                    str(sender['name'], 'User'),
                    if (type != 'text') type.replaceAll('_', ' '),
                    if (createdAt.isNotEmpty) createdAt,
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              AdminChatMessageBody(message: message),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminChatMessageBody extends StatelessWidget {
  const AdminChatMessageBody({super.key, required this.message});

  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    if (message['is_deleted'] == true) {
      return const Text(
        'Message deleted',
        style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textSecondary),
      );
    }

    final type = str(message['type'], 'text');
    switch (type) {
      case 'image':
        return _ImageBody(message: message);
      case 'video':
        return _VideoBody(message: message);
      case 'voice':
        return _VoiceBody(message: message);
      case 'product':
        return _ProductBody(message: message);
      case 'transfer':
        return _TransferBody(message: message);
      case 'file':
        return _FileBody(message: message);
      case 'call_log':
        return _CallLogBody(message: message);
      default:
        return SelectableText(
          str(message['body'], '—'),
          style: const TextStyle(fontSize: 14, height: 1.35),
        );
    }
  }
}

class _ImageBody extends StatelessWidget {
  const _ImageBody({required this.message});
  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final url = ApiConfig.resolveMediaUrl(message['image_url'] as String?);
    final caption = str(message['body']);
    if (url.isEmpty) {
      return const Text('[Photo unavailable]', style: TextStyle(color: AppColors.textSecondary));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: GestureDetector(
            onTap: () => openChatMedia(message['image_url'] as String?),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: 260,
              height: 220,
              errorWidget: (_, _, _) => Container(
                width: 260,
                height: 160,
                color: AppColors.ringOrange,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined, color: AppColors.accent),
              ),
            ),
          ),
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 8),
          SelectableText(caption, style: const TextStyle(fontSize: 14, height: 1.35)),
        ],
        TextButton.icon(
          onPressed: () => openChatMedia(message['image_url'] as String?),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Open photo'),
        ),
      ],
    );
  }
}

class _VideoBody extends StatelessWidget {
  const _VideoBody({required this.message});
  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final url = ApiConfig.resolveMediaUrl(message['video_url'] as String?);
    final caption = str(message['body']);
    if (url.isEmpty) {
      return const Text('[Video unavailable]', style: TextStyle(color: AppColors.textSecondary));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AdminChatVideoPlayer(url: url),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 8),
          SelectableText(caption, style: const TextStyle(fontSize: 14, height: 1.35)),
        ],
        TextButton.icon(
          onPressed: () => openChatMedia(message['video_url'] as String?),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Open video'),
        ),
      ],
    );
  }
}

class _AdminChatVideoPlayer extends StatefulWidget {
  const _AdminChatVideoPlayer({required this.url});
  final String url;

  @override
  State<_AdminChatVideoPlayer> createState() => _AdminChatVideoPlayerState();
}

class _AdminChatVideoPlayerState extends State<_AdminChatVideoPlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _ready = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        width: 260,
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.ringOrange,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text('Could not load video'),
      );
    }
    if (!_ready || _controller == null) {
      return Container(
        width: 260,
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const CircularProgressIndicator(color: Colors.white),
      );
    }
    final controller = _controller!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 260,
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(controller),
              if (!controller.value.isPlaying)
                IconButton.filled(
                  onPressed: () => setState(() => controller.play()),
                  icon: const Icon(Icons.play_arrow),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceBody extends StatelessWidget {
  const _VoiceBody({required this.message});
  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final url = ApiConfig.resolveMediaUrl(message['voice_url'] as String?);
    final seconds = asInt(message['duration_seconds']);
    if (url.isEmpty) {
      return const Text('[Voice message unavailable]', style: TextStyle(color: AppColors.textSecondary));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.mic, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              seconds > 0 ? 'Voice message · ${seconds}s' : 'Voice message',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _AdminChatVoicePlayer(url: url, durationSeconds: seconds > 0 ? seconds : null),
      ],
    );
  }
}

class _AdminChatVoicePlayer extends StatefulWidget {
  const _AdminChatVoicePlayer({required this.url, this.durationSeconds});
  final String url;
  final int? durationSeconds;

  @override
  State<_AdminChatVoicePlayer> createState() => _AdminChatVoicePlayerState();
}

class _AdminChatVoicePlayerState extends State<_AdminChatVoicePlayer> {
  final _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completeSub;
  bool _playing = false;
  bool _loading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    if ((widget.durationSeconds ?? 0) > 0) {
      _duration = Duration(seconds: widget.durationSeconds!);
    }
    _positionSub = _player.onPositionChanged.listen((value) {
      if (!mounted) return;
      setState(() => _position = value);
    });
    _durationSub = _player.onDurationChanged.listen((value) {
      if (!mounted || value.inMilliseconds <= 0) return;
      setState(() => _duration = value);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _loading = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _clock(Duration value) {
    final total = value.inSeconds.clamp(0, 99 * 60);
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _loading = true);
    try {
      if (_position.inMilliseconds == 0) {
        await _player.play(UrlSource(widget.url));
      } else {
        await _player.resume();
      }
      if (!mounted) return;
      setState(() {
        _playing = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _loading = false;
      });
    }
  }

  Future<void> _seek(double value) async {
    final total = _duration.inMilliseconds;
    if (total <= 0) return;
    final next = Duration(milliseconds: (value * total).round());
    await _player.seek(next);
    if (mounted) setState(() => _position = next);
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _duration.inMilliseconds;
    final progress = totalMs > 0 ? (_position.inMilliseconds / totalMs).clamp(0.0, 1.0) : 0.0;
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _loading ? null : _toggle,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_playing ? Icons.pause : Icons.play_arrow),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Slider(
                  value: progress,
                  onChanged: totalMs > 0 ? _seek : null,
                ),
                Text(
                  '${_clock(_position)} / ${_clock(_duration)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductBody extends StatelessWidget {
  const _ProductBody({required this.message});
  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final product = asMap(message['product']);
    if (product.isEmpty) {
      return const Text('[Product]', style: TextStyle(color: AppColors.textSecondary));
    }
    final imageUrl = ApiConfig.resolveMediaUrl(
      product['image_url'] as String? ?? product['image'] as String?,
    );
    return Container(
      width: 260,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      child: Row(
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const NetworkThumb(null, size: 56),
              ),
            )
          else
            const NetworkThumb(null, size: 56),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  str(product['name'], 'Product'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                if (product['price'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatMoney(asDouble(product['price'])),
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferBody extends StatelessWidget {
  const _TransferBody({required this.message});
  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final transfer = asMap(message['transfer']);
    final amount = asDouble(transfer['amount']);
    final currency = str(transfer['currency'], 'GHS');
    final note = str(transfer['note']);
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MONEY TRANSFER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF047857),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatMoney(amount, currency: currency),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF065F46)),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(note, style: const TextStyle(color: Color(0xFF065F46), fontSize: 13)),
          ] else if (str(message['body']).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(str(message['body']), style: const TextStyle(color: Color(0xFF065F46), fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _FileBody extends StatelessWidget {
  const _FileBody({required this.message});
  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final url = ApiConfig.resolveMediaUrl(message['file_url'] as String?);
    final name = str(message['file_name'], 'Attachment');
    final size = asInt(message['file_size']);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: AppColors.ringOrange,
        child: Icon(Icons.insert_drive_file_outlined, color: AppColors.accent),
      ),
      title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: size > 0 ? Text('${(size / 1024).toStringAsFixed(1)} KB') : null,
      trailing: url.isEmpty
          ? null
          : IconButton(
              icon: const Icon(Icons.download_outlined),
              onPressed: () => openChatMedia(message['file_url'] as String?),
            ),
      onTap: url.isEmpty ? null : () => openChatMedia(message['file_url'] as String?),
    );
  }
}

class _CallLogBody extends StatelessWidget {
  const _CallLogBody({required this.message});
  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final call = asMap(message['call_log']);
    final status = str(call['status'], 'completed');
    final seconds = asInt(call['duration_seconds']);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.phone, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          'Voice call · $status${seconds > 0 ? ' · ${seconds}s' : ''}',
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
